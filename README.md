# UnifiedInterpreter

[Offline Linux x86_64 executable and usage guide](docs/offline-executable.md)

UnifiedInterpreter is an OCaml 5 prototype for a unified, effect-based
interpreter design inspired by the Huawei AscendNPU IR interpreter question.

The repository also includes a CPU interpreter for the archived HFusion and
HIVM attention MLIR. It parses the input, dispatches OCaml effects to Rocq-extracted
semantics, and compares both stages with an independent float64 reference.
Start with the [user guide](docs/user-guide.md) for environment setup, running
attention, inspecting results and traces, and executing mixed-stage IR.
See the [attention interpreter design](docs/attention-interpreter-design.md) for
the semantic layers, handlers, execution model, code reading guide and limits.

Download native Linux binaries from GitHub Actions or build and run the Docker
image using the [binary distribution and Docker guide](docs/binary-distribution.md).

```sh
ATTENTION_PYTHON=python3.12 sh scripts/bootstrap_attention.sh
export TMPDIR="$PWD/_build/task-tmp"
opam exec --switch=unified-interpreter -- dune build @all
opam exec --switch=unified-interpreter -- dune exec attention -- \
  --stage both --output reports/attention.json --trace reports/attention.jsonl
```

Execute HFusion and HIVM operations together in one function:

```sh
opam exec --switch=unified-interpreter -- dune exec attention -- \
  --stage mixed --ir examples/attention_mixed.mlir \
  --output reports/attention-mixed.json --trace reports/attention-mixed.jsonl
```

Each parsed operation carries an IR stage. The runner selects its computation
handler while sharing SSA values and memory across stages. The mixed example is
manually derived from the archived HFusion input. Trace field `ir_stage` records
each operation's stage; `stage` records the CLI execution mode.

The source interpreter also accepts parsed HFusion and HIVM modules. H1 tracks
instruction sites and the execution budget, H2 maps the active stream to its
block and subblock, H3 evaluates vector and tensor operations, H4 accesses
typed memory, and H5 drives submitted tasks, flags and barriers. Each execution
requests one trace from the scheduler. Previously unseen race prefixes take
priority, followed by other observable schedules for that module and launch.
Requests share a persistent history across processes. Use `--trace-db FILE`
to select a history or `--builtin` to select the autonomous interpreter policy.
Delayed transfers read and write shared storage at completion.

Run the [interpreter benchmark matrix](scripts/check_interpreter_matrix.py)
with the frontend environment and a BiShengIR compiler that supports AVE.
It saves each launch and execution result under `_build/interpreter-matrix`.
For example, these commands prepare the two FIFO runs and repeat the HIVM run
with its instruction locations on standard error.

```sh
opam exec --switch=unified-interpreter -- dune build bin/main.exe
.venv-attention/bin/python scripts/check_interpreter_matrix.py --bishengir-opt "$BISHENGIR_OPT" --filter fifo-copy
_build/default/bin/main.exe run benchmarks/ir-pairs/fixture/fifo-copy/hivm.mlir \
  --stage hivm --launch _build/interpreter-matrix/hivm/fixture/fifo-copy/launch.json --trace
```

JSON output includes execution status,
completed task count, per-stream return values, and the final bytes of each
named storage in `memory_hex`. The `schedule` object contains the delivered
events, their SHA-256, the trace extent and the reuse flag. The first two
scheduled HIVM FIFO runs with a fresh history produce `[7, 7, 7]` and
`[7, 7, 0]` in `gm:0`. OCaml callers use `Ir_scheduler.run_module` with the
parsed module and launch. See the [interface](lib/scheduler/ir_scheduler.mli)
and [trace guide](docs/scheduler-traces.md).

Pass `--scheduled` to the matrix script to request two traces in separate
processes for each benchmark and stage. The [scheduled results](benchmarks/results/scheduled-interpreter-matrix.csv)
record the extent, hash, reuse flag and execution outcome for each request.
The [autonomous results](benchmarks/results/interpreter-matrix.csv) also
record parse time, execution time and peak RSS.

Two small MLIR kernel examples are available in
[`examples/kernels`](examples/kernels): vector addition and row sum, each with
HFusion and HIVM variants. Run them through the same extracted semantics and
effect handlers:

```sh
opam exec --switch=unified-interpreter -- dune exec kernel-example -- --kernel vector-add
opam exec --switch=unified-interpreter -- dune exec kernel-example -- --kernel row-sum
```

See the [kernel walkthrough](docs/user-guide.md#9-运行两个小型-kernel) for inputs,
expected results, trace output and the OCaml interface.

All 84 benchmarks support both BFS and SMT at both IR stages. Use
`race list --hfusion` or `race list --hivm` to inspect the catalog.
`race run cv/scene1/error --hivm --backend smt` returns the launch inputs
and two prefixes in which the conflicting accesses complete in opposite orders.
The interpreter can pass its AST to the [shared OCaml scheduler](lib/scheduler/ir_scheduler.mli).
See the [trace guide](docs/scheduler-traces.md) and the
[BFS and SMT results for each parsed HFusion and HIVM source](benchmarks/results/scheduler-mlir-matrix.csv).
The tensor frontend also supports symbolic loop counts, for example
`race run strided-output --hfusion --backend symbolic`.

Run `dune exec unified-interpreter -- race pairs` to list the HFusion and HIVM
files for all 84 benchmark variants. For a single variant, use
`race pairs cv/scene1/error --json`. The [IR catalog guide](docs/benchmark-ir-pairs.md)
describes the original compiler snapshots, computation-only HFusion projections,
and the command for verifying every pair with BiShengIR.

Run the archived vectorlayout kernel as a concrete Core Lang device AST with
`dune exec unified-interpreter -- vectorlayout --variant fail`. The
[vectorlayout guide](docs/vectorlayout.md) describes the two kernel versions,
physical store coverage, input tensors and trace replay.

The key design point is that there is **one shallow-embedded program language**.
Lowering levels are not represented by separate ASTs. Instead, the same program
is run under a nested stack of non-overlapping algebraic-effect handlers:

```ocaml
H5 { H4 { H3 { H2 { H1 { program } } } } }
```

`H1` is the innermost, highest-level source scope. If `H1` sees an operation
owned by a lower level, it deliberately does not handle it; the effect
propagates outward to `H2`, `H3`, `H4`, or `H5`. This mirrors the five stages
in the Huawei slide and is the extensibility story: users can explicitly
control handler scope and mix levels in one execution.

Handler stacks are ordinary program combinators, not hidden interpreter
configuration. The program itself chooses the surrounding handler stack. A
program can run with the full stack by wrapping its body:

```ocaml
default_handler_stack (fun () ->
  trace "enter vector_add";
  ...)
```

or with only the higher layers:

```ocaml
source_to_simd_stack (fun () ->
  trace "enter vector_add_user_scoped";
  ...)
```

That same program can then introduce a lower-level region:

```ocaml
with_on_chip_memory (fun () ->
  let x_vals = load ~ptr:x ~offsets ~mask ~other:0.0 () in
  let y_vals = load ~ptr:y ~offsets ~mask ~other:0.0 () in
  let sum = fadd x_vals y_vals in
  with_sync_ops (fun () ->
    alloc_local pid "manual_h5_midpoint" 1;
    barrier pid "after_vector_fadd";
    wait pid "after_vector_fadd");
  store ~ptr:out ~offsets ~values:sum ~mask ())
```

In that example, most of the region is explicitly under the H4 on-chip-memory
mapping; the middle block is explicitly H5 sync/async code. The `fadd` still
belongs to H3, so it propagates outward to the surrounding SIMD/T handler.

## Examples

The repository currently focuses on two sourced Triton-like programs plus one
user-scoped variant:

- `vector-add`: based on the Triton-Ascend Vector Addition example.
- `vector-add-user-scoped`: the same vector-add computation, but with memory and
  sync handler scopes chosen inside the program.
- `fused-softmax`: based on the Triton-Ascend Fused Softmax example.

The handler choice is visible in the example source. For instance,
`vector_add_user_scoped_program` starts with:

```ocaml
let vector_add_user_scoped_program ... () =
  source_to_simd_stack (fun () ->
    ...
    with_on_chip_memory (fun () ->
      ...
      with_sync_ops (fun () -> ...)
      ...))
```

All are written as OCaml shallow embeddings using ordinary `let` plus
effectful operations such as:

- `program_id`
- `arange`
- `load` / `store`
- `iadd`, `imul`, `ilt`
- `fadd`, `fsub`, `fdiv`
- `exp`
- `reduce_max`, `reduce_sum`

For example, vector add is not a single primitive command. It is a program:

```ocaml
default_handler_stack (fun () ->
  let pid = program_id 0 in
  let offsets =
    iadd (ibroadcast block_size (pid * block_size)) (arange 0 block_size)
  in
  let mask = ilt offsets (ibroadcast block_size n_elements) in
  let x_vals = load ~ptr:x ~offsets ~mask ~other:0.0 () in
  let y_vals = load ~ptr:y ~offsets ~mask ~other:0.0 () in
  let sum = fadd x_vals y_vals in
  store ~ptr:out ~offsets ~values:sum ~mask ())
```

## Handlers

- `H1/CV-before-map`: owns source-region annotations and forwards executable
  effects.
- `H2/CV-core-map`: owns `program_id` and logical CV core/program instances.
- `H3/SIMD-T-map`: owns vector operations, masks, maps, and reductions.
- `H4/on-chip-memory-map`: owns global `load`/`store` and maps them to UB-local
  traffic.
- `H5/sync-op-async-map`: owns `alloc.local`, `async.copy.in/out`, `wait`, and
  `barrier`.

The handlers are intentionally non-overlapping in the current prototype. For
example, `load` is handled by `H4`, not by `H1`; `fadd` and `reduce_sum` are
handled by `H3`, not by `H1`; `async.copy` and `barrier` are handled by `H5`,
not by `H4`.

## Code Layout

- `lib/language.ml`: shared language types and handler-stage names.
- `lib/effects.ml`: unified effect declarations and shallow-embedding helpers.
- `lib/interpreter.ml`: runtime state and H1-H5 handlers.
- `lib/examples.ml`: the sourced Triton-like programs and user-scoped variant.
- `lib/report.ml`: comparison harness for handler scopes.
- `test/test_unified_interpreter.ml`: acceptance tests for all programs.
- `rocq/`: executable semantic foundation with parameterized values and
  composable state capabilities; see `rocq/README.md`.

## Run

**Scheduling from HIVM or HFusion source.** Pass the parsed module AST and its launch
arguments to `Ir_scheduler.generate_mlir`. The file-based test command is
`race mlir FILE --launch LAUNCH.json --backend smt --hivm`. Both return
source-level events for the interpreter. See the [interpreter interface](docs/scheduler-traces.md),
[source analysis](lib/hivm/mlir_trace.ml) and [source benchmark results](benchmarks/results/scheduler-mlir-matrix.csv).

**Registered benchmark models.** `race list`, `race run NAME` and `race replay FILE`
use the benchmark catalog. For example, `race run issue316/missing-ready --backend smt --n 70`
loads the [parameterized Core Lang model](lib/race_benchmarks.ml). See the
[catalog commands and model inputs](docs/race-benchmarks.md) and [catalog scheduler](lib/scheduler/catalog_scheduler.ml).

Use an OCaml 5 switch:

```sh
opam exec --switch=5.2.0 -- dune exec ./bin/main.exe
```

Run tests:

```sh
opam exec --switch=5.2.0 -- dune test
```

Check the Rocq executable-semantics framework and regenerate its OCaml
extraction artifact:

```sh
./scripts/check_rocq.sh
```

Optional external Python tools can be installed into an isolated local venv:

```sh
./scripts/bootstrap_external_tools.sh
```

## Research Archive

- [`references/README.md`](references/README.md): papers discussed during the
  semantic-design investigation, with checksums.
- [`artifacts/flash_attention/README.md`](artifacts/flash_attention/README.md):
  the archived Triton-Ascend FlashAttention source and HFusion IR snapshot.
- [`docs/research-notes.md`](docs/research-notes.md): design decisions and
  lessons from the related formal-semantics work.
- [`docs/hfusion-instruction-scope.md`](docs/hfusion-instruction-scope.md): the
  concrete instruction and semantic scope for the HFusion milestone.
- `vendor/ascendnpu-ir`: a revision-pinned snapshot of the official AscendNPU
  IR documentation and relevant dialect definitions.

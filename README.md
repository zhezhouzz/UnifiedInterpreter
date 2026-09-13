# UnifiedInterpreter

UnifiedInterpreter is an OCaml 5 prototype for a unified, effect-based
interpreter design inspired by the Huawei AscendNPU IR interpreter question.

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

## Run

Use an OCaml 5 switch:

```sh
opam exec --switch=5.2.0 -- dune exec ./bin/main.exe
```

Run tests:

```sh
opam exec --switch=5.2.0 -- dune test
```

Optional external Python tools can be installed into an isolated local venv:

```sh
./scripts/bootstrap_external_tools.sh
```

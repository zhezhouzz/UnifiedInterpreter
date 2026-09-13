# UnifiedInterpreter

UnifiedInterpreter is an OCaml 5 prototype for comparing a mixed-level,
effect-based AscendNPU-style interpreter with the four routes already explored
in the Huawei problem statement:

- `mlir-runner` / `mlir-cpu-runner`
- `xdsl-run`
- `EmitC`
- Triton interpreter / Triton-Ascend

The current goal is not automatic derivation from Reynolds-style semantic
definitions yet. The current goal is to make the cross-layer effects executable:
program/core mapping, SIMD/T vector behavior, GM/UB memory movement, async copy,
wait/barrier, masks, reductions, and precision points.

## Cases

The demo uses five sourced examples, adapted into a compact internal IR:

- `vector-add`: Triton-Ascend Vector Addition.
- `fused-softmax`: Triton-Ascend Fused Softmax.
- `layer-norm`: Triton-Ascend Layer Normalization.
- `matmul-bias`: Triton-Ascend Matrix Multiplication, `output = x @ y + z`.
- `toy-transpose-mul`: MLIR Toy Tutorial Chapter 5 partial lowering example.

Each case reports:

- source URL and source note
- top IR
- L1 core/program mapping
- L2 vector mapping
- L3 memory/async mapping
- internal numerical agreement
- best-effort status for the four external routes
- extra effect trace explaining what our interpreter can expose when a route is
  unsupported or too low-level

`layer-norm` intentionally uses a `bf16ish` policy, so L2/L3 may differ from the
top-level real-number reference within a small tolerance. That difference is the
  precision diagnostic signal, not a failure.

## Code Layout

- `lib/language.ml`: language definition only. It contains dtypes, primitive
  operation names, top commands, and the L1/L2/L3 IR datatypes plus pretty
  printers.
- `lib/effects.ml`: algebraic effect vocabulary used by the interpreter.
- `lib/interpreter.ml`: the real interpreter: runtime state, effect handlers,
  and evaluators for top/core/vector/memory-async levels.
- `lib/lowering.ml`: lowering passes from top commands to core tasks, vector
  tasks, and memory/async tasks.
- `lib/examples.ml`: sourced examples and case metadata.
- `lib/routes.ml`: best-effort external route status for MLIR runner, xDSL,
  EmitC, and Triton.
- `lib/report.ml`: comparison harness that runs all levels and produces a
  readable report.
- `test/test_unified_interpreter.ml`: acceptance tests over all five cases.

## Run

Use an OCaml 5 switch:

```sh
opam exec --switch=5.2.0 -- dune exec ./bin/main.exe
```

Run the agreement and trace-marker tests:

```sh
opam exec --switch=5.2.0 -- dune test
```

Optional external Python tools can be installed into an isolated local venv:

```sh
./scripts/bootstrap_external_tools.sh
```

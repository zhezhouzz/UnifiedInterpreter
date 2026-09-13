# UnifiedInterpreter

UnifiedInterpreter is an OCaml 5 prototype for a unified, effect-based
interpreter design inspired by the Huawei AscendNPU IR interpreter question.

The key design point is that there is **one shallow-embedded program language**.
Lowering levels are not represented by separate ASTs. Instead, the same program
is run under different algebraic-effect handlers:

```ocaml
H1 { program }
H1 { H2 { program } }
H1 { H3 { program } }
H1 { H4 { program } }
H1 { H4 { H3 { program } } }
```

This is the extensibility story: users can explicitly control handler scope and
mix levels in one execution.

## Examples

The repository currently focuses only on two sourced Triton-like programs:

- `vector-add`: based on the Triton-Ascend Vector Addition example.
- `fused-softmax`: based on the Triton-Ascend Fused Softmax example.

Both are written as OCaml shallow embeddings using ordinary `let` plus
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
let pid = program_id 0 in
let offsets =
  iadd (ibroadcast block_size (pid * block_size)) (arange 0 block_size)
in
let mask = ilt offsets (ibroadcast block_size n_elements) in
let x_vals = load ~ptr:x ~offsets ~mask ~other:0.0 () in
let y_vals = load ~ptr:y ~offsets ~mask ~other:0.0 () in
let sum = fadd x_vals y_vals in
store ~ptr:out ~offsets ~values:sum ~mask ()
```

## Handlers

- `H1/source`: direct source-level semantics.
- `H2/core`: binds `program_id` to logical core/program instances.
- `H3/vector`: handles vector operations, masks, maps, and reductions.
- `H4/memory-async`: lowers loads/stores into local-buffer, async-copy,
  wait, and barrier effects.

`H1` is used as a fallback handler in the demo so that focused handlers can
choose which effects to interpret and let the rest propagate outward.

## Code Layout

- `lib/language.ml`: shared language types and pure helpers.
- `lib/effects.ml`: unified effect declarations and shallow-embedding helpers.
- `lib/interpreter.ml`: runtime state and H1-H4 handlers.
- `lib/examples.ml`: the two sourced Triton-like programs.
- `lib/report.ml`: comparison harness for handler scopes.
- `test/test_unified_interpreter.ml`: acceptance tests for both programs.

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

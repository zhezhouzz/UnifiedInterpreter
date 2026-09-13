# UnifiedInterpreter

UnifiedInterpreter is an OCaml 5 prototype for a unified, effect-based
interpreter design inspired by the Huawei AscendNPU IR interpreter question.

The key design point is that there is **one shallow-embedded program language**.
Lowering levels are not represented by separate ASTs. Instead, the same program
is run under a nested stack of non-overlapping algebraic-effect handlers:

```ocaml
H4 { H3 { H2 { H1 { program } } } }
```

`H1` is the innermost, highest-level source scope. If `H1` sees an operation
owned by a lower level, it deliberately does not handle it; the effect
propagates outward to `H2`, `H3`, or `H4`. This is the extensibility story:
users can explicitly control handler scope and mix levels in one execution.

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

- `H1/source`: owns source-region annotations and forwards executable effects.
- `H2/core`: owns `program_id` and logical core/program instances.
- `H3/vector`: owns vector operations, masks, maps, and reductions.
- `H4/memory-async`: owns loads/stores and lowers them into local-buffer, async-copy,
  wait, and barrier effects.

The handlers are intentionally non-overlapping in the current prototype. For
example, `load` is handled by `H4`, not by `H1`; `fadd` and `reduce_sum` are
handled by `H3`, not by `H1`.

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

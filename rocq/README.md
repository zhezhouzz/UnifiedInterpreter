# Rocq Executable Semantics

This directory contains the executable-semantics foundation for the HFusion
interpreter. Its definitions are organized around three constraints:

1. Every instruction semantics is a total Rocq function.
2. An instruction depends only on the state components it reads or writes.
3. Proof-only laws live in `Prop`, so extraction erases them.

The current milestone is deliberately small. It establishes the abstraction
boundaries and includes one executable allocation instruction, lifting through
capability lenses, frame lemmas, a smoke test, and an OCaml extraction entry
point. It does not yet attempt to parse or execute the complete FlashAttention
artifact.

## Layout

- `Base`: result, state-and-trace computation, and lawful lenses.
- `Value`: data types and a parameterized scalar interface.
- `Memory`: allocation and descriptor state, independent of unified state.
- `Unified`: concrete events, errors, capabilities, and the first unified state.
- `HFusion`: instruction functions assembled from the smaller capabilities.
- `Examples`: executable examples and basic proofs.
- `Extraction`: OCaml extraction boundary.

## Native Rocq build and extraction

The project uses Rocq's native `_CoqProject + rocq makefile + make` workflow.
Compiled `.vo`, `.vos`, `.vok`, and `.glob` files are written beside their
corresponding `.v` sources so Rocq IDEs can resolve imported modules.

Select the Rocq 9.1 environment and invoke the generated Makefile:

```sh
opam switch with-rocq-1
eval $(opam env)
cd rocq
make
```

`opam` selects the compiler environment only; `make` performs the build using
Rocq's native dependency graph. The checked-in `Makefile` is generated from
`_CoqProject` using:

```sh
rocq makefile -f _CoqProject -o Makefile
```

For CI or a one-command check from either the repository root or `rocq/`, use:

```sh
../scripts/check_rocq.sh
```

The wrapper runs native `make` inside the selected opam environment and then
checks the extracted OCaml with `ocamlc`. A direct command such as
`rocq compile Extraction/Extract.v` does not recursively build imports and
therefore fails on a clean checkout.

The generated OCaml belongs under `Extraction/` and is not edited by hand.

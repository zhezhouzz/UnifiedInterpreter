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

## Build

The repository currently uses the `with-rocq-1` opam switch for Rocq 9.1:

```sh
./scripts/check_rocq.sh
```

To regenerate the extracted OCaml file after a successful check:

```sh
cd rocq
opam exec --switch=with-rocq-1 -- rocq compile \
  -Q . UnifiedInterpreter Extraction/Extract.v
```

The generated extraction output belongs under `_build` and is not edited by
hand.

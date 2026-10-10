# Rocq Executable Semantics

This directory contains the executable-semantics foundation for the HFusion
interpreter. Its definitions are organized around three constraints:

1. Every instruction semantics is a total Rocq function.
2. An instruction depends only on the state components it reads or writes.
3. Proof-only laws live in `Prop`, so extraction erases them.

The current milestone is deliberately small. It establishes the abstraction
boundaries and includes one executable allocation instruction, lifting through
a top-level capability lens, finite-map locality lemmas, a smoke test, and an
OCaml extraction entry point. It does not yet attempt to parse or execute the complete FlashAttention
artifact.

## Layout

- `Base`: result, atomic state computation, and lawful top-level lenses.
- `Value`: data types and a parameterized scalar interface.
- `Tensor`: pure n-dimensional values with shape, element type, and row-major
  logical elements. Tensors have no allocation identity or mutable aliasing.
- `Memory`: stdpp `gmap` buffers and descriptors, independent of unified state.
  A buffer is typed linear storage with allocation identity. A descriptor maps
  n-dimensional coordinates to storage using offset, sizes, and strides.
  Buffers also carry the HIVM address space (`GM`, `UB`, `L1`, `L0A/B/C`, and
  specialized buffers); `ASDefault` represents placement not yet decided.
- `Unified`: errors, optional observation events, capabilities, and the first
  unified state.
- `HFusion`: instruction functions assembled from the smaller capabilities.
- `Examples`: executable examples and basic proofs.
- `Extraction`: OCaml extraction boundary.

## Current semantic choices

The core computation type is:

```coq
State -> result Error (Value * State)
```

A failed atomic instruction exposes no successor state. Events are not an
input to this computation and cannot be inspected by instructions;
`Unified/Events.v` currently defines only a vocabulary for a future external
observer.

`Lens` is used only to embed fixed components such as memory into a larger
machine state. It is not claimed to provide separation semantics. Dynamic
allocation locality comes from stdpp finite-map facts such as
`lookup_insert_eq` and `lookup_insert_ne`.

`Memory.read_view` is the explicit boundary from memory to tensor: it resolves
a descriptor, reads the corresponding buffer cells, and returns an independent
tensor value. Creating the descriptor itself is metadata-only and does not copy
or allocate storage.

## Native Rocq build and extraction

The project uses Rocq's native `_CoqProject + rocq makefile + make` workflow.
Compiled `.vo`, `.vos`, `.vok`, and `.glob` files are written beside their
corresponding `.v` sources so Rocq IDEs can resolve imported modules.

The switch must contain `rocq-stdpp`. Select the Rocq 9.1 environment and
invoke the generated Makefile:

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

# UnifiedInterpreter

This is a small OCaml 5 prototype for explaining why an AscendNPU IR
interpreter should support multiple IR levels instead of only one final IR.

The example is a tiny CV-style tensor command:

```text
C[M,N] = relu(A[M,K] @ B[K,N] + Bias[N])
```

For a real convolution, `M` can stand for `batch * height * width`, `N` for
output channels, and `K` for input channels. This keeps the example compact
while still exposing the compilation issues that matter: CV-core mapping,
SIMD/T vectorization, on-chip memory, DMA, waits, barriers, and precision
points.

## IR levels

- `L0 Top`: one tensor command.
- `L1 Core`: tile the output matrix and launch one CV-core task per tile.
- `L2 Vector`: lower each tile to vector FMA and vector max blocks.
- `L3 MemAsync`: make global memory, on-chip buffers, async copies, waits,
  barriers, and stores explicit.

All evaluators are written against the same OCaml 5 algebraic effects:

- `Read_tensor` / `Write_tensor`
- `Launch_core`
- `Vector_fma` / `Vector_max`
- `Alloc_local` / `Read_local` / `Write_local`
- `Async_copy_in` / `Async_copy_out`
- `Wait` / `Barrier`
- `Trace`

The point is not to derive the interpreter automatically yet. The point is to
first make the cross-layer effects explicit and executable.

## Run

Use an OCaml 5 switch:

```sh
opam exec --switch=5.2.0 -- dune exec unified-interpreter
```

Run the agreement test:

```sh
opam exec --switch=5.2.0 -- dune test
```

# Triton kernel compiler artifacts

The complete workflow and supported compilation parameters are documented in
`docs/user-guide.md`, sections 2–4. After generation, run
`sh scripts/check_compiled_kernels.sh` to compare all three kernels against
their reference computations (24 executions).

`_attn_fwd.*.mlir` is compiled from the two Triton JIT functions in the archived
attention tutorial using Python AST loading. Its signature follows source order:
Q/K/V f16, M f32, Out f16, acc f32, sm_scale f32. The fixed configuration is
Z=H=1, N_CTX=HEAD_DIM=128, BLOCK_M=32, BLOCK_N=128, STAGE=1.
Attention additionally uses `convert-math-to-hfusion` and
`convert-linalg-to-hfusion`. Its HIVM conversion uses `canonicalize-ext` followed
by `convert-hfusion-to-hivm=mm-map-mode=macro_instr`.

`add_kernel.*.mlir` contains dynamic vector addition with BLOCK_SIZE=256,
masked loads/stores and an i32 runtime length. These artifacts and attention
retain their compiled entry ABI and are executed directly.

`examples/kernels/source/kernels.py` defines vector addition and row sum in
Triton. Vector addition processes two blocks of four elements. Row sum processes
three rows of four elements. Both loops use `tl.static_range`, so the compiler
emits one independent output segment per block or row.

The compiler environment uses Python 3.10, `triton-ascend==3.2.0` and
`ascendnpu-ir==1.2.0`. Regenerate all artifacts from the repository root:

```sh
TRITON_PYTHON=python3.10 ATTENTION_PYTHON=python3.12 sh scripts/generate_kernel_ir.sh
```

The command installs the pinned compiler dependencies under `_build/`, compiles
the source, verifies the resulting MLIR with `bishengir-opt`, and prepares the
interpreter examples. It needs no NPU execution or device binary generation.

For each kernel this directory contains:

- `*.ttir.mlir`: Triton AST compilation and TTIR optimization output.
- `*.hfusion.mlir`: the official Triton-Ascend adapter's named-operation output,
  followed by `bishengir-opt --convert-arith-to-hfusion`.
- `*.hivm.mlir`: the HFusion artifact compiled with
  `bishengir-opt --convert-hfusion-to-hivm`.

`provenance.json` records source hashes, package versions, compiler executable
hashes, specialization constants, conversion options and artifact hashes. The
target selected for the compiler frontend is `Ascend910B1`.

`scripts/prepare_kernel_ir.py` uses xDSL to specialize the compiled entry ABI:
it supplies the known static f32 argument shapes, names the arguments for the
OCaml bindings, and removes unused synchronization, workspace and grid
arguments. The computation and memory operations are cloned from the compiler
artifacts. This produces the `*_hfusion.mlir` and `*_hivm.mlir` interpreter
inputs in `examples/kernels`.

The same script creates each `*_mixed.mlir` by cloning the first output segment
from HFusion and subsequent segments from HIVM, including their SSA
dependencies. Vector addition writes elements 0–3 through HFusion and 4–7
through HIVM. Row sum writes row 0 through HFusion and rows 1–2 through HIVM.
All segments share the function arguments and interpreter memory. Numerical
results retain the original kernel definitions. `examples/kernels/provenance.json`
records the input/output hashes and the stage chosen for each segment.

CI regenerates the artifacts and checks their contents against the repository.
The interpreter tests exercise two input sets in all three execution modes and
verify both computation handlers appear in mixed traces. Docker and relocated
binary checks also execute both mixed kernels.

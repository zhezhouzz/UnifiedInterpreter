### Environment

AscendNPU-IR HIVM pipeline targeting `Ascend950PR_9579`. Tracking ID `DTS2026111639735`.

### Reproduction

GEN-1749 stages an FP32 broadcast in L1, extracts a row or a column, and inserts it into a zero-filled matmul operand. Layout propagation stops at the UB-to-L1 copy. In the column case, transpose lowering pads a live `16×1` column to `16×8` and emits `tensor.expand_shape` from 128 elements to 16. MLIR verification fails before batch matmul tiling.

The compact conversion alone reproduces the invalid reshape with `bishengir-opt --hivm-convert-layout-to-transpose --verify-each`.

```mlir
func.func @live_column(%arg: tensor<16x1xf32>) -> tensor<1x1x16x1xf32> {
  %p = hivm.hir.convert_layout %arg output_shape [1, 1, 16, 1]
      {srcLayout = #hivm.data_layout<ND>,
       dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 8]>}
      : (tensor<16x1xf32>) -> tensor<1x1x16x1xf32>
  return %p : tensor<1x1x16x1xf32>
}
```

### Expected behavior

Preserve the live column’s 16 elements. Assemble the zero-filled Fractal operand on the vector side, then copy the completed tile to L1. Matmuls sharing an operand should read the same initialized buffer.

The fix and regression tests are in [!5303](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5303).

### Physical A5 verification

The layout-only revision `c404c86cec81` compiled the original program. FP16 and signed INT16 at lengths 128 and 126 then faulted on all eight launches across the stock and archived compiler settings (device error `507015`). The Cube predicate loaded its singleton i32 loop counter from CBUF.

Revision `3b682d4956d7` keeps that counter in scalar SSA and packs the sliced matmul inputs before copying them to L1. On physical Ascend950PR_9579, all 110 original tests passed against PyTorch with the stock settings (11 dtypes, ranks 1–5, aligned and tail inputs). The four FP16 and signed INT16 cases also passed with the archived O2 flags. The original source and comparison tolerances were used for all 114 runs, with zero mismatches across 14,852 values.
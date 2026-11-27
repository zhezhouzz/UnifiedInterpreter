### 环境信息
            
```
例如：
- Operating system: <OS and version>
- Ascend hardware information: Ascend950PR_9589 (regbase)
- CANN software version: <CANN version>
- bishengir-compile: <version / commit>
```

### 🐛 问题描述
            
### Summary

Triton FP8 kernels that use **scalar** `f8E4M3FN` / `f8E5M2` values fail to compile on the regbase pipeline. There are two related symptoms:

1. **Normalize aborts** when a scalar-to-tensor cast requests a rounding mode that the shared rounding-mode selection does not provide for `f8`.
2. **The backend rejects the emitted LLVM IR** when a conditional scalar `f8` value is lowered: an `f8` constant ends up inside an LLVM `phi`, and the    BiSheng backend fails to parse it with `expected value token`.

Tensor `f8` conversions are unaffected; only the scalar path is broken.

### Affected scenario

A Triton FP8 kernel loads a scalar `f8` bias under a mask (`scf.if`), extends it to `f32`, adds it to an integer-derived scalar, narrows the result back to `f8`, and broadcasts it with a `linalg.fill`.

### Minimal reproducible example

`repro.mlir`:

```mlir
module attributes {hacc.target = #hacc.target<"Ascend950PR_9589">} {
  func.func @masked_scalar_f8_bias_add(%bias: memref<?xf8E4M3FN>, %dst: memref<?xf8E4M3FN>,
                                    %rows: i32, %block: i32, %sum: i32,
                                    %row_stride: i32, %col_stride: i32, %total: i32, %pid: i32)
      attributes {hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %zero = arith.constant 0.0 : f8E4M3FN
    %c0 = arith.constant 0 : index
    %c128 = arith.constant 128 : i32
    %bias_index = arith.remsi %rows, %c128 : i32
    %mask = arith.cmpi slt, %bias_index, %c128 : i32
    %bias_offset = arith.index_cast %bias_index : i32 to index
    %bias_view = memref.reinterpret_cast %bias to offset: [%bias_offset], sizes: [1], strides: [1] : memref<?xf8E4M3FN> to memref<1xf8E4M3FN, strided<[1], offset: ?>>
    %value = scf.if %mask -> (f8E4M3FN) {
      %loaded = memref.load %bias_view[%c0] : memref<1xf8E4M3FN, strided<[1], offset: ?>>
      scf.yield %loaded : f8E4M3FN
    } else {
      scf.yield %zero : f8E4M3FN
    }
    %extended = arith.extf %value {round_mode = #hfusion.round_mode<rint>} : f8E4M3FN to f32
    %sum_f32 = arith.sitofp %sum : i32 to f32
    %scalar = arith.addf %sum_f32, %extended : f32
    %truncated = arith.truncf %scalar {round_mode = #hfusion.round_mode<rint>} : f32 to f8E4M3FN
    %empty = tensor.empty() : tensor<128xf8E4M3FN>
    %filled = linalg.fill ins(%truncated : f8E4M3FN) outs(%empty : tensor<128xf8E4M3FN>) -> tensor<128xf8E4M3FN>
    bufferization.materialize_in_destination %filled in writable %dst : (tensor<128xf8E4M3FN>, memref<?xf8E4M3FN>) -> ()
    return
  }
}
```

Reproduce with:

```bash
bishengir-compile repro.mlir \
  --target=Ascend950PR_9589 \
  --enable-hfusion-compile=true \
  --enable-triton-kernel-compile \
  -o repro.o
```

### Where the error is (in the IR)

The `f8` result of `scf.if` lowers to an LLVM `phi` whose incoming value is an `f8` constant:

```llvm
%value = phi float8e4m3 [ %loaded, %then ], [ 0xP00, %else ]
```

### Actual behavior

- Normalize fails for the scalar cast because the requested rounding mode is   not selected for `f8` by the shared rounding-mode selection logic.
- The backend rejects the `phi` above:

```text
LLVM ERROR: expected value token
```

### Expected behavior

The kernel compiles successfully. A conditional scalar `f8` selection must not leave `f8` constants in LLVM `phi` nodes, and casts (bidirectional) between `f32` and `f8` must use a defined rounding mode.
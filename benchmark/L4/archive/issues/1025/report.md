### 🐛 问题描述
            
HFusion Simplify removes `f32 → fp8 → f32` cast chains even when the downcast has no `arith.fastmath<contract>` attribute. This skips the intermediate FP8 quantization and rounding, so downstream operations consume the original FP32 value instead of the FP8-rounded value.

FP8 legalization implements arithmetic through FP32 upcasts and FP8 downcasts. Consecutive operations can therefore create the following chain:

```text
                            /-- folded --\
f8 in1 -> f32 -+-> f32 op1 -> f8 -> f32 -+-> f32 op2 -> f8 out
               |                         |
f8 in2 -> f32 -+         f8 in3 -> f32 --+
```

Removing the middle downcast/upcast changes the calculation semantics. Reference calculations that explicitly perform these casts can consequently disagree with the compiled result.

### Minimal reproducer

Save the following IR, adapted from PR [!4137](https://gitcode.com/Ascend/AscendNPU-IR/pull/4137), as `fp8-cast-repro.mlir`:

```mlir
func.func @fp8DownUp(%arg0: tensor<f32>) -> tensor<f32> {
  %empty_f8 = tensor.empty() : tensor<f8E4M3FN>
  %empty_f32 = tensor.empty() : tensor<f32>
  %0 = hfusion.cast ins(%arg0 : tensor<f32>) outs(%empty_f8 : tensor<f8E4M3FN>) -> tensor<f8E4M3FN>
  %1 = hfusion.cast ins(%0 : tensor<f8E4M3FN>) outs(%empty_f32 : tensor<f32>) -> tensor<f32>
  return %1 : tensor<f32>
}
```

Run from the repository root:

```bash
build/bin/bishengir-opt fp8-cast-repro.mlir --hfusion-simplify-ops
```

### Actual result

The locally observed output is:

```mlir
module {
  func.func @fp8DownUp(%arg0: tensor<f32>) -> tensor<f32> {
    return %arg0 : tensor<f32>
  }
}
```

Both casts disappear. The command succeeds without an exception; this is a semantic miscompilation, not a crash.

### Expected result

Without explicit permission to discard intermediate rounding, preserve the FP32 → FP8 → FP32 conversion semantics. For the minimal reproducer, both casts should remain, as in the input IR.

For example, under round-to-nearest-even, `1.0625` becomes `1.0` after conversion to `f8E4M3FN` and back to FP32; returning the original FP32 value is not equivalent. Overflow behavior must likewise follow the selected cast mode rather than be bypassed.

### Related PRs

- **[!4137](https://gitcode.com/Ascend/AscendNPU-IR/pull/4137), by @anaumchev:** replaced the hand-written ranking with `FloatType::getFPMantissaWidth()`. It added tests preserving untagged E4M3FN/E5M2 round trips and allowing explicitly `contract`-tagged chains to fold. The change was subsequently reverted by commit `ba2d3bd67` (merged through !4214). The revert message states that !4137 introduced a new failure and explicitly notes that FP8 down/up chains would be folded again. The draft identifies this as a new DTS failure; the specific failing case still needs to be established before reintroducing the fix.
- **[!5175](https://gitcode.com/Ascend/AscendNPU-IR/pull/5175), by @stewartxiang:** addresses the same missing FP8 ranking for issue #961 / PD-1865. Its discussion includes the runtime results above and a subsequent change to derive precision rank from significand width. Its fix should be evaluated against the regression that prompted the !4137 revert, not only the newly passing FP8 cases.

### Resolution considerations

The resolution needs to balance correctness and performance *based on FP8 operational semantics agreement*:

1. **Recognize FP8 in precision ranking and preserve untagged down/up chains.** This restores the existing lossiness guard. Validate the prior regression as well as FP8 rounding, overflow, and explicitly tagged folding cases.
2. **Recognize FP8 and explicitly permit folding where relaxed semantics are intended.** Adding fastmath permission during legalization would retain current folding behavior, but also deliberately discard intermediate FP8 rounding. Such permission must follow an agreed semantic contract, not be added solely to recover performance or pass tests. **Reference tests must also be adapted to reflect the agreed semantics.**
3. **Align reference tests with the agreed contract.** If relaxed FP32-intermediate semantics are intentional, document them and adjust the relevant reference calculations. 


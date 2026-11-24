### 环境信息
            
CANN: 9.3.0
Triton: 3.6.0
### 🐛 问题描述
            
### Description:

The HFusion flattener prevents valid dimension collapsing when a rank-reducing slice drops an intermediate dimension.

### Example:

```
func.func @insert_slice(
    %src: tensor<12x450xi32>,
    %dst: tensor<12x2x450xi32>) -> tensor<12x2x450xi32> {
  %result = tensor.insert_slice %src into %dst[0, 0, 0]
      [12, 1, 450] [1, 1, 1]
      : tensor<12x450xi32> into tensor<12x2x450xi32>
  return %result : tensor<12x2x450xi32>
}
```

Run with:

```
bishengir-opt repro.mlir \
  -hfusion-flatten-ops="flatten-mode=tidy register-based=true multi-dynamic-shape=false"
```

### Actual behavior

The destination remains *tensor<12x2x450xi32>*, although its last two dimensions can legally collapse.

### Expected behavior

Collapse the destination to *tensor<12x900xi32>* and rebuild the insertion as:

```
tensor.insert_slice %src into %collapsed_dst[0, 0]
    [12, 450] [1, 1]
    : tensor<12x450xi32> into tensor<12x900xi32>
```

This preserves the insertion’s semantics: each source row fills the first 450 elements of the corresponding 900-element destination row.

### Cause

Slice-boundary propagation disconnects both sides of the boundary between retained dimensions. Since connectivity constraints are shared with the corresponding source dimensions, this unnecessarily splits an otherwise contiguous source group on the opposite side of a dropped dimension.

The analysis should preserve the required boundary while allowing neighboring contiguous groups to collapse. It must also retain protection against invalid rank reduction and handle partial dimensions, multiple dropped dimensions, offsets, and non-unit strides.


### 环境信息
            
CANN: 9.3.0
Triton: 3.6.0
### 🐛 问题描述
            
### Issue description:

The HFusion flattener can generate an invalid tensor.extract_slice when rank reduction drops dimensions between retained source dimensions that belong to different collapse groups.

Reproducer:

```
func.func @rank_reducing_slice_boundary(
    %arg: tensor<2x1x2x2xi32>) -> tensor<2x2xi32> {
  %slice = tensor.extract_slice %arg[0, 0, 0, 0]
      [2, 1, 1, 2] [1, 1, 1, 1]
      : tensor<2x1x2x2xi32> to tensor<2x2xi32>
  return %slice : tensor<2x2xi32>
}
```

Run with:

```
bishengir-opt repro.mlir \
  -hfusion-flatten-ops="flatten-mode=tidy register-based=true multi-dynamic-shape=false"
```

### Actual behavior

The pass collapses the source to tensor<2x4xi32> and rebuilds the slice with selected sizes [2, 2] but result type tensor<4xi32>. Verification fails because slice rank reduction can only drop dimensions of size 1; it cannot merge two non-unit dimensions.

```
expected type to be 'tensor<2x2xi32>' or a rank-reduced version.
(size mismatch)
```

### Expected behavior

The pass should preserve compatible source and result collapse groups and produce valid IR. For this reproducer, the slice result should remain tensor<2x2xi32>.

### Cause

Dimension analysis does not propagate all source collapse boundaries across dropped dimensions into the slice result. Boundaries introduced by other source users after the slice is visited can also be missed, making the outcome depend on visitation order.

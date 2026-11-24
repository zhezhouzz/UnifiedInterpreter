### 环境信息
            
CANN: 9.3.0
Triton 3.6.0
### 🐛 问题描述
            
hfusion-flatten-ops aborts when reconstructing a tensor.extract_slice whose source is an scf.while region argument.

### Reproducer

```
func.func @while_slice(%arg: tensor<32xf32>, %n: index,
                      %cond: i1) -> tensor<?xf32> {
  %r = scf.while (%x = %arg) : (tensor<32xf32>) -> tensor<32xf32> {
    scf.condition(%cond) %x : tensor<32xf32>
  } do {
  ^bb0(%x: tensor<32xf32>):
    %s = tensor.extract_slice %x[0] [%n] [1]
      : tensor<32xf32> to tensor<?xf32>
    %i = tensor.insert_slice %s into %arg[0] [%n] [1]
      : tensor<?xf32> into tensor<32xf32>
    scf.yield %i : tensor<32xf32>
  }
  %s = tensor.extract_slice %r[0] [%n] [1]
    : tensor<32xf32> to tensor<?xf32>
  return %s : tensor<?xf32>
}
```

Command:

```
bishengir-opt repro.mlir \
  -hfusion-flatten-ops="flatten-mode=tidy register-based=true multi-dynamic-shape=false"
```

The failure also occurs with *use-preorder-walk-traversal=false*.

### Actual behavior

In an assertions-enabled build, the pass aborts with:

```
Assertion `detail::isPresent(Val) &&
"dyn_cast on a non-existent value"' failed.
```

The failure occurs in *Flattener::calculateSliceStrides()* in *Collapser.cpp*:

`dyn_cast<RankedTensorType>(previousType_[src]);`

The source is the while after-region’s *%x* argument. Its original type was not recorded in the flattener’s *previousType_* map, so the lookup supplies a null type to *dyn_cast*.

### Expected behavior

The pass should process this valid IR without crashing. It should record the original types needed for slice reconstruction and preserve compatible types across while operands, region arguments, condition/yield operands, and results.

Until coordinated while-signature rewriting is supported, retaining the original boundary ranks is acceptable. Independent operations inside the loop should remain eligible for flattening.

### Impact

Valid programs containing slices of while-carried tensors cannot complete the flattening pass. The reproducer uses rank-one tensors, so the crash occurs even when no dimension collapse is required.

Motivation: hfusion-flatten-ops crashes when rebuilding a slice whose
source is an scf.while region argument because the argument's original
type is missing. This change adds dedicated while-loop analysis and
signature rewriting, fixing GEN-1411 and allowing fully static shapes
to collapse consistently across loop boundaries.

### IR for reproduction:

```mlir
func.func @while_slice(%arg: tensor<128xf32>, %n: index,
                      %cond: i1) -> tensor {
  %r = scf.while (%x = %arg) : (tensor<128xf32>) -> tensor<128xf32> {
    scf.condition(%cond) %x : tensor<128xf32>
  } do {
  ^bb0(%x: tensor<128xf32>):
    %s = tensor.extract_slice %x[0] [%n] [1]
      : tensor<128xf32> to tensor
    %i = tensor.insert_slice %s into %x[0] [%n] [1]
      : tensor into tensor<128xf32>
    scf.yield %i : tensor<128xf32>
  }
  %s = tensor.extract_slice %r[0] [%n] [1]
    : tensor<128xf32> to tensor
  return %s : tensor
}
```

Run:

```bash
bishengir-opt repro.mlir \
  -hfusion-flatten-ops="flatten-mode=tidy register-based=true multi-dynamic-shape=false"
```

### Failed MLIR:
```mlir
func.func @while_dynamic_slice(%input: tensor<128xf32>, %n: index,
                              %count: i32) -> tensor<128xf32> {
  %c0 = arith.constant 0 : i32
  %result = scf.while (%before = %input, %counter = %count)
      : (tensor<128xf32>, i32) -> tensor<128xf32> {
    %cond = arith.cmpi sgt, %counter, %c0 : i32
    scf.condition(%cond) %before : tensor<128xf32>
  } do {
  ^bb0(%after: tensor<128xf32>):
    // old flatten fails while transering this slice.
    %slice = tensor.extract_slice %after[0] [%n] [1]
      : tensor<128xf32> to tensor<?xf32>
    %next = tensor.insert_slice %slice into %after[0] [%n] [1]
      : tensor<?xf32> into tensor<128xf32>
    scf.yield %next, %c0 : tensor<128xf32>, i32
  }
  return %result : tensor<128xf32>
}
```
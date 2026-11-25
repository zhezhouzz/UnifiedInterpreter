A 2D elementwise chain that contains `arith.select` on tensors makes the pass
emit *invalid IR*: the operands get collapsed to rank 1, the selects result
type is left at the original rank, and the op no longer verifies.

Repro (`bishengir-opt %s -hfusion-flatten-ops="flatten-mode=tidy register-based=true"`):

```
func.func @with_select(%a: tensor<16x64xf32>, %b: tensor<16x64xf32>, %c: i1) -> tensor<16x64xf32> {
  %0 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>}
         ins(%a, %b : tensor<16x64xf32>, tensor<16x64xf32>)
         outs(%a : tensor<16x64xf32>) -> tensor<16x64xf32>
  %s = arith.select %c, %0, %b : tensor<16x64xf32>
  %1 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>}
         ins(%s, %b : tensor<16x64xf32>, tensor<16x64xf32>)
         outs(%b : tensor<16x64xf32>) -> tensor<16x64xf32>
  return %1 : tensor<16x64xf32>
```


Output:


```
%3 = "arith.select"(%arg2, %2, %0) : (i1, tensor<1024xf32>, tensor<1024xf32>) -> tensor<16x64xf32>
%4 = "linalg.elemwise_binary"(%3, %0, %0) : (tensor<16x64xf32>, tensor<1024xf32>, tensor<1024xf32>) -> tensor<1024xf32>
```


```
error: 'arith.select' op failed to verify that all of {true_value, false_value, result} have same type
```

The same chain without the select flattens correctly to tensor<1024xf32>. **Also need to check all the operators for same issue**
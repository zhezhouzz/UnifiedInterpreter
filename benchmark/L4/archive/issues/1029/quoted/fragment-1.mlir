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

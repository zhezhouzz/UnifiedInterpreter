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

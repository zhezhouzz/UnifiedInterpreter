func.func @tensor_entry_add(%a: tensor<8xf32>, %b: tensor<8xf32>, %out: memref<8xf32>) {
  %empty = tensor.empty() : tensor<8xf32>
  %sum = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%a, %b : tensor<8xf32>, tensor<8xf32>) outs(%empty : tensor<8xf32>) -> tensor<8xf32>
  bufferization.materialize_in_destination %sum in writable %out : (tensor<8xf32>, memref<8xf32>) -> ()
  return
}

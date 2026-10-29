func.func @vector_add(%a: memref<8xf32>, %b: memref<8xf32>, %out: memref<8xf32>) {
  %a_tensor = bufferization.to_tensor %a restrict : memref<8xf32>
  %b_tensor = bufferization.to_tensor %b restrict : memref<8xf32>
  %empty = tensor.empty() : tensor<8xf32>
  %sum = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%a_tensor, %b_tensor : tensor<8xf32>, tensor<8xf32>) outs(%empty : tensor<8xf32>) -> tensor<8xf32>
  bufferization.materialize_in_destination %sum in writable %out : (tensor<8xf32>, memref<8xf32>) -> ()
  return
}

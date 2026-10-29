func.func @row_sum(%input: memref<3x4xf32>, %out: memref<3xf32>) {
  %input_tensor = bufferization.to_tensor %input restrict : memref<3x4xf32>
  %empty = tensor.empty() : tensor<3x1xf32>
  %sum = hivm.hir.vreduce <sum> ins(%input_tensor : tensor<3x4xf32>) outs(%empty : tensor<3x1xf32>) reduce_dims = [1] -> tensor<3x1xf32>
  %collapsed = tensor.collapse_shape %sum [[0, 1]] : tensor<3x1xf32> into tensor<3xf32>
  bufferization.materialize_in_destination %collapsed in writable %out : (tensor<3xf32>, memref<3xf32>) -> ()
  return
}

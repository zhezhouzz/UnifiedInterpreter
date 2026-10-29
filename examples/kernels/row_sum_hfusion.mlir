func.func @row_sum(%input: memref<3x4xf32>, %out: memref<3xf32>) {
  %input_tensor = bufferization.to_tensor %input restrict : memref<3x4xf32>
  %zero = arith.constant 0.0 : f32
  %empty = tensor.empty() : tensor<3xf32>
  %init = linalg.fill ins(%zero : f32) outs(%empty : tensor<3xf32>) -> tensor<3xf32>
  %sum = linalg.reduce ins(%input_tensor : tensor<3x4xf32>) outs(%init : tensor<3xf32>) dimensions = [1]
    (%element: f32, %acc: f32) {
      %next = arith.addf %element, %acc : f32
      linalg.yield %next : f32
    }
  bufferization.materialize_in_destination %sum in writable %out : (tensor<3xf32>, memref<3xf32>) -> ()
  return
}

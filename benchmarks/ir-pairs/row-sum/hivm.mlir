module {
  func.func @row_sum(%arg0: memref<3x4xf32>, %arg1: memref<3xf32>) {
    %cst = arith.constant 0.000000e+00 : f32
    %0 = bufferization.to_tensor %arg0 restrict : memref<3x4xf32>
    %1 = tensor.empty() : tensor<3xf32>
    %2 = hivm.hir.vbrc ins(%cst : f32) outs(%1 : tensor<3xf32>) -> tensor<3xf32>
    %expanded = tensor.expand_shape %2 [[0, 1]] output_shape [3, 1] : tensor<3xf32> into tensor<3x1xf32>
    %3 = hivm.hir.vreduce <sum> ins(%0 : tensor<3x4xf32>) outs(%expanded : tensor<3x1xf32>) reduce_dims = [1] -> tensor<3x1xf32>
    %collapsed = tensor.collapse_shape %3 [[0, 1]] : tensor<3x1xf32> into tensor<3xf32>
    bufferization.materialize_in_destination %collapsed in writable %arg1 : (tensor<3xf32>, memref<3xf32>) -> ()
    return
  }
}


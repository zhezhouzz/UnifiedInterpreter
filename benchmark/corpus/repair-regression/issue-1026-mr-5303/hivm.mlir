module {
  func.func @nd_to_fractal_aligned_f16(%arg0: tensor<128x144xf16>) -> tensor<9x8x16x16xf16> {
    %expanded = tensor.expand_shape %arg0 [[0], [1, 2]] output_shape [128, 9, 16] : tensor<128x144xf16> into tensor<128x9x16xf16>
    %0 = tensor.empty() : tensor<9x128x16xf16>
    %1 = hivm.hir.vtranspose ins(%expanded : tensor<128x9x16xf16>) outs(%0 : tensor<9x128x16xf16>) permutation = [1, 0, 2] -> tensor<9x128x16xf16>
    %expanded_0 = tensor.expand_shape %1 [[0], [1, 2], [3]] output_shape [9, 8, 16, 16] : tensor<9x128x16xf16> into tensor<9x8x16x16xf16>
    return %expanded_0 : tensor<9x8x16x16xf16>
  }
}


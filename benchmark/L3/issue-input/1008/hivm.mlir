module attributes {hacc.target = #hacc.target<"Ascend950PR_957b">} {
  func.func @rtz_broadcast_normalized(%arg0: tensor<16xf32>) -> tensor<16x16xf16> {
    %0 = tensor.empty() : tensor<16x16xf32>
    %expanded = tensor.expand_shape %arg0 [[0, 1]] output_shape [1, 16] : tensor<16xf32> into tensor<1x16xf32>
    %1 = hivm.hir.vbrc ins(%expanded : tensor<1x16xf32>) outs(%0 : tensor<16x16xf32>) broadcast_dims = [0] -> tensor<16x16xf32>
    %2 = tensor.empty() : tensor<16x16xf16>
    %3 = hivm.hir.vcast {enable_overflow = true, enable_saturate = false, hivm.unsigned_mode = #hivm.unsigned_mode<si2si>} ins(%1 : tensor<16x16xf32>) outs(%2 : tensor<16x16xf16>) round_mode = <trunc> -> tensor<16x16xf16>
    return %3 : tensor<16x16xf16>
  }
}


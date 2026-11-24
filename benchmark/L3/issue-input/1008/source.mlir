module attributes {hacc.target = #hacc.target<"Ascend950PR_957b">} {
  func.func @rtz_broadcast_normalized(%src: tensor<16xf32>) -> tensor<16x16xf16> {
    %empty = tensor.empty() : tensor<16x16xf32>
    %brc = linalg.broadcast ins(%src : tensor<16xf32>) outs(%empty : tensor<16x16xf32>) dimensions = [0]
    %init = tensor.empty() : tensor<16x16xf16>
    %r = hfusion.cast {round_mode = #hfusion.round_mode<trunc>}
        ins(%brc : tensor<16x16xf32>) outs(%init : tensor<16x16xf16>) -> tensor<16x16xf16>
    return %r : tensor<16x16xf16>
  }
}

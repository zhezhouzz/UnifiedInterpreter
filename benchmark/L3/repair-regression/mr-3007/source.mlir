module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @dot_abs(%4: tensor<16x16xf16>, %e4: tensor<16x16xf16>) -> tensor<16x16xf32> {
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %7 = tensor.empty() : tensor<16x16xf32>
    %8 = hivm.hir.mmadL1 ins(%4, %e4, %true, %c16, %c16, %c16 : tensor<16x16xf16>, tensor<16x16xf16>, i1, index, index, index) outs(%7 : tensor<16x16xf32>) -> tensor<16x16xf32>
    %9 = tensor.empty() : tensor<16x16xf32>
    %10 = hivm.hir.vabs ins(%8 : tensor<16x16xf32>) outs(%9 : tensor<16x16xf32>) -> tensor<16x16xf32>
    return %10 : tensor<16x16xf32>
  }
}

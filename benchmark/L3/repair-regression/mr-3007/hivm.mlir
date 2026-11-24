module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @dot_abs(%arg0: tensor<16x16xf16>, %arg1: tensor<16x16xf16>) -> tensor<16x16xf32> {
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %0 = tensor.empty() : tensor<16x16xf32>
    %1 = hivm.hir.mmadL1 {fixpipe_for_result_already_inserted = true} ins(%arg0, %arg1, %true, %c16, %c16, %c16 : tensor<16x16xf16>, tensor<16x16xf16>, i1, index, index, index) outs(%0 : tensor<16x16xf32>) -> tensor<16x16xf32>
    %2 = tensor.empty() {hivm.address_space = #hivm.address_space<ub>, "hivm.inserted-tensor"} : tensor<16x16xf32>
    %3 = hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%1 : tensor<16x16xf32>) outs(%2 : tensor<16x16xf32>) -> tensor<16x16xf32>
    %4 = tensor.empty() : tensor<16x16xf32>
    %5 = hivm.hir.vabs ins(%3 : tensor<16x16xf32>) outs(%4 : tensor<16x16xf32>) -> tensor<16x16xf32>
    return %5 : tensor<16x16xf32>
  }
}


module {
  func.func @pair(%arg0: tensor<bf16>) -> tensor<bf16> {
    %0 = tensor.empty() : tensor<f32>
    %1 = tensor.empty() : tensor<bf16>
    %2 = hivm.hir.vcast ins(%arg0 : tensor<bf16>) outs(%0 : tensor<f32>) -> tensor<f32>
    %3 = hivm.hir.vcast ins(%2 : tensor<f32>) outs(%1 : tensor<bf16>) -> tensor<bf16>
    return %3 : tensor<bf16>
  }
}


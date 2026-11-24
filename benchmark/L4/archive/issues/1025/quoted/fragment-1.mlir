func.func @fp8DownUp(%arg0: tensor<f32>) -> tensor<f32> {
  %empty_f8 = tensor.empty() : tensor<f8E4M3FN>
  %empty_f32 = tensor.empty() : tensor<f32>
  %0 = hfusion.cast ins(%arg0 : tensor<f32>) outs(%empty_f8 : tensor<f8E4M3FN>) -> tensor<f8E4M3FN>
  %1 = hfusion.cast ins(%0 : tensor<f8E4M3FN>) outs(%empty_f32 : tensor<f32>) -> tensor<f32>
  return %1 : tensor<f32>
}

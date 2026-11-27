func.func @pair(%arg0: tensor<bf16>) -> tensor<bf16> {
    %empty_f32 = tensor.empty() : tensor<f32>
    %empty_bf16 = tensor.empty() : tensor<bf16>
    %0 = hfusion.cast {arith.fastmath = #arith.fastmath<contract>} ins(%arg0 : tensor<bf16>) outs(%empty_f32 : tensor<f32>) -> tensor<f32>
    %1 = hfusion.cast {arith.fastmath = #arith.fastmath<contract>} ins(%0 : tensor<f32>) outs(%empty_bf16 : tensor<bf16>) -> tensor<bf16>
    return %1 : tensor<bf16>
}

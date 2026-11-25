module {
  func.func @propagate_up_from_for_result(%arg0: tensor<16x16xf16>, %arg1: index, %arg2: index, %arg3: index) -> tensor<1x1x16x16xf16> {
    %0 = hivm.hir.convert_layout %arg0 output_shape [1, 1, 16, 16] {dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>, srcLayout = #hivm.data_layout<ND>} : (tensor<16x16xf16>) -> tensor<1x1x16x16xf16>
    %1 = scf.for %arg4 = %arg1 to %arg2 step %arg3 iter_args(%arg5 = %0) -> (tensor<1x1x16x16xf16>) {
      %2 = tensor.empty() : tensor<1x1x16x16xf16>
      %3 = hivm.hir.vexp ins(%arg5 : tensor<1x1x16x16xf16>) outs(%2 : tensor<1x1x16x16xf16>) -> tensor<1x1x16x16xf16>
      scf.yield %3 : tensor<1x1x16x16xf16>
    }
    return %1 : tensor<1x1x16x16xf16>
  }
}


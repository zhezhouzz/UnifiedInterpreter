func.func @propagate_up_from_for_result(
  %init: tensor<16x16xf16>, %lb: index, %ub: index, %step: index
) -> tensor<1x1x16x16xf16> {
  %r = scf.for %iv = %lb to %ub step %step
      iter_args(%arg = %init) -> (tensor<16x16xf16>) {
    %tmp = tensor.empty() : tensor<16x16xf16>
    %mid = hivm.hir.vexp ins(%arg : tensor<16x16xf16>) outs(%tmp : tensor<16x16xf16>) -> tensor<16x16xf16>
    scf.yield %mid : tensor<16x16xf16>
  }

  %r_up = hivm.hir.convert_layout %r output_shape [1, 1, 16, 16]
    {dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>,
     srcLayout = #hivm.data_layout<ND>}
    : (tensor<16x16xf16>) -> tensor<1x1x16x16xf16>

  return %r_up : tensor<1x1x16x16xf16>
}

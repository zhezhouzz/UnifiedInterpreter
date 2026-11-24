func.func @live_column(%arg: tensor<16x1xf32>) -> tensor<1x1x16x1xf32> {
  %p = hivm.hir.convert_layout %arg output_shape [1, 1, 16, 1]
      {srcLayout = #hivm.data_layout<ND>,
       dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 8]>}
      : (tensor<16x1xf32>) -> tensor<1x1x16x1xf32>
  return %p : tensor<1x1x16x1xf32>
}

func.func @nd_to_fractal_aligned_f16(%arg0: tensor<128x144xf16>) -> tensor<9x8x16x16xf16> {
  %0 = hivm.hir.convert_layout %arg0 output_shape [9, 8, 16, 16]
       {dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>,
        srcLayout = #hivm.data_layout<ND, transpose = false>}
       : (tensor<128x144xf16>) -> tensor<9x8x16x16xf16>
  return %0 : tensor<9x8x16x16xf16>
}

func.func @packed_column_and_row(%cols: tensor<16x16xf32>, %rows: tensor<16x16xf32>) -> tensor<1x1x16x16xf32> {
  %true = arith.constant true
  %c16 = arith.constant 16 : index
  %zero = arith.constant 0.0 : f32
  %empty_a = tensor.empty() {hivm.address_space = #hivm.address_space<cbuf>} : tensor<2x1x16x8xf32>
  %az = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<CUBE>} ins(%zero : f32) outs(%empty_a : tensor<2x1x16x8xf32>) -> tensor<2x1x16x8xf32>
  %empty_b = tensor.empty() : tensor<16x16xf32>
  %bz = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<CUBE>} ins(%zero : f32) outs(%empty_b : tensor<16x16xf32>) -> tensor<16x16xf32>
  %abuf = memref.alloc() : memref<16x16xf32, #hivm.address_space<cbuf>>
  %av = bufferization.to_tensor %abuf restrict writable : memref<16x16xf32, #hivm.address_space<cbuf>>
  hivm.hir.copy ins(%cols : tensor<16x16xf32>) outs(%abuf : memref<16x16xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
  %col = tensor.extract_slice %av[0, 0] [16, 1] [1, 1] : tensor<16x16xf32> to tensor<16x1xf32>
  %live = hivm.hir.convert_layout %col output_shape [1, 1, 16, 1] {srcLayout = #hivm.data_layout<ND>, dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 8]>} : (tensor<16x1xf32>) -> tensor<1x1x16x1xf32>
  %a = tensor.insert_slice %live into %az[0, 0, 0, 0] [1, 1, 16, 1] [1, 1, 1, 1] : tensor<1x1x16x1xf32> into tensor<2x1x16x8xf32>
  %bbuf = memref.alloc() : memref<16x16xf32, #hivm.address_space<cbuf>>
  %bv = bufferization.to_tensor %bbuf restrict writable : memref<16x16xf32, #hivm.address_space<cbuf>>
  hivm.hir.copy ins(%rows : tensor<16x16xf32>) outs(%bbuf : memref<16x16xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
  %row = tensor.extract_slice %bv[0, 0] [1, 16] [1, 1] : tensor<16x16xf32> to tensor<1x16xf32>
  %bm = tensor.insert_slice %row into %bz[0, 0] [1, 16] [1, 1] : tensor<1x16xf32> into tensor<16x16xf32>
  %b = hivm.hir.convert_layout %bm output_shape [2, 1, 16, 8] {srcLayout = #hivm.data_layout<ND>, dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 8]>} : (tensor<16x16xf32>) -> tensor<2x1x16x8xf32>
  %acc = tensor.empty() : tensor<1x1x16x16xf32>
  %dot = hivm.hir.mmadL1 ins(%a, %b, %true, %c16, %c16, %c16 : tensor<2x1x16x8xf32>, tensor<2x1x16x8xf32>, i1, index, index, index) outs(%acc : tensor<1x1x16x16xf32>) -> tensor<1x1x16x16xf32>
  return %dot : tensor<1x1x16x16xf32>
}

module {
  func.func @packed_column_and_row(%arg0: tensor<16x16xf32>, %arg1: tensor<16x16xf32>) -> tensor<1x1x16x16xf32> {
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %cst = arith.constant 0.000000e+00 : f32
    %0 = tensor.empty() {hivm.address_space = #hivm.address_space<cbuf>} : tensor<2x1x16x8xf32>
    %1 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<CUBE>} ins(%cst : f32) outs(%0 : tensor<2x1x16x8xf32>) -> tensor<2x1x16x8xf32>
    %2 = tensor.empty() : tensor<16x16xf32>
    %3 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<CUBE>} ins(%cst : f32) outs(%2 : tensor<16x16xf32>) -> tensor<16x16xf32>
    %alloc = memref.alloc() : memref<16x16xf32, #hivm.address_space<cbuf>>
    %4 = bufferization.to_tensor %alloc restrict writable : memref<16x16xf32, #hivm.address_space<cbuf>>
    hivm.hir.copy ins(%arg0 : tensor<16x16xf32>) outs(%alloc : memref<16x16xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
    %extracted_slice = tensor.extract_slice %4[0, 0] [16, 1] [1, 1] : tensor<16x16xf32> to tensor<16x1xf32>
    %5 = hivm.hir.convert_layout %extracted_slice output_shape [1, 1, 16, 1] {dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 8]>, srcLayout = #hivm.data_layout<ND>} : (tensor<16x1xf32>) -> tensor<1x1x16x1xf32>
    %inserted_slice = tensor.insert_slice %5 into %1[0, 0, 0, 0] [1, 1, 16, 1] [1, 1, 1, 1] : tensor<1x1x16x1xf32> into tensor<2x1x16x8xf32>
    %alloc_0 = memref.alloc() : memref<16x16xf32, #hivm.address_space<cbuf>>
    %6 = bufferization.to_tensor %alloc_0 restrict writable : memref<16x16xf32, #hivm.address_space<cbuf>>
    hivm.hir.copy ins(%arg1 : tensor<16x16xf32>) outs(%alloc_0 : memref<16x16xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
    %extracted_slice_1 = tensor.extract_slice %6[0, 0] [1, 16] [1, 1] : tensor<16x16xf32> to tensor<1x16xf32>
    %inserted_slice_2 = tensor.insert_slice %extracted_slice_1 into %3[0, 0] [1, 16] [1, 1] : tensor<1x16xf32> into tensor<16x16xf32>
    %7 = hivm.hir.convert_layout %inserted_slice_2 output_shape [2, 1, 16, 8] {dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 8]>, srcLayout = #hivm.data_layout<ND>} : (tensor<16x16xf32>) -> tensor<2x1x16x8xf32>
    %8 = tensor.empty() : tensor<1x1x16x16xf32>
    %9 = hivm.hir.mmadL1 ins(%inserted_slice, %7, %true, %c16, %c16, %c16 : tensor<2x1x16x8xf32>, tensor<2x1x16x8xf32>, i1, index, index, index) outs(%8 : tensor<1x1x16x16xf32>) -> tensor<1x1x16x16xf32>
    return %9 : tensor<1x1x16x16xf32>
  }
}


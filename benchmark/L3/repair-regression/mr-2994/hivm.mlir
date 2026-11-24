module attributes {hacc.target = #hacc.target<"Ascend910B4">} {
  func.func @test_MmadL1_Normalize_decompose_matmul(%arg0: memref<16x16xf32>) -> tensor<16x16xf32> {
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %0 = bufferization.to_tensor %arg0 restrict writable : memref<16x16xf32>
    %alloc = memref.alloc() : memref<16x16xf16>
    %1 = bufferization.to_tensor %alloc restrict writable : memref<16x16xf16>
    %alloc_0 = memref.alloc() : memref<16x16xf16>
    %2 = bufferization.to_tensor %alloc_0 restrict writable : memref<16x16xf16>
    %3 = tensor.empty() : tensor<16x16xf32>
    %4 = hivm.hir.load ins(%0 : tensor<16x16xf32>) outs(%3 : tensor<16x16xf32>) -> tensor<16x16xf32>
    %5 = tensor.empty() : tensor<16x16xf32>
    %6 = hivm.hir.mmadL1 {already_set_real_mkn, normalized_in_L0C} ins(%1, %2, %true, %c16, %c16, %c16 : tensor<16x16xf16>, tensor<16x16xf16>, i1, index, index, index) outs(%5 : tensor<16x16xf32>) -> tensor<16x16xf32>
    %7 = tensor.empty() : tensor<16x16xf32>
    %8 = hivm.hir.vadd ins(%6, %4 : tensor<16x16xf32>, tensor<16x16xf32>) outs(%7 : tensor<16x16xf32>) -> tensor<16x16xf32>
    return %8 : tensor<16x16xf32>
  }
}


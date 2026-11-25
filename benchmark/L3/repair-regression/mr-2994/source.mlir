module attributes {hacc.target = #hacc.target<"Ascend910B4">} {

func.func @test_MmadL1_Normalize_decompose_matmul(%arg0: memref<16x16xf32>) -> tensor<16x16xf32> {
    %cst = arith.constant 0.000000e+00 : f32
    %0 = bufferization.to_tensor %arg0 restrict writable : memref<16x16xf32>
    %alloc = memref.alloc() : memref<16x16xf16>
    %1 = bufferization.to_tensor %alloc restrict writable : memref<16x16xf16>
    %alloc_0 = memref.alloc() : memref<16x16xf16>
    %2 = bufferization.to_tensor %alloc_0 restrict writable : memref<16x16xf16>
    %false = arith.constant false
    %3 = tensor.empty() : tensor<16x16xf32>
    %c0 = arith.constant 0 : index
    %5 = hivm.hir.load ins(%0 : tensor<16x16xf32>) outs(%3 : tensor<16x16xf32>) -> tensor<16x16xf32>
    %4 = hivm.hir.mmadL1 ins(%1, %2, %false, %c0, %c0, %c0: tensor<16x16xf16>, tensor<16x16xf16>, i1, index, index, index) outs(%5 : tensor<16x16xf32>) -> tensor<16x16xf32>
    return %4 : tensor<16x16xf32>
}
}

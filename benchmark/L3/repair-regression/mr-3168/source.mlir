module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @test_nd_c_nz2nd_fixpipe_fallback(%arg0: tensor<16x16xi8>, %arg1: tensor<16x16xi8>, %arg2: memref<16x16xf32>) {
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %empty = tensor.empty() : tensor<16x16xi32>
    %mmad = hivm.hir.mmadL1 ins(%arg0, %arg1, %true, %c16, %c16, %c16 : tensor<16x16xi8>, tensor<16x16xi8>, i1, index, index, index) outs(%empty : tensor<16x16xi32>) -> tensor<16x16xi32>
    %cast_empty = tensor.empty() : tensor<16x16xf32>
    %casted = hivm.hir.vcast ins(%mmad : tensor<16x16xi32>) outs(%cast_empty : tensor<16x16xf32>) -> tensor<16x16xf32>
    hivm.hir.store ins(%casted : tensor<16x16xf32>) outs(%arg2 : memref<16x16xf32>)
    return
  }
}

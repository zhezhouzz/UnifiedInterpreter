module {
  func.func @transpose2d(%arg0: memref<64x16xf32, #hivm.address_space<ub>>, %arg1: memref<16x64xf32, #hivm.address_space<ub>>) {
    hivm.hir.vtranspose ins(%arg0 : memref<64x16xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<16x64xf32, #hivm.address_space<ub>>) permutation = [1, 0]
    return
  }
}

// -----
module {
  func.func @transpose3d(%arg0: memref<64x4x16xf16, #hivm.address_space<ub>>, %arg1: memref<4x64x16xf16, #hivm.address_space<ub>>) {
    hivm.hir.vtranspose ins(%arg0 : memref<64x4x16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<4x64x16xf16, #hivm.address_space<ub>>) permutation = [1, 0, 2]
    return
  }
}


module {
  func.func @transpose2d(%arg0: memref<64x16xf32, #hivm.address_space<ub>>, %arg1: memref<16x64xf32, #hivm.address_space<ub>>) {
    hivm.hir.vtranspose ins(%arg0 : memref<64x16xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<16x64xf32, #hivm.address_space<ub>>) permutation = [1, 0]
    return
  }
}

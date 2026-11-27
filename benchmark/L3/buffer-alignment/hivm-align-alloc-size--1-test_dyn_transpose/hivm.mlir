module {
  func.func @test_dyn_transpose(%arg0: index, %arg1: index) {
    %alloc = memref.alloc(%arg0, %arg1) : memref<?x16x?xf16, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc(%arg0, %arg1) : memref<?x16x?xf16, #hivm.address_space<ub>>
    hivm.hir.vtranspose ins(%alloc : memref<?x16x?xf16, #hivm.address_space<ub>>) outs(%alloc_0 : memref<?x16x?xf16, #hivm.address_space<ub>>) permutation = [2, 1, 0]
    return
  }
}


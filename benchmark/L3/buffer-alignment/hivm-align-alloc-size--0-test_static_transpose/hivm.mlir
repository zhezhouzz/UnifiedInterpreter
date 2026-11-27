module {
  func.func @test_static_transpose() {
    %alloc = memref.alloc() : memref<2x16x15xf16, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<15x16x2xf16, #hivm.address_space<ub>>
    hivm.hir.vtranspose ins(%alloc : memref<2x16x15xf16, #hivm.address_space<ub>>) outs(%alloc_0 : memref<15x16x2xf16, #hivm.address_space<ub>>) permutation = [2, 1, 0]
    return
  }
}


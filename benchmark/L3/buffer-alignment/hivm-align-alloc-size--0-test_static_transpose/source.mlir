
func.func @test_static_transpose() {
  %src = memref.alloc() : memref<2x16x15xf16, #hivm.address_space<ub>>
  %dst = memref.alloc() : memref<15x16x2xf16, #hivm.address_space<ub>>
  hivm.hir.vtranspose ins(%src : memref<2x16x15xf16, #hivm.address_space<ub>>)
                      outs(%dst : memref<15x16x2xf16, #hivm.address_space<ub>>)
                      permutation = [2, 1, 0]
  return
}

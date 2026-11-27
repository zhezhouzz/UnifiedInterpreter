func.func @test_dyn_transpose(%index0: index, %index1: index) {
  %src = memref.alloc(%index0, %index1) : memref<?x16x?xf16, #hivm.address_space<ub>>
  %dst = memref.alloc(%index0, %index1) : memref<?x16x?xf16, #hivm.address_space<ub>>
  hivm.hir.vtranspose ins(%src : memref<?x16x?xf16, #hivm.address_space<ub>>)
                      outs(%dst : memref<?x16x?xf16, #hivm.address_space<ub>>)
                      permutation = [2, 1, 0]
  return
}

func.func @valid_alloc_for_simd(%arg0: memref<61440xf16, #hivm.address_space<gm>>, %arg1: memref<61440xf16, #hivm.address_space<gm>>) -> f16 attributes {hivm.vf_mode = #hivm.vf_mode<SIMD>} {
  %c0 = arith.constant 0 : index
  %alloc = memref.alloc() : memref<61440xf16, #hivm.address_space<ub>>
  %alloc_0 = memref.alloc() : memref<61440xf16, #hivm.address_space<ub>>
  hivm.hir.load ins(%arg0 : memref<61440xf16, #hivm.address_space<gm>>) outs(%alloc : memref<61440xf16, #hivm.address_space<ub>>)
  hivm.hir.load ins(%arg1 : memref<61440xf16, #hivm.address_space<gm>>) outs(%alloc_0 : memref<61440xf16, #hivm.address_space<ub>>)
  %0 = memref.load %alloc[%c0] : memref<61440xf16, #hivm.address_space<ub>>
  %1 = memref.load %alloc_0[%c0] : memref<61440xf16, #hivm.address_space<ub>>
  %2 = arith.mulf %0, %1 : f16
  return %2 : f16
}

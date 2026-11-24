func.func @hivm_memref_load_gm_to_ub() {
  %src = memref.alloc() : memref<16x16xf16, #hivm.address_space<gm>>
  %dst = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
  hivm.hir.load ins(%src : memref<16x16xf16, #hivm.address_space<gm>>)
                outs(%dst : memref<16x16xf16, #hivm.address_space<ub>>)
  return
}

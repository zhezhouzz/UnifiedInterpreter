func.func @hivm_memref_store_ub_to_gm() {
  %src = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
  %dst = memref.alloc() : memref<16x16xf16, #hivm.address_space<gm>>
  hivm.hir.store ins(%src : memref<16x16xf16, #hivm.address_space<ub>>)
                outs(%dst : memref<16x16xf16, #hivm.address_space<gm>>)
  return
}

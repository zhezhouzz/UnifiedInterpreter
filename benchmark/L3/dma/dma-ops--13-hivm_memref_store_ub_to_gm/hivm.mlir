module {
  func.func @hivm_memref_store_ub_to_gm() {
    %alloc = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<16x16xf16, #hivm.address_space<gm>>
    hivm.hir.store ins(%alloc : memref<16x16xf16, #hivm.address_space<ub>>) outs(%alloc_0 : memref<16x16xf16, #hivm.address_space<gm>>)
    return
  }
}


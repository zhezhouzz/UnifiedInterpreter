module {
  func.func @hivm_memref_load_gm_to_ub() {
    %alloc = memref.alloc() : memref<16x16xf16, #hivm.address_space<gm>>
    %alloc_0 = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%alloc : memref<16x16xf16, #hivm.address_space<gm>>) outs(%alloc_0 : memref<16x16xf16, #hivm.address_space<ub>>)
    return
  }
}


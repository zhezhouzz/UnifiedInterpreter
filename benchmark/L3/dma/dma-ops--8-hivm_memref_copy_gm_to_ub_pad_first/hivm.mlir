module {
  func.func @hivm_memref_copy_gm_to_ub_pad_first() {
    %alloc = memref.alloc() : memref<16x15xf16, #hivm.address_space<gm>>
    %alloc_0 = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%alloc : memref<16x15xf16, #hivm.address_space<gm>>) outs(%alloc_0 : memref<16x16xf16, #hivm.address_space<ub>>) pad_mode = <PadFirstElem>
    return
  }
}


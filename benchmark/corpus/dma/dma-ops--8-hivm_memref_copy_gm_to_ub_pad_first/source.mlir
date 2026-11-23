func.func @hivm_memref_copy_gm_to_ub_pad_first() {
  %src = memref.alloc() : memref<16x15xf16, #hivm.address_space<gm>>
  %dst = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
  hivm.hir.load ins(%src : memref<16x15xf16, #hivm.address_space<gm>>)
                outs(%dst : memref<16x16xf16, #hivm.address_space<ub>>)
                pad_mode = #hivm.padmode<PadFirstElem>
  return
}

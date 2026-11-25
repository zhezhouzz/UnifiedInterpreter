module {
  func.func @hivm_memref_copy_gm_to_ub_pad_value_only() {
    %cst = arith.constant 1.000000e+01 : f16
    %alloc = memref.alloc() : memref<16x16xf16, #hivm.address_space<gm>>
    %alloc_0 = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%alloc : memref<16x16xf16, #hivm.address_space<gm>>) outs(%alloc_0 : memref<16x16xf16, #hivm.address_space<ub>>) pad_mode = <PadValue> pad_value = %cst : f16
    return
  }
}


module {
  func.func @copy(%src: memref<16x16xf32, #hivm.address_space<gm>>,
                  %dst: memref<16x16xf32, #hivm.address_space<gm>>)
      attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>,
                  hivm.func_core_type = #hivm.func_core_type<MIX>, mix_mode = "mix"} {
    %buf = memref.alloc() : memref<16x16xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%src : memref<16x16xf32, #hivm.address_space<gm>>)
                  outs(%buf : memref<16x16xf32, #hivm.address_space<ub>>)
    hivm.hir.store ins(%buf : memref<16x16xf32, #hivm.address_space<ub>>)
                   outs(%dst : memref<16x16xf32, #hivm.address_space<gm>>)
    return
  }
}

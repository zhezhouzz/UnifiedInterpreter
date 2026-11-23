module {
  func.func @copy(%arg0: memref<16x16xf32, #hivm.address_space<gm>>, %arg1: memref<16x16xf32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<MIX>, mix_mode = "mix"} {
    %alloc = memref.alloc() : memref<16x16xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16x16xf32, #hivm.address_space<gm>>) outs(%alloc : memref<16x16xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%alloc : memref<16x16xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<16x16xf32, #hivm.address_space<gm>>)
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
}


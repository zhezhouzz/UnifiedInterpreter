module {
  func.func @cube(%workspace: memref<256xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %zero = arith.constant 0 : i64
    %acc = hivm.hir.pointer_cast(%zero) : memref<256xf32, #hivm.address_space<cc>>
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%acc : memref<256xf32, #hivm.address_space<cc>>) outs(%workspace : memref<256xf32, #hivm.address_space<gm>>)
    hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_S>] flag = 0
    return
  }
  func.func @vector(%workspace: memref<256xf32, #hivm.address_space<gm>>, %result: memref<256xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>} {
    %zero = arith.constant 0 : i64
    %buf = hivm.hir.pointer_cast(%zero) : memref<256xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%workspace : memref<256xf32, #hivm.address_space<gm>>) outs(%buf : memref<256xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%buf : memref<256xf32, #hivm.address_space<ub>>) outs(%result : memref<256xf32, #hivm.address_space<gm>>)
    return
  }
}

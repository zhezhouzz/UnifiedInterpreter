module {
  func.func @cube(%arg0: memref<256xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<256xf32, #hivm.address_space<cc>>
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%0 : memref<256xf32, #hivm.address_space<cc>>) outs(%arg0 : memref<256xf32, #hivm.address_space<gm>>)
    hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_S>] flag = 0
    return
  }
  func.func @vector(%arg0: memref<256xf32, #hivm.address_space<gm>>, %arg1: memref<256xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>} {
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<256xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<256xf32, #hivm.address_space<gm>>) outs(%0 : memref<256xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%0 : memref<256xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<256xf32, #hivm.address_space<gm>>)
    return
  }
}


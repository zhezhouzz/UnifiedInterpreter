module {
  func.func @vcast_inplace_1d_large_to_small_valid(%arg0: memref<1024xf32, #hivm.address_space<gm>>, %arg1: memref<1024xf16, #hivm.address_space<gm>>) {
    %alloc = memref.alloc() : memref<1024xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<1024xf32, #hivm.address_space<gm>>) outs(%alloc : memref<1024xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    %alloc_0 = memref.alloc() : memref<1024xf16, #hivm.address_space<ub>>
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vcast ins(%alloc : memref<1024xf32, #hivm.address_space<ub>>) outs(%alloc_0 : memref<1024xf16, #hivm.address_space<ub>>) round_mode = <trunc>
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%alloc_0 : memref<1024xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<1024xf16, #hivm.address_space<gm>>)
    return
  }
}


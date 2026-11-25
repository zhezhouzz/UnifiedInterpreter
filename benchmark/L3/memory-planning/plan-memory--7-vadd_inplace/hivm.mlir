module {
  func.func @vadd_inplace(%arg0: memref<16x16xf16, #hivm.address_space<gm>>, %arg1: memref<16x16xf16, #hivm.address_space<gm>>, %arg2: memref<16x16xf16, #hivm.address_space<gm>>) {
    %alloc = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16x16xf16, #hivm.address_space<gm>>) outs(%alloc : memref<16x16xf16, #hivm.address_space<ub>>)
    %alloc_0 = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg1 : memref<16x16xf16, #hivm.address_space<gm>>) outs(%alloc_0 : memref<16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    %alloc_1 = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vadd ins(%alloc, %alloc_0 : memref<16x16xf16, #hivm.address_space<ub>>, memref<16x16xf16, #hivm.address_space<ub>>) outs(%alloc_1 : memref<16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%alloc_1 : memref<16x16xf16, #hivm.address_space<ub>>) outs(%arg2 : memref<16x16xf16, #hivm.address_space<gm>>)
    return
  }
}


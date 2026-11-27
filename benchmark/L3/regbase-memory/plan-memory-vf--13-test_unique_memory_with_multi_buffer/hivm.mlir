module {
  func.func @test_unique_memory_with_multi_buffer(%arg0: memref<16x32x64xf16, #hivm.address_space<gm>>, %arg1: memref<16x32x64xf16, #hivm.address_space<gm>>) {
    %alloc = memref.alloc() : memref<16x32x64xf16, #hivm.address_space<ub>>
    annotation.mark %alloc {hivm.multi_buffer = 2 : i32, mem_unique} : memref<16x32x64xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16x32x64xf16, #hivm.address_space<gm>>) outs(%alloc : memref<16x32x64xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%alloc : memref<16x32x64xf16, #hivm.address_space<ub>>) outs(%arg0 : memref<16x32x64xf16, #hivm.address_space<gm>>)
    %alloc_0 = memref.alloc() : memref<16x32x64xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg1 : memref<16x32x64xf16, #hivm.address_space<gm>>) outs(%alloc_0 : memref<16x32x64xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%alloc_0 : memref<16x32x64xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16x32x64xf16, #hivm.address_space<gm>>)
    return
  }
}


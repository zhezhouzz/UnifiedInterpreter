module {
  func.func @test_multi_buffer_loadstore_level0_inplace(%arg0: memref<24576xf32, #hivm.address_space<gm>>, %arg1: memref<24576xf32, #hivm.address_space<gm>>) {
    %c0 = arith.constant 0 : index
    %c1024 = arith.constant 1024 : index
    %c128 = arith.constant 128 : index
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    scf.for %arg2 = %c0 to %c1024 step %c128 {
      %alloc = memref.alloc() : memref<24576xf32, #hivm.address_space<ub>>
      annotation.mark %alloc {hivm.multi_buffer = 2 : i32} : memref<24576xf32, #hivm.address_space<ub>>
      %alloc_0 = memref.alloc() : memref<24576xf32, #hivm.address_space<ub>>
      annotation.mark %alloc_0 {hivm.multi_buffer = 2 : i32} : memref<24576xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.load ins(%arg0 : memref<24576xf32, #hivm.address_space<gm>>) outs(%alloc : memref<24576xf32, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.vadd ins(%alloc, %alloc : memref<24576xf32, #hivm.address_space<ub>>, memref<24576xf32, #hivm.address_space<ub>>) outs(%alloc_0 : memref<24576xf32, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%alloc_0 : memref<24576xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<24576xf32, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
    }
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
    return
  }
}


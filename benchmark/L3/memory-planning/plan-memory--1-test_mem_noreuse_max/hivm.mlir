module {
  func.func @test_mem_noreuse_max(%arg0: memref<16384xi64, #hivm.address_space<gm>>, %arg1: memref<16384xi32, #hivm.address_space<gm>>) {
    %alloc = memref.alloc() : memref<16384xi64, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<16384xi32, #hivm.address_space<ub>>
    %alloc_1 = memref.alloc() : memref<0xi64, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16384xi64, #hivm.address_space<gm>>) outs(%alloc : memref<16384xi64, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vcast ins(%alloc : memref<16384xi64, #hivm.address_space<ub>>) outs(%alloc_0 : memref<16384xi32, #hivm.address_space<ub>>) temp_buffer(%alloc_1 : memref<0xi64, #hivm.address_space<ub>>) round_mode = <truncwithoverflow>
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%alloc_0 : memref<16384xi32, #hivm.address_space<ub>>) outs(%arg1 : memref<16384xi32, #hivm.address_space<gm>>)
    return
  }
}


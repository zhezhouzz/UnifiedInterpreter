module {
  func.func @test_select_init_iter_no_reuse_yield(%arg0: memref<64xf32, #hivm.address_space<gm>>, %arg1: memref<64xf32, #hivm.address_space<gm>>, %arg2: memref<64xf32, #hivm.address_space<gm>>, %arg3: memref<64xf32, #hivm.address_space<gm>>, %arg4: i1) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %alloc = memref.alloc() : memref<64xf32, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<64xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<64xf32, #hivm.address_space<gm>>) outs(%alloc : memref<64xf32, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg1 : memref<64xf32, #hivm.address_space<gm>>) outs(%alloc_0 : memref<64xf32, #hivm.address_space<ub>>)
    %0 = arith.select %arg4, %alloc, %alloc_0 : memref<64xf32, #hivm.address_space<ub>>
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    %1 = scf.for %arg5 = %c0 to %c2 step %c1 iter_args(%arg6 = %0) -> (memref<64xf32, #hivm.address_space<ub>>) {
      %alloc_1 = memref.alloc() : memref<64xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.load ins(%arg2 : memref<64xf32, #hivm.address_space<gm>>) outs(%alloc_1 : memref<64xf32, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      %alloc_2 = memref.alloc() : memref<64xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.vadd ins(%arg6, %alloc_1 : memref<64xf32, #hivm.address_space<ub>>, memref<64xf32, #hivm.address_space<ub>>) outs(%alloc_2 : memref<64xf32, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
      scf.yield %alloc_2 : memref<64xf32, #hivm.address_space<ub>>
    }
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%1 : memref<64xf32, #hivm.address_space<ub>>) outs(%arg3 : memref<64xf32, #hivm.address_space<gm>>)
    return
  }
}


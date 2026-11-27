module {
  func.func @while_pipeline_vadd(%arg0: memref<8xf32, #hivm.address_space<gm>>, %arg1: memref<8xf32, #hivm.address_space<gm>>) {
    %true = arith.constant true
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    %0 = scf.while (%arg2 = %true) : (i1) -> i1 {
      scf.condition(%arg2) %arg2 : i1
    } do {
    ^bb0(%arg2: i1):
      %alloc = memref.alloc() : memref<8xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.load ins(%arg0 : memref<8xf32, #hivm.address_space<gm>>) outs(%alloc : memref<8xf32, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.vadd ins(%alloc, %alloc : memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) outs(%alloc : memref<8xf32, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%alloc : memref<8xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<8xf32, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      scf.yield %arg2 : i1
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    return
  }
}


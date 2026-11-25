module {
  func.func @while_signature_immutability(%arg0: memref<8xf32, #hivm.address_space<gm>>, %arg1: memref<8xf32, #hivm.address_space<gm>>, %arg2: i32, %arg3: i64) {
    %true = arith.constant true
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    %0:3 = scf.while (%arg4 = %true, %arg5 = %arg2, %arg6 = %arg3) : (i1, i32, i64) -> (i1, i32, i64) {
      scf.condition(%arg4) %arg4, %arg5, %arg6 : i1, i32, i64
    } do {
    ^bb0(%arg4: i1, %arg5: i32, %arg6: i64):
      %alloc = memref.alloc() : memref<8xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.load ins(%arg0 : memref<8xf32, #hivm.address_space<gm>>) outs(%alloc : memref<8xf32, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%alloc : memref<8xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<8xf32, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      scf.yield %arg4, %arg5, %arg6 : i1, i32, i64
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    return
  }
}


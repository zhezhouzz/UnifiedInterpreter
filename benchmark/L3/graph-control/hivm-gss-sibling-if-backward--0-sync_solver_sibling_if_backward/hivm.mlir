module {
  func.func @sync_solver_sibling_if_backward(%arg0: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %c0_i64 = arith.constant 0 : i64
    %c1_i64 = arith.constant 1 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<1xi1, #hivm.address_space<gm>>
    %1 = hivm.hir.pointer_cast(%c1_i64) : memref<1xi1, #hivm.address_space<ub>>
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    scf.for %arg1 = %c0 to %arg0 step %c1 {
      scf.if %true {
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        hivm.hir.load ins(%0 : memref<1xi1, #hivm.address_space<gm>>) outs(%1 : memref<1xi1, #hivm.address_space<ub>>)
      } else {
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      }
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      scf.if %true {
        hivm.hir.store ins(%1 : memref<1xi1, #hivm.address_space<ub>>) outs(%0 : memref<1xi1, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      } else {
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      }
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    return
  }
}


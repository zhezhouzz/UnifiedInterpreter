module {
  func.func @sync_solver_test_if_else_backward_pair(%arg0: index) {
    %alloca = memref.alloca() : memref<1xi64>
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    memref.store %c0_i64, %alloca[%c0] : memref<1xi64>
    %c0_0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %false = arith.constant false
    %c0_i64_1 = arith.constant 0 : i64
    %c1_i64 = arith.constant 1 : i64
    %c2_i64 = arith.constant 2 : i64
    %c3_i64 = arith.constant 3 : i64
    %c4_i64 = arith.constant 4 : i64
    %c5_i64 = arith.constant 5 : i64
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID2>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID2>]
    scf.for %arg1 = %c0_0 to %arg0 step %c1 {
      %c0_2 = arith.constant 0 : index
      %0 = memref.load %alloca[%c0_2] : memref<1xi64>
      %c2_i64_3 = arith.constant 2 : i64
      %1 = arith.remui %0, %c2_i64_3 : i64
      %2 = arith.index_cast %1 : i64 to index
      %3 = arith.index_cast %2 : index to i1
      %c1_i64_4 = arith.constant 1 : i64
      %c2_i64_5 = arith.constant 2 : i64
      %4 = arith.select %3, %c1_i64_4, %c2_i64_5 : i64
      %5 = hivm.hir.pointer_cast(%c0_i64_1, %c1_i64) : memref<1xi1, #hivm.address_space<gm>>
      %6 = hivm.hir.pointer_cast(%c2_i64, %c3_i64) : memref<1xi1, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, %4]
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, %4]
      scf.if %false {
        hivm.hir.pipe_barrier[<PIPE_MTE2>]
        hivm.hir.load ins(%5 : memref<1xi1, #hivm.address_space<gm>>) outs(%6 : memref<1xi1, #hivm.address_space<ub>>)
      } else {
        hivm.hir.pipe_barrier[<PIPE_MTE3>]
        hivm.hir.store ins(%6 : memref<1xi1, #hivm.address_space<ub>>) outs(%5 : memref<1xi1, #hivm.address_space<gm>>)
      }
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, %4]
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, %4]
      %c1_i64_6 = arith.constant 1 : i64
      %7 = arith.addi %0, %c1_i64_6 : i64
      %c0_7 = arith.constant 0 : index
      memref.store %7, %alloca[%c0_7] : memref<1xi64>
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID2>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID1>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID2>]
    scf.for %arg1 = %c0_0 to %arg0 step %c1 {
      %0 = hivm.hir.pointer_cast(%c4_i64) : memref<1xi1, #hivm.address_space<gm>>
      %1 = hivm.hir.pointer_cast(%c5_i64) : memref<1xi1, #hivm.address_space<ub>>
      scf.if %false {
        hivm.hir.pipe_barrier[<PIPE_MTE2>]
        hivm.hir.load ins(%0 : memref<1xi1, #hivm.address_space<gm>>) outs(%1 : memref<1xi1, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      } else {
        hivm.hir.pipe_barrier[<PIPE_MTE3>]
        hivm.hir.store ins(%1 : memref<1xi1, #hivm.address_space<ub>>) outs(%0 : memref<1xi1, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      }
    }
    return
  }
}


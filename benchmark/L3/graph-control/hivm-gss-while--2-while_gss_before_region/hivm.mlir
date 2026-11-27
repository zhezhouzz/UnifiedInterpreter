module {
  func.func @while_gss_before_region(%arg0: memref<16xf16, #hivm.address_space<gm>>, %arg1: memref<16xf16, #hivm.address_space<gm>>) {
    %alloca = memref.alloca() : memref<1xi64>
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    memref.store %c0_i64, %alloca[%c0] : memref<1xi64>
    %c0_i64_0 = arith.constant 0 : i64
    %c32_i64 = arith.constant 32 : i64
    %true = arith.constant true
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    %0 = scf.while (%arg2 = %true) : (i1) -> i1 {
      %c0_1 = arith.constant 0 : index
      %1 = memref.load %alloca[%c0_1] : memref<1xi64>
      %c2_i64 = arith.constant 2 : i64
      %2 = arith.remui %1, %c2_i64 : i64
      %3 = arith.index_cast %2 : i64 to index
      %4 = arith.index_cast %3 : index to i1
      %c0_i64_2 = arith.constant 0 : i64
      %c1_i64 = arith.constant 1 : i64
      %5 = arith.select %4, %c0_i64_2, %c1_i64 : i64
      %6 = hivm.hir.pointer_cast(%c0_i64_0, %c32_i64) : memref<16xf16, #hivm.address_space<ub>>
      annotation.mark %6 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, %5]
      hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%6 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.pipe_barrier[<PIPE_MTE3>]
      hivm.hir.store ins(%6 : memref<16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16xf16, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, %5]
      %c1_i64_3 = arith.constant 1 : i64
      %7 = arith.addi %1, %c1_i64_3 : i64
      %c0_4 = arith.constant 0 : index
      memref.store %7, %alloca[%c0_4] : memref<1xi64>
      scf.condition(%arg2) %arg2 : i1
    } do {
    ^bb0(%arg2: i1):
      scf.yield %arg2 : i1
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    return
  }
}


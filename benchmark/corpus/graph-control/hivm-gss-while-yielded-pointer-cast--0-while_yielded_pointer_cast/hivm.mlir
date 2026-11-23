module {
  func.func @while_yielded_pointer_cast(%arg0: memref<16xf16, #hivm.address_space<gm>>, %arg1: memref<16xf16, #hivm.address_space<gm>>) {
    %alloca = memref.alloca() : memref<1xi64>
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    memref.store %c0_i64, %alloca[%c0] : memref<1xi64>
    %c0_i64_0 = arith.constant 0 : i64
    %c32_i64 = arith.constant 32 : i64
    %true = arith.constant true
    %0 = hivm.hir.pointer_cast(%c0_i64_0, %c32_i64) : memref<16xf16, #hivm.address_space<ub>>
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    %1 = scf.while (%arg2 = %0) : (memref<16xf16, #hivm.address_space<ub>>) -> memref<16xf16, #hivm.address_space<ub>> {
      scf.condition(%true) %arg2 : memref<16xf16, #hivm.address_space<ub>>
    } do {
    ^bb0(%arg2: memref<16xf16, #hivm.address_space<ub>>):
      %c0_1 = arith.constant 0 : index
      %2 = memref.load %alloca[%c0_1] : memref<1xi64>
      %c2_i64 = arith.constant 2 : i64
      %3 = arith.remui %2, %c2_i64 : i64
      %4 = arith.index_cast %3 : i64 to index
      %5 = arith.index_cast %4 : index to i1
      %c0_i64_2 = arith.constant 0 : i64
      %c1_i64 = arith.constant 1 : i64
      %6 = arith.select %5, %c0_i64_2, %c1_i64 : i64
      %7 = hivm.hir.pointer_cast(%c0_i64_0, %c32_i64) : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, %6]
      hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%7 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.pipe_barrier[<PIPE_MTE3>]
      hivm.hir.store ins(%7 : memref<16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16xf16, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, %6]
      %c1_i64_3 = arith.constant 1 : i64
      %8 = arith.addi %2, %c1_i64_3 : i64
      %c0_4 = arith.constant 0 : index
      memref.store %8, %alloca[%c0_4] : memref<1xi64>
      scf.yield %7 : memref<16xf16, #hivm.address_space<ub>>
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    return
  }
}


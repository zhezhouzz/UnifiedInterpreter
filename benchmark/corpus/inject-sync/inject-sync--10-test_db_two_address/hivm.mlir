module {
  func.func @test_db_two_address(%arg0: memref<16xf16, #hivm.address_space<gm>>, %arg1: memref<16xf16, #hivm.address_space<gm>>) {
    %alloca = memref.alloca() : memref<1xi64>
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    memref.store %c0_i64, %alloca[%c0] : memref<1xi64>
    %c32_i64 = arith.constant 32 : i64
    %c0_i64_0 = arith.constant 0 : i64
    %c0_1 = arith.constant 0 : index
    %c4 = arith.constant 4 : index
    %c16 = arith.constant 16 : index
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    scf.for %arg2 = %c0_1 to %c16 step %c4 {
      %c0_2 = arith.constant 0 : index
      %0 = memref.load %alloca[%c0_2] : memref<1xi64>
      %c2_i64 = arith.constant 2 : i64
      %1 = arith.remui %0, %c2_i64 : i64
      %2 = arith.index_cast %1 : i64 to index
      %3 = arith.index_cast %2 : index to i64
      %c0_i64_3 = arith.constant 0 : i64
      %c1_i64 = arith.constant 1 : i64
      %c1_i64_4 = arith.constant 1 : i64
      %4 = arith.cmpi eq, %3, %c1_i64_4 : i64
      %5 = arith.select %4, %c1_i64, %c0_i64_3 : i64
      %6 = hivm.hir.pointer_cast(%c0_i64_0, %c32_i64) : memref<16xf16, #hivm.address_space<ub>>
      annotation.mark %6 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, %5]
      hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%6 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.pipe_barrier[<PIPE_MTE3>]
      hivm.hir.store ins(%6 : memref<16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16xf16, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, %5]
      %c1_i64_5 = arith.constant 1 : i64
      %7 = arith.addi %0, %c1_i64_5 : i64
      %c0_6 = arith.constant 0 : index
      memref.store %7, %alloca[%c0_6] : memref<1xi64>
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    return
  }
}


module {
  func.func @test_db_event_info_avoids_redundant_barrier(%arg0: memref<16xf16, #hivm.address_space<gm>>) {
    %alloca = memref.alloca() : memref<1xi64>
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    memref.store %c0_i64, %alloca[%c0] : memref<1xi64>
    %c0_i64_0 = arith.constant 0 : i64
    %c32_i64 = arith.constant 32 : i64
    %c0_1 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c4 = arith.constant 4 : index
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
    scf.for %arg1 = %c0_1 to %c4 step %c1 {
      %c0_2 = arith.constant 0 : index
      %0 = memref.load %alloca[%c0_2] : memref<1xi64>
      %c2_i64 = arith.constant 2 : i64
      %1 = arith.remui %0, %c2_i64 : i64
      %2 = arith.index_cast %1 : i64 to index
      %3 = arith.index_cast %2 : index to i1
      %c0_i64_3 = arith.constant 0 : i64
      %c1_i64 = arith.constant 1 : i64
      %4 = arith.select %3, %c0_i64_3, %c1_i64 : i64
      %5 = hivm.hir.pointer_cast(%c0_i64_0, %c32_i64) : memref<16xf16, #hivm.address_space<ub>>
      annotation.mark %5 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, %4]
      hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%5 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.vadd ins(%5, %5 : memref<16xf16, #hivm.address_space<ub>>, memref<16xf16, #hivm.address_space<ub>>) outs(%5 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, %4]
      %c1_i64_4 = arith.constant 1 : i64
      %6 = arith.addi %0, %c1_i64_4 : i64
      %c0_5 = arith.constant 0 : index
      memref.store %6, %alloca[%c0_5] : memref<1xi64>
    }
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
    return
  }
}


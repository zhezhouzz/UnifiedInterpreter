module {
  func.func @test_inner_yielded_db_anchored_outer(%arg0: memref<16xf16, #hivm.address_space<gm>>, %arg1: memref<16xf16, #hivm.address_space<gm>>) {
    %c0_i64 = arith.constant 0 : i64
    %c32_i64 = arith.constant 32 : i64
    %c0 = arith.constant 0 : index
    %c2 = arith.constant 2 : index
    %c4 = arith.constant 4 : index
    %0 = hivm.hir.pointer_cast(%c0_i64, %c32_i64) : memref<16xf16, #hivm.address_space<ub>>
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID2>]
    scf.for %arg2 = %c0 to %c4 step %c2 {
      %1 = hivm.hir.multi_buffer_counter -> i64
      %c2_i64 = arith.constant 2 : i64
      %2 = arith.remui %1, %c2_i64 : i64
      %3 = arith.index_cast %2 : i64 to index
      %4 = arith.index_cast %3 : index to i1
      %c0_i64_0 = arith.constant 0 : i64
      %c1_i64 = arith.constant 1 : i64
      %5 = arith.select %4, %c0_i64_0, %c1_i64 : i64
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, %5]
      hivm.hir.pipe_barrier[<PIPE_MTE3>]
      %6 = scf.for %arg3 = %c0 to %c4 step %c2 iter_args(%arg4 = %0) -> (memref<16xf16, #hivm.address_space<ub>>) {
        %7 = hivm.hir.pointer_cast(%c0_i64, %c32_i64) : memref<16xf16, #hivm.address_space<ub>>
        annotation.mark %7 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID2>]
        hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%7 : memref<16xf16, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.store ins(%7 : memref<16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16xf16, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID2>]
        scf.yield %7 : memref<16xf16, #hivm.address_space<ub>>
      }
      hivm.hir.pipe_barrier[<PIPE_MTE3>]
      hivm.hir.store ins(%6 : memref<16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16xf16, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, %5]
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID2>]
    return
  }
}


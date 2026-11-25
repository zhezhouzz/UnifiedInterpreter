module {
  func.func @case_D_while_outer_for_inner_alloc_in_while(%arg0: memref<16xf16, #hivm.address_space<gm>>, %arg1: memref<16xf16, #hivm.address_space<gm>>) {
    %c0_i64 = arith.constant 0 : i64
    %c16_i64 = arith.constant 16 : i64
    %c128_i64 = arith.constant 128 : i64
    %c144_i64 = arith.constant 144 : i64
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c4 = arith.constant 4 : index
    %true = arith.constant true
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    %0 = scf.while (%arg2 = %true) : (i1) -> i1 {
      scf.condition(%arg2) %arg2 : i1
    } do {
    ^bb0(%arg2: i1):
      %1 = hivm.hir.pointer_cast(%c0_i64, %c16_i64) : memref<16xf16, #hivm.address_space<ub>>
      annotation.mark %1 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_ALL>]
      %2 = hivm.hir.pointer_cast(%c128_i64, %c144_i64) : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_ALL>]
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%1 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.pipe_barrier[<PIPE_ALL>]
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.vadd ins(%1, %1 : memref<16xf16, #hivm.address_space<ub>>, memref<16xf16, #hivm.address_space<ub>>) outs(%2 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      scf.for %arg3 = %c0 to %c4 step %c1 {
        hivm.hir.pipe_barrier[<PIPE_MTE3>]
        hivm.hir.store ins(%2 : memref<16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16xf16, #hivm.address_space<gm>>)
      }
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
      scf.yield %arg2 : i1
    }
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
    return
  }
}


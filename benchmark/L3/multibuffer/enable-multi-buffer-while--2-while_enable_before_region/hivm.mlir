module {
  func.func @while_enable_before_region(%arg0: memref<16xf16, #hivm.address_space<gm>>, %arg1: memref<16xf16, #hivm.address_space<gm>>) {
    %c0_i64 = arith.constant 0 : i64
    %c16_i64 = arith.constant 16 : i64
    %c128_i64 = arith.constant 128 : i64
    %c144_i64 = arith.constant 144 : i64
    %true = arith.constant true
    %0 = scf.while (%arg2 = %true) : (i1) -> i1 {
      %1 = hivm.hir.pointer_cast(%c0_i64, %c16_i64) : memref<16xf16, #hivm.address_space<ub>>
      annotation.mark %1 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_ALL>]
      %2 = hivm.hir.pointer_cast(%c128_i64, %c144_i64) : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_MTE2>]
      hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%1 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.pipe_barrier[<PIPE_MTE3>]
      hivm.hir.store ins(%2 : memref<16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16xf16, #hivm.address_space<gm>>)
      scf.condition(%arg2) %arg2 : i1
    } do {
    ^bb0(%arg2: i1):
      scf.yield %arg2 : i1
    }
    return
  }
}


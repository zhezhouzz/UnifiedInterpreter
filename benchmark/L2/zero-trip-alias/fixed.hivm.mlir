module {
  func.func @kernel(%arg0: index, %arg1: memref<32xf32, #hivm.address_space<gm>>, %arg2: memref<32xf32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<32xf32, #hivm.address_space<ub>>
    %c256_i64 = arith.constant 256 : i64
    %1 = hivm.hir.pointer_cast(%c256_i64) : memref<32xf32, #hivm.address_space<ub>>
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %2 = scf.for %arg3 = %c0 to %arg0 step %c1 iter_args(%arg4 = %0) -> (memref<32xf32, #hivm.address_space<ub>>) {
      hivm.hir.pipe_barrier[<PIPE_V>]
      scf.yield %1 : memref<32xf32, #hivm.address_space<ub>>
    }
    hivm.hir.load ins(%arg1 : memref<32xf32, #hivm.address_space<gm>>) outs(%0 : memref<32xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vabs ins(%2 : memref<32xf32, #hivm.address_space<ub>>) outs(%1 : memref<32xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%1 : memref<32xf32, #hivm.address_space<ub>>) outs(%arg2 : memref<32xf32, #hivm.address_space<gm>>)
    return
  }
}


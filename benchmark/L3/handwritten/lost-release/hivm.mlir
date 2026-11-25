module {
  func.func @lost_release(%arg0: memref<32xf32, #hivm.address_space<gm>>, %arg1: memref<32xf32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c256_i64 = arith.constant 256 : i64
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<32xf32, #hivm.address_space<ub>>
    %1 = hivm.hir.pointer_cast(%c256_i64) : memref<32xf32, #hivm.address_space<ub>>
    hivm.hir.vabs ins(%0 : memref<32xf32, #hivm.address_space<ub>>) outs(%1 : memref<32xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.load ins(%arg0 : memref<32xf32, #hivm.address_space<gm>>) outs(%0 : memref<32xf32, #hivm.address_space<ub>>)
    return
  }
}


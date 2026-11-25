module {
  func.func @kernel(%arg0: memref<1xf32, #hivm.address_space<gm>>, %arg1: memref<1xf32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %cst = arith.constant 7.000000e+00 : f32
    %c0 = arith.constant 0 : index
    %c256_i64 = arith.constant 256 : i64
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<1xf32, #hivm.address_space<ub>>
    %1 = hivm.hir.pointer_cast(%c256_i64) : memref<1xf32, #hivm.address_space<ub>>
    hivm.hir.vabs ins(%0 : memref<1xf32, #hivm.address_space<ub>>) outs(%1 : memref<1xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
    memref.store %cst, %0[%c0] : memref<1xf32, #hivm.address_space<ub>>
    hivm.hir.set_flag[<PIPE_S>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_S>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vabs ins(%0 : memref<1xf32, #hivm.address_space<ub>>) outs(%1 : memref<1xf32, #hivm.address_space<ub>>)
    return
  }
}


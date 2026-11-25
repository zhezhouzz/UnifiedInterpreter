func.func @kernel(%arg0: memref<32xf32, #hivm.address_space<gm>>, %arg1: memref<32xf32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
  %c0 = arith.constant 0 : i64
  %b0 = hivm.hir.pointer_cast(%c0) : memref<32xf32, #hivm.address_space<ub>>
  %c1 = arith.constant 256 : i64
  %b1 = hivm.hir.pointer_cast(%c1) : memref<32xf32, #hivm.address_space<ub>>
  hivm.hir.load ins(%arg0 : memref<32xf32, #hivm.address_space<gm>>) outs(%b0 : memref<32xf32, #hivm.address_space<ub>>)
  hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
  hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
  hivm.hir.vabs ins(%b0 : memref<32xf32, #hivm.address_space<ub>>) outs(%b1 : memref<32xf32, #hivm.address_space<ub>>)
  hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
  hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
  hivm.hir.store ins(%b1 : memref<32xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<32xf32, #hivm.address_space<gm>>)
  return
}

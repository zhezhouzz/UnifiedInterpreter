func.func @kernel(%arg0: memref<1xf32, #hivm.address_space<gm>>, %arg1: memref<1xf32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
  %c0 = arith.constant 0 : i64
  %b0 = hivm.hir.pointer_cast(%c0) : memref<1xf32, #hivm.address_space<ub>>
  %c1 = arith.constant 256 : i64
  %b1 = hivm.hir.pointer_cast(%c1) : memref<1xf32, #hivm.address_space<ub>>
  %idx = arith.constant 0 : index
  %new = arith.constant 7.0 : f32
  hivm.hir.vabs ins(%b0 : memref<1xf32, #hivm.address_space<ub>>) outs(%b1 : memref<1xf32, #hivm.address_space<ub>>)
  hivm.hir.set_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
  hivm.hir.wait_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
  memref.store %new, %b0[%idx] : memref<1xf32, #hivm.address_space<ub>>
  hivm.hir.set_flag[<PIPE_S>, <PIPE_V>, <EVENT_ID0>]
  hivm.hir.wait_flag[<PIPE_S>, <PIPE_V>, <EVENT_ID0>]
  hivm.hir.vabs ins(%b0 : memref<1xf32, #hivm.address_space<ub>>) outs(%b1 : memref<1xf32, #hivm.address_space<ub>>)
  return
}

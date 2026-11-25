module {
  func.func @scatter_base(%arg0: memref<32xi32, #hivm.address_space<gm>>, %arg1: memref<32xi32, #hivm.address_space<gm>>, %arg2: memref<32xi32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<32xi32, #hivm.address_space<ub>>
    %c256_i64 = arith.constant 256 : i64
    %1 = hivm.hir.pointer_cast(%c256_i64) : memref<32xi32, #hivm.address_space<ub>>
    %c512_i64 = arith.constant 512 : i64
    %2 = hivm.hir.pointer_cast(%c512_i64) : memref<32xi32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<32xi32, #hivm.address_space<gm>>) outs(%0 : memref<32xi32, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg1 : memref<32xi32, #hivm.address_space<gm>>) outs(%1 : memref<32xi32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vmul ins(%0, %1 : memref<32xi32, #hivm.address_space<ub>>, memref<32xi32, #hivm.address_space<ub>>) outs(%2 : memref<32xi32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%2 : memref<32xi32, #hivm.address_space<ub>>) outs(%arg2 : memref<32xi32, #hivm.address_space<gm>>)
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
}


module {
  func.func @output_base(%arg0: memref<32xi32, #hivm.address_space<gm>>, %arg1: memref<32xi32, #hivm.address_space<gm>>, %arg2: memref<32xi32, #hivm.address_space<gm>>, %arg3: memref<32xi32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<32xi32, #hivm.address_space<ub>>
    %c256_i64 = arith.constant 256 : i64
    %1 = hivm.hir.pointer_cast(%c256_i64) : memref<32xi32, #hivm.address_space<ub>>
    %c512_i64 = arith.constant 512 : i64
    %2 = hivm.hir.pointer_cast(%c512_i64) : memref<32xi32, #hivm.address_space<ub>>
    %c768_i64 = arith.constant 768 : i64
    %3 = hivm.hir.pointer_cast(%c768_i64) : memref<32xi32, #hivm.address_space<ub>>
    %c1024_i64 = arith.constant 1024 : i64
    %4 = hivm.hir.pointer_cast(%c1024_i64) : memref<32xi32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<32xi32, #hivm.address_space<gm>>) outs(%0 : memref<32xi32, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg1 : memref<32xi32, #hivm.address_space<gm>>) outs(%1 : memref<32xi32, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg2 : memref<32xi32, #hivm.address_space<gm>>) outs(%2 : memref<32xi32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vmul ins(%1, %2 : memref<32xi32, #hivm.address_space<ub>>, memref<32xi32, #hivm.address_space<ub>>) outs(%3 : memref<32xi32, #hivm.address_space<ub>>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vmul ins(%3, %0 : memref<32xi32, #hivm.address_space<ub>>, memref<32xi32, #hivm.address_space<ub>>) outs(%4 : memref<32xi32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%4 : memref<32xi32, #hivm.address_space<ub>>) outs(%arg3 : memref<32xi32, #hivm.address_space<gm>>)
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
}


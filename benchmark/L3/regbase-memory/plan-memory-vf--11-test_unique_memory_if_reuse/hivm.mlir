module {
  func.func @test_unique_memory_if_reuse(%arg0: i32, %arg1: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg2: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg3: memref<16x16x16xf16, #hivm.address_space<gm>>) {
    %c1_i32 = arith.constant 1 : i32
    %alloc = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    annotation.mark %alloc {mem_unique} : memref<16x16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg1 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%alloc : memref<16x16x16xf16, #hivm.address_space<ub>>)
    %alloc_0 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg1 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%alloc_0 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    %0 = arith.cmpi eq, %arg0, %c1_i32 : i32
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    %1 = scf.if %0 -> (memref<16x16x16xf16, #hivm.address_space<ub>>) {
      %alloc_1 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
      hivm.hir.vadd ins(%alloc, %alloc_0 : memref<16x16x16xf16, #hivm.address_space<ub>>, memref<16x16x16xf16, #hivm.address_space<ub>>) outs(%alloc_1 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      scf.yield %alloc_1 : memref<16x16x16xf16, #hivm.address_space<ub>>
    } else {
      scf.yield %alloc : memref<16x16x16xf16, #hivm.address_space<ub>>
    }
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%1 : memref<16x16x16xf16, #hivm.address_space<ub>>) outs(%arg3 : memref<16x16x16xf16, #hivm.address_space<gm>>)
    return
  }
}


module {
  func.func @test_plan_memory_for_result(%arg0: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg1: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg2: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg3: memref<16x16x16xf16, #hivm.address_space<gm>>) -> memref<16x16x16xf16, #hivm.address_space<ub>> {
    %alloc = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc_1 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc_2 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc_3 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%alloc : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg1 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%alloc_0 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID1>]
    hivm.hir.load ins(%arg3 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%alloc_3 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID1>]
    hivm.hir.vadd ins(%alloc, %alloc_0 : memref<16x16x16xf16, #hivm.address_space<ub>>, memref<16x16x16xf16, #hivm.address_space<ub>>) outs(%alloc_1 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    %c128 = arith.constant 128 : index
    %c1024 = arith.constant 1024 : index
    %c0 = arith.constant 0 : index
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    %0 = scf.for %arg4 = %c0 to %c1024 step %c128 iter_args(%arg5 = %alloc_3) -> (memref<16x16x16xf16, #hivm.address_space<ub>>) {
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vadd ins(%alloc, %arg5 : memref<16x16x16xf16, #hivm.address_space<ub>>, memref<16x16x16xf16, #hivm.address_space<ub>>) outs(%alloc_2 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      scf.yield %alloc_2 : memref<16x16x16xf16, #hivm.address_space<ub>>
    }
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%alloc_1 : memref<16x16x16xf16, #hivm.address_space<ub>>) outs(%arg2 : memref<16x16x16xf16, #hivm.address_space<gm>>)
    return %0 : memref<16x16x16xf16, #hivm.address_space<ub>>
  }
}


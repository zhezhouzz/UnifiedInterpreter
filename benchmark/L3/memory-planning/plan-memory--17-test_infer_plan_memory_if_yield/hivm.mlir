module {
  func.func @test_infer_plan_memory_if_yield(%arg0: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg1: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg2: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg3: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg4: i1) {
    %alloc = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc_1 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc_2 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc_3 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc_4 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%alloc : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg1 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%alloc_1 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg2 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%alloc_3 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg3 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%alloc_4 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    %0 = scf.if %arg4 -> (memref<16x16x16xf16, #hivm.address_space<ub>>) {
      hivm.hir.vadd ins(%alloc, %alloc_3 : memref<16x16x16xf16, #hivm.address_space<ub>>, memref<16x16x16xf16, #hivm.address_space<ub>>) outs(%alloc_0 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      scf.yield %alloc_0 : memref<16x16x16xf16, #hivm.address_space<ub>>
    } else {
      hivm.hir.vadd ins(%alloc_1, %alloc_4 : memref<16x16x16xf16, #hivm.address_space<ub>>, memref<16x16x16xf16, #hivm.address_space<ub>>) outs(%alloc_2 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      scf.yield %alloc_2 : memref<16x16x16xf16, #hivm.address_space<ub>>
    }
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%0 : memref<16x16x16xf16, #hivm.address_space<ub>>) outs(%arg3 : memref<16x16x16xf16, #hivm.address_space<gm>>)
    return
  }
}


module attributes {hacc.target = #hacc.target<"Ascend950PR_950z">} {
  func.func @test_tightly_coupled_buffer_in_AIC(%arg0: memref<16x16xf16, #hivm.address_space<gm>>, %arg1: memref<16x16xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<16x16xf32, #hivm.address_space<cbuf>>
    hivm.hir.load ins(%arg1 : memref<16x16xf32, #hivm.address_space<gm>>) outs(%alloc : memref<16x16xf32, #hivm.address_space<cbuf>>)
    %alloc_0 = memref.alloc() {alignment = 64 : i64} : memref<16x16xf16, #hivm.address_space<cbuf>>
    annotation.mark %alloc_0 {hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<2>} : memref<16x16xf16, #hivm.address_space<cbuf>>
    %alloc_1 = memref.alloc() {alignment = 64 : i64} : memref<16x16xf32, #hivm.address_space<cc>>
    hivm.hir.load ins(%arg1 : memref<16x16xf32, #hivm.address_space<gm>>) outs(%alloc_1 : memref<16x16xf32, #hivm.address_space<cc>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID0>]
    %alloc_2 = memref.alloc() {alignment = 64 : i64} : memref<16x16xf32, #hivm.address_space<ub>>
    annotation.mark %alloc_2 {hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<4>} : memref<16x16xf32, #hivm.address_space<ub>>
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID0>]
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>, l0c_to_ub} ins(%alloc_1 : memref<16x16xf32, #hivm.address_space<cc>>) outs(%alloc_2 : memref<16x16xf32, #hivm.address_space<ub>>)
    return
  }
  func.func @test_tightly_coupled_buffer_in_AIV(%arg0: memref<16x16xf16, #hivm.address_space<gm>>, %arg1: memref<16x16xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>} {
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16x16xf16, #hivm.address_space<gm>>) outs(%alloc : memref<16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    %alloc_0 = memref.alloc() {alignment = 64 : i64} : memref<16x16xf16, #hivm.address_space<cbuf>>
    annotation.mark %alloc_0 {hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<2>} : memref<16x16xf16, #hivm.address_space<cbuf>>
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.copy ins(%alloc : memref<16x16xf16, #hivm.address_space<ub>>) outs(%alloc_0 : memref<16x16xf16, #hivm.address_space<cbuf>>) {ub_to_l1}
    %alloc_1 = memref.alloc() {alignment = 64 : i64} : memref<16x16xf32, #hivm.address_space<ub>>
    annotation.mark %alloc_1 {hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<4>} : memref<16x16xf32, #hivm.address_space<ub>>
    return
  }
}


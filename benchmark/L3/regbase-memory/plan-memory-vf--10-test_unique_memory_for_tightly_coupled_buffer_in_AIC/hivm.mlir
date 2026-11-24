module attributes {hacc.target = #hacc.target<"Ascend950PR_950z">} {
  func.func @test_unique_memory_for_tightly_coupled_buffer_in_AIC(%arg0: memref<16x16xf16, #hivm.address_space<gm>>, %arg1: memref<16x16xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<16x16xf32, #hivm.address_space<cc>>
    hivm.hir.load ins(%arg1 : memref<16x16xf32, #hivm.address_space<gm>>) outs(%alloc : memref<16x16xf32, #hivm.address_space<cc>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID0>]
    %alloc_0 = memref.alloc() {alignment = 64 : i64} : memref<16x16xf16, #hivm.address_space<ub>>
    annotation.mark %alloc_0 {hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<4>} : memref<16x16xf16, #hivm.address_space<ub>>
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID0>]
    hivm.hir.fixpipe {pre_quant = #hivm.fixpipe_pre_quant_mode<F322F16>} ins(%alloc : memref<16x16xf32, #hivm.address_space<cc>>) outs(%alloc_0 : memref<16x16xf16, #hivm.address_space<ub>>)
    return
  }
  func.func @test_unique_memory_for_tightly_coupled_buffer_in_AIV(%arg0: i32, %arg1: memref<16x16xf16, #hivm.address_space<gm>>, %arg2: memref<16x16xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>} {
    %c1_i32 = arith.constant 1 : i32
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<16x16xf16, #hivm.address_space<ub>>
    annotation.mark %alloc {hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<4>} : memref<16x16xf16, #hivm.address_space<ub>>
    %0 = arith.cmpi eq, %arg0, %c1_i32 : i32
    %1 = scf.if %0 -> (memref<16x16xf16, #hivm.address_space<ub>>) {
      %alloc_0 = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
      hivm.hir.load ins(%arg1 : memref<16x16xf16, #hivm.address_space<gm>>) outs(%alloc_0 : memref<16x16xf16, #hivm.address_space<ub>>)
      scf.yield %alloc_0 : memref<16x16xf16, #hivm.address_space<ub>>
    } else {
      scf.yield %alloc : memref<16x16xf16, #hivm.address_space<ub>>
    }
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%1 : memref<16x16xf16, #hivm.address_space<ub>>) outs(%arg2 : memref<16x16xf16, #hivm.address_space<gm>>)
    return
  }
}


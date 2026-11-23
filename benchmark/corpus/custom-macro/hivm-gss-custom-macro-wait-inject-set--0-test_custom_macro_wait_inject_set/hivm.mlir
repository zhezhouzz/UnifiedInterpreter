module {
  func.func @test_custom_macro_wait_inject_set(%arg0: memref<16xf16, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0_i64 = arith.constant 0 : i64
    %c0_i64_0 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64_0) : memref<16xf16, #hivm.address_space<ub>>
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
    %c-1_i64 = arith.constant -1 : i64
    hivm.hir.custom_macro {hivm.pipe_in = #hivm.pipe<PIPE_MTE2>, hivm.pipe_out = #hivm.pipe<PIPE_V>, hivm.tcore_type = #hivm.tcore_type<VECTOR>, symbol = "k_custom_macro_wait_inject", sync_event_slots = [#hivm.sync_event_slot<#hivm.pipe<PIPE_MTE2>, #hivm.pipe<PIPE_MTE1>, wait>]} "user.macro_wait_inject" ins(%0 : memref<16xf16, #hivm.address_space<ub>>) outs(%0 : memref<16xf16, #hivm.address_space<ub>>) sync_related_args(%c0_i64 : i64)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.pipe_barrier[<PIPE_MTE2>]
    hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%0 : memref<16xf16, #hivm.address_space<ub>>)
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
}


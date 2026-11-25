module {
  func.func @custom_macro_sync_set_slot(%arg0: memref<4xf32>, %arg1: i64, %arg2: i64) attributes {hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0_i64 = arith.constant 0 : i64
    %c2_i64 = arith.constant 2 : i64
    %c-1_i64 = arith.constant -1 : i64
    hivm.hir.custom_macro {hivm.pipe_in = #hivm.pipe<PIPE_MTE2>, hivm.pipe_out = #hivm.pipe<PIPE_V>, hivm.tcore_type = #hivm.tcore_type<VECTOR>, symbol = "k_set_slot", sync_event_slots = [#hivm.sync_event_slot<#hivm.pipe<PIPE_MTE2>, #hivm.pipe<PIPE_MTE1>, set>, #hivm.sync_event_slot<#hivm.pipe<PIPE_M>, #hivm.pipe<PIPE_MTE2>, set, <EVENT_ID2>>]} "user.set_slot" ins(%arg0 : memref<4xf32>) outs(%arg0 : memref<4xf32>) sync_related_args(%c0_i64, %c2_i64 : i64, i64)
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE2>, <EVENT_ID2>]
    return
  }
}


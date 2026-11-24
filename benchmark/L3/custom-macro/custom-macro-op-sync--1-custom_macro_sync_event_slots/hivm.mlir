module {
  func.func @custom_macro_sync_event_slots(%arg0: memref<4xf32>, %arg1: tensor<4xf32>, %arg2: i64) attributes {hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c1_i64 = arith.constant 1 : i64
    %0 = tensor.empty() : tensor<4xf32>
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID1>]
    %c-1_i64 = arith.constant -1 : i64
    %1 = hivm.hir.custom_macro {hivm.pipe_in = #hivm.pipe<PIPE_MTE2>, hivm.pipe_out = #hivm.pipe<PIPE_V>, hivm.tcore_type = #hivm.tcore_type<VECTOR>, symbol = "k_custom_macro_sync", sync_event_slots = [#hivm.sync_event_slot<#hivm.pipe<PIPE_MTE2>, #hivm.pipe<PIPE_MTE1>, wait, <EVENT_ID1>>]} "user.macro_sync" ins(%arg0, %arg1 : memref<4xf32>, tensor<4xf32>) outs(%0 : tensor<4xf32>) -> tensor<4xf32> sync_related_args(%c1_i64 : i64)
    return
  }
}


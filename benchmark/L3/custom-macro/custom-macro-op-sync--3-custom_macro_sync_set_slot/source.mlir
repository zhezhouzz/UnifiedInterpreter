func.func @custom_macro_sync_set_slot(%arg0: memref<4xf32>, %evt0: i64, %evt1: i64)
    attributes {hacc.function_kind = #hacc.function_kind<DEVICE>} {
  hivm.hir.custom_macro
      {hivm.tcore_type = #hivm.tcore_type<VECTOR>,
       hivm.pipe_in = #hivm.pipe<PIPE_MTE2>,
       hivm.pipe_out = #hivm.pipe<PIPE_V>,
       symbol = "k_set_slot",
       sync_event_slots = [
         #hivm.sync_event_slot<#hivm.pipe<PIPE_MTE2>, #hivm.pipe<PIPE_MTE1>, set>,
         #hivm.sync_event_slot<#hivm.pipe<PIPE_M>, #hivm.pipe<PIPE_MTE2>, set, <EVENT_ID2>>
       ]}
      "user.set_slot"
      ins(%arg0 : memref<4xf32>)
      outs(%arg0 : memref<4xf32>)
      sync_related_args(%evt0, %evt1 : i64, i64)
  return
}


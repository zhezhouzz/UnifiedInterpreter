
func.func @custom_macro_sync_event_slots(%arg0: memref<4xf32>, %arg1: tensor<4xf32>,
                                         %evt0: i64)
    attributes {hacc.function_kind = #hacc.function_kind<DEVICE>} {
  %empty = tensor.empty() : tensor<4xf32>
  %0 = hivm.hir.custom_macro
      {hivm.tcore_type = #hivm.tcore_type<VECTOR>,
       hivm.pipe_in = #hivm.pipe<PIPE_MTE2>,
       hivm.pipe_out = #hivm.pipe<PIPE_V>,
       symbol = "k_custom_macro_sync",
       sync_event_slots = [
         #hivm.sync_event_slot<#hivm.pipe<PIPE_MTE2>, #hivm.pipe<PIPE_MTE1>, wait, <EVENT_ID1>>
       ]}
      "user.macro_sync"
      ins(%arg0, %arg1 : memref<4xf32>, tensor<4xf32>)
      outs(%empty : tensor<4xf32>) -> tensor<4xf32>
      sync_related_args(%evt0 : i64)
  return
}


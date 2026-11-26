module {
  func.func @kernel(%arg0: memref<32xf32>, %arg1: memref<32xf32>, %arg2: memref<32xf32>, %arg3: memref<32xf32>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    linalg.elemwise_unary {fun = #linalg.unary_fn<abs>} ins(%arg2 : memref<32xf32>) outs(%arg3 : memref<32xf32>)
    linalg.copy ins(%arg0 : memref<32xf32>) outs(%arg2 : memref<32xf32>)
    return
  }
}


module {
  func.func @kernel(%arg0: memref<1xf32>, %arg1: memref<1xf32>, %arg2: memref<1xf32>, %arg3: memref<1xf32>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %cst = arith.constant 7.000000e+00 : f32
    %c0 = arith.constant 0 : index
    linalg.elemwise_unary {fun = #linalg.unary_fn<abs>} ins(%arg2 : memref<1xf32>) outs(%arg3 : memref<1xf32>)
    memref.store %cst, %arg2[%c0] : memref<1xf32>
    linalg.elemwise_unary {fun = #linalg.unary_fn<abs>} ins(%arg2 : memref<1xf32>) outs(%arg3 : memref<1xf32>)
    return
  }
}


module {
  func.func @kernel(%arg0: index, %arg1: memref<32xf32>, %arg2: memref<32xf32>, %arg3: memref<32xf32>, %arg4: memref<32xf32>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %0 = scf.for %arg5 = %c0 to %arg0 step %c1 iter_args(%arg6 = %arg3) -> (memref<32xf32>) {
      scf.yield %arg4 : memref<32xf32>
    }
    linalg.copy ins(%arg1 : memref<32xf32>) outs(%arg3 : memref<32xf32>)
    linalg.elemwise_unary {fun = #linalg.unary_fn<abs>} ins(%0 : memref<32xf32>) outs(%arg4 : memref<32xf32>)
    linalg.copy ins(%arg4 : memref<32xf32>) outs(%arg2 : memref<32xf32>)
    return
  }
}


module {
  func.func @kernel(%arg0: memref<32xf32>, %arg1: memref<32xf32>, %arg2: index, %arg3: memref<32xf32>, %arg4: memref<32xf32>, %arg5: memref<32xf32>) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    scf.for %arg6 = %c0 to %arg2 step %c1 {
      %0 = arith.cmpi eq, %arg6, %c1 : index
      %1 = arith.cmpi eq, %arg6, %c2 : index
      %2 = arith.select %0, %arg4, %arg3 : memref<32xf32>
      %3 = arith.select %1, %arg1, %arg0 : memref<32xf32>
      linalg.copy ins(%3 : memref<32xf32>) outs(%2 : memref<32xf32>)
      linalg.elemwise_unary {fun = #linalg.unary_fn<abs>} ins(%2 : memref<32xf32>) outs(%arg5 : memref<32xf32>)
    }
    return
  }
}


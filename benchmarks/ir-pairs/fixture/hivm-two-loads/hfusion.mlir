module {
  func.func @two_loads(%arg0: memref<1xf32>, %arg1: memref<1xf32>, %arg2: memref<1xf32>, %arg3: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    scf.for %arg4 = %c0 to %arg3 step %c1 {
      linalg.copy ins(%arg0 : memref<1xf32>) outs(%arg2 : memref<1xf32>)
      linalg.copy ins(%arg1 : memref<1xf32>) outs(%arg2 : memref<1xf32>)
    }
    return
  }
}


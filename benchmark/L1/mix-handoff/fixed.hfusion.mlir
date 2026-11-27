module {
  func.func @cube(%arg0: memref<256xf32>, %arg1: memref<256xf32>) {
    memref.copy %arg1, %arg0 : memref<256xf32> to memref<256xf32>
    return
  }
  func.func @vector(%arg0: memref<256xf32>, %arg1: memref<256xf32>, %arg2: memref<256xf32>) {
    linalg.copy ins(%arg0 : memref<256xf32>) outs(%arg2 : memref<256xf32>)
    linalg.copy ins(%arg2 : memref<256xf32>) outs(%arg1 : memref<256xf32>)
    return
  }
}


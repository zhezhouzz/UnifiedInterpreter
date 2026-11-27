module {
  func.func @alias_copy(%arg0: memref<128xf32>, %arg1: memref<128xf32>) {
    %cst = arith.constant 0.000000e+00 : f32
    %alloc = memref.alloc() : memref<256xf32>
    %subview = memref.subview %alloc[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
    linalg.fill ins(%cst : f32) outs(%subview : memref<64xf32, strided<[1]>>)
    memref.copy %arg0, %arg1 : memref<128xf32> to memref<128xf32>
    return
  }
}


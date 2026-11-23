module {
  func.func @repro(%arg0: memref<128xf32>, %arg1: memref<64xf32>, %arg2: memref<128xf32>) {
    %alloc = memref.alloc() : memref<256xf32>
    %subview = memref.subview %alloc[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
    memref.copy %subview, %arg1 : memref<64xf32, strided<[1]>> to memref<64xf32>
    memref.copy %arg0, %arg2 : memref<128xf32> to memref<128xf32>
    return
  }
}

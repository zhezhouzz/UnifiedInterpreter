module {
  func.func @alias_copy(%a: memref<128xf32>, %c: memref<128xf32>) {
    %b = memref.alloc() : memref<256xf32>
    %b128 = memref.subview %b[0] [128] [1] : memref<256xf32> to memref<128xf32, strided<[1]>>
    memref.copy %a, %b128 : memref<128xf32> to memref<128xf32, strided<[1]>>
    %b64 = memref.subview %b[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
    %zero = arith.constant 0.0 : f32
    linalg.fill ins(%zero : f32) outs(%b64 : memref<64xf32, strided<[1]>>)
    memref.copy %b128, %c : memref<128xf32, strided<[1]>> to memref<128xf32>
    return
  }
}

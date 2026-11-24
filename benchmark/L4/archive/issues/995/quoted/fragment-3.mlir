func.func @repro(%data: memref<128xf32>, %out: memref<64xf32>, %out2: memref<128xf32>) {
  %b = memref.alloc() : memref<256xf32>
  %b128 = memref.subview %b[0] [128] [1] : memref<256xf32> to memref<128xf32, strided<[1]>>
  memref.copy %data, %b128 : memref<128xf32> to memref<128xf32, strided<[1]>>
  %b64 = memref.subview %b[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
  memref.copy %b64, %out : memref<64xf32, strided<[1]>> to memref<64xf32>
  memref.copy %b128, %out2 : memref<128xf32, strided<[1]>> to memref<128xf32>
  return
}

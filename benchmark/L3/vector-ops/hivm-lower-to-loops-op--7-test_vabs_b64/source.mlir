func.func @test_vabs_b64() {
   %allocIn0 = memref.alloc() : memref<64x8xi64>
   %allocOut = memref.alloc() : memref<64x8xi64>
   hivm.hir.vabs ins(%allocIn0 : memref<64x8xi64>) outs(%allocOut : memref<64x8xi64>)
   return
}


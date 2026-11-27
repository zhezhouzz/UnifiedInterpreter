func.func @test_vmin_b64() {
   %allocIn0 = memref.alloc() : memref<64xi64>
   %allocIn1 = memref.alloc() : memref<64xi64>
   %allocOut = memref.alloc() : memref<64xi64>
   hivm.hir.vmin ins(%allocIn0, %allocIn1 : memref<64xi64>, memref<64xi64>) outs(%allocOut : memref<64xi64>)
   return
}


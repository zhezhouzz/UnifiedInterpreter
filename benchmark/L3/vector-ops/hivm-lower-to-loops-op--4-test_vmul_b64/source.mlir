func.func @test_vmul_b64() {
   %allocIn0 = memref.alloc() : memref<64x8xi64>
   %allocIn1 = memref.alloc() : memref<64x8xi64>
   %allocOut = memref.alloc() : memref<64x8xi64>
   hivm.hir.vmul ins(%allocIn0, %allocIn1 : memref<64x8xi64>, memref<64x8xi64>) outs(%allocOut : memref<64x8xi64>)
   return
}


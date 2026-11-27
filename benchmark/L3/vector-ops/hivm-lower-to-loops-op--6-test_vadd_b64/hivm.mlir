module {
  func.func @test_vadd_b64() {
    %alloc = memref.alloc() : memref<64x8xi64>
    %alloc_0 = memref.alloc() : memref<64x8xi64>
    %alloc_1 = memref.alloc() : memref<64x8xi64>
    hivm.hir.vadd ins(%alloc, %alloc_0 : memref<64x8xi64>, memref<64x8xi64>) outs(%alloc_1 : memref<64x8xi64>)
    return
  }
}


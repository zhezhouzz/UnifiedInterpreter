module {
  func.func @test_vabs_b64() {
    %alloc = memref.alloc() : memref<64x8xi64>
    %alloc_0 = memref.alloc() : memref<64x8xi64>
    hivm.hir.vabs ins(%alloc : memref<64x8xi64>) outs(%alloc_0 : memref<64x8xi64>)
    return
  }
}


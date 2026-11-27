module {
  func.func @test_vmin_b64() {
    %alloc = memref.alloc() : memref<64xi64>
    %alloc_0 = memref.alloc() : memref<64xi64>
    %alloc_1 = memref.alloc() : memref<64xi64>
    hivm.hir.vmin ins(%alloc, %alloc_0 : memref<64xi64>, memref<64xi64>) outs(%alloc_1 : memref<64xi64>)
    return
  }
}


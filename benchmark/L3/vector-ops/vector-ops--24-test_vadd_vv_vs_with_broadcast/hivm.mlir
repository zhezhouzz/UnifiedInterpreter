module {
  func.func @test_vadd_vv_vs_with_broadcast(%arg0: memref<1x?xf16>, %arg1: memref<1x?xf16>, %arg2: memref<?x?xf16>, %arg3: f16) {
    hivm.hir.vadd ins(%arg0, %arg1 : memref<1x?xf16>, memref<1x?xf16>) outs(%arg2 : memref<?x?xf16>) broadcast = [0]
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vadd ins(%arg0, %arg3 : memref<1x?xf16>, f16) outs(%arg2 : memref<?x?xf16>) broadcast = [0]
    return
  }
}


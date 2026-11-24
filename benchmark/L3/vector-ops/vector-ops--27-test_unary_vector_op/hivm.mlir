module {
  func.func @test_unary_vector_op(%arg0: memref<?x?xf16>, %arg1: memref<?x?xf16>) {
    hivm.hir.vexp ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vabs ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vln ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vrelu ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vrsqrt ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vsqrt ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vrec ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vtanh ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vsin ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcos ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.verf ins(%arg0 : memref<?x?xf16>) outs(%arg1 : memref<?x?xf16>)
    return
  }
}


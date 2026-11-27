module {
  func.func @test_binary_vector_op_vv_vs(%arg0: memref<?x?xf16>, %arg1: memref<?x?xf16>, %arg2: memref<?x?xf16>, %arg3: f16) {
    hivm.hir.vadd ins(%arg0, %arg1 : memref<?x?xf16>, memref<?x?xf16>) outs(%arg2 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vmul ins(%arg0, %arg1 : memref<?x?xf16>, memref<?x?xf16>) outs(%arg2 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vsub ins(%arg0, %arg1 : memref<?x?xf16>, memref<?x?xf16>) outs(%arg2 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vdiv ins(%arg0, %arg1 : memref<?x?xf16>, memref<?x?xf16>) outs(%arg2 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vmax ins(%arg0, %arg1 : memref<?x?xf16>, memref<?x?xf16>) outs(%arg2 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vmin ins(%arg0, %arg1 : memref<?x?xf16>, memref<?x?xf16>) outs(%arg2 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vadd ins(%arg0, %arg3 : memref<?x?xf16>, f16) outs(%arg2 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vmul ins(%arg0, %arg3 : memref<?x?xf16>, f16) outs(%arg2 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vsub ins(%arg0, %arg3 : memref<?x?xf16>, f16) outs(%arg2 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vmax ins(%arg0, %arg3 : memref<?x?xf16>, f16) outs(%arg2 : memref<?x?xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vmin ins(%arg0, %arg3 : memref<?x?xf16>, f16) outs(%arg2 : memref<?x?xf16>)
    return
  }
}


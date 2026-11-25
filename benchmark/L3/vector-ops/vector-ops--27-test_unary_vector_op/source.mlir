func.func @test_unary_vector_op(
  %src : memref<?x?xf16>, %dst : memref<?x?xf16>) {
  hivm.hir.vexp ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  hivm.hir.vabs ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  hivm.hir.vln ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  hivm.hir.vrelu ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  hivm.hir.vrsqrt ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  hivm.hir.vsqrt ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  hivm.hir.vrec ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  hivm.hir.vtanh ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  hivm.hir.vsin ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  hivm.hir.vcos ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  hivm.hir.verf ins(%src : memref<?x?xf16>) outs(%dst : memref<?x?xf16>)
  return
}

func.func @test_vadd_vv_vs_with_broadcast(
  %src1 : memref<1x?xf16>, %src2 : memref<1x?xf16>, %dst : memref<?x?xf16>, %cst : f16) {
  hivm.hir.vadd ins(%src1, %src2 : memref<1x?xf16>, memref<1x?xf16>)
                outs(%dst : memref<?x?xf16>)
                broadcast = [0]

  hivm.hir.vadd ins(%src1, %cst : memref<1x?xf16>, f16)
                outs(%dst : memref<?x?xf16>)
                broadcast = [0]
  return
}

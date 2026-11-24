func.func @test_batchMmadL1() {
  %ma = memref.alloc() : memref<2x256x128xf16>
  %mb = memref.alloc() : memref<2x128x256xf16>
  %mc = memref.alloc() : memref<2x256x256xf32>
  %c256 = arith.constant 256 : index
  %c128 = arith.constant 128 : index
  %init = arith.constant 1 : i1
  hivm.hir.batchMmadL1 ins(%ma, %mb, %init, %c256, %c128, %c256 :
                        memref<2x256x128xf16>, memref<2x128x256xf16>, i1, index, index, index)
                  outs(%mc : memref<2x256x256xf32>)
  return
}

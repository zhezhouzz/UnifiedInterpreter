func.func @test_mmadL1_with_k_init() {
  %mc = memref.alloc() : memref<256x256xf32>
  %start = arith.constant 0 : index
  %end = arith.constant 1024 : index
  %step = arith.constant 128 : index
  %c256 = arith.constant 256 : index
  %c128 = arith.constant 128 : index
  scf.for %arg0 = %start to %end step %step {
    %ma = memref.alloc() : memref<256x128xf16>
    %mb = memref.alloc() : memref<128x256xf16>
    %init_condition = arith.cmpi eq, %arg0, %start : index
    hivm.hir.mmadL1 ins(%ma, %mb, %init_condition, %c256, %c128, %c256 :
                          memref<256x128xf16>, memref<128x256xf16>, i1, index, index, index)
                    outs(%mc : memref<256x256xf32>)
  }

  return
}

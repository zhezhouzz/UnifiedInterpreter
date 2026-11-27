module {
  func.func @test_mmadL1_with_k_init() {
    %alloc = memref.alloc() : memref<256x256xf32>
    %c0 = arith.constant 0 : index
    %c1024 = arith.constant 1024 : index
    %c128 = arith.constant 128 : index
    %c256 = arith.constant 256 : index
    %c128_0 = arith.constant 128 : index
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    scf.for %arg0 = %c0 to %c1024 step %c128 {
      %alloc_1 = memref.alloc() : memref<256x128xf16>
      %alloc_2 = memref.alloc() : memref<128x256xf16>
      %0 = arith.cmpi eq, %arg0, %c0 : index
      hivm.hir.mmadL1 ins(%alloc_1, %alloc_2, %0, %c256, %c128_0, %c256 : memref<256x128xf16>, memref<128x256xf16>, i1, index, index, index) outs(%alloc : memref<256x256xf32>)
    }
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    return
  }
}


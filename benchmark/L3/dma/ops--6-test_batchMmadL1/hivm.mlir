module {
  func.func @test_batchMmadL1() {
    %alloc = memref.alloc() : memref<2x256x128xf16>
    %alloc_0 = memref.alloc() : memref<2x128x256xf16>
    %alloc_1 = memref.alloc() : memref<2x256x256xf32>
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    %true = arith.constant true
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.batchMmadL1 ins(%alloc, %alloc_0, %true, %c256, %c128, %c256 : memref<2x256x128xf16>, memref<2x128x256xf16>, i1, index, index, index) outs(%alloc_1 : memref<2x256x256xf32>)
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    return
  }
}


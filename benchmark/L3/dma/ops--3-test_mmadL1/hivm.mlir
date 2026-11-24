module {
  func.func @test_mmadL1() {
    %alloc = memref.alloc() : memref<256x128xf16>
    %alloc_0 = memref.alloc() : memref<128x256xf16>
    %alloc_1 = memref.alloc() : memref<256x256xf32>
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    %true = arith.constant true
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.mmadL1 ins(%alloc, %alloc_0, %true, %c256, %c128, %c256 : memref<256x128xf16>, memref<128x256xf16>, i1, index, index, index) outs(%alloc_1 : memref<256x256xf32>)
    %alloc_2 = memref.alloc() : memref<128x256xf16>
    hivm.hir.mmadL1 {a_transpose} ins(%alloc_2, %alloc_0, %true, %c256, %c128, %c256 : memref<128x256xf16>, memref<128x256xf16>, i1, index, index, index) outs(%alloc_1 : memref<256x256xf32>)
    %alloc_3 = memref.alloc() : memref<256x128xf16>
    hivm.hir.mmadL1 {b_transpose} ins(%alloc, %alloc_3, %true, %c256, %c128, %c256 : memref<256x128xf16>, memref<256x128xf16>, i1, index, index, index) outs(%alloc_1 : memref<256x256xf32>)
    hivm.hir.mmadL1 {a_transpose, b_transpose} ins(%alloc_2, %alloc_3, %true, %c256, %c128, %c256 : memref<128x256xf16>, memref<256x128xf16>, i1, index, index, index) outs(%alloc_1 : memref<256x256xf32>)
    %alloc_4 = memref.alloc() : memref<256x128xf32>
    %alloc_5 = memref.alloc() : memref<128x256xf32>
    hivm.hir.mmadL1 ins(%alloc_4, %alloc_5, %true, %c256, %c128, %c256 : memref<256x128xf32>, memref<128x256xf32>, i1, index, index, index) outs(%alloc_1 : memref<256x256xf32>)
    %0 = tensor.empty() : tensor<256x128xi8>
    %1 = tensor.empty() : tensor<128x256xi8>
    %2 = tensor.empty() : tensor<256x256xi32>
    %3 = hivm.hir.mmadL1 ins(%0, %1, %true, %c256, %c128, %c256 : tensor<256x128xi8>, tensor<128x256xi8>, i1, index, index, index) outs(%2 : tensor<256x256xi32>) -> tensor<256x256xi32>
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    "some_use"(%3) : (tensor<256x256xi32>) -> ()
    return
  }
}


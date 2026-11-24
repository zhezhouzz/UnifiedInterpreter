module attributes {hacc.target = #hacc.target<"Ascend960">} {
  func.func @test_mmadmxL1_transpose_with_config() {
    %alloc = memref.alloc() : memref<256x128xi8>
    %alloc_0 = memref.alloc() : memref<128x256xi8>
    %alloc_1 = memref.alloc() : memref<128x256xi8>
    %alloc_2 = memref.alloc() : memref<256x128xi8>
    %alloc_3 = memref.alloc() : memref<256x4xui8>
    %alloc_4 = memref.alloc() : memref<256x4xui8>
    %alloc_5 = memref.alloc() : memref<256x256xf32>
    %true = arith.constant true
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.mmadmxL1 {lhsFormat = 1 : i32, rhsFormat = 1 : i32} a_transpose ins(%alloc_1, %alloc_0, %alloc_3, %alloc_4, %true, %c256, %c128, %c256 : memref<128x256xi8>, memref<128x256xi8>, memref<256x4xui8>, memref<256x4xui8>, i1, index, index, index) outs(%alloc_5 : memref<256x256xf32>)
    hivm.hir.mmadmxL1 {lhsFormat = 2 : i32, rhsFormat = 2 : i32} b_transpose ins(%alloc, %alloc_2, %alloc_3, %alloc_4, %true, %c256, %c128, %c256 : memref<256x128xi8>, memref<256x128xi8>, memref<256x4xui8>, memref<256x4xui8>, i1, index, index, index) outs(%alloc_5 : memref<256x256xf32>)
    hivm.hir.mmadmxL1 {lhsFormat = 2 : i32, rhsFormat = 2 : i32} a_transpose b_transpose ins(%alloc_1, %alloc_2, %alloc_3, %alloc_4, %true, %c256, %c128, %c256 : memref<128x256xi8>, memref<256x128xi8>, memref<256x4xui8>, memref<256x4xui8>, i1, index, index, index) outs(%alloc_5 : memref<256x256xf32>)
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    return
  }
}


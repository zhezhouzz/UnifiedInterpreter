module {
  func.func @test_mmadL1_with_k_init_tensor() {
    %0 = tensor.empty() : tensor<256x256xf32>
    %c0 = arith.constant 0 : index
    %c1024 = arith.constant 1024 : index
    %c128 = arith.constant 128 : index
    %c256 = arith.constant 256 : index
    %c128_0 = arith.constant 128 : index
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    %1 = scf.for %arg0 = %c0 to %c1024 step %c128 iter_args(%arg1 = %0) -> (tensor<256x256xf32>) {
      %2 = tensor.empty() : tensor<256x128xf16>
      %3 = tensor.empty() : tensor<128x256xf16>
      %4 = arith.cmpi eq, %arg0, %c0 : index
      %5 = hivm.hir.mmadL1 ins(%2, %3, %4, %c256, %c128_0, %c256 : tensor<256x128xf16>, tensor<128x256xf16>, i1, index, index, index) outs(%arg1 : tensor<256x256xf32>) -> tensor<256x256xf32>
      scf.yield %5 : tensor<256x256xf32>
    }
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    return
  }
}


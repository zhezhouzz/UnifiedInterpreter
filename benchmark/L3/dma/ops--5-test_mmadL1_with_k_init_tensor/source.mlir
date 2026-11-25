func.func @test_mmadL1_with_k_init_tensor() {
  %mc = tensor.empty() : tensor<256x256xf32>
  %start = arith.constant 0 : index
  %end = arith.constant 1024 : index
  %step = arith.constant 128 : index
  %c256 = arith.constant 256 : index
  %c128 = arith.constant 128 : index
  %scf_ret = scf.for %arg0 = %start to %end step %step iter_args(%mC_iter = %mc) -> (tensor<256x256xf32>) {
    %ma = tensor.empty() : tensor<256x128xf16>
    %mb = tensor.empty() : tensor<128x256xf16>
    %init_condition = arith.cmpi eq, %arg0, %start : index
    %res = hivm.hir.mmadL1 ins(%ma, %mb, %init_condition, %c256, %c128, %c256 :
                                 tensor<256x128xf16>, tensor<128x256xf16>, i1, index, index, index)
                           outs(%mC_iter : tensor<256x256xf32>) -> tensor<256x256xf32>
    scf.yield %res : tensor<256x256xf32>
  }

  return
}

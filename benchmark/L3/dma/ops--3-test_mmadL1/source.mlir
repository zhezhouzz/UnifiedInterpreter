func.func @test_mmadL1() {
  %ma = memref.alloc() : memref<256x128xf16>
  %mb = memref.alloc() : memref<128x256xf16>
  %mc = memref.alloc() : memref<256x256xf32>
  %c256 = arith.constant 256 : index
  %c128 = arith.constant 128 : index
  %init = arith.constant 1 : i1
  hivm.hir.mmadL1 ins(%ma, %mb, %init, %c256, %c128, %c256 :
                        memref<256x128xf16>, memref<128x256xf16>, i1, index, index, index)
                  outs(%mc : memref<256x256xf32>)

  %ma_t = memref.alloc() : memref<128x256xf16>
  hivm.hir.mmadL1 {a_transpose}
                 ins(%ma_t, %mb, %init, %c256, %c128, %c256 :
                       memref<128x256xf16>, memref<128x256xf16>, i1, index, index, index)
                 outs(%mc : memref<256x256xf32>)

  %mb_t = memref.alloc() : memref<256x128xf16>
  hivm.hir.mmadL1 {b_transpose}
                 ins(%ma, %mb_t, %init, %c256, %c128, %c256 :
                       memref<256x128xf16>, memref<256x128xf16>, i1, index, index, index)
                 outs(%mc : memref<256x256xf32>)

  hivm.hir.mmadL1 {a_transpose, b_transpose}
                 ins(%ma_t, %mb_t, %init, %c256, %c128, %c256 :
                       memref<128x256xf16>, memref<256x128xf16>, i1, index, index, index)
                 outs(%mc : memref<256x256xf32>)

  %ma_f32 = memref.alloc() : memref<256x128xf32>
  %mb_f32 = memref.alloc() : memref<128x256xf32>
  hivm.hir.mmadL1 ins(%ma_f32, %mb_f32, %init, %c256, %c128, %c256 :
                        memref<256x128xf32>, memref<128x256xf32>, i1, index, index, index)
                  outs(%mc : memref<256x256xf32>)

  %ma_i8 = tensor.empty() : tensor<256x128xi8>
  %mb_i8 = tensor.empty() : tensor<128x256xi8>
  %mc_i32 = tensor.empty() : tensor<256x256xi32>
  %res_i32 = hivm.hir.mmadL1
      ins(%ma_i8, %mb_i8, %init, %c256, %c128, %c256 :
          tensor<256x128xi8>, tensor<128x256xi8>, i1, index, index, index)
      outs(%mc_i32 : tensor<256x256xi32>) -> tensor<256x256xi32>
  "some_use"(%res_i32) : (tensor<256x256xi32>) -> ()
  return
}

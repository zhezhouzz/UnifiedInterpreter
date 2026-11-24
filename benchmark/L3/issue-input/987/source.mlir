module attributes {hacc.target = #hacc.target<"Ascend960">} {
  func.func @test_mmadmxL1_transpose_with_config() {
    %ma = memref.alloc() : memref<256x128xi8>
    %mb = memref.alloc() : memref<128x256xi8>
    %ma_t = memref.alloc() : memref<128x256xi8>
    %mb_t = memref.alloc() : memref<256x128xi8>
    %scaleA = memref.alloc() : memref<256x4xui8>
    %scaleB = memref.alloc() : memref<256x4xui8>
    %mc = memref.alloc() : memref<256x256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index

    hivm.hir.mmadmxL1 {a_transpose, lhsFormat = 1 : i32, rhsFormat = 1 : i32}
      ins(%ma_t, %mb, %scaleA, %scaleB, %init, %c256, %c128, %c256 :
          memref<128x256xi8>, memref<128x256xi8>,
          memref<256x4xui8>, memref<256x4xui8>, i1, index, index, index)
      outs(%mc : memref<256x256xf32>)

    hivm.hir.mmadmxL1 {b_transpose, lhsFormat = 2 : i32, rhsFormat = 2 : i32}
      ins(%ma, %mb_t, %scaleA, %scaleB, %init, %c256, %c128, %c256 :
          memref<256x128xi8>, memref<256x128xi8>,
          memref<256x4xui8>, memref<256x4xui8>, i1, index, index, index)
      outs(%mc : memref<256x256xf32>)

    hivm.hir.mmadmxL1 {a_transpose, b_transpose, lhsFormat = 2 : i32, rhsFormat = 2 : i32}
      ins(%ma_t, %mb_t, %scaleA, %scaleB, %init, %c256, %c128, %c256 :
          memref<128x256xi8>, memref<256x128xi8>,
          memref<256x4xui8>, memref<256x4xui8>, i1, index, index, index)
      outs(%mc : memref<256x256xf32>)
    return
  }
}

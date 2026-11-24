// RUN: bishengir-opt %s -hacc-append-device-spec=target=Ascend960 -convert-hivm-to-std -split-input-file | FileCheck %s

// Mixed-precision mmadL1 on Ascend960: the emitted library symbol carries both
// the A and the B element type, mirroring the mma_tile_<a>_<b>_to_<dst>
// entry points registered by the template library on dav-920r1.
module attributes {hacc.target = #hacc.target<"Ascend960">} {
  // CHECK-LABEL: func.func @test_mmadL1_bf16_e4m3
  // CHECK: call @mma_tile_bfloat16_t_float8_e4m3_t_to_float(
  // CHECK-NOT: hivm.hir.mmadL1
  func.func @test_mmadL1_bf16_e4m3() {
    %ma = memref.alloc() : memref<256x128xbf16>
    %mb = memref.alloc() : memref<128x256xf8E4M3FN>
    %mc = memref.alloc() : memref<256x256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 ins(%ma, %mb, %init, %c256, %c128, %c256 :
                          memref<256x128xbf16>, memref<128x256xf8E4M3FN>,
                          i1, index, index, index)
                    outs(%mc : memref<256x256xf32>)
    return
  }

  // CHECK-LABEL: func.func @test_mmadL1_f16_e4m3
  // CHECK: call @mma_tile_half_float8_e4m3_t_to_float(
  // CHECK-NOT: hivm.hir.mmadL1
  func.func @test_mmadL1_f16_e4m3() {
    %ma = memref.alloc() : memref<256x128xf16>
    %mb = memref.alloc() : memref<128x256xf8E4M3FN>
    %mc = memref.alloc() : memref<256x256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 ins(%ma, %mb, %init, %c256, %c128, %c256 :
                          memref<256x128xf16>, memref<128x256xf8E4M3FN>,
                          i1, index, index, index)
                    outs(%mc : memref<256x256xf32>)
    return
  }

  // CHECK-LABEL: func.func @test_mmadL1_bf16_i8
  // CHECK: call @mma_tile_bfloat16_t_int8_t_to_float(
  // CHECK-NOT: hivm.hir.mmadL1
  func.func @test_mmadL1_bf16_i8() {
    %ma = memref.alloc() : memref<256x128xbf16>
    %mb = memref.alloc() : memref<128x256xi8>
    %mc = memref.alloc() : memref<256x256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 ins(%ma, %mb, %init, %c256, %c128, %c256 :
                          memref<256x128xbf16>, memref<128x256xi8>,
                          i1, index, index, index)
                    outs(%mc : memref<256x256xf32>)
    return
  }

  // CHECK-LABEL: func.func @test_mmadL1_f16_i8
  // CHECK: call @mma_tile_half_int8_t_to_float(
  // CHECK-NOT: hivm.hir.mmadL1
  func.func @test_mmadL1_f16_i8() {
    %ma = memref.alloc() : memref<256x128xf16>
    %mb = memref.alloc() : memref<128x256xi8>
    %mc = memref.alloc() : memref<256x256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 ins(%ma, %mb, %init, %c256, %c128, %c256 :
                          memref<256x128xf16>, memref<128x256xi8>,
                          i1, index, index, index)
                    outs(%mc : memref<256x256xf32>)
    return
  }

  // CHECK-LABEL: func.func @test_mmadL1_e4m3_e5m2
  // CHECK: call @mma_tile_float8_e4m3_t_float8_e5m2_t_to_float(
  // CHECK-NOT: hivm.hir.mmadL1
  func.func @test_mmadL1_e4m3_e5m2() {
    %ma = memref.alloc() : memref<256x128xf8E4M3FN>
    %mb = memref.alloc() : memref<128x256xf8E5M2>
    %mc = memref.alloc() : memref<256x256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 ins(%ma, %mb, %init, %c256, %c128, %c256 :
                          memref<256x128xf8E4M3FN>, memref<128x256xf8E5M2>,
                          i1, index, index, index)
                    outs(%mc : memref<256x256xf32>)
    return
  }

  // CHECK-LABEL: func.func @test_mmadL1_e5m2_e4m3
  // CHECK: call @mma_tile_float8_e5m2_t_float8_e4m3_t_to_float(
  // CHECK-NOT: hivm.hir.mmadL1
  func.func @test_mmadL1_e5m2_e4m3() {
    %ma = memref.alloc() : memref<256x128xf8E5M2>
    %mb = memref.alloc() : memref<128x256xf8E4M3FN>
    %mc = memref.alloc() : memref<256x256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 ins(%ma, %mb, %init, %c256, %c128, %c256 :
                          memref<256x128xf8E5M2>, memref<128x256xf8E4M3FN>,
                          i1, index, index, index)
                    outs(%mc : memref<256x256xf32>)
    return
  }

  // CHECK-LABEL: func.func @test_mmadL1_bf16_e4m3_with_bias
  // CHECK: call @mma_tile_with_float_bias_bfloat16_t_float8_e4m3_t_to_float(
  // CHECK-NOT: hivm.hir.mmadL1
  func.func @test_mmadL1_bf16_e4m3_with_bias() {
    %ma = memref.alloc() : memref<256x128xbf16>
    %mb = memref.alloc() : memref<128x256xf8E4M3FN>
    %mc = memref.alloc() : memref<256x256xf32>
    %bias = memref.alloc() : memref<256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 ins(%ma, %mb, %init, %c256, %c128, %c256, %bias :
                          memref<256x128xbf16>, memref<128x256xf8E4M3FN>,
                          i1, index, index, index, memref<256xf32>)
                    outs(%mc : memref<256x256xf32>)
    return
  }

  // Same element type on both sides keeps the historical single-element-type
  // symbol, so the existing ABI stays untouched.
  // CHECK-LABEL: func.func @test_mmadL1_homo_unchanged
  // CHECK: call @mma_tile_bfloat16_t_to_float(
  // CHECK-NOT: call @mma_tile_bfloat16_t_bfloat16_t_to_float
  func.func @test_mmadL1_homo_unchanged() {
    %ma = memref.alloc() : memref<256x128xbf16>
    %mb = memref.alloc() : memref<128x256xbf16>
    %mc = memref.alloc() : memref<256x256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 ins(%ma, %mb, %init, %c256, %c128, %c256 :
                          memref<256x128xbf16>, memref<128x256xbf16>,
                          i1, index, index, index)
                    outs(%mc : memref<256x256xf32>)
    return
  }

  // Packed 4-bit weight (s4) MMAD: A stays a normal element, B is a packed
  // int4b_t buffer and enable_I4 selects the dedicated mad_*s4 intrinsic.
  // The library symbol follows the plain mma_tile_<a>_<b>_to_<dst> naming.
  // CHECK-LABEL: func.func @test_mmadL1_bf16_s4
  // CHECK: call @mma_tile_bfloat16_t_int4b_t_to_float(
  // CHECK-NOT: hivm.hir.mmadL1
  func.func @test_mmadL1_bf16_s4() {
    %ma = memref.alloc() : memref<256x128xbf16>
    %mb = memref.alloc() : memref<128x256xi4>
    %mc = memref.alloc() : memref<256x256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 {enable_I4}
        ins(%ma, %mb, %init, %c256, %c128, %c256 :
            memref<256x128xbf16>, memref<128x256xi4>, i1, index, index, index)
        outs(%mc : memref<256x256xf32>)
    return
  }

  // CHECK-LABEL: func.func @test_mmadL1_f16_s4
  // CHECK: call @mma_tile_half_int4b_t_to_float(
  func.func @test_mmadL1_f16_s4() {
    %ma = memref.alloc() : memref<256x128xf16>
    %mb = memref.alloc() : memref<128x256xi4>
    %mc = memref.alloc() : memref<256x256xf32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 {enable_I4}
        ins(%ma, %mb, %init, %c256, %c128, %c256 :
            memref<256x128xf16>, memref<128x256xi4>, i1, index, index, index)
        outs(%mc : memref<256x256xf32>)
    return
  }

  // CHECK-LABEL: func.func @test_mmadL1_s8_s4
  // CHECK: call @mma_tile_int8_t_int4b_t_to_int32_t(
  func.func @test_mmadL1_s8_s4() {
    %ma = memref.alloc() : memref<256x128xi8>
    %mb = memref.alloc() : memref<128x256xi4>
    %mc = memref.alloc() : memref<256x256xi32>
    %init = arith.constant 1 : i1
    %c256 = arith.constant 256 : index
    %c128 = arith.constant 128 : index
    hivm.hir.mmadL1 {enable_I4}
        ins(%ma, %mb, %init, %c256, %c128, %c256 :
            memref<256x128xi8>, memref<128x256xi4>, i1, index, index, index)
        outs(%mc : memref<256x256xi32>)
    return
  }
}

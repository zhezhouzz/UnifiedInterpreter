module {
  func.func @test_vadd_v128_f16(%arg0: vector<128xf16>, %arg1: vector<128xf16>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vadd %arg0, %arg1, %arg2 : vector<128xf16>, vector<256xi1>
    "test.test"(%0) : (vector<128xf16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vadd_v128_s16(%arg0: vector<128xsi16>, %arg1: vector<128xsi16>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vadd %arg0, %arg1, %arg2 : vector<128xsi16>, vector<256xi1>
    "test.test"(%0) : (vector<128xsi16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vadd_v128_u16(%arg0: vector<128xui16>, %arg1: vector<128xui16>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vadd %arg0, %arg1, %arg2 : vector<128xui16>, vector<256xi1>
    "test.test"(%0) : (vector<128xui16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vadd_v256_s8(%arg0: vector<256xsi8>, %arg1: vector<256xsi8>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vadd %arg0, %arg1, %arg2 : vector<256xsi8>, vector<256xi1>
    "test.test"(%0) : (vector<256xsi8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vadd_v256_u8(%arg0: vector<256xui8>, %arg1: vector<256xui8>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vadd %arg0, %arg1, %arg2 : vector<256xui8>, vector<256xi1>
    "test.test"(%0) : (vector<256xui8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vadd_v64_f32(%arg0: vector<64xf32>, %arg1: vector<64xf32>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vadd %arg0, %arg1, %arg2 : vector<64xf32>, vector<256xi1>
    "test.test"(%0) : (vector<64xf32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vadd_v64_s32(%arg0: vector<64xsi32>, %arg1: vector<64xsi32>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vadd %arg0, %arg1, %arg2 : vector<64xsi32>, vector<256xi1>
    "test.test"(%0) : (vector<64xsi32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vadd_v64_u32(%arg0: vector<64xui32>, %arg1: vector<64xui32>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vadd %arg0, %arg1, %arg2 : vector<64xui32>, vector<256xi1>
    "test.test"(%0) : (vector<64xui32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vmul_v128_f16(%arg0: vector<128xf16>, %arg1: vector<128xf16>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vmul %arg0, %arg1, %arg2 : vector<128xf16>, vector<256xi1>
    "test.test"(%0) : (vector<128xf16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vmul_v128_s16(%arg0: vector<128xsi16>, %arg1: vector<128xsi16>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vmul %arg0, %arg1, %arg2 : vector<128xsi16>, vector<256xi1>
    "test.test"(%0) : (vector<128xsi16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vmul_v128_u16(%arg0: vector<128xui16>, %arg1: vector<128xui16>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vmul %arg0, %arg1, %arg2 : vector<128xui16>, vector<256xi1>
    "test.test"(%0) : (vector<128xui16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vmul_v256_s8(%arg0: vector<256xsi8>, %arg1: vector<256xsi8>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vmul %arg0, %arg1, %arg2 : vector<256xsi8>, vector<256xi1>
    "test.test"(%0) : (vector<256xsi8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vmul_v256_u8(%arg0: vector<256xui8>, %arg1: vector<256xui8>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vmul %arg0, %arg1, %arg2 : vector<256xui8>, vector<256xi1>
    "test.test"(%0) : (vector<256xui8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vmul_v64_f32(%arg0: vector<64xf32>, %arg1: vector<64xf32>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vmul %arg0, %arg1, %arg2 : vector<64xf32>, vector<256xi1>
    "test.test"(%0) : (vector<64xf32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vmul_v64_s32(%arg0: vector<64xsi32>, %arg1: vector<64xsi32>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vmul %arg0, %arg1, %arg2 : vector<64xsi32>, vector<256xi1>
    "test.test"(%0) : (vector<64xsi32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vmul_v64_u32(%arg0: vector<64xui32>, %arg1: vector<64xui32>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vmul %arg0, %arg1, %arg2 : vector<64xui32>, vector<256xi1>
    "test.test"(%0) : (vector<64xui32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vsub_v128_f16(%arg0: vector<128xf16>, %arg1: vector<128xf16>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vsub %arg0, %arg1, %arg2 : vector<128xf16>, vector<256xi1>
    "test.test"(%0) : (vector<128xf16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vsub_v128_s16(%arg0: vector<128xsi16>, %arg1: vector<128xsi16>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vsub %arg0, %arg1, %arg2 : vector<128xsi16>, vector<256xi1>
    "test.test"(%0) : (vector<128xsi16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vsub_v128_u16(%arg0: vector<128xui16>, %arg1: vector<128xui16>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vsub %arg0, %arg1, %arg2 : vector<128xui16>, vector<256xi1>
    "test.test"(%0) : (vector<128xui16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vsub_v256_s8(%arg0: vector<256xsi8>, %arg1: vector<256xsi8>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vsub %arg0, %arg1, %arg2 : vector<256xsi8>, vector<256xi1>
    "test.test"(%0) : (vector<256xsi8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vsub_v256_u8(%arg0: vector<256xui8>, %arg1: vector<256xui8>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vsub %arg0, %arg1, %arg2 : vector<256xui8>, vector<256xi1>
    "test.test"(%0) : (vector<256xui8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vsub_v64_f32(%arg0: vector<64xf32>, %arg1: vector<64xf32>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vsub %arg0, %arg1, %arg2 : vector<64xf32>, vector<256xi1>
    "test.test"(%0) : (vector<64xf32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vsub_v64_s32(%arg0: vector<64xsi32>, %arg1: vector<64xsi32>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vsub %arg0, %arg1, %arg2 : vector<64xsi32>, vector<256xi1>
    "test.test"(%0) : (vector<64xsi32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vsub_v64_u32(%arg0: vector<64xui32>, %arg1: vector<64xui32>, %arg2: vector<256xi1>) {
    %0 = ave.hir.vsub %arg0, %arg1, %arg2 : vector<64xui32>, vector<256xi1>
    "test.test"(%0) : (vector<64xui32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vrelu_v128_f16(%arg0: vector<128xf16>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vrelu %arg0, %arg1 : vector<128xf16>, vector<256xi1>
    "test.test"(%0) : (vector<128xf16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vrelu_v64_f32(%arg0: vector<64xf32>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vrelu %arg0, %arg1 : vector<64xf32>, vector<256xi1>
    "test.test"(%0) : (vector<64xf32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vrelu_v128_s32(%arg0: vector<64xsi32>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vrelu %arg0, %arg1 : vector<64xsi32>, vector<256xi1>
    "test.test"(%0) : (vector<64xsi32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vabs_v256_s8(%arg0: vector<256xsi8>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vabs %arg0, %arg1 : vector<256xsi8>, vector<256xi1>
    "test.test"(%0) : (vector<256xsi8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vabs_v128_s16(%arg0: vector<128xsi16>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vabs %arg0, %arg1 : vector<128xsi16>, vector<256xi1>
    "test.test"(%0) : (vector<128xsi16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vabs_v128_f16(%arg0: vector<128xf16>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vabs %arg0, %arg1 : vector<128xf16>, vector<256xi1>
    "test.test"(%0) : (vector<128xf16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vabs_v64_s32(%arg0: vector<64xsi32>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vabs %arg0, %arg1 : vector<64xsi32>, vector<256xi1>
    "test.test"(%0) : (vector<64xsi32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vabs_v64_f32(%arg0: vector<64xf32>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vabs %arg0, %arg1 : vector<64xf32>, vector<256xi1>
    "test.test"(%0) : (vector<64xf32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vneg_v256_s8(%arg0: vector<256xsi8>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vneg %arg0, %arg1 : vector<256xsi8>, vector<256xi1>
    "test.test"(%0) : (vector<256xsi8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vneg_v128_s16(%arg0: vector<128xsi16>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vneg %arg0, %arg1 : vector<128xsi16>, vector<256xi1>
    "test.test"(%0) : (vector<128xsi16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vneg_v128_f16(%arg0: vector<128xf16>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vneg %arg0, %arg1 : vector<128xf16>, vector<256xi1>
    "test.test"(%0) : (vector<128xf16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vneg_v64_s32(%arg0: vector<64xsi32>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vneg %arg0, %arg1 : vector<64xsi32>, vector<256xi1>
    "test.test"(%0) : (vector<64xsi32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vneg_v64_f32(%arg0: vector<64xf32>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vneg %arg0, %arg1 : vector<64xf32>, vector<256xi1>
    "test.test"(%0) : (vector<64xf32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vnot_v256_s8(%arg0: vector<256xsi8>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vnot %arg0, %arg1 : vector<256xsi8>, vector<256xi1>
    "test.test"(%0) : (vector<256xsi8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vnot_v128_s16(%arg0: vector<128xsi16>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vnot %arg0, %arg1 : vector<128xsi16>, vector<256xi1>
    "test.test"(%0) : (vector<128xsi16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vnot_v128_f16(%arg0: vector<128xf16>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vnot %arg0, %arg1 : vector<128xf16>, vector<256xi1>
    "test.test"(%0) : (vector<128xf16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vnot_v64_s32(%arg0: vector<64xsi32>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vnot %arg0, %arg1 : vector<64xsi32>, vector<256xi1>
    "test.test"(%0) : (vector<64xsi32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_vnot_v64_f32(%arg0: vector<64xf32>, %arg1: vector<256xi1>) {
    %0 = ave.hir.vnot %arg0, %arg1 : vector<64xf32>, vector<256xi1>
    "test.test"(%0) : (vector<64xf32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v64_f32(%arg0: memref<64xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<64xf32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xf32>
    "test.test"(%res) : (vector<64xf32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v32_u64(%arg0: memref<32xui64, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<32xui64, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<32xi64>
    "test.test"(%res) : (vector<32xi64>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v32_s64(%arg0: memref<32xsi64, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<32xsi64, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<32xi64>
    "test.test"(%res) : (vector<32xi64>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v64_s32(%arg0: memref<64xsi32, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<64xsi32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xi32>
    "test.test"(%res) : (vector<64xi32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v64_u32(%arg0: memref<64xui32, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<64xui32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xi32>
    "test.test"(%res) : (vector<64xi32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v128_s16(%arg0: memref<128xsi16, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<128xsi16, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<128xi16>
    "test.test"(%res) : (vector<128xi16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v128_u16(%arg0: memref<128xui16, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<128xui16, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<128xi16>
    "test.test"(%res) : (vector<128xi16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v256_s8(%arg0: memref<256xsi8, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<256xsi8, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<256xi8>
    "test.test"(%res) : (vector<256xi8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v256_u8(%arg0: memref<256xui8, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<256xui8, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<256xi8>
    "test.test"(%res) : (vector<256xi8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v128_f16(%arg0: memref<128xf16, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<128xf16, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<128xf16>
    "test.test"(%res) : (vector<128xf16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_load_v128_bf16(%arg0: memref<128xbf16, strided<[1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %res = ave.hir.vload <NORM> %arg0[%c0] : memref<128xbf16, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<128xbf16>
    "test.test"(%res) : (vector<128xbf16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_store_v64_f32(%arg0: memref<64xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>, %arg1: vector<64xf32>, %arg2: vector<256xi1>) {
    %c0 = arith.constant 0 : index
    ave.hir.masked_store <NORM_B32> %arg0[%c0], %arg2, %arg1 : memref<64xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<256xi1>, vector<64xf32>
    return
  }
}

// -----
module {
  func.func @test_gather_v64_s32(%arg0: memref<64x1xsi32, strided<[32, 1], offset: ?>, #hivm.address_space<ub>>, %arg1: index, %arg2: vector<64xi32>, %arg3: vector<64xi1>) {
    %0 = ave.hir.vgather %arg0[%arg1, %arg1] [%arg2], %arg3 : memref<64x1xsi32, strided<[32, 1], offset: ?>, #hivm.address_space<ub>>, vector<64xi32>, vector<64xi1> into vector<64xsi32>
    "test.test"(%0) : (vector<64xsi32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_gather_v64_u32(%arg0: memref<64x1xui32, strided<[32, 1], offset: ?>, #hivm.address_space<ub>>, %arg1: index, %arg2: vector<64xi32>, %arg3: vector<64xi1>) {
    %0 = ave.hir.vgather %arg0[%arg1, %arg1] [%arg2], %arg3 : memref<64x1xui32, strided<[32, 1], offset: ?>, #hivm.address_space<ub>>, vector<64xi32>, vector<64xi1> into vector<64xui32>
    "test.test"(%0) : (vector<64xui32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_gather_v128_s16(%arg0: memref<128x1xsi16, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, %arg1: index, %arg2: vector<128xi16>, %arg3: vector<128xi1>) {
    %0 = ave.hir.vgather %arg0[%arg1, %arg1] [%arg2], %arg3 : memref<128x1xsi16, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, vector<128xi16>, vector<128xi1> into vector<128xi16>
    "test.test"(%0) : (vector<128xi16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_gather_v128_u16(%arg0: memref<128x1xui16, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, %arg1: index, %arg2: vector<128xi16>, %arg3: vector<128xi1>) {
    %0 = ave.hir.vgather %arg0[%arg1, %arg1] [%arg2], %arg3 : memref<128x1xui16, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, vector<128xi16>, vector<128xi1> into vector<128xi16>
    "test.test"(%0) : (vector<128xi16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_gather_v256_s8(%arg0: memref<256x1xsi8, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, %arg1: index, %arg2: vector<256xi16>, %arg3: vector<256xi1>) {
    %0 = ave.hir.vgather %arg0[%arg1, %arg1] [%arg2], %arg3 : memref<256x1xsi8, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, vector<256xi16>, vector<256xi1> into vector<256xi8>
    "test.test"(%0) : (vector<256xi8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_gather_v256_u8(%arg0: memref<256x1xui8, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, %arg1: index, %arg2: vector<256xi16>, %arg3: vector<256xi1>) {
    %0 = ave.hir.vgather %arg0[%arg1, %arg1] [%arg2], %arg3 : memref<256x1xui8, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, vector<256xi16>, vector<256xi1> into vector<256xi8>
    "test.test"(%0) : (vector<256xi8>) -> ()
    return
  }
}

// -----
module {
  func.func @test_gather_v64_f32(%arg0: memref<64x1xf32, strided<[32, 1], offset: ?>, #hivm.address_space<ub>>, %arg1: index, %arg2: vector<64xi32>, %arg3: vector<64xi1>) {
    %0 = ave.hir.vgather %arg0[%arg1, %arg1] [%arg2], %arg3 : memref<64x1xf32, strided<[32, 1], offset: ?>, #hivm.address_space<ub>>, vector<64xi32>, vector<64xi1> into vector<64xf32>
    "test.test"(%0) : (vector<64xf32>) -> ()
    return
  }
}

// -----
module {
  func.func @test_gather_v128_f16(%arg0: memref<128x1xf16, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, %arg1: index, %arg2: vector<128xi16>, %arg3: vector<128xi1>) {
    %0 = ave.hir.vgather %arg0[%arg1, %arg1] [%arg2], %arg3 : memref<128x1xf16, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, vector<128xi16>, vector<128xi1> into vector<128xf16>
    "test.test"(%0) : (vector<128xf16>) -> ()
    return
  }
}

// -----
module {
  func.func @test_gather_v128_bf16(%arg0: memref<128x1xbf16, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, %arg1: index, %arg2: vector<128xi16>, %arg3: vector<128xi1>) {
    %0 = ave.hir.vgather %arg0[%arg1, %arg1] [%arg2], %arg3 : memref<128x1xbf16, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, vector<128xi16>, vector<128xi1> into vector<128xbf16>
    "test.test"(%0) : (vector<128xbf16>) -> ()
    return
  }
}

// -----
#map = affine_map<(d0, d1)[s0] -> (d0 * 1024 + d1 + s0)>
#map1 = affine_map<(d0, d1)[s0] -> (d0 * 512 + d1 + s0)>
module {
  func.func @test_gather_v256_f8e5m2(%arg0: memref<256x1xf8E5M2, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, %arg1: index, %arg2: vector<256xi16>, %arg3: vector<256xi1>) {
    %0 = ave.hir.vgather %arg0[%arg1, %arg1] [%arg2], %arg3 : memref<256x1xf8E5M2, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>, vector<256xi16>, vector<256xi1> into vector<256xf8E5M2>
    "test.test"(%0) : (vector<256xf8E5M2>) -> ()
    return
  }
  func.func @test_vsstb_rank_three(%arg0: memref<4x1x16xf16, strided<[1024, 16, 1]>, #hivm.address_space<ub>>, %arg1: vector<128xi1>, %arg2: vector<128xf16>) {
    %c0 = arith.constant 0 : index
    %c1024 = arith.constant 1024 : index
    ave.hir.store_with_stride %arg0[%c0, %c0, %c0], %c1024, %arg1, %arg2 : memref<4x1x16xf16, strided<[1024, 16, 1]>, #hivm.address_space<ub>>, vector<128xi1>, vector<128xf16>
    return
  }
  func.func @test_vsstb_v128_f16(%arg0: memref<4x16xf16, #map, #hivm.address_space<ub>>, %arg1: vector<64xi1>, %arg2: vector<64xf16>) {
    %c1024 = arith.constant 1024 : index
    %c0 = arith.constant 0 : index
    ave.hir.store_with_stride %arg0[%c0, %c0], %c1024, %arg1, %arg2 : memref<4x16xf16, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf16>
    return
  }
  func.func @test_vsstb_v128_bf16(%arg0: memref<4x16xf16, #map, #hivm.address_space<ub>>, %arg1: vector<64xi1>, %arg2: vector<64xbf16>) {
    %c1024 = arith.constant 1024 : index
    %c0 = arith.constant 0 : index
    ave.hir.store_with_stride %arg0[%c0, %c0], %c1024, %arg1, %arg2 : memref<4x16xf16, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xbf16>
    return
  }
  func.func @test_vsstb_v64_f32(%arg0: memref<8x8xf32, #map1, #hivm.address_space<ub>>, %arg1: vector<64xi1>, %arg2: vector<64xf32>) {
    %c512 = arith.constant 512 : index
    %c0 = arith.constant 0 : index
    ave.hir.store_with_stride %arg0[%c0, %c0], %c512, %arg1, %arg2 : memref<8x8xf32, #map1, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    return
  }
}

// -----
module {
  func.func @test_vshls$i8$subvl(%arg0: vector<128xi8>) -> vector<128xi8> {
    %false = arith.constant false
    %c7_i8 = arith.constant 7 : i8
    %0 = ave.hir.pge <VL32> {functionType = #ave.func_dist_type<pb8>, mask_op_idx = 0 : i32} : vector<128xi1>
    %1 = ave.hir.vshls %arg0, %c7_i8, %0, %false : vector<128xi8>, i8, vector<128xi1>
    return %1 : vector<128xi8>
  }
}

// -----
module {
  func.func @test_vshrs$i8$subvl(%arg0: vector<128xi8>) -> vector<128xi8> {
    %false = arith.constant false
    %c7_i8 = arith.constant 7 : i8
    %0 = ave.hir.pge <VL32> {functionType = #ave.func_dist_type<pb8>, mask_op_idx = 0 : i32} : vector<128xi1>
    %1 = ave.hir.vshrs %arg0, %c7_i8, %0, %false : vector<128xi8>, i8, vector<128xi1>
    return %1 : vector<128xi8>
  }
}

// -----
module {
  func.func @test_vshls$i16$subvl(%arg0: vector<64xi16>) -> vector<64xi16> {
    %false = arith.constant false
    %c7_i16 = arith.constant 7 : i16
    %0 = ave.hir.pge <VL32> {functionType = #ave.func_dist_type<pb16>, mask_op_idx = 0 : i32} : vector<64xi1>
    %1 = ave.hir.vshls %arg0, %c7_i16, %0, %false : vector<64xi16>, i16, vector<64xi1>
    return %1 : vector<64xi16>
  }
}

// -----
module {
  func.func @test_vshrs$i16$subvl(%arg0: vector<64xi16>) -> vector<64xi16> {
    %false = arith.constant false
    %c7_i16 = arith.constant 7 : i16
    %0 = ave.hir.pge <VL32> {functionType = #ave.func_dist_type<pb16>, mask_op_idx = 0 : i32} : vector<64xi1>
    %1 = ave.hir.vshrs %arg0, %c7_i16, %0, %false : vector<64xi16>, i16, vector<64xi1>
    return %1 : vector<64xi16>
  }
}

// -----
module {
  func.func @test_vshls$i32$subvl(%arg0: vector<32xi32>) -> vector<32xi32> {
    %false = arith.constant false
    %c7_i32 = arith.constant 7 : i32
    %0 = ave.hir.pge <VL32> {functionType = #ave.func_dist_type<pb32>, mask_op_idx = 0 : i32} : vector<32xi1>
    %1 = ave.hir.vshls %arg0, %c7_i32, %0, %false : vector<32xi32>, i32, vector<32xi1>
    return %1 : vector<32xi32>
  }
}

// -----
module {
  func.func @test_vshrs$i32$subvl(%arg0: vector<32xi32>) -> vector<32xi32> {
    %false = arith.constant false
    %c7_i32 = arith.constant 7 : i32
    %0 = ave.hir.pge <VL32> {functionType = #ave.func_dist_type<pb32>, mask_op_idx = 0 : i32} : vector<32xi1>
    %1 = ave.hir.vshrs %arg0, %c7_i32, %0, %false : vector<32xi32>, i32, vector<32xi1>
    return %1 : vector<32xi32>
  }
}

// -----
module {
  func.func @test_vshls$i8$eqvl(%arg0: vector<256xi8>) -> vector<256xi8> {
    %false = arith.constant false
    %c7_i8 = arith.constant 7 : i8
    %0 = ave.hir.pge <VL32> {functionType = #ave.func_dist_type<pb8>, mask_op_idx = 0 : i32} : vector<256xi1>
    %1 = ave.hir.vshls %arg0, %c7_i8, %0, %false : vector<256xi8>, i8, vector<256xi1>
    return %1 : vector<256xi8>
  }
}

// -----
module {
  func.func @test_vshls$i32$eqvl(%arg0: vector<64xi32>) -> vector<64xi32> {
    %false = arith.constant false
    %c7_i32 = arith.constant 7 : i32
    %0 = ave.hir.pge <VL32> {functionType = #ave.func_dist_type<pb8>, mask_op_idx = 0 : i32} : vector<256xi1>
    %1 = ave.hir.vshls %arg0, %c7_i32, %0, %false : vector<64xi32>, i32, vector<256xi1>
    return %1 : vector<64xi32>
  }
}


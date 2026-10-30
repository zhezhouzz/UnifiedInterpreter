module {
  tt.func public @_attn_fwd(%arg0: !tt.ptr<f16>, %arg1: !tt.ptr<f16>, %arg2: !tt.ptr<f16>, %arg3: !tt.ptr<f32>, %arg4: !tt.ptr<f16>, %arg5: !tt.ptr<f32>, %arg6: f32) attributes {noinline = false} {
    %cst = arith.constant dense<0.000000e+00> : tensor<32x1xf32>
    %cst_0 = arith.constant dense<0xFF800000> : tensor<32xf32>
    %cst_1 = arith.constant dense<0.000000e+00> : tensor<32x128xf32>
    %c20_i32 = arith.constant 20 : i32
    %c128_i32 = arith.constant 128 : i32
    %c0_i32 = arith.constant 0 : i32
    %c1_i64 = arith.constant 1 : i64
    %c128_i64 = arith.constant 128 : i64
    %c32_i32 = arith.constant 32 : i32
    %c16384_i64 = arith.constant 16384 : i64
    %c4_i32 = arith.constant 4 : i32
    %0 = tt.get_program_id x : i32
    %1 = tt.make_range {end = 32 : i32, start = 0 : i32} : tensor<32xi32>
    %2 = tt.splat %arg6 : f32 -> tensor<32x128xf32>
    scf.for %arg7 = %0 to %c4_i32 step %c20_i32  : i32 {
      %3 = arith.divsi %arg7, %c4_i32 : i32
      %4 = arith.remsi %arg7, %c4_i32 : i32
      %5 = arith.extsi %3 : i32 to i64
      %6 = arith.muli %5, %c16384_i64 : i64
      %7 = tt.addptr %arg0, %6 : !tt.ptr<f16>, i64
      %8 = arith.muli %4, %c32_i32 : i32
      %9 = tt.make_tensor_ptr %7, [%c128_i64, %c128_i64], [%c128_i64, %c1_i64], [%8, %c0_i32] {order = array<i32: 1, 0>} : <tensor<32x128xf16>>
      %10 = tt.addptr %arg2, %6 : !tt.ptr<f16>, i64
      %11 = tt.make_tensor_ptr %10, [%c128_i64, %c128_i64], [%c128_i64, %c1_i64], [%c0_i32, %c0_i32] {order = array<i32: 1, 0>} : <tensor<128x128xf16>>
      %12 = tt.addptr %arg1, %6 : !tt.ptr<f16>, i64
      %13 = tt.make_tensor_ptr %12, [%c128_i64, %c128_i64], [%c128_i64, %c1_i64], [%c0_i32, %c0_i32] {order = array<i32: 1, 0>} : <tensor<128x128xf16>>
      %14 = tt.addptr %arg4, %6 : !tt.ptr<f16>, i64
      %15 = tt.make_tensor_ptr %14, [%c128_i64, %c128_i64], [%c128_i64, %c1_i64], [%8, %c0_i32] {order = array<i32: 1, 0>} : <tensor<32x128xf16>>
      %16 = tt.splat %8 : i32 -> tensor<32xi32>
      %17 = arith.addi %16, %1 : tensor<32xi32>
      %18 = tt.load %9 : !tt.ptr<tensor<32x128xf16>>
      %19 = tt.load %13 : !tt.ptr<tensor<128x128xf16>>
      %20 = tt.trans %19 {order = array<i32: 1, 0>} : tensor<128x128xf16> -> tensor<128x128xf16>
      %21 = tt.dot %18, %20, %cst_1 : tensor<32x128xf16> * tensor<128x128xf16> -> tensor<32x128xf32>
      %22 = arith.mulf %21, %2 : tensor<32x128xf32>
      %23 = "tt.reduce"(%22) <{axis = 1 : i32}> ({
      ^bb0(%arg8: f32, %arg9: f32):
        %48 = arith.maxnumf %arg8, %arg9 : f32
        tt.reduce.return %48 : f32
      }) : (tensor<32x128xf32>) -> tensor<32xf32>
      %24 = tt.expand_dims %23 {axis = 1 : i32} : tensor<32xf32> -> tensor<32x1xf32>
      %25 = tt.broadcast %24 : tensor<32x1xf32> -> tensor<32x128xf32>
      %26 = arith.subf %22, %25 : tensor<32x128xf32>
      %27 = math.exp %26 : tensor<32x128xf32>
      %28 = arith.truncf %27 : tensor<32x128xf32> to tensor<32x128xf16>
      %29 = tt.load %11 : !tt.ptr<tensor<128x128xf16>>
      %30 = "tt.reduce"(%27) <{axis = 1 : i32}> ({
      ^bb0(%arg8: f32, %arg9: f32):
        %48 = arith.addf %arg8, %arg9 : f32
        tt.reduce.return %48 : f32
      }) : (tensor<32x128xf32>) -> tensor<32xf32>
      %31 = arith.subf %cst_0, %23 : tensor<32xf32>
      %32 = math.exp %31 : tensor<32xf32>
      %33 = arith.addf %32, %30 : tensor<32xf32>
      %34 = tt.expand_dims %32 {axis = 1 : i32} : tensor<32xf32> -> tensor<32x1xf32>
      %35 = arith.mulf %34, %cst : tensor<32x1xf32>
      %36 = tt.broadcast %35 : tensor<32x1xf32> -> tensor<32x128xf32>
      %37 = tt.dot %28, %29, %36 : tensor<32x128xf16> * tensor<128x128xf16> -> tensor<32x128xf32>
      %38 = math.log %33 : tensor<32xf32>
      %39 = arith.addf %23, %38 : tensor<32xf32>
      %40 = tt.expand_dims %33 {axis = 1 : i32} : tensor<32xf32> -> tensor<32x1xf32>
      %41 = tt.broadcast %40 : tensor<32x1xf32> -> tensor<32x128xf32>
      %42 = arith.divf %37, %41 : tensor<32x128xf32>
      %43 = arith.muli %3, %c128_i32 : i32
      %44 = tt.addptr %arg3, %43 : !tt.ptr<f32>, i32
      %45 = tt.splat %44 : !tt.ptr<f32> -> tensor<32x!tt.ptr<f32>>
      %46 = tt.addptr %45, %17 : tensor<32x!tt.ptr<f32>>, tensor<32xi32>
      tt.store %46, %39 : tensor<32x!tt.ptr<f32>>
      %47 = arith.truncf %42 : tensor<32x128xf32> to tensor<32x128xf16>
      tt.store %15, %47 : !tt.ptr<tensor<32x128xf16>>
    }
    tt.return
  }
}


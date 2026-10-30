module {
  tt.func public @add_kernel(%arg0: !tt.ptr<f32>, %arg1: !tt.ptr<f32>, %arg2: !tt.ptr<f32>, %arg3: i32) attributes {noinline = false} {
    %cst = arith.constant dense<0.000000e+00> : tensor<256xf32>
    %c256_i32 = arith.constant 256 : i32
    %0 = tt.get_program_id x : i32
    %1 = arith.muli %0, %c256_i32 : i32
    %2 = tt.make_range {end = 256 : i32, start = 0 : i32} : tensor<256xi32>
    %3 = tt.splat %1 : i32 -> tensor<256xi32>
    %4 = arith.addi %3, %2 : tensor<256xi32>
    %5 = tt.splat %arg3 : i32 -> tensor<256xi32>
    %6 = arith.cmpi slt, %4, %5 : tensor<256xi32>
    %7 = tt.splat %arg0 : !tt.ptr<f32> -> tensor<256x!tt.ptr<f32>>
    %8 = tt.addptr %7, %4 : tensor<256x!tt.ptr<f32>>, tensor<256xi32>
    %9 = tt.load %8, %6, %cst : tensor<256x!tt.ptr<f32>>
    %10 = tt.splat %arg1 : !tt.ptr<f32> -> tensor<256x!tt.ptr<f32>>
    %11 = tt.addptr %10, %4 : tensor<256x!tt.ptr<f32>>, tensor<256xi32>
    %12 = tt.load %11, %6, %cst : tensor<256x!tt.ptr<f32>>
    %13 = tt.splat %arg2 : !tt.ptr<f32> -> tensor<256x!tt.ptr<f32>>
    %14 = tt.addptr %13, %4 : tensor<256x!tt.ptr<f32>>, tensor<256xi32>
    %15 = arith.addf %9, %12 : tensor<256xf32>
    tt.store %14, %15, %6 : tensor<256x!tt.ptr<f32>>
    tt.return
  }
}


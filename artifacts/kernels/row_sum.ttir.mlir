module {
  tt.func public @row_sum(%arg0: !tt.ptr<f32>, %arg1: !tt.ptr<f32>) attributes {noinline = false} {
    %cst = arith.constant dense<8> : tensor<1x4xi32>
    %cst_0 = arith.constant dense<4> : tensor<1x4xi32>
    %c2_i32 = arith.constant 2 : i32
    %c1_i32 = arith.constant 1 : i32
    %c0_i32 = arith.constant 0 : i32
    %0 = tt.make_range {end = 4 : i32, start = 0 : i32} : tensor<4xi32>
    %1 = tt.expand_dims %0 {axis = 0 : i32} : tensor<4xi32> -> tensor<1x4xi32>
    %2 = tt.splat %arg0 : !tt.ptr<f32> -> tensor<1x4x!tt.ptr<f32>>
    %3 = tt.addptr %2, %1 : tensor<1x4x!tt.ptr<f32>>, tensor<1x4xi32>
    %4 = tt.load %3 : tensor<1x4x!tt.ptr<f32>>
    %5 = "tt.reduce"(%4) <{axis = 1 : i32}> ({
    ^bb0(%arg2: f32, %arg3: f32):
      %23 = arith.addf %arg2, %arg3 : f32
      tt.reduce.return %23 : f32
    }) : (tensor<1x4xf32>) -> tensor<1xf32>
    %6 = tt.addptr %arg1, %c0_i32 : !tt.ptr<f32>, i32
    %7 = tt.addptr %6, %c0_i32 : !tt.ptr<f32>, i32
    %8 = tt.splat %7 : !tt.ptr<f32> -> tensor<1x!tt.ptr<f32>>
    tt.store %8, %5 : tensor<1x!tt.ptr<f32>>
    %9 = arith.addi %1, %cst_0 : tensor<1x4xi32>
    %10 = tt.addptr %2, %9 : tensor<1x4x!tt.ptr<f32>>, tensor<1x4xi32>
    %11 = tt.load %10 : tensor<1x4x!tt.ptr<f32>>
    %12 = "tt.reduce"(%11) <{axis = 1 : i32}> ({
    ^bb0(%arg2: f32, %arg3: f32):
      %23 = arith.addf %arg2, %arg3 : f32
      tt.reduce.return %23 : f32
    }) : (tensor<1x4xf32>) -> tensor<1xf32>
    %13 = tt.addptr %arg1, %c1_i32 : !tt.ptr<f32>, i32
    %14 = tt.addptr %13, %c0_i32 : !tt.ptr<f32>, i32
    %15 = tt.splat %14 : !tt.ptr<f32> -> tensor<1x!tt.ptr<f32>>
    tt.store %15, %12 : tensor<1x!tt.ptr<f32>>
    %16 = arith.addi %1, %cst : tensor<1x4xi32>
    %17 = tt.addptr %2, %16 : tensor<1x4x!tt.ptr<f32>>, tensor<1x4xi32>
    %18 = tt.load %17 : tensor<1x4x!tt.ptr<f32>>
    %19 = "tt.reduce"(%18) <{axis = 1 : i32}> ({
    ^bb0(%arg2: f32, %arg3: f32):
      %23 = arith.addf %arg2, %arg3 : f32
      tt.reduce.return %23 : f32
    }) : (tensor<1x4xf32>) -> tensor<1xf32>
    %20 = tt.addptr %arg1, %c2_i32 : !tt.ptr<f32>, i32
    %21 = tt.addptr %20, %c0_i32 : !tt.ptr<f32>, i32
    %22 = tt.splat %21 : !tt.ptr<f32> -> tensor<1x!tt.ptr<f32>>
    tt.store %22, %19 : tensor<1x!tt.ptr<f32>>
    tt.return
  }
}


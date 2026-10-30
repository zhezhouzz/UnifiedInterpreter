module {
  tt.func public @vector_add(%arg0: !tt.ptr<f32>, %arg1: !tt.ptr<f32>, %arg2: !tt.ptr<f32>) attributes {noinline = false} {
    %cst = arith.constant dense<4> : tensor<4xi32>
    %0 = tt.make_range {end = 4 : i32, start = 0 : i32} : tensor<4xi32>
    %1 = tt.splat %arg0 : !tt.ptr<f32> -> tensor<4x!tt.ptr<f32>>
    %2 = tt.addptr %1, %0 : tensor<4x!tt.ptr<f32>>, tensor<4xi32>
    %3 = tt.load %2 : tensor<4x!tt.ptr<f32>>
    %4 = tt.splat %arg1 : !tt.ptr<f32> -> tensor<4x!tt.ptr<f32>>
    %5 = tt.addptr %4, %0 : tensor<4x!tt.ptr<f32>>, tensor<4xi32>
    %6 = tt.load %5 : tensor<4x!tt.ptr<f32>>
    %7 = tt.splat %arg2 : !tt.ptr<f32> -> tensor<4x!tt.ptr<f32>>
    %8 = tt.addptr %7, %0 : tensor<4x!tt.ptr<f32>>, tensor<4xi32>
    %9 = arith.addf %3, %6 : tensor<4xf32>
    tt.store %8, %9 : tensor<4x!tt.ptr<f32>>
    %10 = arith.addi %0, %cst : tensor<4xi32>
    %11 = tt.addptr %1, %10 : tensor<4x!tt.ptr<f32>>, tensor<4xi32>
    %12 = tt.load %11 : tensor<4x!tt.ptr<f32>>
    %13 = tt.addptr %4, %10 : tensor<4x!tt.ptr<f32>>, tensor<4xi32>
    %14 = tt.load %13 : tensor<4x!tt.ptr<f32>>
    %15 = tt.addptr %7, %10 : tensor<4x!tt.ptr<f32>>, tensor<4xi32>
    %16 = arith.addf %12, %14 : tensor<4xf32>
    tt.store %15, %16 : tensor<4x!tt.ptr<f32>>
    tt.return
  }
}


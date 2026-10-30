module {
  func.func @_attn_fwd(%arg0: memref<?xi8>, %arg1: memref<?xi8>, %arg2: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg5: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg6: memref<?xf16> {tt.tensor_kind = 1 : i32}, %arg7: memref<?xf32>, %arg8: f32, %arg9: i32, %arg10: i32, %arg11: i32, %arg12: i32, %arg13: i32, %arg14: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, global_kernel = "local", mix_mode = "mix", parallel_mode = "simd"} {
    %c128 = arith.constant 128 : index
    %c4_i32 = arith.constant 4 : i32
    %c16384_i64 = arith.constant 16384 : i64
    %c32_i32 = arith.constant 32 : i32
    %c128_i32 = arith.constant 128 : i32
    %c20_i32 = arith.constant 20 : i32
    %cst = arith.constant 0xFF800000 : f32
    %cst_0 = arith.constant 0.000000e+00 : f32
    %0 = tensor.empty() : tensor<32x1xf32>
    %1 = linalg.fill ins(%cst_0 : f32) outs(%0 : tensor<32x1xf32>) -> tensor<32x1xf32>
    %2 = tensor.empty() : tensor<32xf32>
    %3 = linalg.fill ins(%cst : f32) outs(%2 : tensor<32xf32>) -> tensor<32xf32>
    %4 = tensor.empty() : tensor<32x128xf32>
    %5 = linalg.fill ins(%cst_0 : f32) outs(%4 : tensor<32x128xf32>) -> tensor<32x128xf32>
    %6 = linalg.fill ins(%arg8 : f32) outs(%4 : tensor<32x128xf32>) -> tensor<32x128xf32>
    scf.for %arg15 = %arg12 to %c4_i32 step %c20_i32  : i32 {
      %7 = arith.divsi %arg15, %c4_i32 : i32
      %8 = arith.remsi %arg15, %c4_i32 : i32
      %9 = arith.extsi %7 : i32 to i64
      %10 = arith.muli %9, %c16384_i64 : i64
      %11 = arith.index_cast %10 : i64 to index
      %12 = arith.muli %8, %c32_i32 : i32
      %13 = arith.index_cast %12 : i32 to index
      %14 = arith.muli %13, %c128 : index
      %15 = arith.addi %14, %11 : index
      %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [%15], sizes: [32, 128], strides: [128, 1] : memref<?xf16> to memref<32x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_1 = memref.reinterpret_cast %arg4 to offset: [%11], sizes: [128, 128], strides: [128, 1] : memref<?xf16> to memref<128x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_2 = memref.reinterpret_cast %arg3 to offset: [%11], sizes: [128, 128], strides: [128, 1] : memref<?xf16> to memref<128x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_3 = memref.reinterpret_cast %arg6 to offset: [%15], sizes: [32, 128], strides: [128, 1] : memref<?xf16> to memref<32x128xf16, strided<[128, 1], offset: ?>>
      %alloc = memref.alloc() : memref<32x128xf16>
      memref.copy %reinterpret_cast, %alloc : memref<32x128xf16, strided<[128, 1], offset: ?>> to memref<32x128xf16>
      %16 = bufferization.to_tensor %alloc restrict writable : memref<32x128xf16>
      %alloc_4 = memref.alloc() : memref<128x128xf16>
      memref.copy %reinterpret_cast_2, %alloc_4 : memref<128x128xf16, strided<[128, 1], offset: ?>> to memref<128x128xf16>
      %17 = bufferization.to_tensor %alloc_4 restrict writable : memref<128x128xf16>
      %18 = tensor.empty() : tensor<128x128xf16>
      %transposed = linalg.transpose ins(%17 : tensor<128x128xf16>) outs(%18 : tensor<128x128xf16>) permutation = [1, 0] 
      %19 = linalg.matmul {input_precison = "ieee"} ins(%16, %transposed : tensor<32x128xf16>, tensor<128x128xf16>) outs(%5 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %20 = tensor.empty() : tensor<32x128xf32>
      %21 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%19, %6 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%20 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %reduced = linalg.reduce ins(%21 : tensor<32x128xf32>) outs(%3 : tensor<32xf32>) dimensions = [1] 
        (%in: f32, %init: f32) {
          %50 = arith.maxnumf %in, %init : f32
          linalg.yield %50 : f32
        }
      %broadcasted = linalg.broadcast ins(%reduced : tensor<32xf32>) outs(%4 : tensor<32x128xf32>) dimensions = [1] 
      %22 = tensor.empty() : tensor<32x128xf32>
      %23 = linalg.elemwise_binary {fun = #linalg.binary_fn<sub>} ins(%21, %broadcasted : tensor<32x128xf32>, tensor<32x128xf32>) outs(%22 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %24 = tensor.empty() : tensor<32x128xf32>
      %25 = linalg.elemwise_unary {fun = #linalg.unary_fn<exp>} ins(%23 : tensor<32x128xf32>) outs(%24 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %26 = tensor.empty() : tensor<32x128xf16>
      %27 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, round_mode = #hfusion.round_mode<rint>} ins(%25 : tensor<32x128xf32>) outs(%26 : tensor<32x128xf16>) -> tensor<32x128xf16>
      %alloc_5 = memref.alloc() : memref<128x128xf16>
      memref.copy %reinterpret_cast_1, %alloc_5 : memref<128x128xf16, strided<[128, 1], offset: ?>> to memref<128x128xf16>
      %28 = bufferization.to_tensor %alloc_5 restrict writable : memref<128x128xf16>
      %29 = linalg.fill ins(%cst_0 : f32) outs(%2 : tensor<32xf32>) -> tensor<32xf32>
      %reduced_6 = linalg.reduce ins(%25 : tensor<32x128xf32>) outs(%29 : tensor<32xf32>) dimensions = [1] 
        (%in: f32, %init: f32) {
          %50 = arith.addf %in, %init : f32
          linalg.yield %50 : f32
        }
      %30 = tensor.empty() : tensor<32xf32>
      %31 = linalg.elemwise_binary {fun = #linalg.binary_fn<sub>} ins(%3, %reduced : tensor<32xf32>, tensor<32xf32>) outs(%30 : tensor<32xf32>) -> tensor<32xf32>
      %32 = tensor.empty() : tensor<32xf32>
      %33 = linalg.elemwise_unary {fun = #linalg.unary_fn<exp>} ins(%31 : tensor<32xf32>) outs(%32 : tensor<32xf32>) -> tensor<32xf32>
      %34 = tensor.empty() : tensor<32xf32>
      %35 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%33, %reduced_6 : tensor<32xf32>, tensor<32xf32>) outs(%34 : tensor<32xf32>) -> tensor<32xf32>
      %expanded = tensor.expand_shape %33 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %36 = tensor.empty() : tensor<32x1xf32>
      %37 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%expanded, %1 : tensor<32x1xf32>, tensor<32x1xf32>) outs(%36 : tensor<32x1xf32>) -> tensor<32x1xf32>
      %collapsed = tensor.collapse_shape %37 [[0, 1]] : tensor<32x1xf32> into tensor<32xf32>
      %broadcasted_7 = linalg.broadcast ins(%collapsed : tensor<32xf32>) outs(%4 : tensor<32x128xf32>) dimensions = [1] 
      %38 = linalg.matmul {input_precison = "ieee"} ins(%27, %28 : tensor<32x128xf16>, tensor<128x128xf16>) outs(%broadcasted_7 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %39 = tensor.empty() : tensor<32xf32>
      %40 = linalg.elemwise_unary {fun = #linalg.unary_fn<log>} ins(%35 : tensor<32xf32>) outs(%39 : tensor<32xf32>) -> tensor<32xf32>
      %41 = tensor.empty() : tensor<32xf32>
      %42 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%reduced, %40 : tensor<32xf32>, tensor<32xf32>) outs(%41 : tensor<32xf32>) -> tensor<32xf32>
      %broadcasted_8 = linalg.broadcast ins(%35 : tensor<32xf32>) outs(%4 : tensor<32x128xf32>) dimensions = [1] 
      %43 = tensor.empty() : tensor<32x128xf32>
      %44 = linalg.elemwise_binary {fun = #linalg.binary_fn<div>} ins(%38, %broadcasted_8 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%43 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %45 = arith.muli %7, %c128_i32 : i32
      %46 = arith.index_cast %45 : i32 to index
      %47 = arith.addi %46, %13 : index
      %reinterpret_cast_9 = memref.reinterpret_cast %arg5 to offset: [%47], sizes: [32], strides: [1] : memref<?xf32> to memref<32xf32, strided<[1], offset: ?>>
      bufferization.materialize_in_destination %42 in writable %reinterpret_cast_9 : (tensor<32xf32>, memref<32xf32, strided<[1], offset: ?>>) -> ()
      %48 = tensor.empty() : tensor<32x128xf16>
      %49 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, round_mode = #hfusion.round_mode<rint>} ins(%44 : tensor<32x128xf32>) outs(%48 : tensor<32x128xf16>) -> tensor<32x128xf16>
      bufferization.materialize_in_destination %49 in writable %reinterpret_cast_3 : (tensor<32x128xf16>, memref<32x128xf16, strided<[128, 1], offset: ?>>) -> ()
    }
    return
  }
}


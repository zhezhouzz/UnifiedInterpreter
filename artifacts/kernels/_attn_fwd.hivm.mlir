module {
  func.func @_attn_fwd(%arg0: memref<?xi8>, %arg1: memref<?xi8>, %arg2: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg5: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg6: memref<?xf16> {tt.tensor_kind = 1 : i32}, %arg7: memref<?xf32>, %arg8: f32, %arg9: i32, %arg10: i32, %arg11: i32, %arg12: i32, %arg13: i32, %arg14: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, global_kernel = "local", mix_mode = "mix", parallel_mode = "simd"} {
    %false = arith.constant false
    %c0 = arith.constant 0 : index
    %true = arith.constant true
    %c128 = arith.constant 128 : index
    %c4_i32 = arith.constant 4 : i32
    %c16384_i64 = arith.constant 16384 : i64
    %c32_i32 = arith.constant 32 : i32
    %c128_i32 = arith.constant 128 : i32
    %c20_i32 = arith.constant 20 : i32
    %cst = arith.constant 0xFF800000 : f32
    %cst_0 = arith.constant 0.000000e+00 : f32
    %0 = tensor.empty() : tensor<32x1xf32>
    %1 = hivm.hir.vbrc ins(%cst_0 : f32) outs(%0 : tensor<32x1xf32>) -> tensor<32x1xf32>
    %2 = tensor.empty() : tensor<32xf32>
    %3 = hivm.hir.vbrc ins(%cst : f32) outs(%2 : tensor<32xf32>) -> tensor<32xf32>
    %4 = tensor.empty() : tensor<32x128xf32>
    %5 = hivm.hir.vbrc ins(%arg8 : f32) outs(%4 : tensor<32x128xf32>) -> tensor<32x128xf32>
    scf.for %arg15 = %arg12 to %c4_i32 step %c20_i32  : i32 {
      %6 = arith.divsi %arg15, %c4_i32 : i32
      %7 = arith.remsi %arg15, %c4_i32 : i32
      %8 = arith.extsi %6 : i32 to i64
      %9 = arith.muli %8, %c16384_i64 : i64
      %10 = arith.index_cast %9 : i64 to index
      %11 = arith.muli %7, %c32_i32 : i32
      %12 = arith.index_cast %11 : i32 to index
      %13 = arith.muli %12, %c128 : index
      %14 = arith.addi %13, %10 : index
      %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [%14], sizes: [32, 128], strides: [128, 1] : memref<?xf16> to memref<32x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_1 = memref.reinterpret_cast %arg4 to offset: [%10], sizes: [128, 128], strides: [128, 1] : memref<?xf16> to memref<128x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_2 = memref.reinterpret_cast %arg3 to offset: [%10], sizes: [128, 128], strides: [128, 1] : memref<?xf16> to memref<128x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_3 = memref.reinterpret_cast %arg6 to offset: [%14], sizes: [32, 128], strides: [128, 1] : memref<?xf16> to memref<32x128xf16, strided<[128, 1], offset: ?>>
      %alloc = memref.alloc() : memref<32x128xf16>
      memref.copy %reinterpret_cast, %alloc : memref<32x128xf16, strided<[128, 1], offset: ?>> to memref<32x128xf16>
      %15 = bufferization.to_tensor %alloc restrict writable : memref<32x128xf16>
      %alloc_4 = memref.alloc() : memref<128x128xf16>
      memref.copy %reinterpret_cast_2, %alloc_4 : memref<128x128xf16, strided<[128, 1], offset: ?>> to memref<128x128xf16>
      %16 = bufferization.to_tensor %alloc_4 restrict writable : memref<128x128xf16>
      %17 = tensor.empty() : tensor<32x128xf32>
      %18 = hivm.hir.mmadL1 {b_transpose} ins(%15, %16, %true, %c0, %c0, %c0 : tensor<32x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%17 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %19 = tensor.empty() : tensor<32x128xf32>
      %20 = hivm.hir.vmul ins(%18, %5 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%19 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %expanded = tensor.expand_shape %3 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %21 = hivm.hir.vreduce <max> ins(%20 : tensor<32x128xf32>) outs(%expanded : tensor<32x1xf32>) reduce_dims = [1] -> tensor<32x1xf32>
      %collapsed = tensor.collapse_shape %21 [[0, 1]] : tensor<32x1xf32> into tensor<32xf32>
      %22 = hivm.hir.vbrc ins(%21 : tensor<32x1xf32>) outs(%4 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %23 = tensor.empty() : tensor<32x128xf32>
      %24 = hivm.hir.vsub ins(%20, %22 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%23 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %25 = tensor.empty() : tensor<32x128xf32>
      %26 = hivm.hir.vexp ins(%24 : tensor<32x128xf32>) outs(%25 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %27 = tensor.empty() : tensor<32x128xf16>
      %28 = hivm.hir.vcast ins(%26 : tensor<32x128xf32>) outs(%27 : tensor<32x128xf16>) -> tensor<32x128xf16>
      %alloc_5 = memref.alloc() : memref<128x128xf16>
      memref.copy %reinterpret_cast_1, %alloc_5 : memref<128x128xf16, strided<[128, 1], offset: ?>> to memref<128x128xf16>
      %29 = bufferization.to_tensor %alloc_5 restrict writable : memref<128x128xf16>
      %30 = hivm.hir.vbrc ins(%cst_0 : f32) outs(%2 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_6 = tensor.expand_shape %30 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %31 = hivm.hir.vreduce <sum> ins(%26 : tensor<32x128xf32>) outs(%expanded_6 : tensor<32x1xf32>) reduce_dims = [1] -> tensor<32x1xf32>
      %collapsed_7 = tensor.collapse_shape %31 [[0, 1]] : tensor<32x1xf32> into tensor<32xf32>
      %32 = tensor.empty() : tensor<32xf32>
      %33 = hivm.hir.vsub ins(%3, %collapsed : tensor<32xf32>, tensor<32xf32>) outs(%32 : tensor<32xf32>) -> tensor<32xf32>
      %34 = tensor.empty() : tensor<32xf32>
      %35 = hivm.hir.vexp ins(%33 : tensor<32xf32>) outs(%34 : tensor<32xf32>) -> tensor<32xf32>
      %36 = tensor.empty() : tensor<32xf32>
      %37 = hivm.hir.vadd ins(%35, %collapsed_7 : tensor<32xf32>, tensor<32xf32>) outs(%36 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_8 = tensor.expand_shape %35 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %38 = tensor.empty() : tensor<32x1xf32>
      %39 = hivm.hir.vmul ins(%expanded_8, %1 : tensor<32x1xf32>, tensor<32x1xf32>) outs(%38 : tensor<32x1xf32>) -> tensor<32x1xf32>
      %40 = hivm.hir.vbrc ins(%39 : tensor<32x1xf32>) outs(%4 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %41 = hivm.hir.mmadL1 ins(%28, %29, %false, %c0, %c0, %c0 : tensor<32x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%40 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %42 = tensor.empty() : tensor<32xf32>
      %43 = hivm.hir.vln ins(%37 : tensor<32xf32>) outs(%42 : tensor<32xf32>) -> tensor<32xf32>
      %44 = tensor.empty() : tensor<32xf32>
      %45 = hivm.hir.vadd ins(%collapsed, %43 : tensor<32xf32>, tensor<32xf32>) outs(%44 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_9 = tensor.expand_shape %37 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %46 = hivm.hir.vbrc ins(%expanded_9 : tensor<32x1xf32>) outs(%4 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %47 = tensor.empty() : tensor<32x128xf32>
      %48 = hivm.hir.vdiv ins(%41, %46 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%47 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %49 = arith.muli %6, %c128_i32 : i32
      %50 = arith.index_cast %49 : i32 to index
      %51 = arith.addi %50, %12 : index
      %reinterpret_cast_10 = memref.reinterpret_cast %arg5 to offset: [%51], sizes: [32], strides: [1] : memref<?xf32> to memref<32xf32, strided<[1], offset: ?>>
      bufferization.materialize_in_destination %45 in writable %reinterpret_cast_10 : (tensor<32xf32>, memref<32xf32, strided<[1], offset: ?>>) -> ()
      %52 = tensor.empty() : tensor<32x128xf16>
      %53 = hivm.hir.vcast ins(%48 : tensor<32x128xf32>) outs(%52 : tensor<32x128xf16>) -> tensor<32x128xf16>
      bufferization.materialize_in_destination %53 in writable %reinterpret_cast_3 : (tensor<32x128xf16>, memref<32x128xf16, strided<[128, 1], offset: ?>>) -> ()
    }
    return
  }
}


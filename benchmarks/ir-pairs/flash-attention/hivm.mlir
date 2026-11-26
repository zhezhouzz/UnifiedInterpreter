module {
  func.func @_attn_fwd(%arg0: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}, %arg1: memref<?xi8> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg2: memref<?xi8> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg3: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg5: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg6: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg7: memref<?xf16> {tt.tensor_kind = 1 : i32}, %arg8: memref<?xf32>, %arg9: f32, %arg10: i32, %arg11: i32, %arg12: i32, %arg13: i32, %arg14: i32, %arg15: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, mix_mode = "mix", parallel_mode = "simd"} {
    %cst = arith.constant -1.000000e+00 : f32
    %c128 = arith.constant 128 : index
    %c4_i32 = arith.constant 4 : i32
    %c16384_i64 = arith.constant 16384 : i64
    %c32_i32 = arith.constant 32 : i32
    %c128_i32 = arith.constant 128 : i32
    %c20_i32 = arith.constant 20 : i32
    %cst_0 = arith.constant 0xFF800000 : f32
    %cst_1 = arith.constant 0.000000e+00 : f32
    %0 = tensor.empty() : tensor<32x1xf32>
    %1 = tensor.empty() : tensor<32xf32>
    %2 = hivm.hir.vbrc ins(%cst_0 : f32) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
    %3 = tensor.empty() : tensor<32x128xf32>
    %4 = hivm.hir.vbrc ins(%cst_1 : f32) outs(%3 : tensor<32x128xf32>) -> tensor<32x128xf32>
    scf.for %arg16 = %arg13 to %c4_i32 step %c20_i32  : i32 {
      %5 = arith.divsi %arg16, %c4_i32 : i32
      %6 = arith.remsi %arg16, %c4_i32 : i32
      %7 = arith.extsi %5 : i32 to i64
      %8 = arith.muli %7, %c16384_i64 : i64
      %9 = arith.index_cast %8 : i64 to index
      %10 = arith.muli %6, %c32_i32 : i32
      %11 = arith.index_cast %10 : i32 to index
      %12 = arith.muli %11, %c128 : index
      %13 = arith.addi %12, %9 : index
      %reinterpret_cast = memref.reinterpret_cast %arg3 to offset: [%13], sizes: [32, 128], strides: [128, 1] : memref<?xf16> to memref<32x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_2 = memref.reinterpret_cast %arg5 to offset: [%9], sizes: [128, 128], strides: [128, 1] : memref<?xf16> to memref<128x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_3 = memref.reinterpret_cast %arg4 to offset: [%9], sizes: [128, 128], strides: [128, 1] : memref<?xf16> to memref<128x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_4 = memref.reinterpret_cast %arg7 to offset: [%13], sizes: [32, 128], strides: [128, 1] : memref<?xf16> to memref<32x128xf16, strided<[128, 1], offset: ?>>
      %alloc = memref.alloc() : memref<32x128xf16>
      memref.copy %reinterpret_cast, %alloc : memref<32x128xf16, strided<[128, 1], offset: ?>> to memref<32x128xf16>
      %14 = bufferization.to_tensor %alloc restrict writable : memref<32x128xf16>
      %alloc_5 = memref.alloc() : memref<128x128xf16>
      memref.copy %reinterpret_cast_3, %alloc_5 : memref<128x128xf16, strided<[128, 1], offset: ?>> to memref<128x128xf16>
      %15 = bufferization.to_tensor %alloc_5 restrict writable : memref<128x128xf16>
      %16 = tensor.empty() : tensor<128x128xf16>
      %17 = hivm.hir.vtranspose ins(%15 : tensor<128x128xf16>) outs(%16 : tensor<128x128xf16>) permutation = [1, 0] -> tensor<128x128xf16>
      %18 = hivm.hir.matmul ins(%14, %17 : tensor<32x128xf16>, tensor<128x128xf16>) outs(%4 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %19 = hivm.hir.vmul ins(%18, %arg9 : tensor<32x128xf32>, f32) outs(%3 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %expanded = tensor.expand_shape %2 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %20 = hivm.hir.vreduce <max> ins(%19 : tensor<32x128xf32>) outs(%expanded : tensor<32x1xf32>) reduce_dims = [1] -> tensor<32x1xf32>
      %collapsed = tensor.collapse_shape %20 [[0, 1]] : tensor<32x1xf32> into tensor<32xf32>
      %21 = hivm.hir.vbrc ins(%20 : tensor<32x1xf32>) outs(%3 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %22 = hivm.hir.vsub ins(%19, %21 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%3 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %23 = hivm.hir.vexp ins(%22 : tensor<32x128xf32>) outs(%3 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %24 = tensor.empty() : tensor<32x128xf16>
      %25 = hivm.hir.vcast ins(%23 : tensor<32x128xf32>) outs(%24 : tensor<32x128xf16>) -> tensor<32x128xf16>
      %alloc_6 = memref.alloc() : memref<128x128xf16>
      memref.copy %reinterpret_cast_2, %alloc_6 : memref<128x128xf16, strided<[128, 1], offset: ?>> to memref<128x128xf16>
      %26 = bufferization.to_tensor %alloc_6 restrict writable : memref<128x128xf16>
      %27 = hivm.hir.vbrc ins(%cst_1 : f32) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_7 = tensor.expand_shape %27 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %28 = hivm.hir.vreduce <sum> ins(%23 : tensor<32x128xf32>) outs(%expanded_7 : tensor<32x1xf32>) reduce_dims = [1] -> tensor<32x1xf32>
      %collapsed_8 = tensor.collapse_shape %28 [[0, 1]] : tensor<32x1xf32> into tensor<32xf32>
      %29 = hivm.hir.vmul ins(%collapsed, %cst : tensor<32xf32>, f32) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %30 = hivm.hir.vadd ins(%29, %cst_0 : tensor<32xf32>, f32) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %31 = hivm.hir.vexp ins(%30 : tensor<32xf32>) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %32 = hivm.hir.vadd ins(%31, %collapsed_8 : tensor<32xf32>, tensor<32xf32>) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_9 = tensor.expand_shape %31 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %33 = hivm.hir.vmul ins(%expanded_9, %cst_1 : tensor<32x1xf32>, f32) outs(%0 : tensor<32x1xf32>) -> tensor<32x1xf32>
      %34 = hivm.hir.vbrc ins(%33 : tensor<32x1xf32>) outs(%3 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %35 = hivm.hir.matmul ins(%25, %26 : tensor<32x128xf16>, tensor<128x128xf16>) outs(%34 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %36 = hivm.hir.vln ins(%32 : tensor<32xf32>) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %37 = hivm.hir.vadd ins(%collapsed, %36 : tensor<32xf32>, tensor<32xf32>) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_10 = tensor.expand_shape %32 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %38 = hivm.hir.vbrc ins(%expanded_10 : tensor<32x1xf32>) outs(%3 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %39 = hivm.hir.vdiv ins(%35, %38 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%3 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %40 = arith.muli %5, %c128_i32 : i32
      %41 = arith.index_cast %40 : i32 to index
      %42 = arith.addi %41, %11 : index
      %reinterpret_cast_11 = memref.reinterpret_cast %arg6 to offset: [%42], sizes: [32], strides: [1] : memref<?xf32> to memref<32xf32, strided<[1], offset: ?>>
      bufferization.materialize_in_destination %37 in writable %reinterpret_cast_11 : (tensor<32xf32>, memref<32xf32, strided<[1], offset: ?>>) -> ()
      %43 = hivm.hir.vcast ins(%39 : tensor<32x128xf32>) outs(%24 : tensor<32x128xf16>) -> tensor<32x128xf16>
      bufferization.materialize_in_destination %43 in writable %reinterpret_cast_4 : (tensor<32x128xf16>, memref<32x128xf16, strided<[128, 1], offset: ?>>) -> ()
    }
    return
  }
}


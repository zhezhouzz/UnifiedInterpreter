// -----// IR Dump After ConvertHFusionToHIVM (convert-hfusion-to-hivm) ('builtin.module' operation) //----- //
module attributes {dlti.target_system_spec = #dlti.target_system_spec<"NPU" : #hacc.target_device_spec<#dlti.dl_entry<"AI_CORE_COUNT", 24 : i32>, #dlti.dl_entry<"CUBE_CORE_COUNT", 24 : i32>, #dlti.dl_entry<"VECTOR_CORE_COUNT", 48 : i32>, #dlti.dl_entry<"UB_SIZE", 1572864 : i32>, #dlti.dl_entry<"L1_SIZE", 4194304 : i32>, #dlti.dl_entry<"L0A_SIZE", 524288 : i32>, #dlti.dl_entry<"L0B_SIZE", 524288 : i32>, #dlti.dl_entry<"L0C_SIZE", 1048576 : i32>, #dlti.dl_entry<"UB_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L1_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L0C_ALIGN_SIZE", 4096 : i32>>>, hacc.hivmc_compatible_print = false, hacc.hivmc_version = #hacc.hivmc_version<"0.0.0">} {
  func.func @_attn_fwd(%arg0: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}, %arg1: memref<?xi8> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg2: memref<?xi8> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg3: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg5: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg6: memref<?xf16> {tt.tensor_kind = 1 : i32}, %arg7: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg8: memref<?xf32>, %arg9: f32, %arg10: i32, %arg11: i32, %arg12: i32, %arg13: i32, %arg14: i32, %arg15: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, mix_mode = "mix", parallel_mode = "simd"} {
    %false = arith.constant false
    %c0 = arith.constant 0 : index
    %true = arith.constant true
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
    scf.for %arg16 = %arg13 to %c4_i32 step %c20_i32  : i32 {
      %4 = arith.divsi %arg16, %c4_i32 : i32
      %5 = arith.remsi %arg16, %c4_i32 : i32
      %6 = arith.extsi %4 : i32 to i64
      %7 = arith.muli %6, %c16384_i64 : i64
      %8 = arith.index_cast %7 : i64 to index
      %9 = arith.muli %5, %c32_i32 : i32
      %10 = arith.index_cast %9 : i32 to index
      %11 = arith.muli %10, %c128 : index
      %12 = arith.addi %11, %8 : index
      %reinterpret_cast = memref.reinterpret_cast %arg3 to offset: [%12], sizes: [32, 128], strides: [128, 1] : memref<?xf16> to memref<32x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_2 = memref.reinterpret_cast %arg5 to offset: [%8], sizes: [128, 128], strides: [128, 1] : memref<?xf16> to memref<128x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_3 = memref.reinterpret_cast %arg4 to offset: [%8], sizes: [128, 128], strides: [128, 1] : memref<?xf16> to memref<128x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_4 = memref.reinterpret_cast %arg7 to offset: [%12], sizes: [32, 128], strides: [128, 1] : memref<?xf32> to memref<32x128xf32, strided<[128, 1], offset: ?>>
      %alloc = memref.alloc() : memref<32x128xf16>
      memref.copy %reinterpret_cast, %alloc : memref<32x128xf16, strided<[128, 1], offset: ?>> to memref<32x128xf16>
      %13 = bufferization.to_tensor %alloc restrict writable : memref<32x128xf16>
      %alloc_5 = memref.alloc() : memref<128x128xf16>
      memref.copy %reinterpret_cast_3, %alloc_5 : memref<128x128xf16, strided<[128, 1], offset: ?>> to memref<128x128xf16>
      %14 = bufferization.to_tensor %alloc_5 restrict writable : memref<128x128xf16>
      %15 = tensor.empty() : tensor<32x128xf32>
      %16 = hivm.hir.mmadL1 {b_transpose} ins(%13, %14, %true, %c0, %c0, %c0 : tensor<32x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%15 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %17 = hivm.hir.vmul ins(%16, %arg9 : tensor<32x128xf32>, f32) outs(%3 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %expanded = tensor.expand_shape %2 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %18 = hivm.hir.vreduce <max> ins(%17 : tensor<32x128xf32>) outs(%expanded : tensor<32x1xf32>) reduce_dims = [1] -> tensor<32x1xf32>
      %collapsed = tensor.collapse_shape %18 [[0, 1]] : tensor<32x1xf32> into tensor<32xf32>
      %19 = hivm.hir.vbrc ins(%18 : tensor<32x1xf32>) outs(%3 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %20 = hivm.hir.vsub ins(%17, %19 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%3 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %21 = hivm.hir.vexp ins(%20 : tensor<32x128xf32>) outs(%3 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %22 = tensor.empty() : tensor<32x128xf16>
      %23 = hivm.hir.vcast ins(%21 : tensor<32x128xf32>) outs(%22 : tensor<32x128xf16>) -> tensor<32x128xf16>
      %alloc_6 = memref.alloc() : memref<128x128xf16>
      memref.copy %reinterpret_cast_2, %alloc_6 : memref<128x128xf16, strided<[128, 1], offset: ?>> to memref<128x128xf16>
      %24 = bufferization.to_tensor %alloc_6 restrict writable : memref<128x128xf16>
      %25 = hivm.hir.vbrc ins(%cst_1 : f32) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_7 = tensor.expand_shape %25 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %26 = hivm.hir.vreduce <sum> ins(%21 : tensor<32x128xf32>) outs(%expanded_7 : tensor<32x1xf32>) reduce_dims = [1] -> tensor<32x1xf32>
      %collapsed_8 = tensor.collapse_shape %26 [[0, 1]] : tensor<32x1xf32> into tensor<32xf32>
      %27 = hivm.hir.vmul ins(%collapsed, %cst : tensor<32xf32>, f32) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %28 = hivm.hir.vadd ins(%27, %cst_0 : tensor<32xf32>, f32) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %29 = hivm.hir.vexp ins(%28 : tensor<32xf32>) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %30 = hivm.hir.vadd ins(%29, %collapsed_8 : tensor<32xf32>, tensor<32xf32>) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_9 = tensor.expand_shape %29 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %31 = hivm.hir.vmul ins(%expanded_9, %cst_1 : tensor<32x1xf32>, f32) outs(%0 : tensor<32x1xf32>) -> tensor<32x1xf32>
      %32 = hivm.hir.vbrc ins(%31 : tensor<32x1xf32>) outs(%3 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %33 = hivm.hir.mmadL1 ins(%23, %24, %false, %c0, %c0, %c0 : tensor<32x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%32 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %34 = hivm.hir.vln ins(%30 : tensor<32xf32>) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %35 = hivm.hir.vadd ins(%collapsed, %34 : tensor<32xf32>, tensor<32xf32>) outs(%1 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_10 = tensor.expand_shape %30 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %36 = hivm.hir.vbrc ins(%expanded_10 : tensor<32x1xf32>) outs(%3 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %37 = hivm.hir.vdiv ins(%33, %36 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%3 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %38 = arith.muli %4, %c128_i32 : i32
      %39 = arith.index_cast %38 : i32 to index
      %40 = arith.addi %39, %10 : index
      %reinterpret_cast_11 = memref.reinterpret_cast %arg6 to offset: [%40], sizes: [32], strides: [1] : memref<?xf16> to memref<32xf16, strided<[1], offset: ?>>
      %41 = tensor.empty() : tensor<32xf16>
      %42 = hivm.hir.vcast ins(%35 : tensor<32xf32>) outs(%41 : tensor<32xf16>) -> tensor<32xf16>
      bufferization.materialize_in_destination %42 in writable %reinterpret_cast_11 : (tensor<32xf16>, memref<32xf16, strided<[1], offset: ?>>) -> ()
      bufferization.materialize_in_destination %37 in writable %reinterpret_cast_4 : (tensor<32x128xf32>, memref<32x128xf32, strided<[128, 1], offset: ?>>) -> ()
    }
    return
  }
}



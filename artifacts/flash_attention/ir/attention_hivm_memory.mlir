// -----// IR Dump After ConvertToHIVMOp (convert-to-hivm-op) ('builtin.module' operation) //----- //
module attributes {dlti.target_system_spec = #dlti.target_system_spec<"NPU" : #hacc.target_device_spec<#dlti.dl_entry<"AI_CORE_COUNT", 24 : i32>, #dlti.dl_entry<"CUBE_CORE_COUNT", 24 : i32>, #dlti.dl_entry<"VECTOR_CORE_COUNT", 48 : i32>, #dlti.dl_entry<"UB_SIZE", 1572864 : i32>, #dlti.dl_entry<"L1_SIZE", 4194304 : i32>, #dlti.dl_entry<"L0A_SIZE", 524288 : i32>, #dlti.dl_entry<"L0B_SIZE", 524288 : i32>, #dlti.dl_entry<"L0C_SIZE", 1048576 : i32>, #dlti.dl_entry<"UB_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L1_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L0C_ALIGN_SIZE", 4096 : i32>>>, hacc.hivmc_compatible_print = false, hacc.hivmc_version = #hacc.hivmc_version<"0.0.0">} {
  func.func @_attn_fwd(%arg0: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}, %arg1: memref<?xi8> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg2: memref<?xi8> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg3: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg5: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg6: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg7: memref<?xf16> {tt.tensor_kind = 1 : i32}, %arg8: memref<?xf32>, %arg9: f32, %arg10: i32, %arg11: i32, %arg12: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, func_dyn_memref_args = dense<[false, true, true, true, true, true, true, true, true, false, false, false, false]> : vector<13xi1>, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, mix_mode = "mix", parallel_mode = "simd"} {
    %cst = arith.constant 0.000000e+00 : f32
    %cst_0 = arith.constant 0xFF800000 : f32
    %c20_i32 = arith.constant 20 : i32
    %c128_i32 = arith.constant 128 : i32
    %c32_i32 = arith.constant 32 : i32
    %c16384_i64 = arith.constant 16384 : i64
    %c4_i32 = arith.constant 4 : i32
    %c128 = arith.constant 128 : index
    %cst_1 = arith.constant -1.000000e+00 : f32
    %true = arith.constant true
    %c0 = arith.constant 0 : index
    %false = arith.constant false
    %0 = arith.muli %arg10, %arg11 : i32
    %1 = arith.muli %0, %arg12 : i32
    annotation.mark %1 {logical_block_num} : i32
    %2 = hivm.hir.get_block_idx -> i64
    %3 = arith.trunci %2 : i64 to i32
    %4 = arith.muli %arg12, %arg11 : i32
    %5 = arith.divsi %3, %4 : i32
    %6 = arith.remsi %5, %arg10 : i32
    %7 = tensor.empty() : tensor<32x1xf32>
    %8 = tensor.empty() : tensor<32xf32>
    %9 = hivm.hir.vbrc ins(%cst_0 : f32) outs(%8 : tensor<32xf32>) -> tensor<32xf32>
    %10 = tensor.empty() : tensor<32x128xf32>
    scf.for %arg13 = %6 to %c4_i32 step %c20_i32  : i32 {
      %11 = arith.divsi %arg13, %c4_i32 : i32
      %12 = arith.remsi %arg13, %c4_i32 : i32
      %13 = arith.extsi %11 : i32 to i64
      %14 = arith.muli %13, %c16384_i64 : i64
      %15 = arith.index_cast %14 : i64 to index
      %16 = arith.muli %12, %c32_i32 : i32
      %17 = arith.index_cast %16 : i32 to index
      %18 = arith.muli %17, %c128 : index
      %19 = arith.addi %18, %15 : index
      %reinterpret_cast = memref.reinterpret_cast %arg3 to offset: [%19], sizes: [32, 128], strides: [128, 1] : memref<?xf16> to memref<32x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_2 = memref.reinterpret_cast %arg5 to offset: [%15], sizes: [128, 128], strides: [128, 1] : memref<?xf16> to memref<128x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_3 = memref.reinterpret_cast %arg4 to offset: [%15], sizes: [128, 128], strides: [128, 1] : memref<?xf16> to memref<128x128xf16, strided<[128, 1], offset: ?>>
      %reinterpret_cast_4 = memref.reinterpret_cast %arg7 to offset: [%19], sizes: [32, 128], strides: [128, 1] : memref<?xf16> to memref<32x128xf16, strided<[128, 1], offset: ?>>
      %alloc = memref.alloc() : memref<32x128xf16>
      hivm.hir.load ins(%reinterpret_cast : memref<32x128xf16, strided<[128, 1], offset: ?>>) outs(%alloc : memref<32x128xf16>) init_out_buffer = false may_implicit_transpose_with_last_axis = false
      %20 = bufferization.to_tensor %alloc restrict writable : memref<32x128xf16>
      %alloc_5 = memref.alloc() : memref<128x128xf16>
      hivm.hir.load ins(%reinterpret_cast_3 : memref<128x128xf16, strided<[128, 1], offset: ?>>) outs(%alloc_5 : memref<128x128xf16>) init_out_buffer = false may_implicit_transpose_with_last_axis = false
      %21 = bufferization.to_tensor %alloc_5 restrict writable : memref<128x128xf16>
      %22 = tensor.empty() : tensor<32x128xf32>
      %23 = hivm.hir.mmadL1 {b_transpose} ins(%20, %21, %true, %c0, %c0, %c0 : tensor<32x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%22 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %24 = hivm.hir.vmul ins(%23, %arg9 : tensor<32x128xf32>, f32) outs(%10 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %expanded = tensor.expand_shape %9 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %25 = hivm.hir.vreduce <max> ins(%24 : tensor<32x128xf32>) outs(%expanded : tensor<32x1xf32>) reduce_dims = [1] -> tensor<32x1xf32>
      %collapsed = tensor.collapse_shape %25 [[0, 1]] : tensor<32x1xf32> into tensor<32xf32>
      %26 = hivm.hir.vbrc ins(%25 : tensor<32x1xf32>) outs(%10 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %27 = hivm.hir.vsub ins(%24, %26 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%10 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %28 = hivm.hir.vexp ins(%27 : tensor<32x128xf32>) outs(%10 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %29 = tensor.empty() : tensor<32x128xf16>
      %30 = hivm.hir.vcast ins(%28 : tensor<32x128xf32>) outs(%29 : tensor<32x128xf16>) -> tensor<32x128xf16>
      %alloc_6 = memref.alloc() : memref<128x128xf16>
      hivm.hir.load ins(%reinterpret_cast_2 : memref<128x128xf16, strided<[128, 1], offset: ?>>) outs(%alloc_6 : memref<128x128xf16>) init_out_buffer = false may_implicit_transpose_with_last_axis = false
      %31 = bufferization.to_tensor %alloc_6 restrict writable : memref<128x128xf16>
      %32 = hivm.hir.vbrc ins(%cst : f32) outs(%8 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_7 = tensor.expand_shape %32 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %33 = hivm.hir.vreduce <sum> ins(%28 : tensor<32x128xf32>) outs(%expanded_7 : tensor<32x1xf32>) reduce_dims = [1] -> tensor<32x1xf32>
      %collapsed_8 = tensor.collapse_shape %33 [[0, 1]] : tensor<32x1xf32> into tensor<32xf32>
      %34 = hivm.hir.vmul ins(%collapsed, %cst_1 : tensor<32xf32>, f32) outs(%8 : tensor<32xf32>) -> tensor<32xf32>
      %35 = hivm.hir.vadd ins(%34, %cst_0 : tensor<32xf32>, f32) outs(%8 : tensor<32xf32>) -> tensor<32xf32>
      %36 = hivm.hir.vexp ins(%35 : tensor<32xf32>) outs(%8 : tensor<32xf32>) -> tensor<32xf32>
      %37 = hivm.hir.vadd ins(%36, %collapsed_8 : tensor<32xf32>, tensor<32xf32>) outs(%8 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_9 = tensor.expand_shape %36 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %38 = hivm.hir.vmul ins(%expanded_9, %cst : tensor<32x1xf32>, f32) outs(%7 : tensor<32x1xf32>) -> tensor<32x1xf32>
      %39 = hivm.hir.vbrc ins(%38 : tensor<32x1xf32>) outs(%10 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %40 = hivm.hir.mmadL1 ins(%30, %31, %false, %c0, %c0, %c0 : tensor<32x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%39 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %41 = hivm.hir.vln ins(%37 : tensor<32xf32>) outs(%8 : tensor<32xf32>) -> tensor<32xf32>
      %42 = hivm.hir.vadd ins(%collapsed, %41 : tensor<32xf32>, tensor<32xf32>) outs(%8 : tensor<32xf32>) -> tensor<32xf32>
      %expanded_10 = tensor.expand_shape %37 [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %43 = hivm.hir.vbrc ins(%expanded_10 : tensor<32x1xf32>) outs(%10 : tensor<32x128xf32>) broadcast_dims = [1] -> tensor<32x128xf32>
      %44 = hivm.hir.vdiv ins(%40, %43 : tensor<32x128xf32>, tensor<32x128xf32>) outs(%10 : tensor<32x128xf32>) -> tensor<32x128xf32>
      %45 = arith.muli %11, %c128_i32 : i32
      %46 = arith.index_cast %45 : i32 to index
      %47 = arith.addi %46, %17 : index
      %reinterpret_cast_11 = memref.reinterpret_cast %arg6 to offset: [%47], sizes: [32], strides: [1] : memref<?xf32> to memref<32xf32, strided<[1], offset: ?>>
      hivm.hir.store ins(%42 : tensor<32xf32>) outs(%reinterpret_cast_11 : memref<32xf32, strided<[1], offset: ?>>)
      %48 = hivm.hir.vcast ins(%44 : tensor<32x128xf32>) outs(%29 : tensor<32x128xf16>) -> tensor<32x128xf16>
      hivm.hir.store ins(%48 : tensor<32x128xf16>) outs(%reinterpret_cast_4 : memref<32x128xf16, strided<[128, 1], offset: ?>>)
    }
    return
  }
}

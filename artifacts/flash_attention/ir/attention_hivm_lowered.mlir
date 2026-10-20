// -----// IR Dump After InsertFreeLockVarBeforeReturn (hivm-insert-free-lock-var-before-return) ('builtin.module' operation) //----- //
#map = affine_map<()[s0, s1] -> ((s0 - s1) floordiv 20)>
#map1 = affine_map<()[s0, s1] -> (s0 + s1 * 128)>
#map2 = affine_map<(d0) -> (d0 * 40960)>
#map3 = affine_map<(d0) -> (d0 * 40960 + 16384)>
#map4 = affine_map<(d0) -> (d0 * 40960 + 24576)>
#map5 = affine_map<()[s0] -> (s0 * 16)>
#map6 = affine_map<()[s0, s1] -> (s0 + s1)>
module attributes {dlti.target_system_spec = #dlti.target_system_spec<"NPU" : #hacc.target_device_spec<#dlti.dl_entry<"AI_CORE_COUNT", 24 : i32>, #dlti.dl_entry<"CUBE_CORE_COUNT", 24 : i32>, #dlti.dl_entry<"VECTOR_CORE_COUNT", 48 : i32>, #dlti.dl_entry<"UB_SIZE", 1572864 : i32>, #dlti.dl_entry<"L1_SIZE", 4194304 : i32>, #dlti.dl_entry<"L0A_SIZE", 524288 : i32>, #dlti.dl_entry<"L0B_SIZE", 524288 : i32>, #dlti.dl_entry<"L0C_SIZE", 1048576 : i32>, #dlti.dl_entry<"UB_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L1_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L0C_ALIGN_SIZE", 4096 : i32>>>, hacc.hivmc_compatible_print = true, hacc.hivmc_version = #hacc.hivmc_version<"0.0.0">, hivm.module_core_type = #hivm.module_core_type<MIX>} {
  func.func @_attn_fwd_infer_workspace_shape_function() -> index attributes {hacc.function_kind = #hacc.function_kind<HOST>, hacc.host_func_type = #hacc.host_func_type<infer_workspace_shape_function>} {
    %c40960 = arith.constant 40960 : index
    return %c40960 : index
  }
  func.func @_attn_fwd_infer_task_type_function() -> i8 attributes {hacc.function_kind = #hacc.function_kind<HOST>, hacc.host_func_type = #hacc.host_func_type<infer_task_type_function>} {
    %c32_i8 = arith.constant 32 : i8
    return %c32_i8 : i8
  }
  func.func @_attn_fwd_mix_aic(%arg0: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}, %arg1: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg2: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg3: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg5: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg6: memref<?xf32, #hivm.address_space<gm>> {tt.tensor_kind = 1 : i32}, %arg7: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 1 : i32}, %arg8: memref<?xf32, #hivm.address_space<gm>>, %arg9: f32, %arg10: i32, %arg11: i32, %arg12: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, func_dyn_memref_args = dense<[false, true, true, true, true, true, true, true, true, false, false, false, false]> : vector<13xi1>, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<AIC>, hivm.part_of_mix, hivm.storage_aligned, mix_mode = "mix", parallel_mode = "simd"} {
    %c-1_i64 = arith.constant -1 : i64
    %c3_i64 = arith.constant 3 : i64
    %c2_i64 = arith.constant 2 : i64
    %c1_i64 = arith.constant 1 : i64
    %c0_i64 = arith.constant 0 : i64
    %c49152_i64 = arith.constant 49152 : i64
    %c40960_i64 = arith.constant 40960 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c32 = arith.constant 32 : index
    %c20_i32 = arith.constant 20 : i32
    %c32_i32 = arith.constant 32 : i32
    %c16384_i64 = arith.constant 16384 : i64
    %c4_i32 = arith.constant 4 : i32
    %c128 = arith.constant 128 : index
    %true = arith.constant true
    hivm.hir.set_ffts_base_addr %arg0
    hivm.hir.set_mask_norm
    %0 = hivm.hir.get_block_idx -> i64
    %1 = arith.trunci %0 : i64 to i32
    %2 = arith.muli %arg12, %arg11 : i32
    %3 = arith.divsi %1, %2 : i32
    %4 = arith.remsi %3, %arg10 : i32
    hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE2>, <PIPE_S>] flag = 3 ffts_base_addr = %arg0
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID2>]
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID3>]
    hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
    scf.for %arg13 = %4 to %c4_i32 step %c20_i32  : i32 {
      %5 = arith.index_cast %arg13 : i32 to index
      %6 = arith.index_cast %4 : i32 to index
      %7 = affine.apply #map()[%5, %6]
      %8 = arith.index_cast %7 : index to i64
      %9 = arith.divsi %arg13, %c4_i32 : i32
      %10 = arith.remsi %arg13, %c4_i32 : i32
      %11 = arith.extsi %9 : i32 to i64
      %12 = arith.muli %11, %c16384_i64 : i64
      %13 = arith.index_cast %12 : i64 to index
      %14 = arith.muli %10, %c32_i32 : i32
      %15 = arith.index_cast %14 : i32 to index
      %16 = affine.apply #map1()[%13, %15]
      %reinterpret_cast = memref.reinterpret_cast %arg3 to offset: [%16], sizes: [32, 128], strides: [128, 1] : memref<?xf16, #hivm.address_space<gm>> to memref<32x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_0 = memref.reinterpret_cast %arg5 to offset: [%13], sizes: [128, 128], strides: [128, 1] : memref<?xf16, #hivm.address_space<gm>> to memref<128x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_1 = memref.reinterpret_cast %arg4 to offset: [%13], sizes: [128, 128], strides: [128, 1] : memref<?xf16, #hivm.address_space<gm>> to memref<128x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>
      %17 = hivm.hir.pointer_cast(%c0_i64) : memref<8x2x16x16xf16, #hivm.address_space<cbuf>>
      %cast = memref.cast %17 : memref<8x2x16x16xf16, #hivm.address_space<cbuf>> to memref<?x?x?x?xf16, #hivm.address_space<cbuf>>
      hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.nd2nz {dst_continuous} ins(%reinterpret_cast : memref<32x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>) outs(%cast : memref<?x?x?x?xf16, #hivm.address_space<cbuf>>) init_out_buffer = false
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
      %18 = hivm.hir.pointer_cast(%c8192_i64) : memref<8x8x16x16xf16, #hivm.address_space<cbuf>>
      %cast_2 = memref.cast %18 : memref<8x8x16x16xf16, #hivm.address_space<cbuf>> to memref<?x?x?x?xf16, #hivm.address_space<cbuf>>
      hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
      hivm.hir.nd2nz {dst_continuous} ins(%reinterpret_cast_1 : memref<128x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>) outs(%cast_2 : memref<?x?x?x?xf16, #hivm.address_space<cbuf>>) init_out_buffer = false
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID1>]
      %19 = hivm.hir.pointer_cast(%c0_i64) : memref<8x2x16x16xf32, #hivm.address_space<cc>>
      %cast_3 = memref.cast %19 : memref<8x2x16x16xf32, #hivm.address_space<cc>> to memref<?x?x?x?xf32, #hivm.address_space<cc>>
      hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
      hivm.hir.mmadL1 {b_transpose, fixpipe_for_result_already_inserted = true} ins(%cast, %cast_2, %true, %c32, %c128, %c128 : memref<?x?x?x?xf16, #hivm.address_space<cbuf>>, memref<?x?x?x?xf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%cast_3 : memref<?x?x?x?xf32, #hivm.address_space<cc>>) sync_related_args(%c0_i64, %c1_i64, %c0_i64, %c1_i64, %8, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
      hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
      %20 = hivm.hir.get_block_idx -> i64
      %21 = arith.index_cast %20 : i64 to index
      %22 = affine.apply #map2(%21)
      %view = memref.view %arg2[%22][] : memref<?xi8, #hivm.address_space<gm>> to memref<32x128xf32, #hivm.address_space<gm>>
      hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE2>, <PIPE_S>] flag = 2
      hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
      hivm.hir.fixpipe {enable_nz2nd} ins(%cast_3 : memref<?x?x?x?xf32, #hivm.address_space<cc>>) outs(%view : memref<32x128xf32, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
      hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_S>] flag = 0 ffts_base_addr = %arg0
      %23 = hivm.hir.get_block_idx -> i64
      %24 = arith.index_cast %23 : i64 to index
      %25 = affine.apply #map3(%24)
      %view_4 = memref.view %arg2[%25][] : memref<?xi8, #hivm.address_space<gm>> to memref<32x128xf16, #hivm.address_space<gm>>
      hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 1
      %26 = hivm.hir.pointer_cast(%c40960_i64) : memref<8x2x16x16xf16, #hivm.address_space<cbuf>>
      %cast_5 = memref.cast %26 : memref<8x2x16x16xf16, #hivm.address_space<cbuf>> to memref<?x?x?x?xf16, #hivm.address_space<cbuf>>
      hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID2>]
      hivm.hir.nd2nz {dst_continuous} ins(%view_4 : memref<32x128xf16, #hivm.address_space<gm>>) outs(%cast_5 : memref<?x?x?x?xf16, #hivm.address_space<cbuf>>) init_out_buffer = false
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
      hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE2>, <PIPE_S>] flag = 3 ffts_base_addr = %arg0
      %27 = hivm.hir.pointer_cast(%c49152_i64) : memref<8x8x16x16xf16, #hivm.address_space<cbuf>>
      %cast_6 = memref.cast %27 : memref<8x8x16x16xf16, #hivm.address_space<cbuf>> to memref<?x?x?x?xf16, #hivm.address_space<cbuf>>
      hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID3>]
      hivm.hir.nd2nz {dst_continuous} ins(%reinterpret_cast_0 : memref<128x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>) outs(%cast_6 : memref<?x?x?x?xf16, #hivm.address_space<cbuf>>) init_out_buffer = false
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID1>]
      %28 = hivm.hir.pointer_cast(%c16384_i64) : memref<8x2x16x16xf32, #hivm.address_space<cc>>
      %cast_7 = memref.cast %28 : memref<8x2x16x16xf32, #hivm.address_space<cc>> to memref<?x?x?x?xf32, #hivm.address_space<cc>>
      hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
      hivm.hir.mmadL1 {fixpipe_for_result_already_inserted = true} ins(%cast_5, %cast_6, %true, %c32, %c128, %c128 : memref<?x?x?x?xf16, #hivm.address_space<cbuf>>, memref<?x?x?x?xf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%cast_7 : memref<?x?x?x?xf32, #hivm.address_space<cc>>) sync_related_args(%c0_i64, %c1_i64, %c2_i64, %c3_i64, %8, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
      hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
      %29 = hivm.hir.get_block_idx -> i64
      %30 = arith.index_cast %29 : i64 to index
      %31 = affine.apply #map4(%30)
      %view_8 = memref.view %arg2[%31][] : memref<?xi8, #hivm.address_space<gm>> to memref<32x128xf32, #hivm.address_space<gm>>
      hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE2>, <PIPE_S>] flag = 4
      hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
      hivm.hir.fixpipe {enable_nz2nd} ins(%cast_7 : memref<?x?x?x?xf32, #hivm.address_space<cc>>) outs(%view_8 : memref<32x128xf32, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
      hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_S>] flag = 0 ffts_base_addr = %arg0
    } {fixpipe_for_mmad_result_already_inserted = true}
    hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID2>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID3>]
    hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE2>, <PIPE_S>] flag = 2
    hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE2>, <PIPE_S>] flag = 4
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
  func.func @_attn_fwd_mix_aiv(%arg0: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}, %arg1: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg2: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg3: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg5: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg6: memref<?xf32, #hivm.address_space<gm>> {tt.tensor_kind = 1 : i32}, %arg7: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 1 : i32}, %arg8: memref<?xf32, #hivm.address_space<gm>>, %arg9: f32, %arg10: i32, %arg11: i32, %arg12: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, func_dyn_memref_args = dense<[false, true, true, true, true, true, true, true, true, false, false, false, false]> : vector<13xi1>, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.part_of_mix, hivm.storage_aligned, mix_mode = "mix", parallel_mode = "simd"} {
    %c29952_i64 = arith.constant 29952 : i64
    %c29888_i64 = arith.constant 29888 : i64
    %c29376_i64 = arith.constant 29376 : i64
    %c21184_i64 = arith.constant 21184 : i64
    %c21120_i64 = arith.constant 21120 : i64
    %c17024_i64 = arith.constant 17024 : i64
    %c16960_i64 = arith.constant 16960 : i64
    %c12864_i64 = arith.constant 12864 : i64
    %c12352_i64 = arith.constant 12352 : i64
    %c8256_i64 = arith.constant 8256 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c0_i64 = arith.constant 0 : i64
    %cst = arith.constant -1.000000e+00 : f32
    %c4_i32 = arith.constant 4 : i32
    %c16384_i64 = arith.constant 16384 : i64
    %c32_i32 = arith.constant 32 : i32
    %c128_i32 = arith.constant 128 : i32
    %c20_i32 = arith.constant 20 : i32
    %cst_0 = arith.constant 0xFF800000 : f32
    %cst_1 = arith.constant 0.000000e+00 : f32
    %0 = hivm.hir.get_block_idx -> i64
    %1 = arith.trunci %0 : i64 to i32
    %2 = arith.muli %arg12, %arg11 : i32
    %3 = hivm.hir.get_sub_block_idx -> i64
    %4 = arith.index_cast %3 : i64 to index
    %5 = affine.apply #map5()[%4]
    hivm.hir.set_ffts_base_addr %arg0
    hivm.hir.set_mask_norm
    %6 = arith.divsi %1, %2 : i32
    %7 = arith.remsi %6, %arg10 : i32
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE2>, <PIPE_S>] flag = 2 ffts_base_addr = %arg0
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE2>, <PIPE_S>] flag = 4 ffts_base_addr = %arg0
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    scf.for %arg13 = %7 to %c4_i32 step %c20_i32  : i32 {
      %8 = arith.divsi %arg13, %c4_i32 : i32
      %9 = arith.remsi %arg13, %c4_i32 : i32
      %10 = arith.extsi %8 : i32 to i64
      %11 = arith.muli %10, %c16384_i64 : i64
      %12 = arith.index_cast %11 : i64 to index
      %13 = arith.muli %9, %c32_i32 : i32
      %14 = arith.index_cast %13 : i32 to index
      %15 = affine.apply #map1()[%12, %14]
      %reinterpret_cast = memref.reinterpret_cast %arg7 to offset: [%15], sizes: [32, 128], strides: [128, 1] : memref<?xf16, #hivm.address_space<gm>> to memref<32x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>
      %subview = memref.subview %reinterpret_cast[%5, 0] [16, 128] [1, 1] {to_be_bubbled_slice} : memref<32x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>> to memref<16x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>
      %16 = hivm.hir.get_block_idx -> i64
      %17 = arith.index_cast %16 : i64 to index
      %18 = affine.apply #map2(%17)
      %view = memref.view %arg2[%18][] : memref<?xi8, #hivm.address_space<gm>> to memref<32x128xf32, #hivm.address_space<gm>>
      hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_S>] flag = 0
      %subview_2 = memref.subview %view[%5, 0] [16, 128] [1, 1] {to_be_bubbled_slice} : memref<32x128xf32, #hivm.address_space<gm>> to memref<16x128xf32, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>
      %19 = hivm.hir.pointer_cast(%c0_i64) : memref<16x128xf32, #hivm.address_space<ub>>
      %collapse_shape = memref.collapse_shape %subview_2 [[0, 1]] : memref<16x128xf32, strided<[128, 1], offset: ?>, #hivm.address_space<gm>> into memref<2048xf32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %collapse_shape_3 = memref.collapse_shape %19 [[0, 1]] : memref<16x128xf32, #hivm.address_space<ub>> into memref<2048xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.load ins(%collapse_shape : memref<2048xf32, strided<[1], offset: ?>, #hivm.address_space<gm>>) outs(%collapse_shape_3 : memref<2048xf32, #hivm.address_space<ub>>) {"inserted-load"} init_out_buffer = false may_implicit_transpose_with_last_axis = false core_type = <VECTOR>
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE2>, <PIPE_S>] flag = 2 ffts_base_addr = %arg0
      %20 = hivm.hir.pointer_cast(%c0_i64) : memref<16x128xf32, #hivm.address_space<ub>>
      %collapse_shape_4 = memref.collapse_shape %20 [[0, 1]] : memref<16x128xf32, #hivm.address_space<ub>> into memref<2048xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.vmul ins(%collapse_shape_3, %arg9 : memref<2048xf32, #hivm.address_space<ub>>, f32) outs(%collapse_shape_4 : memref<2048xf32, #hivm.address_space<ub>>)
      %21 = hivm.hir.pointer_cast(%c8192_i64) : memref<16x1xf32, #hivm.address_space<ub>>
      %22 = hivm.hir.pointer_cast(%c8256_i64) : memref<1024xf32, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vreduce <max> ins(%20 : memref<16x128xf32, #hivm.address_space<ub>>) outs(%21 : memref<16x1xf32, #hivm.address_space<ub>>) temp_buffer(%22 : memref<1024xf32, #hivm.address_space<ub>>) reduce_dims = [1]
      %collapse_shape_5 = memref.collapse_shape %21 [[0, 1]] : memref<16x1xf32, #hivm.address_space<ub>> into memref<16xf32, #hivm.address_space<ub>>
      %23 = hivm.hir.pointer_cast(%c0_i64) : memref<16x128xf32, #hivm.address_space<ub>>
      %24 = hivm.hir.pointer_cast(%c12352_i64) : memref<128xf32, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vsub ins(%20, %21 : memref<16x128xf32, #hivm.address_space<ub>>, memref<16x1xf32, #hivm.address_space<ub>>) outs(%23 : memref<16x128xf32, #hivm.address_space<ub>>) temp_buffer(%24 : memref<128xf32, #hivm.address_space<ub>>) broadcast = [1]
      %25 = hivm.hir.pointer_cast(%c0_i64) : memref<16x128xf32, #hivm.address_space<ub>>
      %collapse_shape_6 = memref.collapse_shape %23 [[0, 1]] : memref<16x128xf32, #hivm.address_space<ub>> into memref<2048xf32, #hivm.address_space<ub>>
      %collapse_shape_7 = memref.collapse_shape %25 [[0, 1]] : memref<16x128xf32, #hivm.address_space<ub>> into memref<2048xf32, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vexp ins(%collapse_shape_6 : memref<2048xf32, #hivm.address_space<ub>>) outs(%collapse_shape_7 : memref<2048xf32, #hivm.address_space<ub>>)
      %26 = hivm.hir.pointer_cast(%c12864_i64) : memref<16x128xf16, #hivm.address_space<ub>>
      %collapse_shape_8 = memref.collapse_shape %26 [[0, 1]] : memref<16x128xf16, #hivm.address_space<ub>> into memref<2048xf16, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vcast ins(%collapse_shape_7 : memref<2048xf32, #hivm.address_space<ub>>) outs(%collapse_shape_8 : memref<2048xf16, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      %27 = hivm.hir.get_block_idx -> i64
      %28 = arith.index_cast %27 : i64 to index
      %29 = affine.apply #map3(%28)
      %view_9 = memref.view %arg2[%29][] : memref<?xi8, #hivm.address_space<gm>> to memref<32x128xf16, #hivm.address_space<gm>>
      %subview_10 = memref.subview %view_9[%5, 0] [16, 128] [1, 1] {to_be_bubbled_slice} : memref<32x128xf16, #hivm.address_space<gm>> to memref<16x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>
      hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE2>, <PIPE_S>] flag = 3
      %collapse_shape_11 = memref.collapse_shape %subview_10 [[0, 1]] : memref<16x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>> into memref<2048xf16, strided<[1], offset: ?>, #hivm.address_space<gm>>
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%collapse_shape_8 : memref<2048xf16, #hivm.address_space<ub>>) outs(%collapse_shape_11 : memref<2048xf16, strided<[1], offset: ?>, #hivm.address_space<gm>>) {"inserted-store", tiled_op}
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_S>] flag = 1 ffts_base_addr = %arg0
      %30 = hivm.hir.pointer_cast(%c16960_i64) : memref<16x1xf32, #hivm.address_space<ub>>
      %31 = hivm.hir.pointer_cast(%c17024_i64) : memref<1024xf32, #hivm.address_space<ub>>
      hivm.hir.vreduce <sum> ins(%25 : memref<16x128xf32, #hivm.address_space<ub>>) outs(%30 : memref<16x1xf32, #hivm.address_space<ub>>) temp_buffer(%31 : memref<1024xf32, #hivm.address_space<ub>>) reduce_dims = [1]
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
      %collapse_shape_12 = memref.collapse_shape %30 [[0, 1]] : memref<16x1xf32, #hivm.address_space<ub>> into memref<16xf32, #hivm.address_space<ub>>
      %32 = hivm.hir.pointer_cast(%c21120_i64) : memref<16xf32, #hivm.address_space<ub>>
      hivm.hir.vmul ins(%collapse_shape_5, %cst : memref<16xf32, #hivm.address_space<ub>>, f32) outs(%32 : memref<16xf32, #hivm.address_space<ub>>)
      %33 = hivm.hir.pointer_cast(%c21120_i64) : memref<16xf32, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vadd ins(%32, %cst_0 : memref<16xf32, #hivm.address_space<ub>>, f32) outs(%33 : memref<16xf32, #hivm.address_space<ub>>)
      %34 = hivm.hir.pointer_cast(%c21120_i64) : memref<16xf32, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vexp ins(%33 : memref<16xf32, #hivm.address_space<ub>>) outs(%34 : memref<16xf32, #hivm.address_space<ub>>)
      %35 = hivm.hir.pointer_cast(%c16960_i64) : memref<16xf32, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vadd ins(%34, %collapse_shape_12 : memref<16xf32, #hivm.address_space<ub>>, memref<16xf32, #hivm.address_space<ub>>) outs(%35 : memref<16xf32, #hivm.address_space<ub>>)
      %36 = hivm.hir.pointer_cast(%c21120_i64) : memref<16x1xf32, #hivm.address_space<ub>>
      %collapse_shape_13 = memref.collapse_shape %36 [[0, 1]] : memref<16x1xf32, #hivm.address_space<ub>> into memref<16xf32, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vmul ins(%34, %cst_1 : memref<16xf32, #hivm.address_space<ub>>, f32) outs(%collapse_shape_13 : memref<16xf32, #hivm.address_space<ub>>)
      %37 = hivm.hir.get_block_idx -> i64
      %38 = arith.index_cast %37 : i64 to index
      %39 = affine.apply #map4(%38)
      %view_14 = memref.view %arg2[%39][] : memref<?xi8, #hivm.address_space<gm>> to memref<32x128xf32, #hivm.address_space<gm>>
      hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_S>] flag = 0
      %subview_15 = memref.subview %view_14[%5, 0] [16, 128] [1, 1] {to_be_bubbled_slice} : memref<32x128xf32, #hivm.address_space<gm>> to memref<16x128xf32, strided<[128, 1], offset: ?>, #hivm.address_space<gm>>
      %40 = hivm.hir.pointer_cast(%c21184_i64) : memref<16x128xf32, #hivm.address_space<ub>>
      %collapse_shape_16 = memref.collapse_shape %subview_15 [[0, 1]] : memref<16x128xf32, strided<[128, 1], offset: ?>, #hivm.address_space<gm>> into memref<2048xf32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %collapse_shape_17 = memref.collapse_shape %40 [[0, 1]] : memref<16x128xf32, #hivm.address_space<ub>> into memref<2048xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.load ins(%collapse_shape_16 : memref<2048xf32, strided<[1], offset: ?>, #hivm.address_space<gm>>) outs(%collapse_shape_17 : memref<2048xf32, #hivm.address_space<ub>>) {"inserted-load"} init_out_buffer = false may_implicit_transpose_with_last_axis = false core_type = <VECTOR>
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE2>, <PIPE_S>] flag = 4 ffts_base_addr = %arg0
      %41 = hivm.hir.pointer_cast(%c21184_i64) : memref<16x128xf32, #hivm.address_space<ub>>
      %42 = hivm.hir.pointer_cast(%c29376_i64) : memref<128xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vadd ins(%40, %36 : memref<16x128xf32, #hivm.address_space<ub>>, memref<16x1xf32, #hivm.address_space<ub>>) outs(%41 : memref<16x128xf32, #hivm.address_space<ub>>) temp_buffer(%42 : memref<128xf32, #hivm.address_space<ub>>) broadcast = [1]
      %43 = hivm.hir.pointer_cast(%c29888_i64) : memref<16xf32, #hivm.address_space<ub>>
      hivm.hir.vln ins(%35 : memref<16xf32, #hivm.address_space<ub>>) outs(%43 : memref<16xf32, #hivm.address_space<ub>>)
      %44 = hivm.hir.pointer_cast(%c29888_i64) : memref<16xf32, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vadd ins(%collapse_shape_5, %43 : memref<16xf32, #hivm.address_space<ub>>, memref<16xf32, #hivm.address_space<ub>>) outs(%44 : memref<16xf32, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      %expand_shape = memref.expand_shape %35 [[0, 1]] output_shape [16, 1] : memref<16xf32, #hivm.address_space<ub>> into memref<16x1xf32, #hivm.address_space<ub>>
      %45 = hivm.hir.pointer_cast(%c21184_i64) : memref<16x128xf32, #hivm.address_space<ub>>
      %46 = hivm.hir.pointer_cast(%c29952_i64) : memref<128xf32, #hivm.address_space<ub>>
      hivm.hir.vdiv ins(%41, %expand_shape : memref<16x128xf32, #hivm.address_space<ub>>, memref<16x1xf32, #hivm.address_space<ub>>) outs(%45 : memref<16x128xf32, #hivm.address_space<ub>>) temp_buffer(%46 : memref<128xf32, #hivm.address_space<ub>>) broadcast = [1]
      %47 = arith.muli %8, %c128_i32 : i32
      %48 = arith.index_cast %47 : i32 to index
      %49 = affine.apply #map6()[%48, %14]
      %reinterpret_cast_18 = memref.reinterpret_cast %arg6 to offset: [%49], sizes: [32], strides: [1] : memref<?xf32, #hivm.address_space<gm>> to memref<32xf32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %subview_19 = memref.subview %reinterpret_cast_18[%5] [16] [1] {to_be_bubbled_slice} : memref<32xf32, strided<[1], offset: ?>, #hivm.address_space<gm>> to memref<16xf32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%44 : memref<16xf32, #hivm.address_space<ub>>) outs(%subview_19 : memref<16xf32, strided<[1], offset: ?>, #hivm.address_space<gm>>) {tiled_op}
      %50 = hivm.hir.pointer_cast(%c21184_i64) : memref<16x128xf16, #hivm.address_space<ub>>
      %collapse_shape_20 = memref.collapse_shape %45 [[0, 1]] : memref<16x128xf32, #hivm.address_space<ub>> into memref<2048xf32, #hivm.address_space<ub>>
      %collapse_shape_21 = memref.collapse_shape %50 [[0, 1]] : memref<16x128xf16, #hivm.address_space<ub>> into memref<2048xf16, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_V>]
      hivm.hir.vcast ins(%collapse_shape_20 : memref<2048xf32, #hivm.address_space<ub>>) outs(%collapse_shape_21 : memref<2048xf16, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      %collapse_shape_22 = memref.collapse_shape %subview [[0, 1]] : memref<16x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<gm>> into memref<2048xf16, strided<[1], offset: ?>, #hivm.address_space<gm>>
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%collapse_shape_21 : memref<2048xf16, #hivm.address_space<ub>>) outs(%collapse_shape_22 : memref<2048xf16, strided<[1], offset: ?>, #hivm.address_space<gm>>) {tiled_op}
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    } {fixpipe_for_mmad_result_already_inserted = true}
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE2>, <PIPE_S>] flag = 3
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
}

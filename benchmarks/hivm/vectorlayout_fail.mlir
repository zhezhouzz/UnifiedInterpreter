module attributes {dlti.target_system_spec = #dlti.target_system_spec<"NPU" : #hacc.target_device_spec<#dlti.dl_entry<"AI_CORE_COUNT", 28 : i32>, #dlti.dl_entry<"CUBE_CORE_COUNT", 28 : i32>, #dlti.dl_entry<"VECTOR_CORE_COUNT", 56 : i32>, #dlti.dl_entry<"UB_SIZE", 2031616 : i32>, #dlti.dl_entry<"L1_SIZE", 4194304 : i32>, #dlti.dl_entry<"L0A_SIZE", 524288 : i32>, #dlti.dl_entry<"L0B_SIZE", 524288 : i32>, #dlti.dl_entry<"L0C_SIZE", 2097152 : i32>, #dlti.dl_entry<"UB_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L1_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L0C_ALIGN_SIZE", 4096 : i32>, #dlti.dl_entry<"MINIMAL_D_CACHE_SIZE", 262144 : i32>, #dlti.dl_entry<"MAXIMUM_D_CACHE_SIZE", 983040 : i32>, #dlti.dl_entry<"ARCH", "dav-c310">>>, hacc.target = #hacc.target<"Ascend950PR_9579">, ssbuffer.insertionOptimization} {
func.func @_prefill_bnsd_score_kernel_mix_aic(%arg0: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg1: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg5: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg6: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg7: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg8: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg9: memref<?xf32, #hivm.address_space<gm>> {tt.tensor_kind = 1 : i32}, %arg10: i32, %arg11: i32, %arg12: i32, %arg13: i32, %arg14: i32, %arg15: i32, %arg16: f32, %arg17: i32, %arg18: i32, %arg19: i32, %arg20: i32, %arg21: i32, %arg22: i32, %arg23: i32, %arg24: i32, %arg25: i32, %arg26: i32, %arg27: i32) attributes {DirectlyUsedGMArgIdxList = [9, 2], SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, func_dyn_memref_args = dense<[true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]> : vector<28xi1>, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<AIC>, hivm.part_of_mix, hivm.vf_mode = #hivm.vf_mode<MIX>, mix_mode = "mix", parallel_mode = "mix_simd_simt"} {
  %c1_i64 = arith.constant 1 : i64
  %c0_i64 = arith.constant 0 : i64
  %c3_i32 = arith.constant 3 : i32
  %c1 = arith.constant 1 : index
  %c2 = arith.constant 2 : index
  %c2_i64 = arith.constant 2 : i64
  %c16384_i64 = arith.constant 16384 : i64
  %c49152_i64 = arith.constant 49152 : i64
  %c0_i64_0 = arith.constant 0 : i64
  %c97536_i64 = arith.constant 97536 : i64
  %c54368_i64 = arith.constant 54368 : i64
  %c28_i32 = arith.constant 28 : i32
  %c1_i32 = arith.constant 1 : i32
  %true = arith.constant true
  %c64 = arith.constant 64 : index
  %c128 = arith.constant 128 : index
  %c127_i32 = arith.constant 127 : i32
  %c0_i32 = arith.constant 0 : i32
  %cst = arith.constant 0.000000e+00 : f16
  %c128_i32 = arith.constant 128 : i32
  %c0 = arith.constant 0 : index
  %0 = arith.muli %arg25, %arg26 : i32
  %1 = arith.muli %0, %arg27 : i32
  annotation.mark %1 {logical_block_num} : i32
  %2 = hivm.hir.get_block_idx -> i64
  %3 = arith.trunci %2 : i64 to i32
  %4 = arith.subi %arg15, %c1_i32 : i32
  hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 1
  hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 2
  hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
  hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
  scf.for %arg28 = %3 to %1 step %c28_i32  : i32 {
    hivm.hir.set_ctrl false at ctrl[60]
    hivm.hir.set_ctrl true at ctrl[48]
    %5 = arith.remsi %arg28, %arg25 : i32
    %6 = arith.divsi %arg28, %arg25 : i32
    %7 = arith.remsi %6, %arg26 : i32
    %8 = arith.remsi %5, %arg14 : i32
    %9 = arith.divsi %5, %arg14 : i32
    %10 = arith.index_cast %8 : i32 to index
    %reinterpret_cast = memref.reinterpret_cast %arg7 to offset: [%10], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
    %11 = memref.load %reinterpret_cast[%c0] : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
    %12 = arith.addi %11, %c127_i32 : i32
    %13 = arith.divsi %12, %c128_i32 : i32
    %14 = arith.addi %13, %4 : i32
    %15 = arith.divsi %14, %arg15 : i32
    %16 = arith.maxsi %15, %c1_i32 : i32
    %17 = arith.muli %9, %16 : i32
    %18 = arith.addi %17, %16 : i32
    %19 = arith.minsi %18, %13 : i32
    %20 = arith.cmpi sge, %17, %19 : i32
    scf.if %20 {
    } else {
      %21 = arith.subi %19, %17 : i32
      %22 = arith.muli %8, %arg22 : i32
      %23 = arith.extsi %arg19 : i32 to i64
      %24 = arith.muli %7, %arg21 : i32
      %25 = arith.index_cast %24 : i32 to index
      %26 = arith.addi %21, %c3_i32 : i32
      %27 = arith.cmpi sgt, %21, %c0_i32 : i32
      %28 = arith.select %27, %26, %c0_i32 : i32
      hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
      hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
      scf.for %arg29 = %c0_i32 to %28 step %c1_i32  : i32 {
        %29 = arith.subi %arg29, %c1_i32 : i32
        %30 = hivm.hir.multi_buffer_counter -> i64
        %31 = hivm.hir.multi_buffer_counter -> i64
        %32 = hivm.hir.multi_buffer_counter -> i64
        %33 = arith.remui %31, %c2_i64 : i64
        %34 = arith.index_cast %33 : i64 to index
        %35 = arith.addi %34, %c1 : index
        %36 = arith.remsi %35, %c2 : index
        %37 = arith.addi %36, %c1 : index
        %38 = arith.index_cast %37 : index to i64
        %39 = hivm.hir.pointer_cast(%c49152_i64, %c0_i64_0) : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        %40 = hivm.hir.pointer_cast(%c0_i64_0, %c49152_i64) : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        %41 = hivm.hir.pointer_cast(%c49152_i64, %c0_i64_0) : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        annotation.mark %41 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        annotation.mark %40 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        annotation.mark %39 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        %42 = hivm.hir.pointer_cast(%c97536_i64, %c54368_i64) : memref<32x128xf32, #hivm.address_space<ub>>
        %43 = hivm.hir.pointer_cast(%c54368_i64, %c97536_i64) : memref<32x128xf32, #hivm.address_space<ub>>
        %44 = hivm.hir.pointer_cast(%c97536_i64, %c54368_i64) : memref<32x128xf32, #hivm.address_space<ub>>
        annotation.mark %44 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x128xf32, #hivm.address_space<ub>>
        annotation.mark %43 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x128xf32, #hivm.address_space<ub>>
        annotation.mark %42 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x128xf32, #hivm.address_space<ub>>
        %45 = arith.cmpi sge, %arg29, %c0_i32 : i32
        %46 = arith.cmpi slt, %arg29, %21 : i32
        %47 = arith.andi %45, %46 : i1
        annotation.mark %47 {hivm.preload_num = 2 : i32} : i1
        scf.if %47 {
          annotation.mark %39 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<1>, hivm.tiling_dim = -1 : index} : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        }
        %48 = arith.cmpi sge, %29, %c0_i32 : i32
        %49 = arith.cmpi slt, %29, %21 : i32
        %50 = arith.andi %48, %49 : i1
        annotation.mark %50 {hivm.preload_num = 1 : i32} : i1
        scf.if %50 {
          %51 = arith.addi %17, %29 : i32
          %52 = arith.index_cast %22 : i32 to index
          %53 = arith.index_cast %51 : i32 to index
          %54 = affine.apply affine_map<()[s0, s1] -> (s0 + s1)>()[%52, %53]
          %reinterpret_cast_1 = memref.reinterpret_cast %arg4 to offset: [%54], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
          %55 = memref.load %reinterpret_cast_1[%c0] : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
          %56 = arith.extsi %55 : i32 to i64
          %57 = arith.muli %51, %c128_i32 : i32
          %58 = arith.muli %56, %23 : i64
          %59 = arith.index_cast %58 : i64 to index
          %60 = affine.apply affine_map<()[s0, s1] -> (s0 + s1)>()[%59, %25]
          %61 = arith.index_cast %arg20 : i32 to index
          %reinterpret_cast_2 = memref.reinterpret_cast %arg3 to offset: [%60], sizes: [128, 128], strides: [%61, 1] : memref<?xf16, #hivm.address_space<gm>> to memref<128x128xf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
          %62 = hivm.hir.pointer_cast(%c16384_i64) : memref<8x8x16x16xf16, #hivm.address_space<cbuf>>
          %cast = memref.cast %62 : memref<8x8x16x16xf16, #hivm.address_space<cbuf>> to memref<?x?x?x?xf16, #hivm.address_space<cbuf>>
          %63 = arith.index_cast %57 : i32 to index
          %64 = affine.apply affine_map<()[s0] -> (s0 + 128)>()[%63]
          %65 = arith.index_cast %11 : i32 to index
          %66 = arith.maxsi %63, %65 : index
          %67 = arith.minsi %64, %66 : index
          %68 = affine.apply affine_map<()[s0, s1] -> (s0 - s1)>()[%67, %63]
          %69 = arith.index_cast %arg13 : i32 to index
          %70 = arith.maxsi %69, %c0 : index
          %71 = arith.minsi %70, %c128 : index
          %72 = arith.minsi %68, %c128 : index
          %73 = arith.maxsi %72, %c0 : index
          %74 = arith.minsi %71, %c128 : index
          %75 = arith.maxsi %74, %c0 : index
          %76 = arith.cmpi slt, %73, %c128 : index
          %77 = arith.cmpi slt, %75, %c128 : index
          %78 = arith.ori %76, %77 : i1
          %subview = memref.subview %reinterpret_cast_2[0, 0] [%73, %75] [1, 1] : memref<128x128xf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
          %79 = affine.apply affine_map<()[s0] -> ((s0 + 15) floordiv 16)>()[%75]
          %80 = affine.apply affine_map<()[s0] -> ((s0 + 15) floordiv 16)>()[%73]
          %subview_3 = memref.subview %62[0, 0, 0, 0] [%79, %80, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
          %cast_4 = memref.cast %subview_3 : memref<?x?x16x16xf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>> to memref<?x?x?x?xf16, strided<[?, ?, ?, 1], offset: ?>, #hivm.address_space<cbuf>>
          scf.if %78 {
            hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
            %collapse_shape = memref.collapse_shape %62 [[0, 1, 2, 3]] : memref<8x8x16x16xf16, #hivm.address_space<cbuf>> into memref<16384xf16, #hivm.address_space<cbuf>>
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
            hivm.hir.vbrc ins(%cst : f16) outs(%collapse_shape : memref<16384xf16, #hivm.address_space<cbuf>>)
            hivm.hir.pipe_barrier[<PIPE_MTE2>]
          } {hivm.unlikely_condition}
          hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
          hivm.hir.nd2nz {dst_continuous} ins(%subview : memref<?x?xf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%cast_4 : memref<?x?x?x?xf16, strided<[?, ?, ?, 1], offset: ?>, #hivm.address_space<cbuf>>)
          hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
          %81 = hivm.hir.pointer_cast(%c0_i64_0) : memref<8x4x16x16xf32, #hivm.address_space<cc>>
          %cast_5 = memref.cast %81 : memref<8x4x16x16xf32, #hivm.address_space<cc>> to memref<?x?x?x?xf32, #hivm.address_space<cc>>
          hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 0
          hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
          %c-1_i64 = arith.constant -1 : i64
          hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%40, %cast, %true, %c64, %c128, %c128 : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>, memref<?x?x?x?xf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%cast_5 : memref<?x?x?x?xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %c1_i64, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
          hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
          hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %38
          annotation.mark %43 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>, hivm.tiling_dim = 0 : index, tiledAlloc} : memref<32x128xf32, #hivm.address_space<ub>>
          hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %38
          hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
          hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%81 : memref<8x4x16x16xf32, #hivm.address_space<cc>>) outs(%43 : memref<32x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
          hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
          hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 0
        }
      } {hivm.max_preload_num = 3 : i32}
      hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
    }
    hivm.hir.set_ctrl true at ctrl[60]
  } {autoblockify.subloop}
  hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
  hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
  hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = 1
  hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = 2
  hivm.hir.pipe_barrier[<PIPE_ALL>]
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv(%arg0: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg1: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg5: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg6: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg7: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg8: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg9: memref<?xf32, #hivm.address_space<gm>> {tt.tensor_kind = 1 : i32}, %arg10: i32, %arg11: i32, %arg12: i32, %arg13: i32, %arg14: i32, %arg15: i32, %arg16: f32, %arg17: i32, %arg18: i32, %arg19: i32, %arg20: i32, %arg21: i32, %arg22: i32, %arg23: i32, %arg24: i32, %arg25: i32, %arg26: i32, %arg27: i32) attributes {DirectlyUsedGMArgIdxList = [9, 2], SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, func_dyn_memref_args = dense<[true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]> : vector<28xi1>, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.part_of_mix, hivm.vf_mode = #hivm.vf_mode<MIX>, mix_mode = "mix", parallel_mode = "mix_simd_simt"} {
  %c2_i32 = arith.constant 2 : i32
  %c3_i32 = arith.constant 3 : i32
  %c1 = arith.constant 1 : index
  %c2 = arith.constant 2 : index
  %c2_i64 = arith.constant 2 : i64
  %c149536_i64 = arith.constant 149536 : i64
  %c149504_i64 = arith.constant 149504 : i64
  %c88544_i64 = arith.constant 88544 : i64
  %c149376_i64 = arith.constant 149376 : i64
  %c149248_i64 = arith.constant 149248 : i64
  %c88416_i64 = arith.constant 88416 : i64
  %c148992_i64 = arith.constant 148992 : i64
  %c148736_i64 = arith.constant 148736 : i64
  %c88160_i64 = arith.constant 88160 : i64
  %c132352_i64 = arith.constant 132352 : i64
  %c115968_i64 = arith.constant 115968 : i64
  %c71776_i64 = arith.constant 71776 : i64
  %c114944_i64 = arith.constant 114944 : i64
  %c113920_i64 = arith.constant 113920 : i64
  %c70752_i64 = arith.constant 70752 : i64
  %c97024_i64 = arith.constant 97024 : i64
  %c88576_i64 = arith.constant 88576 : i64
  %c49152_i64 = arith.constant 49152 : i64
  %c97536_i64 = arith.constant 97536 : i64
  %c54368_i64 = arith.constant 54368 : i64
  %c54336_i64 = arith.constant 54336 : i64
  %c46144_i64 = arith.constant 46144 : i64
  %c37952_i64 = arith.constant 37952 : i64
  %c33856_i64 = arith.constant 33856 : i64
  %c1088_i64 = arith.constant 1088 : i64
  %c1056_i64 = arith.constant 1056 : i64
  %c928_i64 = arith.constant 928 : i64
  %c896_i64 = arith.constant 896 : i64
  %c768_i64 = arith.constant 768 : i64
  %c640_i64 = arith.constant 640 : i64
  %c512_i64 = arith.constant 512 : i64
  %c0_i64 = arith.constant 0 : i64
  %c32_i32 = arith.constant 32 : i32
  %c128_i32 = arith.constant 128 : i32
  %c0_i32 = arith.constant 0 : i32
  %c127_i32 = arith.constant 127 : i32
  %c1_i32 = arith.constant 1 : i32
  %c28_i32 = arith.constant 28 : i32
  %c0 = arith.constant 0 : index
  %0 = arith.muli %arg25, %arg26 : i32
  %1 = arith.muli %0, %arg27 : i32
  %2 = hivm.hir.get_block_idx -> i64
  %3 = arith.trunci %2 : i64 to i32
  %4 = arith.subi %arg15, %c1_i32 : i32
  %5 = hivm.hir.get_sub_block_idx -> i64
  %6 = arith.index_cast %5 : i64 to index
  %7 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%6]
  %8 = affine.apply affine_map<()[s0] -> (s0 * 2)>()[%6]
  annotation.mark %1 {logical_block_num} : i32
  hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = 1
  hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = 2
  scf.for %arg28 = %3 to %1 step %c28_i32  : i32 {
    hivm.hir.set_ctrl false at ctrl[60]
    hivm.hir.set_ctrl true at ctrl[48]
    %9 = arith.remsi %arg28, %arg25 : i32
    %10 = arith.divsi %arg28, %arg25 : i32
    %11 = arith.remsi %10, %arg26 : i32
    %12 = arith.remsi %9, %arg14 : i32
    %13 = arith.divsi %9, %arg14 : i32
    %14 = arith.index_cast %12 : i32 to index
    %reinterpret_cast = memref.reinterpret_cast %arg7 to offset: [%14], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
    %15 = memref.load %reinterpret_cast[%c0] : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
    %16 = arith.addi %15, %c127_i32 : i32
    %17 = arith.divsi %16, %c128_i32 : i32
    %18 = arith.addi %17, %4 : i32
    %19 = arith.divsi %18, %arg15 : i32
    %20 = arith.maxsi %19, %c1_i32 : i32
    %21 = arith.muli %13, %20 : i32
    %22 = arith.addi %21, %20 : i32
    %23 = arith.minsi %22, %17 : i32
    %24 = arith.cmpi sge, %21, %23 : i32
    scf.if %24 {
    } else {
      %reinterpret_cast_0 = memref.reinterpret_cast %arg5 to offset: [%14], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %25 = memref.load %reinterpret_cast_0[%c0] : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_1 = memref.reinterpret_cast %arg6 to offset: [%14], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %26 = memref.load %reinterpret_cast_1[%c0] : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_2 = memref.reinterpret_cast %arg8 to offset: [%14], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %27 = memref.load %reinterpret_cast_2[%c0] : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %28 = hivm.hir.pointer_cast(%c0_i64) : memref<128xi32, #hivm.address_space<ub>>
      func.call @_prefill_bnsd_score_kernel_mix_aiv_outlined_vf_2(%28) {hivm.vector_function, no_inline} : (memref<128xi32, #hivm.address_space<ub>>) -> ()
      %29 = arith.muli %11, %arg12 : i32
      %30 = arith.muli %26, %c32_i32 : i32
      %31 = arith.addi %25, %30 : i32
      %32 = arith.subi %27, %c1_i32 : i32
      %33 = hivm.hir.pointer_cast(%c512_i64) : memref<32xi32, #hivm.address_space<ub>>
      %34 = hivm.hir.pointer_cast(%c640_i64) : memref<32xi32, #hivm.address_space<ub>>
      func.call @_prefill_bnsd_score_kernel_mix_aiv_fused_4_outlined_vf_0(%7, %31, %33, %34) {hivm.vector_function, no_inline} : (index, i32, memref<32xi32, #hivm.address_space<ub>>, memref<32xi32, #hivm.address_space<ub>>) -> ()
      %35 = hivm.hir.pointer_cast(%c768_i64) : memref<32xi32, #hivm.address_space<ub>>
      %36 = hivm.hir.pointer_cast(%c896_i64) : memref<32xi1, #hivm.address_space<ub>>
      %37 = hivm.hir.pointer_cast(%c928_i64) : memref<32xi32, #hivm.address_space<ub>>
      func.call @_prefill_bnsd_score_kernel_mix_aiv_fused_4_outlined_vf_1(%33, %29, %34, %27, %32, %25, %35, %36, %37) {hivm.vector_function, no_inline} : (memref<32xi32, #hivm.address_space<ub>>, i32, memref<32xi32, #hivm.address_space<ub>>, i32, i32, i32, memref<32xi32, #hivm.address_space<ub>>, memref<32xi1, #hivm.address_space<ub>>, memref<32xi32, #hivm.address_space<ub>>) -> ()
      hivm.hir.set_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
      %expand_shape = memref.expand_shape %37 [[0, 1]] output_shape [32, 1] : memref<32xi32, #hivm.address_space<ub>> into memref<32x1xi32, #hivm.address_space<ub>>
      %expand_shape_3 = memref.expand_shape %35 [[0, 1]] output_shape [32, 1] : memref<32xi32, #hivm.address_space<ub>> into memref<32x1xi32, #hivm.address_space<ub>>
      %expand_shape_4 = memref.expand_shape %28 [[0, 1]] output_shape [1, 128] : memref<128xi32, #hivm.address_space<ub>> into memref<1x128xi32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
      hivm.hir.debug {debugtype = "print", hex = false, memscope = #hivm.address_space<ub>, prefix = " q_token_flat: ", tcoretype = #hivm.tcore_type<VECTOR>, tiled_op} %37 : memref<32xi32, #hivm.address_space<ub>>
      %38 = hivm.hir.pointer_cast(%c1056_i64) : memref<1x256x1xi1, #hivm.address_space<ub>>
      %subview = memref.subview %38[0, 0, 0] [1, 128, 1] [1, 1, 1] : memref<1x256x1xi1, #hivm.address_space<ub>> to memref<1x128xi1, strided<[256, 1]>, #hivm.address_space<ub>>
      func.call @_prefill_bnsd_score_kernel_mix_aiv_outlined_vf_3(%expand_shape_4, %arg13, %subview) {hivm.vector_function, no_inline} : (memref<1x128xi32, #hivm.address_space<ub>>, i32, memref<1x128xi1, strided<[256, 1]>, #hivm.address_space<ub>>) -> ()
      %collapse_shape = memref.collapse_shape %subview [[0, 1]] : memref<1x128xi1, strided<[256, 1]>, #hivm.address_space<ub>> into memref<128xi1, strided<[1]>, #hivm.address_space<ub>>
      %39 = hivm.hir.pointer_cast(%c1088_i64) : memref<32x128xi64, #hivm.address_space<ub>>
      %40 = hivm.hir.pointer_cast(%c512_i64) : memref<32xi1, #hivm.address_space<ub>>
      func.call @_prefill_bnsd_score_kernel_mix_aiv_fused_6_outlined_merged_vf_0(%expand_shape, %expand_shape_3, %28, %arg18, %arg17, %39, %36, %33, %arg12, %40) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<32x1xi32, #hivm.address_space<ub>>, memref<32x1xi32, #hivm.address_space<ub>>, memref<128xi32, #hivm.address_space<ub>>, i32, i32, memref<32x128xi64, #hivm.address_space<ub>>, memref<32xi1, #hivm.address_space<ub>>, memref<32xi32, #hivm.address_space<ub>>, i32, memref<32xi1, #hivm.address_space<ub>>) -> ()
      %41 = hivm.hir.pointer_cast(%c33856_i64) : memref<32x128xi8, #hivm.address_space<ub>>
      %42 = hivm.hir.pointer_cast(%c37952_i64) : memref<32x128xf16, #hivm.address_space<ub>>
      func.call @_prefill_bnsd_score_kernel_mix_aiv_fused_5_outlined_merged_vf_0(%40, %collapse_shape, %41, %42) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<32xi1, #hivm.address_space<ub>>, memref<128xi1, strided<[1]>, #hivm.address_space<ub>>, memref<32x128xi8, #hivm.address_space<ub>>, memref<32x128xf16, #hivm.address_space<ub>>) -> ()
      %43 = hivm.hir.pointer_cast(%c46144_i64) : memref<32x128xf16, #hivm.address_space<ub>>
      hivm.hir.indirect_load ins(%arg2 : memref<?xf16, #hivm.address_space<gm>>, %39 : memref<32x128xi64, #hivm.address_space<ub>>, %41 : memref<32x128xi8, #hivm.address_space<ub>>, %42 : memref<32x128xf16, #hivm.address_space<ub>>) outs(%43 : memref<32x128xf16, #hivm.address_space<ub>>)
      %44 = hivm.hir.pointer_cast(%c54336_i64) : memref<1xf32, #hivm.address_space<ub>>
      memref.store %arg16, %44[%c0] : memref<1xf32, #hivm.address_space<ub>>
      hivm.hir.set_flag[<PIPE_S>, <PIPE_V>, <EVENT_ID0>]
      %45 = hivm.hir.pointer_cast(%c54336_i64) : memref<1xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_S>, <PIPE_V>, <EVENT_ID0>]
      func.call @_prefill_bnsd_score_kernel_mix_aiv_fused_7_outlined_vf_0(%44, %45) {hivm.vector_function, no_inline} : (memref<1xf32, #hivm.address_space<ub>>, memref<1xf32, #hivm.address_space<ub>>) -> ()
      hivm.hir.set_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
      %46 = memref.load %45[%c0] {"DuplicateTensorExtractForCube::visitedLabel" = 1 : i32} : memref<1xf32, #hivm.address_space<ub>>
      %47 = arith.subi %23, %21 : i32
      %48 = hivm.hir.pointer_cast(%c768_i64) : memref<32xi32, #hivm.address_space<ub>>
      func.call @_prefill_bnsd_score_kernel_mix_aiv_fused_8_outlined_vf_0(%35, %34, %arg24, %arg23, %48) {hivm.vector_function, no_inline} : (memref<32xi32, #hivm.address_space<ub>>, memref<32xi32, #hivm.address_space<ub>>, i32, i32, memref<32xi32, #hivm.address_space<ub>>) -> ()
      %49 = arith.addi %47, %c3_i32 : i32
      %50 = arith.cmpi sgt, %47, %c0_i32 : i32
      %51 = arith.select %50, %49, %c0_i32 : i32
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
      scf.for %arg29 = %c0_i32 to %51 step %c1_i32  : i32 {
        %52 = arith.subi %arg29, %c2_i32 : i32
        %53 = hivm.hir.multi_buffer_counter -> i64
        %54 = hivm.hir.multi_buffer_counter -> i64
        %55 = hivm.hir.multi_buffer_counter -> i64
        %56 = arith.remui %53, %c2_i64 : i64
        %57 = arith.remui %55, %c2_i64 : i64
        %58 = arith.index_cast %56 : i64 to index
        %59 = arith.index_cast %57 : i64 to index
        %60 = arith.remsi %58, %c2 : index
        %61 = arith.addi %60, %c1 : index
        %62 = arith.index_cast %61 : index to i64
        %63 = arith.addi %59, %c1 : index
        %64 = arith.index_cast %63 : index to i64
        %65 = hivm.hir.pointer_cast(%c88544_i64, %c149504_i64, %c149536_i64) : memref<32xi8, #hivm.address_space<ub>>
        %66 = hivm.hir.pointer_cast(%c149536_i64, %c88544_i64, %c149504_i64) : memref<32xi8, #hivm.address_space<ub>>
        %67 = hivm.hir.pointer_cast(%c149504_i64, %c149536_i64, %c88544_i64) : memref<32xi8, #hivm.address_space<ub>>
        annotation.mark %67 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32xi8, #hivm.address_space<ub>>
        annotation.mark %66 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32xi8, #hivm.address_space<ub>>
        annotation.mark %65 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32xi8, #hivm.address_space<ub>>
        %68 = hivm.hir.pointer_cast(%c88416_i64, %c149248_i64, %c149376_i64) : memref<32xf32, #hivm.address_space<ub>>
        %69 = hivm.hir.pointer_cast(%c149376_i64, %c88416_i64, %c149248_i64) : memref<32xf32, #hivm.address_space<ub>>
        %70 = hivm.hir.pointer_cast(%c149248_i64, %c149376_i64, %c88416_i64) : memref<32xf32, #hivm.address_space<ub>>
        annotation.mark %70 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32xf32, #hivm.address_space<ub>>
        annotation.mark %69 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32xf32, #hivm.address_space<ub>>
        annotation.mark %68 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32xf32, #hivm.address_space<ub>>
        %71 = hivm.hir.pointer_cast(%c88160_i64, %c148736_i64, %c148992_i64) : memref<32xi64, #hivm.address_space<ub>>
        %72 = hivm.hir.pointer_cast(%c148992_i64, %c88160_i64, %c148736_i64) : memref<32xi64, #hivm.address_space<ub>>
        %73 = hivm.hir.pointer_cast(%c148736_i64, %c148992_i64, %c88160_i64) : memref<32xi64, #hivm.address_space<ub>>
        annotation.mark %73 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32xi64, #hivm.address_space<ub>>
        annotation.mark %72 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32xi64, #hivm.address_space<ub>>
        annotation.mark %71 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32xi64, #hivm.address_space<ub>>
        %74 = hivm.hir.pointer_cast(%c71776_i64, %c115968_i64, %c132352_i64) : memref<32x128xi32, #hivm.address_space<ub>>
        %75 = hivm.hir.pointer_cast(%c132352_i64, %c71776_i64, %c115968_i64) : memref<32x128xi32, #hivm.address_space<ub>>
        %76 = hivm.hir.pointer_cast(%c115968_i64, %c132352_i64, %c71776_i64) : memref<32x128xi32, #hivm.address_space<ub>>
        annotation.mark %76 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x128xi32, #hivm.address_space<ub>>
        annotation.mark %75 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x128xi32, #hivm.address_space<ub>>
        annotation.mark %74 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x128xi32, #hivm.address_space<ub>>
        %77 = hivm.hir.pointer_cast(%c70752_i64, %c113920_i64, %c114944_i64) : memref<32x256x1xi1, #hivm.address_space<ub>>
        %78 = hivm.hir.pointer_cast(%c114944_i64, %c70752_i64, %c113920_i64) : memref<32x256x1xi1, #hivm.address_space<ub>>
        %79 = hivm.hir.pointer_cast(%c113920_i64, %c114944_i64, %c70752_i64) : memref<32x256x1xi1, #hivm.address_space<ub>>
        annotation.mark %79 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x256x1xi1, #hivm.address_space<ub>>
        annotation.mark %78 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x256x1xi1, #hivm.address_space<ub>>
        annotation.mark %77 {hivm.multi_buffer = 3 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x256x1xi1, #hivm.address_space<ub>>
        %80 = hivm.hir.pointer_cast(%c49152_i64, %c0_i64) : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        %81 = hivm.hir.pointer_cast(%c0_i64, %c49152_i64) : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        %82 = hivm.hir.pointer_cast(%c49152_i64, %c0_i64) : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        annotation.mark %82 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        annotation.mark %81 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        annotation.mark %80 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
        %83 = hivm.hir.pointer_cast(%c97536_i64, %c54368_i64) : memref<32x128xf32, #hivm.address_space<ub>>
        %84 = hivm.hir.pointer_cast(%c54368_i64, %c97536_i64) : memref<32x128xf32, #hivm.address_space<ub>>
        %85 = hivm.hir.pointer_cast(%c97536_i64, %c54368_i64) : memref<32x128xf32, #hivm.address_space<ub>>
        annotation.mark %85 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x128xf32, #hivm.address_space<ub>>
        annotation.mark %84 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x128xf32, #hivm.address_space<ub>>
        annotation.mark %83 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<32x128xf32, #hivm.address_space<ub>>
        annotation.mark %85 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>, hivm.tiling_dim = 0 : index, tiledAlloc} : memref<32x128xf32, #hivm.address_space<ub>>
        annotation.mark %84 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>, hivm.tiling_dim = 0 : index, tiledAlloc} : memref<32x128xf32, #hivm.address_space<ub>>
        annotation.mark %83 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>, hivm.tiling_dim = 0 : index, tiledAlloc} : memref<32x128xf32, #hivm.address_space<ub>>
        %subview_5 = memref.subview %80[0, %8, 0, 0] [8, 2, 16, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x4x16x16xf16, #hivm.address_space<cbuf>> to memref<8x2x16x16xf16, strided<[1024, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
        %86 = arith.cmpi sge, %arg29, %c0_i32 : i32
        %87 = arith.cmpi slt, %arg29, %47 : i32
        %88 = arith.andi %86, %87 : i1
        annotation.mark %88 {hivm.preload_num = 2 : i32} : i1
        scf.if %88 {
          %92 = arith.addi %21, %arg29 : i32
          %93 = arith.muli %92, %c128_i32 : i32
          %94 = hivm.hir.pointer_cast(%c88576_i64) : memref<8x33x16x1xf16, #hivm.address_space<ub>>
          %subview_7 = memref.subview %94[0, 0, 0, 0] [8, 32, 16, 1] [1, 1, 1, 1] : memref<8x33x16x1xf16, #hivm.address_space<ub>> to memref<8x32x16xf16, strided<[528, 16, 1]>, #hivm.address_space<ub>>
          %95 = hivm.hir.pointer_cast(%c97024_i64) : memref<128xi32, #hivm.address_space<ub>>
          hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
          func.call @_prefill_bnsd_score_kernel_mix_aiv_fused_1_outlined_merged_vf_0(%43, %subview_7, %28, %93, %95) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<32x128xf16, #hivm.address_space<ub>>, memref<8x32x16xf16, strided<[528, 16, 1]>, #hivm.address_space<ub>>, memref<128xi32, #hivm.address_space<ub>>, i32, memref<128xi32, #hivm.address_space<ub>>) -> ()
          hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
          %expand_shape_8 = memref.expand_shape %subview_7 [[0], [1, 2], [3]] output_shape [8, 2, 16, 16] : memref<8x32x16xf16, strided<[528, 16, 1]>, #hivm.address_space<ub>> into memref<8x2x16x16xf16, strided<[528, 256, 16, 1]>, #hivm.address_space<ub>>
          annotation.mark %80 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<1>, hivm.tiling_dim = 1 : index} : memref<8x4x16x16xf16, #hivm.address_space<cbuf>>
          %collapse_shape_9 = memref.collapse_shape %expand_shape_8 [[0], [1, 2, 3]] : memref<8x2x16x16xf16, strided<[528, 256, 16, 1]>, #hivm.address_space<ub>> into memref<8x512xf16, strided<[528, 1]>, #hivm.address_space<ub>>
          %collapse_shape_10 = memref.collapse_shape %subview_5 [[0], [1, 2, 3]] : memref<8x2x16x16xf16, strided<[1024, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x512xf16, strided<[1024, 1], offset: ?>, #hivm.address_space<cbuf>>
          hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %64
          hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
          hivm.hir.copy ins(%collapse_shape_9 : memref<8x512xf16, strided<[528, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_10 : memref<8x512xf16, strided<[1024, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
          hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
          hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 0
          %subview_11 = memref.subview %77[0, 0, 0] [32, 128, 1] [1, 1, 1] : memref<32x256x1xi1, #hivm.address_space<ub>> to memref<32x128xi1, strided<[256, 1]>, #hivm.address_space<ub>>
          func.call @_prefill_bnsd_score_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%34, %95, %15, %subview_11, %74, %48, %92, %71, %40, %68, %65) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<32xi32, #hivm.address_space<ub>>, memref<128xi32, #hivm.address_space<ub>>, i32, memref<32x128xi1, strided<[256, 1]>, #hivm.address_space<ub>>, memref<32x128xi32, #hivm.address_space<ub>>, memref<32xi32, #hivm.address_space<ub>>, i32, memref<32xi64, #hivm.address_space<ub>>, memref<32xi1, #hivm.address_space<ub>>, memref<32xf32, #hivm.address_space<ub>>, memref<32xi8, #hivm.address_space<ub>>) -> ()
        }
        %subview_6 = memref.subview %79[0, 0, 0] [32, 128, 1] [1, 1, 1] : memref<32x256x1xi1, #hivm.address_space<ub>> to memref<32x128xi1, strided<[256, 1]>, #hivm.address_space<ub>>
        %89 = arith.cmpi sge, %52, %c0_i32 : i32
        %90 = arith.cmpi slt, %52, %47 : i32
        %91 = arith.andi %89, %90 : i1
        annotation.mark %91 {hivm.preload_num = 0 : i32} : i1
        scf.if %91 {
          hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 0
          func.call @_prefill_bnsd_score_kernel_mix_aiv_fused_3_outlined_vf_0(%subview_6, %85, %46, %76, %70) {hivm.vector_function, no_inline} : (memref<32x128xi1, strided<[256, 1]>, #hivm.address_space<ub>>, memref<32x128xf32, #hivm.address_space<ub>>, f32, memref<32x128xi32, #hivm.address_space<ub>>, memref<32xf32, #hivm.address_space<ub>>) -> ()
          hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %62
          hivm.hir.indirect_store ins(%70 : memref<32xf32, #hivm.address_space<ub>>, %73 : memref<32xi64, #hivm.address_space<ub>>, %67 : memref<32xi8, #hivm.address_space<ub>>) outs(%arg9 : memref<?xf32, #hivm.address_space<gm>>)
        }
      } {hivm.max_preload_num = 3 : i32}
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
    }
    hivm.hir.set_ctrl true at ctrl[60]
  } {autoblockify.subloop}
  hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 1
  hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 2
  hivm.hir.pipe_barrier[<PIPE_ALL>]
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%arg0: memref<32xi32, #hivm.address_space<ub>>, %arg1: memref<128xi32, #hivm.address_space<ub>>, %arg2: i32, %arg3: memref<32x128xi1, strided<[256, 1]>, #hivm.address_space<ub>>, %arg4: memref<32x128xi32, #hivm.address_space<ub>>, %arg5: memref<32xi32, #hivm.address_space<ub>>, %arg6: i32, %arg7: memref<32xi64, #hivm.address_space<ub>>, %arg8: memref<32xi1, #hivm.address_space<ub>>, %arg9: memref<32xf32, #hivm.address_space<ub>>, %arg10: memref<32xi8, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function} {
  %cst = arith.constant dense<0xFF800000> : vector<64xf32>
  %false = arith.constant false
  %cst_0 = arith.constant dense<2147483647> : vector<1x64xi32>
  %cst_1 = arith.constant dense<0.000000e+00> : vector<1x64xf16>
  %cst_2 = arith.constant dense<-1.000000e+00> : vector<1x64xf16>
  %c0_i32 = arith.constant 0 : i32
  %c1 = arith.constant 1 : index
  %c32 = arith.constant 32 : index
  %c64 = arith.constant 64 : index
  %c128 = arith.constant 128 : index
  %c0 = arith.constant 0 : index
  %0 = vector.broadcast %arg2 : i32 to vector<1x64xi32>
  scf.for %arg11 = %c0 to %c32 step %c1 {
    %subview = memref.subview %arg0[%arg11] [1] [1] : memref<32xi32, #hivm.address_space<ub>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>
    %8 = vector.transfer_read %subview[%c0], %c0_i32 {in_bounds = [true, true], permutation_map = affine_map<(d0) -> (d0, 0)>} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xi32>
    scf.for %arg12 = %c0 to %c128 step %c64 {
      %subview_3 = memref.subview %arg1[%arg12] [64] [1] : memref<128xi32, #hivm.address_space<ub>> to memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %9 = vector.transfer_read %subview_3[%c0], %c0_i32 {in_bounds = [true, true], permutation_map = affine_map<(d0) -> (0, d0)>} : memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xi32>
      %10 = arith.cmpi sge, %8, %9 : vector<1x64xi32>
      %11 = arith.cmpi slt, %9, %0 : vector<1x64xi32>
      %12 = arith.select %11, %cst_2, %cst_1 : vector<1x64xi1>, vector<1x64xf16>
      %13 = arith.cmpf une, %12, %cst_1 : vector<1x64xf16>
      %subview_4 = memref.subview %arg3[%arg11, %arg12] [1, 64] [1, 1] : memref<32x128xi1, strided<[256, 1]>, #hivm.address_space<ub>> to memref<1x64xi1, strided<[256, 1], offset: ?>, #hivm.address_space<ub>>
      %14 = arith.andi %10, %13 : vector<1x64xi1>
      vector.transfer_write %14, %subview_4[%c0, %c0] {in_bounds = [true, true]} : vector<1x64xi1>, memref<1x64xi1, strided<[256, 1], offset: ?>, #hivm.address_space<ub>>
    }
  }
  scf.for %arg11 = %c0 to %c32 step %c1 {
    scf.for %arg12 = %c0 to %c128 step %c64 {
      %subview = memref.subview %arg4[%arg11, %arg12] [1, 64] [1, 1] : memref<32x128xi32, #hivm.address_space<ub>> to memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      vector.transfer_write %cst_0, %subview[%c0, %c0] {in_bounds = [true, true]} : vector<1x64xi32>, memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
    }
  }
  %1 = vector.constant_mask [32] : vector<64xi1>
  %2 = vector.transfer_read %arg5[%c0], %c0_i32, %1 {in_bounds = [true]} : memref<32xi32, #hivm.address_space<ub>>, vector<64xi32>
  %3 = vector.broadcast %arg6 : i32 to vector<64xi32>
  %4 = arith.addi %2, %3 : vector<64xi32>
  %5 = arith.extsi %4 {round_mode = #hfusion.round_mode<rint>} : vector<64xi32> to vector<64xi64>
  vector.transfer_write %5, %arg7[%c0], %1 {in_bounds = [true]} : vector<64xi64>, memref<32xi64, #hivm.address_space<ub>>
  vector.transfer_write %cst, %arg9[%c0], %1 {in_bounds = [true]} : vector<64xf32>, memref<32xf32, #hivm.address_space<ub>>
  %6 = vector.transfer_read %arg8[%c0], %false, %1 {in_bounds = [true]} : memref<32xi1, #hivm.address_space<ub>>, vector<64xi1>
  %7 = arith.extui %6 {round_mode = #hfusion.round_mode<rint>} : vector<64xi1> to vector<64xi8>
  vector.transfer_write %7, %arg10[%c0], %1 {in_bounds = [true]} : vector<64xi8>, memref<32xi8, #hivm.address_space<ub>>
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_fused_1_outlined_merged_vf_0(%arg0: memref<32x128xf16, #hivm.address_space<ub>>, %arg1: memref<8x32x16xf16, strided<[528, 16, 1]>, #hivm.address_space<ub>>, %arg2: memref<128xi32, #hivm.address_space<ub>>, %arg3: i32, %arg4: memref<128xi32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function} {
  %c128 = arith.constant 128 : index
  %c64 = arith.constant 64 : index
  %c0_i32 = arith.constant 0 : i32
  %cst = arith.constant 0.000000e+00 : f16
  %c1 = arith.constant 1 : index
  %c32 = arith.constant 32 : index
  %c0 = arith.constant 0 : index
  scf.for %arg5 = %c0 to %c32 step %c1 {
    %subview = memref.subview %arg0[%arg5, 0] [1, 128] [1, 1] : memref<32x128xf16, #hivm.address_space<ub>> to memref<1x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
    %subview_0 = memref.subview %arg1[0, %arg5, 0] [8, 1, 16] [1, 1, 1] : memref<8x32x16xf16, strided<[528, 16, 1]>, #hivm.address_space<ub>> to memref<8x1x16xf16, strided<[528, 16, 1], offset: ?>, #hivm.address_space<ub>>
    %1 = vector.transfer_read %subview[%c0, %c0], %cst {in_bounds = [true, true]} : memref<1x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>, vector<1x128xf16>
    %2 = vector.shape_cast %1 : vector<1x128xf16> to vector<8x1x16xf16>
    vector.transfer_write %2, %subview_0[%c0, %c0, %c0] {in_bounds = [true, true, true]} : vector<8x1x16xf16>, memref<8x1x16xf16, strided<[528, 16, 1], offset: ?>, #hivm.address_space<ub>>
  }
  %0 = vector.broadcast %arg3 : i32 to vector<64xi32>
  scf.for %arg5 = %c0 to %c128 step %c64 {
    %subview = memref.subview %arg2[%arg5] [64] [1] : memref<128xi32, #hivm.address_space<ub>> to memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>
    %subview_0 = memref.subview %arg4[%arg5] [64] [1] : memref<128xi32, #hivm.address_space<ub>> to memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>
    %1 = vector.transfer_read %subview[%c0], %c0_i32 {in_bounds = [true]} : memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<64xi32>
    %2 = arith.addi %1, %0 : vector<64xi32>
    vector.transfer_write %2, %subview_0[%c0] {in_bounds = [true]} : vector<64xi32>, memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>
  }
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_fused_3_outlined_vf_0(%arg0: memref<32x128xi1, strided<[256, 1]>, #hivm.address_space<ub>>, %arg1: memref<32x128xf32, #hivm.address_space<ub>>, %arg2: f32, %arg3: memref<32x128xi32, #hivm.address_space<ub>>, %arg4: memref<32xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
  %cst = arith.constant dense<0> : vector<1x64xi32>
  %cst_0 = arith.constant dense<1> : vector<1x64xi32>
  %cst_1 = arith.constant dense<-2139095040> : vector<1x64xi32>
  %c0_i32 = arith.constant 0 : i32
  %cst_2 = arith.constant 0.000000e+00 : f32
  %false = arith.constant false
  %cst_3 = arith.constant dense<0xFF800000> : vector<1x64xf32>
  %c1 = arith.constant 1 : index
  %c32 = arith.constant 32 : index
  %c64 = arith.constant 64 : index
  %c128 = arith.constant 128 : index
  %c0 = arith.constant 0 : index
  %0 = vector.broadcast %arg2 : f32 to vector<1x64xf32>
  scf.for %arg5 = %c0 to %c32 step %c1 {
    %subview = memref.subview %arg4[%arg5] [1] [1] : memref<32xf32, #hivm.address_space<ub>> to memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
    %1 = scf.for %arg6 = %c0 to %c128 step %c64 iter_args(%arg7 = %cst_3) -> (vector<1x64xf32>) {
      %subview_4 = memref.subview %arg0[%arg5, %arg6] [1, 64] [1, 1] : memref<32x128xi1, strided<[256, 1]>, #hivm.address_space<ub>> to memref<1x64xi1, strided<[256, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_5 = memref.subview %arg1[%arg5, %arg6] [1, 64] [1, 1] : memref<32x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %4 = vector.transfer_read %subview_4[%c0, %c0], %false {in_bounds = [true, true]} : memref<1x64xi1, strided<[256, 1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xi1>
      %5 = vector.transfer_read %subview_5[%c0, %c0], %cst_2 {in_bounds = [true, true]} : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xf32>
      %6 = arith.mulf %5, %0 : vector<1x64xf32>
      %7 = arith.select %4, %6, %cst_3 : vector<1x64xi1>, vector<1x64xf32>
      %8 = arith.bitcast %7 : vector<1x64xf32> to vector<1x64xi32>
      %subview_6 = memref.subview %arg3[%arg5, %arg6] [1, 64] [1, 1] : memref<32x128xi32, #hivm.address_space<ub>> to memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %9 = vector.transfer_read %subview_6[%c0, %c0], %c0_i32 {in_bounds = [true, true]} : memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xi32>
      %10 = arith.andi %8, %9 : vector<1x64xi32>
      %11 = arith.addi %10, %cst_1 : vector<1x64xi32>
      %12 = arith.minsi %11, %cst_0 : vector<1x64xi32>
      %13 = arith.maxsi %12, %cst : vector<1x64xi32>
      %14 = arith.cmpi ne, %13, %cst : vector<1x64xi32>
      %15 = arith.select %14, %cst_3, %7 : vector<1x64xi1>, vector<1x64xf32>
      %16 = arith.maximumf %15, %arg7 {reductionOp} : vector<1x64xf32>
      scf.yield %16 : vector<1x64xf32>
    } {reductionLoop}
    %2 = vector.transfer_read %subview[%c0], %cst_2 {in_bounds = [true]} : memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<1xf32>
    %3 = vector.multi_reduction <maximumf>, %1, %2 {withoutInitMergeOp} [1] : vector<1x64xf32> to vector<1xf32>
    vector.transfer_write %3, %subview[%c0] {in_bounds = [true]} : vector<1xf32>, memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
  }
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_fused_4_outlined_vf_0(%arg0: index, %arg1: i32, %arg2: memref<32xi32, #hivm.address_space<ub>>, %arg3: memref<32xi32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
  %cst = arith.constant dense<0> : vector<64xindex>
  %cst_0 = arith.constant dense<[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63]> : vector<64xindex>
  %cst_1 = arith.constant dense<1> : vector<64xi32>
  %cst_2 = arith.constant dense<31> : vector<64xi32>
  %c0 = arith.constant 0 : index
  %0 = vector.constant_mask [32] : vector<64xi1>
  %1 = vector.broadcast %arg0 : index to vector<64xindex>
  %2 = arith.addi %1, %cst_0 : vector<64xindex>
  %3 = arith.index_cast %2 : vector<64xindex> to vector<64xi32>
  %4 = arith.shrsi %3, %cst_2 : vector<64xi32>
  %5 = arith.andi %4, %cst_1 : vector<64xi32>
  %6 = arith.addi %3, %5 : vector<64xi32>
  %7 = arith.andi %6, %cst_1 : vector<64xi32>
  %8 = arith.addi %cst, %cst_0 : vector<64xindex>
  %9 = arith.addi %8, %1 : vector<64xindex>
  %10 = arith.index_cast %9 : vector<64xindex> to vector<64xi32>
  %11 = arith.shrsi %10, %cst_2 : vector<64xi32>
  %12 = arith.andi %11, %cst_1 : vector<64xi32>
  %13 = arith.subi %7, %12 : vector<64xi32>
  vector.transfer_write %13, %arg2[%c0], %0 {in_bounds = [true]} : vector<64xi32>, memref<32xi32, #hivm.address_space<ub>>
  %14 = arith.shrsi %6, %cst_1 : vector<64xi32>
  %15 = vector.broadcast %arg1 : i32 to vector<64xi32>
  %16 = arith.addi %14, %15 : vector<64xi32>
  vector.transfer_write %16, %arg3[%c0], %0 {in_bounds = [true]} : vector<64xi32>, memref<32xi32, #hivm.address_space<ub>>
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_fused_4_outlined_vf_1(%arg0: memref<32xi32, #hivm.address_space<ub>>, %arg1: i32, %arg2: memref<32xi32, #hivm.address_space<ub>>, %arg3: i32, %arg4: i32, %arg5: i32, %arg6: memref<32xi32, #hivm.address_space<ub>>, %arg7: memref<32xi1, #hivm.address_space<ub>>, %arg8: memref<32xi32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
  %c0_i32 = arith.constant 0 : i32
  %c0 = arith.constant 0 : index
  %0 = vector.constant_mask [32] : vector<64xi1>
  %1 = vector.transfer_read %arg0[%c0], %c0_i32, %0 {in_bounds = [true]} : memref<32xi32, #hivm.address_space<ub>>, vector<64xi32>
  %2 = vector.broadcast %arg1 : i32 to vector<64xi32>
  %3 = arith.addi %1, %2 : vector<64xi32>
  vector.transfer_write %3, %arg6[%c0], %0 {in_bounds = [true]} : vector<64xi32>, memref<32xi32, #hivm.address_space<ub>>
  %4 = vector.transfer_read %arg2[%c0], %c0_i32, %0 {in_bounds = [true]} : memref<32xi32, #hivm.address_space<ub>>, vector<64xi32>
  %5 = vector.broadcast %arg3 : i32 to vector<64xi32>
  %6 = arith.cmpi slt, %4, %5 : vector<64xi32>
  vector.transfer_write %6, %arg7[%c0], %0 {in_bounds = [true]} : vector<64xi1>, memref<32xi1, #hivm.address_space<ub>>
  %7 = vector.broadcast %arg4 : i32 to vector<64xi32>
  %8 = arith.minsi %4, %7 : vector<64xi32>
  %9 = vector.broadcast %arg5 : i32 to vector<64xi32>
  %10 = arith.maxsi %8, %9 : vector<64xi32>
  vector.transfer_write %10, %arg8[%c0], %0 {in_bounds = [true]} : vector<64xi32>, memref<32xi32, #hivm.address_space<ub>>
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_fused_5_outlined_merged_vf_0(%arg0: memref<32xi1, #hivm.address_space<ub>>, %arg1: memref<128xi1, strided<[1]>, #hivm.address_space<ub>>, %arg2: memref<32x128xi8, #hivm.address_space<ub>>, %arg3: memref<32x128xf16, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function} {
  %c8_i32 = arith.constant 8 : i32
  %c256_i32 = arith.constant 256 : i32
  %c0 = arith.constant 0 : index
  %c32 = arith.constant 32 : index
  %c1 = arith.constant 1 : index
  %cst = arith.constant -1.000000e+00 : f16
  %cst_0 = arith.constant 1.000000e+00 : f16
  %cst_1 = arith.constant 0.000000e+00 : f16
  %c1_i8 = arith.constant 1 : i8
  %c0_i8 = arith.constant 0 : i8
  %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
  %1 = ave.hir.broadcast %c0_i8, %0 : i8, vector<128xi1> -> vector<128xi8>
  %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
  %3 = ave.hir.broadcast %c1_i8, %2 : i8, vector<128xi1> -> vector<128xi8>
  %4 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<1xi1>
  %5 = ave.hir.broadcast %cst_1, %4 : f16, vector<1xi1> -> vector<1xf16>
  %6 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<1xi1>
  %7 = ave.hir.broadcast %cst_0, %6 : f16, vector<1xi1> -> vector<1xf16>
  %8 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
  %9 = ave.hir.broadcast %cst_1, %8 : f16, vector<128xi1> -> vector<128xf16>
  %10 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
  %11 = ave.hir.broadcast %cst, %10 : f16, vector<128xi1> -> vector<128xf16>
  %res = ave.hir.vload <NORM> %arg1[%c0] {functionType = #ave.func_dist_type<pb32>} : memref<128xi1, strided<[1]>, #hivm.address_space<ub>> into vector<128xi1>
  %12 = ave.hir.vsel %res, %11, %9 : vector<128xi1>, vector<128xf16>
  %13 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
  %14 = ave.hir.vcmp <NE> %12, %9, %13 : vector<128xf16>, vector<128xi1> -> vector<128xi1>
  scf.for %arg4 = %c0 to %c32 step %c1 {
    %base_buffer, %offset, %sizes, %strides = memref.extract_strided_metadata %arg0 : memref<32xi1, #hivm.address_space<ub>> -> memref<i1, #hivm.address_space<ub>>, index, index, index
    %reinterpret_cast = memref.reinterpret_cast %base_buffer to offset: [%c0], sizes: [1], strides: [1] : memref<i1, #hivm.address_space<ub>> to memref<1xi1, strided<[1], offset: ?>, #hivm.address_space<ub>>
    %15 = arith.index_cast %arg4 : index to i32
    %16 = arith.divsi %15, %c256_i32 : i32
    %17 = arith.muli %16, %c256_i32 : i32
    %18 = arith.subi %15, %17 : i32
    %19 = arith.divsi %17, %c8_i32 : i32
    %20 = arith.index_cast %19 : i32 to index
    %21 = arith.index_cast %18 : i32 to index
    %res_2 = ave.hir.vload <NORM> %reinterpret_cast[%20] {"1xi1 processed", functionType = #ave.func_dist_type<pb8>} : memref<1xi1, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<1xi1>
    %22 = builtin.unrealized_conversion_cast %res_2 : vector<1xi1> to vector<256xi1>
    %23 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb8>} : vector<256xi1>
    %24 = ave.hir.scalar_broadcast %c0_i8 : i8 -> vector<256xi8>
    %25 = ave.hir.scalar_broadcast %c1_i8 : i8 -> vector<256xi8>
    %26 = ave.hir.vsel %22, %25, %24 : vector<256xi1>, vector<256xi8>
    %27 = arith.addi %21, %c1 : index
    %res_3, %new_true_shape = ave.hir.plt %27 {functionType = #ave.func_dist_type<pb8>} : vector<256xi1>, index
    %res_4, %new_true_shape_5 = ave.hir.plt %21 {functionType = #ave.func_dist_type<pb8>} : vector<256xi1>, index
    %28 = ave.hir.preg.xor <b8> %res_3, %res_4, %23 : vector<256xi1>
    %29 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb8>} : vector<256xi1>
    %30 = ave.hir.broadcast %c0_i8, %29 : i8, vector<256xi1> -> vector<256xi8>
    %31 = ave.hir.vor %26, %30, %28 : vector<256xi8>, vector<256xi1>
    %32 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb8>} : vector<256xi1>
    %res1, %res2 = ave.hir.vintlv %31, %30 {layout_change = #ave<layout_change UNCHANGED>} : vector<256xi8>, vector<256xi8>
    %33 = ave.hir.vxor %res1, %res2, %32 : vector<256xi8>, vector<256xi1>
    %res1_6, %res2_7 = ave.hir.vintlv %33, %30 {layout_change = #ave<layout_change UNCHANGED>} : vector<256xi8>, vector<256xi8>
    %34 = ave.hir.vxor %res1_6, %res2_7, %32 : vector<256xi8>, vector<256xi1>
    %res1_8, %res2_9 = ave.hir.vintlv %34, %30 {layout_change = #ave<layout_change UNCHANGED>} : vector<256xi8>, vector<256xi8>
    %35 = ave.hir.vxor %res1_8, %res2_9, %32 : vector<256xi8>, vector<256xi1>
    %res1_10, %res2_11 = ave.hir.vintlv %35, %30 {layout_change = #ave<layout_change UNCHANGED>} : vector<256xi8>, vector<256xi8>
    %36 = ave.hir.vxor %res1_10, %res2_11, %32 : vector<256xi8>, vector<256xi1>
    %res1_12, %res2_13 = ave.hir.vintlv %36, %30 {layout_change = #ave<layout_change UNCHANGED>} : vector<256xi8>, vector<256xi8>
    %37 = ave.hir.vxor %res1_12, %res2_13, %32 : vector<256xi8>, vector<256xi1>
    %res1_14, %res2_15 = ave.hir.vintlv %37, %30 {layout_change = #ave<layout_change UNCHANGED>} : vector<256xi8>, vector<256xi8>
    %38 = ave.hir.vxor %res1_14, %res2_15, %32 : vector<256xi8>, vector<256xi1>
    %res1_16, %res2_17 = ave.hir.vintlv %38, %30 {layout_change = #ave<layout_change UNCHANGED>} : vector<256xi8>, vector<256xi8>
    %39 = ave.hir.vxor %res1_16, %res2_17, %32 : vector<256xi8>, vector<256xi1>
    %res1_18, %res2_19 = ave.hir.vintlv %39, %30 {layout_change = #ave<layout_change UNCHANGED>} : vector<256xi8>, vector<256xi8>
    %40 = ave.hir.vxor %res1_18, %res2_19, %32 : vector<256xi8>, vector<256xi1>
    %41 = ave.hir.vector_broadcast %40, %23, true : vector<256xi8>, vector<256xi1> -> vector<256xi8>
    %42 = ave.hir.vcmp <NE> %41, %24, %23 : vector<256xi8>, vector<256xi1> -> vector<256xi1>
    %43 = ave.hir.vector.layout_cast %42 : vector<256xi1> -> vector<256xi1>
    %44 = ave.hir.vector.layout_cast %43 {functionType = #ave.func_dist_type<dintlv4>} : vector<256xi1> -> vector<256xi1>
    %45 = builtin.unrealized_conversion_cast %44 : vector<256xi1> to vector<1xi1>
    %46 = ave.hir.vsel %45, %7, %5 : vector<1xi1>, vector<1xf16>
    %47 = builtin.unrealized_conversion_cast %46 : vector<1xf16> to vector<128xf16>
    %48 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
    %49 = ave.hir.vector_broadcast %47, %48, true : vector<128xf16>, vector<128xi1> -> vector<128xf16>
    %50 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
    %51 = ave.hir.vcmp <NE> %49, %9, %50 : vector<128xf16>, vector<128xi1> -> vector<128xi1>
    %52 = ave.hir.vsel %51, %11, %9 : vector<128xi1>, vector<128xf16>
    %53 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
    %54 = ave.hir.vcmp <NE> %52, %9, %53 : vector<128xf16>, vector<128xi1> -> vector<128xi1>
    %55 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
    %56 = ave.hir.preg.and <b8> %54, %14, %55 : vector<128xi1>
    %subview = memref.subview %arg2[%arg4, 0] [1, 128] [1, 1] : memref<32x128xi8, #hivm.address_space<ub>> to memref<1x128xi8, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
    %57 = ave.hir.vsel %56, %3, %1 : vector<128xi1>, vector<128xi8>
    %subview_20 = memref.subview %subview[0, 0] [1, 128] [1, 1] : memref<1x128xi8, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<128xi8, affine_map<(d0)[s0] -> (d0 + s0)>, #hivm.address_space<ub>>
    %58 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
    ave.hir.masked_store <NORM_B8> %subview_20[%c0], %58, %57 {functionType = #ave.func_dist_type<pk4>, hivm.is_continuous} : memref<128xi8, affine_map<(d0)[s0] -> (d0 + s0)>, #hivm.address_space<ub>>, vector<128xi1>, vector<128xi8>
  }
  scf.for %arg4 = %c0 to %c32 step %c1 {
    %subview = memref.subview %arg3[%arg4, 0] [1, 128] [1, 1] : memref<32x128xf16, #hivm.address_space<ub>> to memref<1x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
    %subview_2 = memref.subview %subview[0, 0] [1, 128] [1, 1] : memref<1x128xf16, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<128xf16, affine_map<(d0)[s0] -> (d0 + s0)>, #hivm.address_space<ub>>
    %15 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<128xi1>
    ave.hir.masked_store <NORM_B16> %subview_2[%c0], %15, %9 {functionType = #ave.func_dist_type<pk>, hivm.is_continuous} : memref<128xf16, affine_map<(d0)[s0] -> (d0 + s0)>, #hivm.address_space<ub>>, vector<128xi1>, vector<128xf16>
  }
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_fused_6_outlined_merged_vf_0(%arg0: memref<32x1xi32, #hivm.address_space<ub>>, %arg1: memref<32x1xi32, #hivm.address_space<ub>>, %arg2: memref<128xi32, #hivm.address_space<ub>>, %arg3: i32, %arg4: i32, %arg5: memref<32x128xi64, #hivm.address_space<ub>>, %arg6: memref<32xi1, #hivm.address_space<ub>>, %arg7: memref<32xi32, #hivm.address_space<ub>>, %arg8: i32, %arg9: memref<32xi1, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function} {
  %false = arith.constant false
  %c0_i32 = arith.constant 0 : i32
  %c1 = arith.constant 1 : index
  %c32 = arith.constant 32 : index
  %c64 = arith.constant 64 : index
  %c128 = arith.constant 128 : index
  %c0 = arith.constant 0 : index
  %0 = vector.broadcast %arg3 : i32 to vector<1x64xi32>
  %1 = vector.broadcast %arg4 : i32 to vector<1x64xi32>
  scf.for %arg10 = %c0 to %c32 step %c1 {
    %subview = memref.subview %arg0[%arg10, 0] [1, 1] [1, 1] : memref<32x1xi32, #hivm.address_space<ub>> to memref<1x1xi32, strided<[1, 1], offset: ?>, #hivm.address_space<ub>>
    %subview_0 = memref.subview %arg1[%arg10, 0] [1, 1] [1, 1] : memref<32x1xi32, #hivm.address_space<ub>> to memref<1x1xi32, strided<[1, 1], offset: ?>, #hivm.address_space<ub>>
    %8 = vector.transfer_read %subview[%c0, %c0], %c0_i32 {in_bounds = [true, true], permutation_map = affine_map<(d0, d1) -> (d0, 0)>} : memref<1x1xi32, strided<[1, 1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xi32>
    %9 = vector.transfer_read %subview_0[%c0, %c0], %c0_i32 {in_bounds = [true, true], permutation_map = affine_map<(d0, d1) -> (d0, 0)>} : memref<1x1xi32, strided<[1, 1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xi32>
    %10 = arith.muli %9, %0 : vector<1x64xi32>
    %11 = arith.muli %8, %1 : vector<1x64xi32>
    %12 = arith.addi %11, %10 : vector<1x64xi32>
    scf.for %arg11 = %c0 to %c128 step %c64 {
      %subview_1 = memref.subview %arg2[%arg11] [64] [1] : memref<128xi32, #hivm.address_space<ub>> to memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %subview_2 = memref.subview %arg5[%arg10, %arg11] [1, 64] [1, 1] : memref<32x128xi64, #hivm.address_space<ub>> to memref<1x64xi64, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %13 = vector.transfer_read %subview_1[%c0], %c0_i32 {in_bounds = [true, true], permutation_map = affine_map<(d0) -> (0, d0)>} : memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xi32>
      %14 = arith.addi %12, %13 : vector<1x64xi32>
      %15 = arith.extsi %14 {round_mode = #hfusion.round_mode<rint>} : vector<1x64xi32> to vector<1x64xi64>
      vector.transfer_write %15, %subview_2[%c0, %c0] {in_bounds = [true, true]} : vector<1x64xi64>, memref<1x64xi64, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
    }
  }
  %2 = vector.constant_mask [32] : vector<64xi1>
  %3 = vector.transfer_read %arg7[%c0], %c0_i32, %2 {in_bounds = [true]} : memref<32xi32, #hivm.address_space<ub>>, vector<64xi32>
  %4 = vector.broadcast %arg8 : i32 to vector<64xi32>
  %5 = arith.cmpi slt, %3, %4 : vector<64xi32>
  %6 = vector.transfer_read %arg6[%c0], %false, %2 {in_bounds = [true]} : memref<32xi1, #hivm.address_space<ub>>, vector<64xi1>
  %7 = arith.andi %6, %5 : vector<64xi1>
  vector.transfer_write %7, %arg9[%c0], %2 {in_bounds = [true]} : vector<64xi1>, memref<32xi1, #hivm.address_space<ub>>
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_fused_7_outlined_vf_0(%arg0: memref<1xf32, #hivm.address_space<ub>>, %arg1: memref<1xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
  %cst = arith.constant dense<1.44269502> : vector<64xf32>
  %cst_0 = arith.constant 0.000000e+00 : f32
  %c0 = arith.constant 0 : index
  %0 = vector.constant_mask [1] : vector<64xi1>
  %1 = vector.transfer_read %arg0[%c0], %cst_0, %0 {in_bounds = [true]} : memref<1xf32, #hivm.address_space<ub>>, vector<64xf32>
  %2 = arith.mulf %1, %cst : vector<64xf32>
  vector.transfer_write %2, %arg1[%c0], %0 {in_bounds = [true]} : vector<64xf32>, memref<1xf32, #hivm.address_space<ub>>
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_fused_8_outlined_vf_0(%arg0: memref<32xi32, #hivm.address_space<ub>>, %arg1: memref<32xi32, #hivm.address_space<ub>>, %arg2: i32, %arg3: i32, %arg4: memref<32xi32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
  %c0_i32 = arith.constant 0 : i32
  %c0 = arith.constant 0 : index
  %0 = vector.constant_mask [32] : vector<64xi1>
  %1 = vector.transfer_read %arg0[%c0], %c0_i32, %0 {in_bounds = [true]} : memref<32xi32, #hivm.address_space<ub>>, vector<64xi32>
  %2 = vector.transfer_read %arg1[%c0], %c0_i32, %0 {in_bounds = [true]} : memref<32xi32, #hivm.address_space<ub>>, vector<64xi32>
  %3 = vector.broadcast %arg2 : i32 to vector<64xi32>
  %4 = arith.muli %2, %3 : vector<64xi32>
  %5 = vector.broadcast %arg3 : i32 to vector<64xi32>
  %6 = arith.muli %1, %5 : vector<64xi32>
  %7 = arith.addi %6, %4 : vector<64xi32>
  vector.transfer_write %7, %arg4[%c0], %0 {in_bounds = [true]} : vector<64xi32>, memref<32xi32, #hivm.address_space<ub>>
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_outlined_vf_2(%arg0: memref<128xi32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
  %cst = arith.constant dense<[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63]> : vector<64xindex>
  %c64 = arith.constant 64 : index
  %c128 = arith.constant 128 : index
  %c0 = arith.constant 0 : index
  scf.for %arg1 = %c0 to %c128 step %c64 {
    %subview = memref.subview %arg0[%arg1] [64] [1] : memref<128xi32, #hivm.address_space<ub>> to memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>
    %0 = vector.broadcast %arg1 : index to vector<64xindex>
    %1 = arith.addi %0, %cst : vector<64xindex>
    %2 = arith.index_cast %1 : vector<64xindex> to vector<64xi32>
    vector.transfer_write %2, %subview[%c0] {in_bounds = [true]} : vector<64xi32>, memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>
  }
  return
}

func.func @_prefill_bnsd_score_kernel_mix_aiv_outlined_vf_3(%arg0: memref<1x128xi32, #hivm.address_space<ub>>, %arg1: i32, %arg2: memref<1x128xi1, strided<[256, 1]>, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
  %c0_i32 = arith.constant 0 : i32
  %c64 = arith.constant 64 : index
  %c128 = arith.constant 128 : index
  %c0 = arith.constant 0 : index
  %0 = vector.broadcast %arg1 : i32 to vector<1x64xi32>
  scf.for %arg3 = %c0 to %c128 step %c64 {
    %subview = memref.subview %arg0[0, %arg3] [1, 64] [1, 1] : memref<1x128xi32, #hivm.address_space<ub>> to memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
    %subview_0 = memref.subview %arg2[0, %arg3] [1, 64] [1, 1] : memref<1x128xi1, strided<[256, 1]>, #hivm.address_space<ub>> to memref<1x64xi1, strided<[256, 1], offset: ?>, #hivm.address_space<ub>>
    %1 = vector.transfer_read %subview[%c0, %c0], %c0_i32 {in_bounds = [true, true]} : memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xi32>
    %2 = arith.cmpi slt, %1, %0 : vector<1x64xi32>
    vector.transfer_write %2, %subview_0[%c0, %c0] {in_bounds = [true, true]} : vector<1x64xi1>, memref<1x64xi1, strided<[256, 1], offset: ?>, #hivm.address_space<ub>>
  }
  return
}

}

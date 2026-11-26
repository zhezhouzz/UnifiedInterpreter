#map = affine_map<(d0)[s0] -> (d0 + s0)>
#map1 = affine_map<()[s0] -> (s0 + 1)>
#map2 = affine_map<()[s0] -> (s0 - ((s0 + 1) floordiv 2) * 2 + 5)>
#map3 = affine_map<()[s0, s1] -> (s0 + s1)>
#map4 = affine_map<()[s0] -> (s0 + 128)>
#map5 = affine_map<()[s0, s1] -> (s0 - s1)>
#map6 = affine_map<(d0) -> (d0 ceildiv 16)>
#map7 = affine_map<()[s0] -> (s0 - ((s0 + 1) floordiv 2) * 2 + 4)>
#map8 = affine_map<()[s0] -> (s0 - ((s0 + 1) floordiv 2) * 2 + 3)>
#map9 = affine_map<()[s0, s1, s2] -> (s0 + s1 + s2)>
#map10 = affine_map<(d0, d1)[s0] -> (d0 * 272 + d1 + s0)>
#map11 = affine_map<()[s0] -> (s0 * 8)>
#map12 = affine_map<()[s0, s1, s2] -> (-s0 + s1 - s2)>
#map13 = affine_map<()[s0] -> (s0 * 8 + 8)>
#map14 = affine_map<()[s0, s1] -> (s0 - s1 * 8)>
#map15 = affine_map<()[s0, s1, s2, s3] -> (s0 * s1 + s2 + s3)>
#map16 = affine_map<()[s0] -> (s0 mod 2 + 4)>
#map17 = affine_map<()[s0] -> (s0 mod 2 + 3)>
#map18 = affine_map<()[s0] -> (s0 mod 2 + 2)>
module attributes {dlti.target_system_spec = #dlti.target_system_spec<"NPU" : #hacc.target_device_spec<#dlti.dl_entry<"AI_CORE_COUNT", 28 : i32>, #dlti.dl_entry<"CUBE_CORE_COUNT", 28 : i32>, #dlti.dl_entry<"VECTOR_CORE_COUNT", 56 : i32>, #dlti.dl_entry<"UB_SIZE", 2031616 : i32>, #dlti.dl_entry<"L1_SIZE", 4194304 : i32>, #dlti.dl_entry<"L0A_SIZE", 524288 : i32>, #dlti.dl_entry<"L0B_SIZE", 524288 : i32>, #dlti.dl_entry<"L0C_SIZE", 2097152 : i32>, #dlti.dl_entry<"UB_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L1_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L0C_ALIGN_SIZE", 4096 : i32>, #dlti.dl_entry<"MINIMAL_D_CACHE_SIZE", 262144 : i32>, #dlti.dl_entry<"MAXIMUM_D_CACHE_SIZE", 983040 : i32>, #dlti.dl_entry<"ARCH", "dav-c310">>>, hacc.target = #hacc.target<"Ascend950PR_9579">, hivm.module_core_type = #hivm.module_core_type<MIX>} {
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%arg0: memref<8xf32, #hivm.address_space<ub>>, %arg1: memref<8xf32, #hivm.address_space<ub>>, %arg2: memref<8xf32, #hivm.address_space<ub>>, %arg3: memref<8x128xi32, #hivm.address_space<ub>>, %arg4: memref<8x1xf32, #hivm.address_space<ub>>, %arg5: memref<8x1xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function} {
    %c0 = arith.constant 0 : index
    %c-2139095040_i32 = arith.constant -2139095040 : i32
    %c1_i32 = arith.constant 1 : i32
    %c0_i32 = arith.constant 0 : i32
    %c2147483647_i32 = arith.constant 2147483647 : i32
    %cst = arith.constant 0.693147182 : f32
    %cst_0 = arith.constant 0xFF800000 : f32
    %c128 = arith.constant 128 : index
    %c64 = arith.constant 64 : index
    %c1 = arith.constant 1 : index
    %c8 = arith.constant 8 : index
    %cst_1 = arith.constant 0.000000e+00 : f32
    %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %1 = ave.hir.broadcast %cst_1, %0 : f32, vector<64xi1> -> vector<64xf32>
    %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %3 = ave.hir.broadcast %cst_0, %2 : f32, vector<64xi1> -> vector<64xf32>
    %4 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %5 = ave.hir.broadcast %cst, %4 : f32, vector<64xi1> -> vector<64xf32>
    %6 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %7 = ave.hir.broadcast %c2147483647_i32, %6 : i32, vector<64xi1> -> vector<64xi32>
    %8 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %9 = ave.hir.broadcast %cst_0, %8 : f32, vector<64xi1> -> vector<64xf32>
    %10 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %11 = ave.hir.broadcast %c0_i32, %10 : i32, vector<64xi1> -> vector<64xi32>
    %12 = ave.hir.pge <VL8> {functionType = #ave.func_dist_type<pb32>, mask_op_idx = 0 : i32} : vector<64xi1>
    %res = ave.hir.vload <NORM> %arg0[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %13 = vector.bitcast %res : vector<64xf32> to vector<64xi32>
    %14 = ave.hir.vsel %12, %7, %11 : vector<64xi1>, vector<64xi32>
    %15 = ave.hir.vand %13, %14, %12 : vector<64xi32>, vector<64xi1>
    %16 = ave.hir.vadds %15, %c-2139095040_i32, %12 : vector<64xi32>, i32, vector<64xi1>
    %17 = ave.hir.vsmins %16, %c1_i32, %12 : vector<64xi32>, i32, vector<64xi1>
    %18 = ave.hir.vsmaxs %17, %c0_i32, %12 : vector<64xi32>, i32, vector<64xi1>
    %19 = ave.hir.vcmp <NE> %18, %11, %12 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
    %20 = ave.hir.vsel %19, %9, %res : vector<64xi1>, vector<64xf32>
    ave.hir.masked_store <NORM_B32> %arg1[%c0], %12, %20 {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    ave.hir.masked_store <NORM_B32> %arg2[%c0], %12, %5 {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    %21 = ave.hir.pge <VL1> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    scf.for %arg6 = %c0 to %c8 step %c1 {
      scf.for %arg7 = %c0 to %c128 step %c64 {
        %subview_3 = memref.subview %arg3[%arg6, %arg7] [1, 64] [1, 1] : memref<8x128xi32, #hivm.address_space<ub>> to memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_4 = memref.subview %subview_3[0, 0] [1, 64] [1, 1] : memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xi32, #map, #hivm.address_space<ub>>
        %22 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        ave.hir.masked_store <NORM_B32> %subview_4[%c0], %22, %7 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xi32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi32>
      }
      %subview = memref.subview %arg4[%arg6, 0] [1, 1] [1, 1] : memref<8x1xf32, #hivm.address_space<ub>> to memref<1x1xf32, strided<[1, 1], offset: ?>, #hivm.address_space<ub>>
      ave.hir.masked_store <ONEPT_B32> %subview[%c0, %c0], %21, %1 {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>} : memref<1x1xf32, strided<[1, 1], offset: ?>, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
      %subview_2 = memref.subview %arg5[%arg6, 0] [1, 1] [1, 1] : memref<8x1xf32, #hivm.address_space<ub>> to memref<1x1xf32, strided<[1, 1], offset: ?>, #hivm.address_space<ub>>
      ave.hir.masked_store <ONEPT_B32> %subview_2[%c0, %c0], %21, %3 {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>} : memref<1x1xf32, strided<[1, 1], offset: ?>, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%arg0: memref<1x1x128xi32, #hivm.address_space<ub>>, %arg1: i32, %arg2: memref<1x8x128xf32, #hivm.address_space<ub>>, %arg3: memref<1x128xf32, #hivm.address_space<ub>>, %arg4: memref<1x128xf32, #hivm.address_space<ub>>, %arg5: memref<8xi32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function} {
    %c0 = arith.constant 0 : index
    %c128 = arith.constant 128 : index
    %c64 = arith.constant 64 : index
    %c8 = arith.constant 8 : index
    %c1 = arith.constant 1 : index
    %c2147483647_i32 = arith.constant 2147483647 : i32
    %cst = arith.constant 0.000000e+00 : f32
    %cst_0 = arith.constant 0xFF800000 : f32
    %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %1 = ave.hir.broadcast %cst_0, %0 : f32, vector<64xi1> -> vector<64xf32>
    %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %3 = ave.hir.broadcast %cst, %2 : f32, vector<64xi1> -> vector<64xf32>
    %4 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %5 = ave.hir.broadcast %c2147483647_i32, %4 : i32, vector<64xi1> -> vector<64xi32>
    scf.for %arg6 = %c0 to %c8 step %c1 {
      scf.for %arg7 = %c0 to %c128 step %c64 {
        %subview = memref.subview %arg0[0, 0, %arg7] [1, 1, 64] [1, 1, 1] : memref<1x1x128xi32, #hivm.address_space<ub>> to memref<1x1x64xi32, strided<[128, 128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_1 = memref.subview %arg2[0, %arg6, %arg7] [1, 1, 64] [1, 1, 1] : memref<1x8x128xf32, #hivm.address_space<ub>> to memref<1x1x64xf32, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>
        %res = ave.hir.vload <NORM> %subview[%c0, %c0, %c0] {functionType = #ave.func_dist_type<norm>} : memref<1x1x64xi32, strided<[128, 128, 1], offset: ?>, #hivm.address_space<ub>> into vector<64xi32>
        %7 = ave.hir.scalar_broadcast %arg1 : i32 -> vector<64xi32>
        %8 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %9 = ave.hir.vcmp <GE> %res, %7, %8 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
        %10 = ave.hir.vsel %9, %3, %1 : vector<64xi1>, vector<64xf32>
        %subview_2 = memref.subview %subview_1[0, 0, 0] [1, 1, 64] [1, 1, 1] : memref<1x1x64xf32, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %11 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        ave.hir.masked_store <NORM_B32> %subview_2[%c0], %11, %10 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xf32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
      }
    }
    scf.for %arg6 = %c0 to %c128 step %c64 {
      %subview = memref.subview %arg3[0, %arg6] [1, 64] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_1 = memref.subview %subview[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
      %7 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      ave.hir.masked_store <NORM_B32> %subview_1[%c0], %7, %3 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xf32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
      %subview_2 = memref.subview %arg4[0, %arg6] [1, 64] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_3 = memref.subview %subview_2[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
      %8 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      ave.hir.masked_store <NORM_B32> %subview_3[%c0], %8, %1 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xf32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    }
    %6 = ave.hir.pge <VL8> {functionType = #ave.func_dist_type<pb32>, mask_op_idx = 0 : i32} : vector<64xi1>
    ave.hir.masked_store <NORM_B32> %arg5[%c0], %6, %5 {functionType = #ave.func_dist_type<norm>} : memref<8xi32, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi32>
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aic(%arg0: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg1: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<?xbf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xbf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xbf16, #hivm.address_space<gm>>, %arg5: memref<?xbf16, #hivm.address_space<gm>>, %arg6: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg7: memref<?xbf16, #hivm.address_space<gm>> {tt.tensor_kind = 1 : i32}, %arg8: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg9: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg10: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg11: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg12: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg13: i32, %arg14: i32, %arg15: i32, %arg16: i32, %arg17: f32, %arg18: i32, %arg19: i32, %arg20: i32, %arg21: i32, %arg22: i32, %arg23: i32, %arg24: i32, %arg25: i32, %arg26: i32, %arg27: i32, %arg28: i32, %arg29: i32, %arg30: i32, %arg31: i32, %arg32: i32, %arg33: i32, %arg34: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, func_dyn_memref_args = dense<[true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]> : vector<35xi1>, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<AIC>, hivm.part_of_mix, hivm.vf_mode = #hivm.vf_mode<SIMD>, mix_mode = "mix", parallel_mode = "simd"} {
    %c5_i64 = arith.constant 5 : i64
    %c24576_i64 = arith.constant 24576 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c40960_i64 = arith.constant 40960 : i64
    %c110592_i64 = arith.constant 110592 : i64
    %c16384_i64 = arith.constant 16384 : i64
    %c77824_i64 = arith.constant 77824 : i64
    %c47968_i64 = arith.constant 47968 : i64
    %c11584_i64 = arith.constant 11584 : i64
    %c73728_i64 = arith.constant 73728 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c43872_i64 = arith.constant 43872 : i64
    %c7488_i64 = arith.constant 7488 : i64
    %c-1_i64 = arith.constant -1 : i64
    %c4_i64 = arith.constant 4 : i64
    %c3_i64 = arith.constant 3 : i64
    %c10_i32 = arith.constant 10 : i32
    %c128 = arith.constant 128 : index
    %c16 = arith.constant 16 : index
    %cst = arith.constant 0.000000e+00 : bf16
    %c0_i32 = arith.constant 0 : i32
    %c128_i32 = arith.constant 128 : i32
    %c1_i64 = arith.constant 1 : i64
    %true = arith.constant true
    %c1_i32 = arith.constant 1 : i32
    %c28_i32 = arith.constant 28 : i32
    %c2_i64 = arith.constant 2 : i64
    %c5_i32 = arith.constant 5 : i32
    %c3_i32 = arith.constant 3 : i32
    %c0 = arith.constant 0 : index
    %c0_i64 = arith.constant 0 : i64
    %alloca = memref.alloca() : memref<1xi64>
    memref.store %c0_i64, %alloca[%c0] : memref<1xi64>
    %0 = hivm.hir.pointer_cast(%c8192_i64) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
    %1 = hivm.hir.pointer_cast(%c24576_i64) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
    %2 = hivm.hir.pointer_cast(%c40960_i64) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
    %3 = hivm.hir.pointer_cast(%c110592_i64) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
    %4 = hivm.hir.pointer_cast(%c0_i64) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
    %5 = hivm.hir.pointer_cast(%c16384_i64) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
    %6 = hivm.hir.pointer_cast(%c8192_i64) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
    %7 = hivm.hir.pointer_cast(%c77824_i64) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
    %8 = hivm.hir.pointer_cast(%c11584_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %9 = hivm.hir.pointer_cast(%c47968_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %10 = hivm.hir.pointer_cast(%c4096_i64) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
    %11 = hivm.hir.pointer_cast(%c73728_i64) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
    %12 = hivm.hir.pointer_cast(%c7488_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %13 = hivm.hir.pointer_cast(%c43872_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %alloca_0 = memref.alloca() : memref<1xi64>
    memref.store %c0_i64, %alloca_0[%c0] : memref<1xi64>
    %14 = arith.muli %arg32, %arg33 : i32
    %15 = arith.muli %14, %arg34 : i32
    %16 = hivm.hir.get_block_idx -> i64
    %17 = arith.trunci %16 : i64 to i32
    hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 0
    hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 3
    hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 4
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    scf.for %arg35 = %17 to %15 step %c28_i32  : i32 {
      hivm.hir.set_ctrl false at ctrl[60]
      hivm.hir.set_ctrl true at ctrl[48]
      %18 = arith.remsi %arg35, %arg32 : i32
      %19 = arith.divsi %arg35, %arg32 : i32
      %20 = arith.remsi %19, %arg33 : i32
      %21 = arith.divsi %arg35, %14 : i32
      %22 = arith.remsi %21, %arg34 : i32
      %23 = arith.index_cast %22 : i32 to index
      %24 = affine.apply #map1()[%23]
      %reinterpret_cast = memref.reinterpret_cast %arg10 to offset: [%23], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %25 = memref.load %reinterpret_cast[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_1 = memref.reinterpret_cast %arg10 to offset: [%24], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %26 = memref.load %reinterpret_cast_1[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %27 = arith.subi %26, %25 : i32
      %reinterpret_cast_2 = memref.reinterpret_cast %arg11 to offset: [%23], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %28 = memref.load %reinterpret_cast_2[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_3 = memref.reinterpret_cast %arg12 to offset: [%23], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %29 = memref.load %reinterpret_cast_3[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %30 = arith.cmpi sge, %18, %27 : i32
      scf.if %30 {
      } else {
        %31 = arith.subi %27, %18 : i32
        %32 = arith.minsi %31, %c1_i32 : i32
        %33 = arith.muli %22, %arg31 : i32
        %34 = arith.index_cast %33 : i32 to index
        %35 = arith.muli %20, %arg27 : i32
        %36 = arith.extsi %arg20 : i32 to i64
        %37 = arith.muli %20, %arg21 : i32
        %38 = arith.index_cast %37 : i32 to index
        %39 = arith.extsi %35 : i32 to i64
        %40 = arith.index_cast %arg15 : i32 to index
        %41 = arith.maxsi %40, %c0 : index
        %42 = arith.minsi %41, %c128 : index
        hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
        hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID2>]
        hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID3>]
        hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID4>]
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID2>]
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID3>]
        scf.for %arg36 = %c0_i32 to %32 step %c1_i32  : i32 {
          %43 = arith.addi %18, %arg36 : i32
          %44 = arith.addi %25, %43 : i32
          %45 = arith.muli %44, %arg28 : i32
          %46 = arith.extsi %45 : i32 to i64
          %47 = arith.addi %46, %39 : i64
          %48 = arith.addi %29, %43 : i32
          %49 = arith.addi %48, %c128_i32 : i32
          %50 = arith.divsi %49, %c128_i32 : i32
          %51 = arith.minsi %arg16, %50 : i32
          %52 = hivm.hir.pointer_cast(%c0_i64) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
          hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 0
          %53 = arith.addi %51, %c5_i32 : i32
          %54 = arith.cmpi sgt, %51, %c0_i32 : i32
          %55 = arith.select %54, %53, %c0_i32 : i32
          %56 = arith.cmpi sge, %55, %c10_i32 : i32
          scf.if %56 {
            %57 = memref.load %alloca_0[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
            %58 = arith.addi %57, %c1_i64 : i64
            memref.store %58, %alloca_0[%c0] : memref<1xi64>
            %59 = arith.remui %58, %c2_i64 : i64
            %60 = arith.index_cast %59 : i64 to index
            %61 = arith.index_cast %60 : index to i1
            %62 = arith.xori %61, %true : i1
            %63 = arith.extui %62 : i1 to i64
            %64 = arith.select %61, %c1_i64, %c2_i64 : i64
            %65 = affine.apply #map2()[%60]
            %66 = arith.index_cast %65 : index to i64
            %67 = arith.cmpi eq, %59, %c1_i64 : i64
            %68 = arith.select %67, %c16384_i64, %c0_i64 : i64
            %69 = hivm.hir.pointer_cast(%68) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %70 = arith.select %67, %c77824_i64, %c8192_i64 : i64
            %71 = hivm.hir.pointer_cast(%70) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %72 = arith.select %67, %c47968_i64, %c11584_i64 : i64
            %73 = hivm.hir.pointer_cast(%72) : memref<8x128xf32, #hivm.address_space<ub>>
            %74 = arith.index_cast %47 : i64 to index
            %reinterpret_cast_4 = memref.reinterpret_cast %arg6 to offset: [%74], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %75 = memref.load %reinterpret_cast_4[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %76 = arith.addi %47, %c1_i64 : i64
            %77 = arith.muli %75, %c128_i32 : i32
            %78 = arith.index_cast %75 : i32 to index
            %79 = affine.apply #map3()[%34, %78]
            %reinterpret_cast_5 = memref.reinterpret_cast %arg8 to offset: [%79], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %80 = memref.load %reinterpret_cast_5[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %81 = arith.extsi %80 : i32 to i64
            %82 = arith.muli %81, %36 : i64
            %83 = arith.index_cast %82 : i64 to index
            %84 = affine.apply #map3()[%83, %38]
            %85 = arith.index_cast %arg22 : i32 to index
            %reinterpret_cast_6 = memref.reinterpret_cast %arg3 to offset: [%84], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %86 = arith.index_cast %77 : i32 to index
            %87 = affine.apply #map4()[%86]
            %88 = arith.index_cast %28 : i32 to index
            %89 = arith.maxsi %86, %88 : index
            %90 = arith.minsi %87, %89 : index
            %91 = affine.apply #map5()[%90, %86]
            %92 = arith.minsi %91, %c128 : index
            %93 = arith.maxsi %92, %c0 : index
            %94 = arith.minsi %42, %c128 : index
            %95 = arith.maxsi %94, %c0 : index
            %96 = arith.cmpi slt, %93, %c128 : index
            %97 = arith.cmpi slt, %95, %c128 : index
            %98 = arith.ori %96, %97 : i1
            %subview = memref.subview %reinterpret_cast_6[0, 0] [%93, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %99 = affine.apply #map6(%93)
            %100 = affine.apply #map6(%95)
            %subview_7 = memref.subview %71[0, 0, 0, 0] [%100, %99, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %98 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %71 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %64]
            hivm.hir.nd2nz {dst_continuous} ins(%subview : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_7 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %63]
            hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%52, %71, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%69 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %64, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %66
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%69 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%73 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %63]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
            %101 = arith.addi %57, %c2_i64 : i64
            memref.store %101, %alloca_0[%c0] : memref<1xi64>
            %102 = arith.remui %101, %c2_i64 : i64
            %103 = arith.index_cast %102 : i64 to index
            %104 = arith.index_cast %103 : index to i1
            %105 = arith.xori %104, %true : i1
            %106 = arith.extui %105 : i1 to i64
            %107 = arith.select %104, %c1_i64, %c2_i64 : i64
            %108 = affine.apply #map2()[%103]
            %109 = arith.index_cast %108 : index to i64
            %110 = arith.cmpi eq, %102, %c1_i64 : i64
            %111 = arith.select %110, %c16384_i64, %c0_i64 : i64
            %112 = hivm.hir.pointer_cast(%111) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %113 = arith.select %110, %c77824_i64, %c8192_i64 : i64
            %114 = hivm.hir.pointer_cast(%113) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %115 = arith.select %110, %c47968_i64, %c11584_i64 : i64
            %116 = hivm.hir.pointer_cast(%115) : memref<8x128xf32, #hivm.address_space<ub>>
            %117 = arith.index_cast %76 : i64 to index
            %reinterpret_cast_8 = memref.reinterpret_cast %arg6 to offset: [%117], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %118 = memref.load %reinterpret_cast_8[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %119 = arith.addi %47, %c2_i64 : i64
            %120 = arith.muli %118, %c128_i32 : i32
            %121 = arith.index_cast %118 : i32 to index
            %122 = affine.apply #map3()[%34, %121]
            %reinterpret_cast_9 = memref.reinterpret_cast %arg8 to offset: [%122], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %123 = memref.load %reinterpret_cast_9[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %124 = arith.extsi %123 : i32 to i64
            %125 = arith.muli %124, %36 : i64
            %126 = arith.index_cast %125 : i64 to index
            %127 = affine.apply #map3()[%126, %38]
            %reinterpret_cast_10 = memref.reinterpret_cast %arg3 to offset: [%127], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %128 = arith.index_cast %120 : i32 to index
            %129 = affine.apply #map4()[%128]
            %130 = arith.maxsi %128, %88 : index
            %131 = arith.minsi %129, %130 : index
            %132 = affine.apply #map5()[%131, %128]
            %133 = arith.minsi %132, %c128 : index
            %134 = arith.maxsi %133, %c0 : index
            %135 = arith.cmpi slt, %134, %c128 : index
            %136 = arith.ori %135, %97 : i1
            %subview_11 = memref.subview %reinterpret_cast_10[0, 0] [%134, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %137 = affine.apply #map6(%134)
            %subview_12 = memref.subview %114[0, 0, 0, 0] [%100, %137, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %136 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %114 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %107]
            hivm.hir.nd2nz {dst_continuous} ins(%subview_11 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_12 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %106]
            hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%52, %114, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%112 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %107, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %109
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%112 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%116 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %106]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
            %138 = arith.addi %57, %c3_i64 : i64
            memref.store %138, %alloca_0[%c0] : memref<1xi64>
            %139 = arith.remui %138, %c2_i64 : i64
            %140 = arith.index_cast %139 : i64 to index
            %141 = arith.index_cast %140 : index to i1
            %142 = arith.select %141, %c2_i64, %c3_i64 : i64
            %143 = arith.select %141, %c3_i64, %c4_i64 : i64
            %144 = arith.xori %141, %true : i1
            %145 = arith.extui %144 : i1 to i64
            %146 = arith.select %141, %c1_i64, %c2_i64 : i64
            %147 = affine.apply #map7()[%140]
            %148 = arith.index_cast %147 : index to i64
            %149 = affine.apply #map8()[%140]
            %150 = arith.index_cast %149 : index to i64
            %151 = affine.apply #map2()[%140]
            %152 = arith.index_cast %151 : index to i64
            %153 = arith.cmpi eq, %139, %c1_i64 : i64
            %154 = arith.select %153, %c24576_i64, %c8192_i64 : i64
            %155 = hivm.hir.pointer_cast(%154) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %156 = arith.select %153, %c110592_i64, %c40960_i64 : i64
            %157 = hivm.hir.pointer_cast(%156) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %158 = arith.select %153, %c16384_i64, %c0_i64 : i64
            %159 = hivm.hir.pointer_cast(%158) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %160 = arith.select %153, %c77824_i64, %c8192_i64 : i64
            %161 = hivm.hir.pointer_cast(%160) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %162 = arith.select %153, %c47968_i64, %c11584_i64 : i64
            %163 = hivm.hir.pointer_cast(%162) : memref<8x128xf32, #hivm.address_space<ub>>
            %164 = arith.select %153, %c73728_i64, %c4096_i64 : i64
            %165 = hivm.hir.pointer_cast(%164) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %166 = arith.select %153, %c43872_i64, %c7488_i64 : i64
            %167 = hivm.hir.pointer_cast(%166) : memref<8x128xf32, #hivm.address_space<ub>>
            %168 = arith.index_cast %119 : i64 to index
            %reinterpret_cast_13 = memref.reinterpret_cast %arg6 to offset: [%168], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %169 = memref.load %reinterpret_cast_13[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %170 = arith.addi %47, %c3_i64 : i64
            %171 = arith.muli %169, %c128_i32 : i32
            %172 = arith.index_cast %169 : i32 to index
            %173 = affine.apply #map3()[%34, %172]
            %reinterpret_cast_14 = memref.reinterpret_cast %arg8 to offset: [%173], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %174 = memref.load %reinterpret_cast_14[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %175 = arith.extsi %174 : i32 to i64
            %176 = arith.muli %175, %36 : i64
            %177 = arith.index_cast %176 : i64 to index
            %178 = affine.apply #map3()[%177, %38]
            %reinterpret_cast_15 = memref.reinterpret_cast %arg3 to offset: [%178], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %179 = arith.index_cast %171 : i32 to index
            %180 = affine.apply #map4()[%179]
            %181 = arith.maxsi %179, %88 : index
            %182 = arith.minsi %180, %181 : index
            %183 = affine.apply #map5()[%182, %179]
            %184 = arith.minsi %183, %c128 : index
            %185 = arith.maxsi %184, %c0 : index
            %186 = arith.cmpi slt, %185, %c128 : index
            %187 = arith.ori %186, %97 : i1
            %subview_16 = memref.subview %reinterpret_cast_15[0, 0] [%185, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %188 = affine.apply #map6(%185)
            %subview_17 = memref.subview %161[0, 0, 0, 0] [%100, %188, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %187 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %161 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %146]
            hivm.hir.nd2nz {dst_continuous} ins(%subview_16 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_17 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %145]
            hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%52, %161, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%159 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %146, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %152
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%159 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%163 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %145]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
            %189 = memref.load %reinterpret_cast_4[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %190 = arith.muli %189, %c128_i32 : i32
            %191 = arith.index_cast %189 : i32 to index
            %192 = affine.apply #map3()[%34, %191]
            %reinterpret_cast_18 = memref.reinterpret_cast %arg8 to offset: [%192], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %193 = memref.load %reinterpret_cast_18[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %194 = arith.extsi %193 : i32 to i64
            %195 = arith.muli %194, %36 : i64
            %196 = arith.index_cast %195 : i64 to index
            %197 = arith.index_cast %190 : i32 to index
            %198 = affine.apply #map4()[%197]
            %199 = arith.maxsi %197, %88 : index
            %200 = arith.minsi %198, %199 : index
            %201 = affine.apply #map5()[%200, %197]
            %202 = arith.minsi %201, %c128 : index
            %203 = arith.maxsi %202, %c0 : index
            %204 = arith.cmpi slt, %203, %c128 : index
            %205 = arith.ori %204, %97 : i1
            %206 = affine.apply #map6(%203)
            %207 = affine.apply #map9()[%40, %196, %38]
            %reinterpret_cast_19 = memref.reinterpret_cast %arg3 to offset: [%207], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %subview_20 = memref.subview %reinterpret_cast_19[0, 0] [%203, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %subview_21 = memref.subview %157[0, 0, 0, 0] [%100, %206, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %205 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %157 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %143]
            hivm.hir.nd2nz {dst_continuous} ins(%subview_20 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_21 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %142]
            hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%165, %157, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%155 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %143, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %148
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %150
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%155 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%167 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %142]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 1
            %208 = arith.addi %57, %c4_i64 : i64
            memref.store %208, %alloca_0[%c0] : memref<1xi64>
            %209 = arith.remui %208, %c2_i64 : i64
            %210 = arith.index_cast %209 : i64 to index
            %211 = arith.index_cast %210 : index to i1
            %212 = arith.select %211, %c2_i64, %c3_i64 : i64
            %213 = arith.select %211, %c3_i64, %c4_i64 : i64
            %214 = arith.xori %211, %true : i1
            %215 = arith.extui %214 : i1 to i64
            %216 = arith.select %211, %c1_i64, %c2_i64 : i64
            %217 = affine.apply #map7()[%210]
            %218 = arith.index_cast %217 : index to i64
            %219 = affine.apply #map8()[%210]
            %220 = arith.index_cast %219 : index to i64
            %221 = affine.apply #map2()[%210]
            %222 = arith.index_cast %221 : index to i64
            %223 = arith.cmpi eq, %209, %c1_i64 : i64
            %224 = arith.select %223, %c24576_i64, %c8192_i64 : i64
            %225 = hivm.hir.pointer_cast(%224) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %226 = arith.select %223, %c110592_i64, %c40960_i64 : i64
            %227 = hivm.hir.pointer_cast(%226) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %228 = arith.select %223, %c16384_i64, %c0_i64 : i64
            %229 = hivm.hir.pointer_cast(%228) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %230 = arith.select %223, %c77824_i64, %c8192_i64 : i64
            %231 = hivm.hir.pointer_cast(%230) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %232 = arith.select %223, %c47968_i64, %c11584_i64 : i64
            %233 = hivm.hir.pointer_cast(%232) : memref<8x128xf32, #hivm.address_space<ub>>
            %234 = arith.select %223, %c73728_i64, %c4096_i64 : i64
            %235 = hivm.hir.pointer_cast(%234) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %236 = arith.select %223, %c43872_i64, %c7488_i64 : i64
            %237 = hivm.hir.pointer_cast(%236) : memref<8x128xf32, #hivm.address_space<ub>>
            %238 = arith.index_cast %170 : i64 to index
            %reinterpret_cast_22 = memref.reinterpret_cast %arg6 to offset: [%238], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %239 = memref.load %reinterpret_cast_22[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %240 = arith.addi %47, %c4_i64 : i64
            %241 = arith.muli %239, %c128_i32 : i32
            %242 = arith.index_cast %239 : i32 to index
            %243 = affine.apply #map3()[%34, %242]
            %reinterpret_cast_23 = memref.reinterpret_cast %arg8 to offset: [%243], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %244 = memref.load %reinterpret_cast_23[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %245 = arith.extsi %244 : i32 to i64
            %246 = arith.muli %245, %36 : i64
            %247 = arith.index_cast %246 : i64 to index
            %248 = affine.apply #map3()[%247, %38]
            %reinterpret_cast_24 = memref.reinterpret_cast %arg3 to offset: [%248], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %249 = arith.index_cast %241 : i32 to index
            %250 = affine.apply #map4()[%249]
            %251 = arith.maxsi %249, %88 : index
            %252 = arith.minsi %250, %251 : index
            %253 = affine.apply #map5()[%252, %249]
            %254 = arith.minsi %253, %c128 : index
            %255 = arith.maxsi %254, %c0 : index
            %256 = arith.cmpi slt, %255, %c128 : index
            %257 = arith.ori %256, %97 : i1
            %subview_25 = memref.subview %reinterpret_cast_24[0, 0] [%255, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %258 = affine.apply #map6(%255)
            %subview_26 = memref.subview %231[0, 0, 0, 0] [%100, %258, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %257 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %231 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %216]
            hivm.hir.nd2nz {dst_continuous} ins(%subview_25 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_26 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %215]
            hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%52, %231, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%229 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %216, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %222
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%229 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%233 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %215]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
            %259 = memref.load %reinterpret_cast_8[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %260 = arith.muli %259, %c128_i32 : i32
            %261 = arith.index_cast %259 : i32 to index
            %262 = affine.apply #map3()[%34, %261]
            %reinterpret_cast_27 = memref.reinterpret_cast %arg8 to offset: [%262], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %263 = memref.load %reinterpret_cast_27[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %264 = arith.extsi %263 : i32 to i64
            %265 = arith.muli %264, %36 : i64
            %266 = arith.index_cast %265 : i64 to index
            %267 = arith.index_cast %260 : i32 to index
            %268 = affine.apply #map4()[%267]
            %269 = arith.maxsi %267, %88 : index
            %270 = arith.minsi %268, %269 : index
            %271 = affine.apply #map5()[%270, %267]
            %272 = arith.minsi %271, %c128 : index
            %273 = arith.maxsi %272, %c0 : index
            %274 = arith.cmpi slt, %273, %c128 : index
            %275 = arith.ori %274, %97 : i1
            %276 = affine.apply #map6(%273)
            %277 = affine.apply #map9()[%40, %266, %38]
            %reinterpret_cast_28 = memref.reinterpret_cast %arg3 to offset: [%277], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %subview_29 = memref.subview %reinterpret_cast_28[0, 0] [%273, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %subview_30 = memref.subview %227[0, 0, 0, 0] [%100, %276, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %275 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %227 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %213]
            hivm.hir.nd2nz {dst_continuous} ins(%subview_29 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_30 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %212]
            hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%235, %227, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%225 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %213, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %218
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %220
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%225 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%237 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %212]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 1
            %278 = arith.addi %57, %c5_i64 : i64
            memref.store %278, %alloca_0[%c0] : memref<1xi64>
            %279 = arith.subi %55, %c5_i32 : i32
            %280:2 = scf.for %arg37 = %c5_i32 to %279 step %c1_i32 iter_args(%arg38 = %240, %arg39 = %119) -> (i64, i64)  : i32 {
              %434 = memref.load %alloca_0[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
              %435 = arith.remui %434, %c2_i64 : i64
              %436 = arith.index_cast %435 : i64 to index
              %437 = arith.index_cast %436 : index to i1
              %438 = arith.select %437, %c2_i64, %c3_i64 : i64
              %439 = arith.select %437, %c3_i64, %c4_i64 : i64
              %440 = arith.xori %437, %true : i1
              %441 = arith.extui %440 : i1 to i64
              %442 = arith.select %437, %c1_i64, %c2_i64 : i64
              %443 = affine.apply #map7()[%436]
              %444 = arith.index_cast %443 : index to i64
              %445 = affine.apply #map8()[%436]
              %446 = arith.index_cast %445 : index to i64
              %447 = affine.apply #map2()[%436]
              %448 = arith.index_cast %447 : index to i64
              %449 = arith.cmpi eq, %435, %c1_i64 : i64
              %450 = arith.select %449, %c24576_i64, %c8192_i64 : i64
              %451 = hivm.hir.pointer_cast(%450) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
              %452 = arith.select %449, %c110592_i64, %c40960_i64 : i64
              %453 = hivm.hir.pointer_cast(%452) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
              %454 = arith.select %449, %c16384_i64, %c0_i64 : i64
              %455 = hivm.hir.pointer_cast(%454) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
              %456 = arith.select %449, %c77824_i64, %c8192_i64 : i64
              %457 = hivm.hir.pointer_cast(%456) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
              %458 = arith.select %449, %c47968_i64, %c11584_i64 : i64
              %459 = hivm.hir.pointer_cast(%458) : memref<8x128xf32, #hivm.address_space<ub>>
              %460 = arith.select %449, %c73728_i64, %c4096_i64 : i64
              %461 = hivm.hir.pointer_cast(%460) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
              %462 = arith.select %449, %c43872_i64, %c7488_i64 : i64
              %463 = hivm.hir.pointer_cast(%462) : memref<8x128xf32, #hivm.address_space<ub>>
              %464 = arith.index_cast %arg38 : i64 to index
              %reinterpret_cast_51 = memref.reinterpret_cast %arg6 to offset: [%464], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %465 = memref.load %reinterpret_cast_51[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %466 = arith.addi %arg38, %c1_i64 : i64
              %467 = arith.muli %465, %c128_i32 : i32
              %468 = arith.index_cast %465 : i32 to index
              %469 = affine.apply #map3()[%34, %468]
              %reinterpret_cast_52 = memref.reinterpret_cast %arg8 to offset: [%469], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %470 = memref.load %reinterpret_cast_52[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %471 = arith.extsi %470 : i32 to i64
              %472 = arith.muli %471, %36 : i64
              %473 = arith.index_cast %472 : i64 to index
              %474 = affine.apply #map3()[%473, %38]
              %reinterpret_cast_53 = memref.reinterpret_cast %arg3 to offset: [%474], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
              %475 = arith.index_cast %467 : i32 to index
              %476 = affine.apply #map4()[%475]
              %477 = arith.maxsi %475, %88 : index
              %478 = arith.minsi %476, %477 : index
              %479 = affine.apply #map5()[%478, %475]
              %480 = arith.minsi %479, %c128 : index
              %481 = arith.maxsi %480, %c0 : index
              %482 = arith.cmpi slt, %481, %c128 : index
              %483 = arith.ori %482, %97 : i1
              %subview_54 = memref.subview %reinterpret_cast_53[0, 0] [%481, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
              %484 = affine.apply #map6(%481)
              %subview_55 = memref.subview %457[0, 0, 0, 0] [%100, %484, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
              scf.if %483 {
                hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                %collapse_shape = memref.collapse_shape %457 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
                hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
                hivm.hir.pipe_barrier[<PIPE_MTE2>]
              } {hivm.unlikely_condition}
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %442]
              hivm.hir.nd2nz {dst_continuous} ins(%subview_54 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_55 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
              hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
              hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %441]
              hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%52, %457, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%455 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %442, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
              hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
              hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %448
              hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
              hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%455 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%459 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
              hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %441]
              hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
              %485 = arith.index_cast %arg39 : i64 to index
              %reinterpret_cast_56 = memref.reinterpret_cast %arg6 to offset: [%485], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %486 = memref.load %reinterpret_cast_56[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %487 = arith.addi %arg39, %c1_i64 : i64
              %488 = arith.muli %486, %c128_i32 : i32
              %489 = arith.index_cast %486 : i32 to index
              %490 = affine.apply #map3()[%34, %489]
              %reinterpret_cast_57 = memref.reinterpret_cast %arg8 to offset: [%490], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %491 = memref.load %reinterpret_cast_57[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %492 = arith.extsi %491 : i32 to i64
              %493 = arith.muli %492, %36 : i64
              %494 = arith.index_cast %493 : i64 to index
              %495 = arith.index_cast %488 : i32 to index
              %496 = affine.apply #map4()[%495]
              %497 = arith.maxsi %495, %88 : index
              %498 = arith.minsi %496, %497 : index
              %499 = affine.apply #map5()[%498, %495]
              %500 = arith.minsi %499, %c128 : index
              %501 = arith.maxsi %500, %c0 : index
              %502 = arith.cmpi slt, %501, %c128 : index
              %503 = arith.ori %502, %97 : i1
              %504 = affine.apply #map6(%501)
              %505 = affine.apply #map9()[%40, %494, %38]
              %reinterpret_cast_58 = memref.reinterpret_cast %arg3 to offset: [%505], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
              %subview_59 = memref.subview %reinterpret_cast_58[0, 0] [%501, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
              %subview_60 = memref.subview %453[0, 0, 0, 0] [%100, %504, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
              scf.if %503 {
                hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                %collapse_shape = memref.collapse_shape %453 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
                hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
                hivm.hir.pipe_barrier[<PIPE_MTE2>]
              } {hivm.unlikely_condition}
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %439]
              hivm.hir.nd2nz {dst_continuous} ins(%subview_59 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_60 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
              hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
              hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
              hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %438]
              hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%461, %453, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%451 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %439, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
              hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
              hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %444
              hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %446
              hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
              hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%451 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%463 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
              hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %438]
              hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 1
              %506 = arith.addi %434, %c1_i64 : i64
              memref.store %506, %alloca_0[%c0] : memref<1xi64>
              scf.yield %466, %487 : i64, i64
            }
            %281 = memref.load %alloca_0[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
            %282 = arith.remui %281, %c2_i64 : i64
            %283 = arith.index_cast %282 : i64 to index
            %284 = arith.index_cast %283 : index to i1
            %285 = arith.select %284, %c2_i64, %c3_i64 : i64
            %286 = arith.select %284, %c3_i64, %c4_i64 : i64
            %287 = arith.xori %284, %true : i1
            %288 = arith.extui %287 : i1 to i64
            %289 = arith.select %284, %c1_i64, %c2_i64 : i64
            %290 = affine.apply #map7()[%283]
            %291 = arith.index_cast %290 : index to i64
            %292 = affine.apply #map8()[%283]
            %293 = arith.index_cast %292 : index to i64
            %294 = affine.apply #map2()[%283]
            %295 = arith.index_cast %294 : index to i64
            %296 = arith.cmpi eq, %282, %c1_i64 : i64
            %297 = arith.select %296, %c24576_i64, %c8192_i64 : i64
            %298 = hivm.hir.pointer_cast(%297) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %299 = arith.select %296, %c110592_i64, %c40960_i64 : i64
            %300 = hivm.hir.pointer_cast(%299) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %301 = arith.select %296, %c16384_i64, %c0_i64 : i64
            %302 = hivm.hir.pointer_cast(%301) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %303 = arith.select %296, %c77824_i64, %c8192_i64 : i64
            %304 = hivm.hir.pointer_cast(%303) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %305 = arith.select %296, %c47968_i64, %c11584_i64 : i64
            %306 = hivm.hir.pointer_cast(%305) : memref<8x128xf32, #hivm.address_space<ub>>
            %307 = arith.select %296, %c73728_i64, %c4096_i64 : i64
            %308 = hivm.hir.pointer_cast(%307) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %309 = arith.select %296, %c43872_i64, %c7488_i64 : i64
            %310 = hivm.hir.pointer_cast(%309) : memref<8x128xf32, #hivm.address_space<ub>>
            %311 = arith.index_cast %280#0 : i64 to index
            %reinterpret_cast_31 = memref.reinterpret_cast %arg6 to offset: [%311], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %312 = memref.load %reinterpret_cast_31[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %313 = arith.muli %312, %c128_i32 : i32
            %314 = arith.index_cast %312 : i32 to index
            %315 = affine.apply #map3()[%34, %314]
            %reinterpret_cast_32 = memref.reinterpret_cast %arg8 to offset: [%315], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %316 = memref.load %reinterpret_cast_32[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %317 = arith.extsi %316 : i32 to i64
            %318 = arith.muli %317, %36 : i64
            %319 = arith.index_cast %318 : i64 to index
            %320 = affine.apply #map3()[%319, %38]
            %reinterpret_cast_33 = memref.reinterpret_cast %arg3 to offset: [%320], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %321 = arith.index_cast %313 : i32 to index
            %322 = affine.apply #map4()[%321]
            %323 = arith.maxsi %321, %88 : index
            %324 = arith.minsi %322, %323 : index
            %325 = affine.apply #map5()[%324, %321]
            %326 = arith.minsi %325, %c128 : index
            %327 = arith.maxsi %326, %c0 : index
            %328 = arith.cmpi slt, %327, %c128 : index
            %329 = arith.ori %328, %97 : i1
            %subview_34 = memref.subview %reinterpret_cast_33[0, 0] [%327, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %330 = affine.apply #map6(%327)
            %subview_35 = memref.subview %304[0, 0, 0, 0] [%100, %330, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %329 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %304 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %289]
            hivm.hir.nd2nz {dst_continuous} ins(%subview_34 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_35 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %288]
            hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%52, %304, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%302 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %289, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %295
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%302 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%306 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %288]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
            %331 = arith.index_cast %280#1 : i64 to index
            %reinterpret_cast_36 = memref.reinterpret_cast %arg6 to offset: [%331], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %332 = memref.load %reinterpret_cast_36[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %333 = arith.addi %280#1, %c1_i64 : i64
            %334 = arith.muli %332, %c128_i32 : i32
            %335 = arith.index_cast %332 : i32 to index
            %336 = affine.apply #map3()[%34, %335]
            %reinterpret_cast_37 = memref.reinterpret_cast %arg8 to offset: [%336], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %337 = memref.load %reinterpret_cast_37[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %338 = arith.extsi %337 : i32 to i64
            %339 = arith.muli %338, %36 : i64
            %340 = arith.index_cast %339 : i64 to index
            %341 = arith.index_cast %334 : i32 to index
            %342 = affine.apply #map4()[%341]
            %343 = arith.maxsi %341, %88 : index
            %344 = arith.minsi %342, %343 : index
            %345 = affine.apply #map5()[%344, %341]
            %346 = arith.minsi %345, %c128 : index
            %347 = arith.maxsi %346, %c0 : index
            %348 = arith.cmpi slt, %347, %c128 : index
            %349 = arith.ori %348, %97 : i1
            %350 = affine.apply #map6(%347)
            %351 = affine.apply #map9()[%40, %340, %38]
            %reinterpret_cast_38 = memref.reinterpret_cast %arg3 to offset: [%351], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %subview_39 = memref.subview %reinterpret_cast_38[0, 0] [%347, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %subview_40 = memref.subview %300[0, 0, 0, 0] [%100, %350, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %349 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %300 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %286]
            hivm.hir.nd2nz {dst_continuous} ins(%subview_39 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_40 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %285]
            hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%308, %300, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%298 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %286, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %291
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %293
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%298 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%310 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %285]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 1
            %352 = arith.addi %281, %c1_i64 : i64
            memref.store %352, %alloca_0[%c0] : memref<1xi64>
            %353 = arith.remui %352, %c2_i64 : i64
            %354 = arith.index_cast %353 : i64 to index
            %355 = arith.index_cast %354 : index to i1
            %356 = arith.select %355, %c2_i64, %c3_i64 : i64
            %357 = arith.select %355, %c3_i64, %c4_i64 : i64
            %358 = affine.apply #map7()[%354]
            %359 = arith.index_cast %358 : index to i64
            %360 = affine.apply #map8()[%354]
            %361 = arith.index_cast %360 : index to i64
            %362 = arith.cmpi eq, %353, %c1_i64 : i64
            %363 = arith.select %362, %c24576_i64, %c8192_i64 : i64
            %364 = hivm.hir.pointer_cast(%363) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %365 = arith.select %362, %c110592_i64, %c40960_i64 : i64
            %366 = hivm.hir.pointer_cast(%365) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %367 = arith.select %362, %c73728_i64, %c4096_i64 : i64
            %368 = hivm.hir.pointer_cast(%367) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %369 = arith.select %362, %c43872_i64, %c7488_i64 : i64
            %370 = hivm.hir.pointer_cast(%369) : memref<8x128xf32, #hivm.address_space<ub>>
            %371 = arith.index_cast %333 : i64 to index
            %reinterpret_cast_41 = memref.reinterpret_cast %arg6 to offset: [%371], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %372 = memref.load %reinterpret_cast_41[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %373 = arith.addi %280#1, %c2_i64 : i64
            %374 = arith.muli %372, %c128_i32 : i32
            %375 = arith.index_cast %372 : i32 to index
            %376 = affine.apply #map3()[%34, %375]
            %reinterpret_cast_42 = memref.reinterpret_cast %arg8 to offset: [%376], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %377 = memref.load %reinterpret_cast_42[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %378 = arith.extsi %377 : i32 to i64
            %379 = arith.muli %378, %36 : i64
            %380 = arith.index_cast %379 : i64 to index
            %381 = arith.index_cast %374 : i32 to index
            %382 = affine.apply #map4()[%381]
            %383 = arith.maxsi %381, %88 : index
            %384 = arith.minsi %382, %383 : index
            %385 = affine.apply #map5()[%384, %381]
            %386 = arith.minsi %385, %c128 : index
            %387 = arith.maxsi %386, %c0 : index
            %388 = arith.cmpi slt, %387, %c128 : index
            %389 = arith.ori %388, %97 : i1
            %390 = affine.apply #map6(%387)
            %391 = affine.apply #map9()[%40, %380, %38]
            %reinterpret_cast_43 = memref.reinterpret_cast %arg3 to offset: [%391], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %subview_44 = memref.subview %reinterpret_cast_43[0, 0] [%387, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %subview_45 = memref.subview %366[0, 0, 0, 0] [%100, %390, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %389 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %366 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %357]
            hivm.hir.nd2nz {dst_continuous} ins(%subview_44 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_45 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %356]
            hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%368, %366, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%364 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %357, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %359
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %361
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%364 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%370 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %356]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 1
            %392 = arith.addi %281, %c2_i64 : i64
            memref.store %392, %alloca_0[%c0] : memref<1xi64>
            %393 = arith.remui %392, %c2_i64 : i64
            %394 = arith.index_cast %393 : i64 to index
            %395 = arith.index_cast %394 : index to i1
            %396 = arith.select %395, %c2_i64, %c3_i64 : i64
            %397 = arith.select %395, %c3_i64, %c4_i64 : i64
            %398 = affine.apply #map7()[%394]
            %399 = arith.index_cast %398 : index to i64
            %400 = affine.apply #map8()[%394]
            %401 = arith.index_cast %400 : index to i64
            %402 = arith.cmpi eq, %393, %c1_i64 : i64
            %403 = arith.select %402, %c24576_i64, %c8192_i64 : i64
            %404 = hivm.hir.pointer_cast(%403) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %405 = arith.select %402, %c110592_i64, %c40960_i64 : i64
            %406 = hivm.hir.pointer_cast(%405) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %407 = arith.select %402, %c73728_i64, %c4096_i64 : i64
            %408 = hivm.hir.pointer_cast(%407) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %409 = arith.select %402, %c43872_i64, %c7488_i64 : i64
            %410 = hivm.hir.pointer_cast(%409) : memref<8x128xf32, #hivm.address_space<ub>>
            %411 = arith.index_cast %373 : i64 to index
            %reinterpret_cast_46 = memref.reinterpret_cast %arg6 to offset: [%411], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %412 = memref.load %reinterpret_cast_46[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %413 = arith.muli %412, %c128_i32 : i32
            %414 = arith.index_cast %412 : i32 to index
            %415 = affine.apply #map3()[%34, %414]
            %reinterpret_cast_47 = memref.reinterpret_cast %arg8 to offset: [%415], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %416 = memref.load %reinterpret_cast_47[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %417 = arith.extsi %416 : i32 to i64
            %418 = arith.muli %417, %36 : i64
            %419 = arith.index_cast %418 : i64 to index
            %420 = arith.index_cast %413 : i32 to index
            %421 = affine.apply #map4()[%420]
            %422 = arith.maxsi %420, %88 : index
            %423 = arith.minsi %421, %422 : index
            %424 = affine.apply #map5()[%423, %420]
            %425 = arith.minsi %424, %c128 : index
            %426 = arith.maxsi %425, %c0 : index
            %427 = arith.cmpi slt, %426, %c128 : index
            %428 = arith.ori %427, %97 : i1
            %429 = affine.apply #map6(%426)
            %430 = affine.apply #map9()[%40, %419, %38]
            %reinterpret_cast_48 = memref.reinterpret_cast %arg3 to offset: [%430], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %subview_49 = memref.subview %reinterpret_cast_48[0, 0] [%426, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %subview_50 = memref.subview %406[0, 0, 0, 0] [%100, %429, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %428 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %406 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %397]
            hivm.hir.nd2nz {dst_continuous} ins(%subview_49 : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_50 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %396]
            hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%408, %406, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%404 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %397, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %399
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %401
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%404 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%410 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %396]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 1
            %431 = arith.addi %281, %c3_i64 : i64
            memref.store %431, %alloca_0[%c0] : memref<1xi64>
            %432 = arith.addi %281, %c4_i64 : i64
            memref.store %432, %alloca_0[%c0] : memref<1xi64>
            %433 = arith.addi %281, %c5_i64 : i64
            memref.store %433, %alloca_0[%c0] : memref<1xi64>
          } else {
            %57:2 = scf.for %arg37 = %c0_i32 to %55 step %c1_i32 iter_args(%arg38 = %47, %arg39 = %47) -> (i64, i64)  : i32 {
              %58 = arith.subi %arg37, %c1_i32 : i32
              %59 = arith.subi %arg37, %c3_i32 : i32
              %60 = memref.load %alloca[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
              %61 = arith.remui %60, %c2_i64 : i64
              %62 = arith.index_cast %61 : i64 to index
              %63 = arith.cmpi eq, %61, %c1_i64 : i64
              %64 = arith.select %63, %3, %2 : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
              %65 = arith.select %63, %7, %6 : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
              %66 = arith.index_cast %62 : index to i1
              %67 = arith.select %66, %c2_i64, %c3_i64 : i64
              %68 = arith.select %66, %c3_i64, %c4_i64 : i64
              %69 = arith.xori %66, %true : i1
              %70 = arith.extui %69 : i1 to i64
              %71 = arith.select %66, %c1_i64, %c2_i64 : i64
              %72 = affine.apply #map7()[%62]
              %73 = arith.index_cast %72 : index to i64
              %74 = affine.apply #map8()[%62]
              %75 = arith.index_cast %74 : index to i64
              %76 = affine.apply #map2()[%62]
              %77 = arith.index_cast %76 : index to i64
              %78 = arith.cmpi sge, %58, %c0_i32 : i32
              %79 = arith.cmpi slt, %58, %51 : i32
              %80 = arith.andi %78, %79 : i1
              %81 = scf.if %80 -> (i64) {
                %87 = arith.select %63, %5, %4 : memref<8x1x16x16xf32, #hivm.address_space<cc>>
                %88 = arith.select %63, %9, %8 : memref<8x128xf32, #hivm.address_space<ub>>
                %89 = arith.index_cast %arg38 : i64 to index
                %reinterpret_cast_4 = memref.reinterpret_cast %arg6 to offset: [%89], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %90 = memref.load %reinterpret_cast_4[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %91 = arith.addi %arg38, %c1_i64 : i64
                %92 = arith.muli %90, %c128_i32 : i32
                %93 = arith.index_cast %90 : i32 to index
                %94 = affine.apply #map3()[%34, %93]
                %reinterpret_cast_5 = memref.reinterpret_cast %arg8 to offset: [%94], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %95 = memref.load %reinterpret_cast_5[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %96 = arith.extsi %95 : i32 to i64
                %97 = arith.muli %96, %36 : i64
                %98 = arith.index_cast %97 : i64 to index
                %99 = affine.apply #map3()[%98, %38]
                %100 = arith.index_cast %arg22 : i32 to index
                %reinterpret_cast_6 = memref.reinterpret_cast %arg3 to offset: [%99], sizes: [128, 128], strides: [%100, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
                %101 = arith.index_cast %92 : i32 to index
                %102 = affine.apply #map4()[%101]
                %103 = arith.index_cast %28 : i32 to index
                %104 = arith.maxsi %101, %103 : index
                %105 = arith.minsi %102, %104 : index
                %106 = affine.apply #map5()[%105, %101]
                %107 = arith.minsi %106, %c128 : index
                %108 = arith.maxsi %107, %c0 : index
                %109 = arith.minsi %42, %c128 : index
                %110 = arith.maxsi %109, %c0 : index
                %111 = arith.cmpi slt, %108, %c128 : index
                %112 = arith.cmpi slt, %110, %c128 : index
                %113 = arith.ori %111, %112 : i1
                %subview = memref.subview %reinterpret_cast_6[0, 0] [%108, %110] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
                %114 = affine.apply #map6(%108)
                %115 = affine.apply #map6(%110)
                %subview_7 = memref.subview %65[0, 0, 0, 0] [%115, %114, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
                scf.if %113 {
                  hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                  %collapse_shape = memref.collapse_shape %65 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
                  hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                  hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
                  hivm.hir.pipe_barrier[<PIPE_MTE2>]
                } {hivm.unlikely_condition}
                hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %71]
                hivm.hir.nd2nz {dst_continuous} ins(%subview : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_7 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
                hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
                hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %70]
                hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%52, %65, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%87 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %71, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
                hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
                hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %77
                hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
                hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%87 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%88 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
                hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %70]
                hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
                scf.yield %91 : i64
              } else {
                scf.yield %arg38 : i64
              }
              %82 = arith.cmpi sge, %59, %c0_i32 : i32
              %83 = arith.cmpi slt, %59, %51 : i32
              %84 = arith.andi %82, %83 : i1
              %85 = scf.if %84 -> (i64) {
                %87 = arith.select %63, %1, %0 : memref<8x1x16x16xf32, #hivm.address_space<cc>>
                %88 = arith.select %63, %11, %10 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
                %89 = arith.select %63, %13, %12 : memref<8x128xf32, #hivm.address_space<ub>>
                %90 = arith.index_cast %arg39 : i64 to index
                %reinterpret_cast_4 = memref.reinterpret_cast %arg6 to offset: [%90], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %91 = memref.load %reinterpret_cast_4[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %92 = arith.addi %arg39, %c1_i64 : i64
                %93 = arith.muli %91, %c128_i32 : i32
                %94 = arith.index_cast %91 : i32 to index
                %95 = affine.apply #map3()[%34, %94]
                %reinterpret_cast_5 = memref.reinterpret_cast %arg8 to offset: [%95], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %96 = memref.load %reinterpret_cast_5[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %97 = arith.extsi %96 : i32 to i64
                %98 = arith.muli %97, %36 : i64
                %99 = arith.index_cast %98 : i64 to index
                %100 = arith.index_cast %arg22 : i32 to index
                %101 = arith.index_cast %93 : i32 to index
                %102 = affine.apply #map4()[%101]
                %103 = arith.index_cast %28 : i32 to index
                %104 = arith.maxsi %101, %103 : index
                %105 = arith.minsi %102, %104 : index
                %106 = affine.apply #map5()[%105, %101]
                %107 = arith.minsi %106, %c128 : index
                %108 = arith.maxsi %107, %c0 : index
                %109 = arith.minsi %42, %c128 : index
                %110 = arith.maxsi %109, %c0 : index
                %111 = arith.cmpi slt, %108, %c128 : index
                %112 = arith.cmpi slt, %110, %c128 : index
                %113 = arith.ori %111, %112 : i1
                %114 = affine.apply #map6(%108)
                %115 = affine.apply #map6(%110)
                %116 = affine.apply #map9()[%40, %99, %38]
                %reinterpret_cast_6 = memref.reinterpret_cast %arg3 to offset: [%116], sizes: [128, 128], strides: [%100, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
                %subview = memref.subview %reinterpret_cast_6[0, 0] [%108, %110] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
                %subview_7 = memref.subview %64[0, 0, 0, 0] [%115, %114, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
                scf.if %113 {
                  hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                  %collapse_shape = memref.collapse_shape %64 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
                  hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                  hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
                  hivm.hir.pipe_barrier[<PIPE_MTE2>]
                } {hivm.unlikely_condition}
                hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %68]
                hivm.hir.nd2nz {dst_continuous} ins(%subview : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_7 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
                hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
                hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
                hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %67]
                hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%88, %64, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%87 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %68, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
                hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
                hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %73
                hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %75
                hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
                hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%87 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%89 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
                hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %67]
                hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 1
                scf.yield %92 : i64
              } else {
                scf.yield %arg39 : i64
              }
              %86 = arith.addi %60, %c1_i64 : i64
              memref.store %86, %alloca[%c0] : memref<1xi64>
              scf.yield %81, %85 : i64, i64
            }
          }
          hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 0
        }
        hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
        hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID2>]
        hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID3>]
        hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
        hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID2>]
        hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID3>]
        hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID4>]
      }
      hivm.hir.set_ctrl true at ctrl[60]
    } {autoblockify.subloop}
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = 2
    hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = 3
    hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = 4
    hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = 5
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%arg0: memref<8x128xf32, #hivm.address_space<ub>>, %arg1: memref<8x128xf32, #hivm.address_space<ub>>, %arg2: memref<1x128xf32, #hivm.address_space<ub>>, %arg3: f32, %arg4: memref<8x128xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c1 = arith.constant 1 : index
    %c8 = arith.constant 8 : index
    %c64 = arith.constant 64 : index
    %c128 = arith.constant 128 : index
    %c0 = arith.constant 0 : index
    scf.for %arg5 = %c0 to %c8 step %c1 {
      scf.for %arg6 = %c0 to %c128 step %c64 {
        %subview = memref.subview %arg0[%arg5, %arg6] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_0 = memref.subview %arg1[%arg5, %arg6] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_1 = memref.subview %arg2[0, %arg6] [1, 64] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_2 = memref.subview %arg4[%arg5, %arg6] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_3 = memref.subview %subview[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %res = ave.hir.vload <NORM> %subview_3[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>
        %subview_4 = memref.subview %subview_0[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %res_5 = ave.hir.vload <NORM> %subview_4[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>
        %res_6 = ave.hir.vload <NORM> %subview_1[%c0, %c0] {functionType = #ave.func_dist_type<norm>} : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> into vector<64xf32>
        %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %1 = ave.hir.vmuls %res_5, %arg3, %0 : vector<64xf32>, f32, vector<64xi1>
        %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %3 = ave.hir.vadd %res, %1, %2 : vector<64xf32>, vector<64xi1>
        %4 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %5 = ave.hir.vadd %3, %res_6, %4 : vector<64xf32>, vector<64xi1>
        %subview_7 = memref.subview %subview_2[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %6 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        ave.hir.masked_store <NORM_B32> %subview_7[%c0], %6, %5 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xf32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
      }
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%arg0: memref<8x128xf32, #hivm.address_space<ub>>, %arg1: memref<8x128xi32, #hivm.address_space<ub>>, %arg2: memref<8xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %c8 = arith.constant 8 : index
    %c1 = arith.constant 1 : index
    %cst = arith.constant 0xFF800000 : f32
    %c-2139095040_i32 = arith.constant -2139095040 : i32
    %c1_i32 = arith.constant 1 : i32
    %c0_i32 = arith.constant 0 : i32
    %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %1 = ave.hir.broadcast %c0_i32, %0 : i32, vector<64xi1> -> vector<64xi32>
    %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %3 = ave.hir.broadcast %cst, %2 : f32, vector<64xi1> -> vector<64xf32>
    scf.for %arg3 = %c0 to %c8 step %c1 {
      %subview = memref.subview %arg2[%arg3] [1] [1] : memref<8xf32, #hivm.address_space<ub>> to memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %subview_0 = memref.subview %arg0[%arg3, 0] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_1 = memref.subview %subview_0[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
      %res = ave.hir.vload <NORM> %subview_1[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>
      %4 = vector.bitcast %res : vector<64xf32> to vector<64xi32>
      %subview_2 = memref.subview %arg1[%arg3, 0] [1, 64] [1, 1] : memref<8x128xi32, #hivm.address_space<ub>> to memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_3 = memref.subview %subview_2[0, 0] [1, 64] [1, 1] : memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xi32, #map, #hivm.address_space<ub>>
      %res_4 = ave.hir.vload <NORM> %subview_3[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xi32, #map, #hivm.address_space<ub>> into vector<64xi32>
      %5 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %6 = ave.hir.vand %4, %res_4, %5 : vector<64xi32>, vector<64xi1>
      %7 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %8 = ave.hir.vadds %6, %c-2139095040_i32, %7 : vector<64xi32>, i32, vector<64xi1>
      %9 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %10 = ave.hir.vsmins %8, %c1_i32, %9 : vector<64xi32>, i32, vector<64xi1>
      %11 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %12 = ave.hir.vsmaxs %10, %c0_i32, %11 : vector<64xi32>, i32, vector<64xi1>
      %13 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %14 = ave.hir.vcmp <NE> %12, %1, %13 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
      %15 = ave.hir.vsel %14, %3, %res : vector<64xi1>, vector<64xf32>
      %subview_5 = memref.subview %arg0[%arg3, 64] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_6 = memref.subview %subview_5[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
      %res_7 = ave.hir.vload <NORM> %subview_6[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>
      %16 = vector.bitcast %res_7 : vector<64xf32> to vector<64xi32>
      %subview_8 = memref.subview %arg1[%arg3, 64] [1, 64] [1, 1] : memref<8x128xi32, #hivm.address_space<ub>> to memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_9 = memref.subview %subview_8[0, 0] [1, 64] [1, 1] : memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xi32, #map, #hivm.address_space<ub>>
      %res_10 = ave.hir.vload <NORM> %subview_9[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xi32, #map, #hivm.address_space<ub>> into vector<64xi32>
      %17 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %18 = ave.hir.vand %16, %res_10, %17 : vector<64xi32>, vector<64xi1>
      %19 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %20 = ave.hir.vadds %18, %c-2139095040_i32, %19 : vector<64xi32>, i32, vector<64xi1>
      %21 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %22 = ave.hir.vsmins %20, %c1_i32, %21 : vector<64xi32>, i32, vector<64xi1>
      %23 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %24 = ave.hir.vsmaxs %22, %c0_i32, %23 : vector<64xi32>, i32, vector<64xi1>
      %25 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %26 = ave.hir.vcmp <NE> %24, %1, %25 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
      %27 = ave.hir.vsel %26, %3, %res_7 : vector<64xi1>, vector<64xf32>
      %28 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %29 = ave.hir.vmax %27, %15, %28 {reductionOp} : vector<64xf32>, vector<64xi1>
      %subview_11 = memref.subview %subview[0] [1] [1] : memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>> to memref<f32, strided<[], offset: ?>, #hivm.address_space<ub>>
      %30 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %31 = ave.hir.reduction <max>, %29, %30 : vector<64xf32>, vector<64xi1> -> vector<64xf32>
      %32 = builtin.unrealized_conversion_cast %31 : vector<64xf32> to vector<1xf32>
      %33 = ave.hir.pge <VL1> {functionType = #ave.func_dist_type<pb32>} : vector<1xi1>
      ave.hir.masked_store <ONEPT_B32> %subview_11[], %33, %32 {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<f32, strided<[], offset: ?>, #hivm.address_space<ub>>, vector<1xi1>, vector<1xf32>
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%arg0: memref<8xf32, #hivm.address_space<ub>>, %arg1: memref<8xf32, #hivm.address_space<ub>>, %arg2: memref<8xi32, #hivm.address_space<ub>>, %arg3: memref<8xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %c-2139095040_i32 = arith.constant -2139095040 : i32
    %c1_i32 = arith.constant 1 : i32
    %c0_i32 = arith.constant 0 : i32
    %cst = arith.constant 0xFF800000 : f32
    %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %1 = ave.hir.broadcast %cst, %0 : f32, vector<64xi1> -> vector<64xf32>
    %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %3 = ave.hir.broadcast %c0_i32, %2 : i32, vector<64xi1> -> vector<64xi32>
    %4 = ave.hir.pge <VL8> {functionType = #ave.func_dist_type<pb32>, mask_op_idx = 0 : i32} : vector<64xi1>
    %res = ave.hir.vload <NORM> %arg1[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %5 = vector.bitcast %res : vector<64xf32> to vector<64xi32>
    %res_0 = ave.hir.vload <NORM> %arg2[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xi32, #hivm.address_space<ub>> into vector<64xi32>
    %6 = ave.hir.vand %5, %res_0, %4 : vector<64xi32>, vector<64xi1>
    %res_1 = ave.hir.vload <NORM> %arg0[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %7 = ave.hir.vadds %6, %c-2139095040_i32, %4 : vector<64xi32>, i32, vector<64xi1>
    %8 = ave.hir.vsmins %7, %c1_i32, %4 : vector<64xi32>, i32, vector<64xi1>
    %9 = ave.hir.vsmaxs %8, %c0_i32, %4 : vector<64xi32>, i32, vector<64xi1>
    %10 = ave.hir.vcmp <NE> %9, %3, %4 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
    %11 = ave.hir.vsel %10, %1, %res : vector<64xi1>, vector<64xf32>
    %12 = ave.hir.vmax %res_1, %11, %4 : vector<64xf32>, vector<64xi1>
    ave.hir.masked_store <NORM_B32> %arg3[%c0], %4, %12 {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%arg0: memref<8xf32, #hivm.address_space<ub>>, %arg1: memref<8x128xf32, #hivm.address_space<ub>>, %arg2: memref<8xf32, #hivm.address_space<ub>>, %arg3: memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c272 = arith.constant 272 : index
    %c0 = arith.constant 0 : index
    %c8 = arith.constant 8 : index
    %c1 = arith.constant 1 : index
    %cst = arith.constant 0.693147182 : f32
    scf.for %arg4 = %c0 to %c8 step %c1 {
      %subview = memref.subview %arg2[%arg4] [1] [1] : memref<8xf32, #hivm.address_space<ub>> to memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %subview_0 = memref.subview %arg0[%arg4] [1] [1] : memref<8xf32, #hivm.address_space<ub>> to memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %res = ave.hir.vload <BRC_B32> %subview_0[%c0] {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>} : memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xf32>
      %subview_1 = memref.subview %arg1[%arg4, 0] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_2 = memref.subview %subview_1[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
      %res_3, %res1 = ave.hir.vload <DINTLV_B32> %subview_2[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>, vector<64xf32>
      %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %1 = ave.hir.vsub %res_3, %res, %0 : vector<64xf32>, vector<64xi1>
      %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %3 = ave.hir.vmuls %1, %cst, %2 : vector<64xf32>, f32, vector<64xi1>
      %4 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %5 = ave.hir.vexp %3, %4 : vector<64xf32>, vector<64xi1>
      %6 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %subview_4 = memref.subview %arg3[0, %arg4, 0] [4, 1, 16] [1, 1, 1] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> to memref<4x1x16xbf16, strided<[272, 16, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_5 = memref.subview %subview_4[0, 0, 0] [4, 1, 16] [1, 1, 1] : memref<4x1x16xbf16, strided<[272, 16, 1], offset: ?>, #hivm.address_space<ub>> to memref<4x16xbf16, #map10, #hivm.address_space<ub>>
      %7 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %8 = ave.hir.vsub %res1, %res, %7 : vector<64xf32>, vector<64xi1>
      %9 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %10 = ave.hir.vmuls %8, %cst, %9 : vector<64xf32>, f32, vector<64xi1>
      %11 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %12 = ave.hir.vexp %10, %11 : vector<64xf32>, vector<64xi1>
      %13 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %14 = ave.hir.vadd %12, %5, %13 {reductionOp} : vector<64xf32>, vector<64xi1>
      %15 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %16 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb16>} : vector<128xi1>
      %17 = ave.hir.vtruncf %5, <rint>, false, <part_even>, %6 {functionType = #ave.func_dist_type<c2c>, layout_change = #ave<layout_change DENSE>} : vector<64xf32>, vector<128xbf16>, vector<64xi1>
      %18 = ave.hir.vtruncf %12, <rint>, false, <part_odd>, %15 {functionType = #ave.func_dist_type<c2c>, layout_change = #ave<layout_change DENSE>} : vector<64xf32>, vector<128xbf16>, vector<64xi1>
      %19 = ave.hir.vor %17, %18, %16 : vector<128xbf16>, vector<128xi1>
      ave.hir.store_with_stride %subview_5[%c0, %c0], %c272, %16, %19 {functionType = #ave.func_dist_type<norm>} : memref<4x16xbf16, #map10, #hivm.address_space<ub>>, vector<128xi1>, vector<128xbf16>
      %subview_6 = memref.subview %subview[0] [1] [1] : memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>> to memref<f32, strided<[], offset: ?>, #hivm.address_space<ub>>
      %20 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %21 = ave.hir.reduction <add>, %14, %20 : vector<64xf32>, vector<64xi1> -> vector<64xf32>
      %22 = builtin.unrealized_conversion_cast %21 : vector<64xf32> to vector<1xf32>
      %23 = ave.hir.pge <VL1> {functionType = #ave.func_dist_type<pb32>} : vector<1xi1>
      ave.hir.masked_store <ONEPT_B32> %subview_6[], %23, %22 {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<f32, strided<[], offset: ?>, #hivm.address_space<ub>>, vector<1xi1>, vector<1xf32>
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%arg0: memref<8xf32, #hivm.address_space<ub>>, %arg1: memref<8xf32, #hivm.address_space<ub>>, %arg2: memref<8xf32, #hivm.address_space<ub>>, %arg3: memref<8xf32, #hivm.address_space<ub>>, %arg4: memref<8xf32, #hivm.address_space<ub>>, %arg5: memref<8xf32, #hivm.address_space<ub>>, %arg6: memref<8xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %cst = arith.constant 0.693147182 : f32
    %0 = ave.hir.pge <VL8> {functionType = #ave.func_dist_type<pb32>, mask_op_idx = 0 : i32} : vector<64xi1>
    %res = ave.hir.vload <NORM> %arg0[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %res_0 = ave.hir.vload <NORM> %arg1[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %1 = ave.hir.vsub %res, %res_0, %0 : vector<64xf32>, vector<64xi1>
    %2 = ave.hir.vmuls %1, %cst, %0 : vector<64xf32>, f32, vector<64xi1>
    %3 = ave.hir.vexp %2, %0 : vector<64xf32>, vector<64xi1>
    ave.hir.masked_store <NORM_B32> %arg5[%c0], %0, %3 {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    %res_1 = ave.hir.vload <NORM> %arg2[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %res_2 = ave.hir.vload <NORM> %arg3[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %res_3 = ave.hir.vload <NORM> %arg4[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %4 = ave.hir.vsub %res_1, %res_0, %0 : vector<64xf32>, vector<64xi1>
    %5 = ave.hir.vmuls %4, %cst, %0 : vector<64xf32>, f32, vector<64xi1>
    %6 = ave.hir.vexp %5, %0 : vector<64xf32>, vector<64xi1>
    %7 = ave.hir.vadd %6, %res_2, %0 : vector<64xf32>, vector<64xi1>
    %8 = ave.hir.vln %7, %0 : vector<64xf32>, vector<64xi1>
    %9 = ave.hir.vdiv %8, %res_3, %0 : vector<64xf32>, vector<64xi1>
    %10 = ave.hir.vadd %res_0, %9, %0 : vector<64xf32>, vector<64xi1>
    ave.hir.masked_store <NORM_B32> %arg6[%c0], %0, %10 {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%arg0: memref<8xf32, #hivm.address_space<ub>>, %arg1: memref<8x128xf32, #hivm.address_space<ub>>, %arg2: memref<8x128xf32, #hivm.address_space<ub>>, %arg3: memref<8x128xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c1 = arith.constant 1 : index
    %c8 = arith.constant 8 : index
    %c64 = arith.constant 64 : index
    %c128 = arith.constant 128 : index
    %c0 = arith.constant 0 : index
    scf.for %arg4 = %c0 to %c8 step %c1 {
      %subview = memref.subview %arg0[%arg4] [1] [1] : memref<8xf32, #hivm.address_space<ub>> to memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %res = ave.hir.vload <BRC_B32> %subview[%c0] {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>} : memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xf32>
      scf.for %arg5 = %c0 to %c128 step %c64 {
        %subview_0 = memref.subview %arg1[%arg4, %arg5] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_1 = memref.subview %arg2[%arg4, %arg5] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_2 = memref.subview %arg3[%arg4, %arg5] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_3 = memref.subview %subview_0[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %res_4 = ave.hir.vload <NORM> %subview_3[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>
        %subview_5 = memref.subview %subview_1[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %res_6 = ave.hir.vload <NORM> %subview_5[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>
        %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %1 = ave.hir.vmul %res_6, %res, %0 : vector<64xf32>, vector<64xi1>
        %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %3 = ave.hir.vadd %res_4, %1, %2 : vector<64xf32>, vector<64xi1>
        %subview_7 = memref.subview %subview_2[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %4 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        ave.hir.masked_store <NORM_B32> %subview_7[%c0], %4, %3 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xf32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
      }
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_8_outlined_vf_0(%arg0: memref<1x128xi32, #hivm.address_space<ub>>, %arg1: i32, %arg2: memref<1x128xi32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c64 = arith.constant 64 : index
    %c128 = arith.constant 128 : index
    %c0 = arith.constant 0 : index
    scf.for %arg3 = %c0 to %c128 step %c64 {
      %subview = memref.subview %arg0[0, %arg3] [1, 64] [1, 1] : memref<1x128xi32, #hivm.address_space<ub>> to memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_0 = memref.subview %arg2[0, %arg3] [1, 64] [1, 1] : memref<1x128xi32, #hivm.address_space<ub>> to memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_1 = memref.subview %subview[0, 0] [1, 64] [1, 1] : memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xi32, #map, #hivm.address_space<ub>>
      %res = ave.hir.vload <NORM> %subview_1[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xi32, #map, #hivm.address_space<ub>> into vector<64xi32>
      %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %1 = ave.hir.vadds %res, %arg1, %0 : vector<64xi32>, i32, vector<64xi1>
      %subview_2 = memref.subview %subview_0[0, 0] [1, 64] [1, 1] : memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xi32, #map, #hivm.address_space<ub>>
      %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      ave.hir.masked_store <NORM_B32> %subview_2[%c0], %2, %1 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xi32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi32>
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_9_outlined_vf_0(%arg0: memref<8x128xbf16, #hivm.address_space<ub>>, %arg1: memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c272 = arith.constant 272 : index
    %c1 = arith.constant 1 : index
    %c8 = arith.constant 8 : index
    %c0 = arith.constant 0 : index
    scf.for %arg2 = %c0 to %c8 step %c1 {
      %subview = memref.subview %arg0[%arg2, 0] [1, 128] [1, 1] : memref<8x128xbf16, #hivm.address_space<ub>> to memref<1x128xbf16, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_0 = memref.subview %arg1[0, %arg2, 0] [8, 1, 16] [1, 1, 1] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> to memref<8x1x16xbf16, strided<[272, 16, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_1 = memref.subview %subview[0, 0] [1, 128] [1, 1] : memref<1x128xbf16, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<128xbf16, #map, #hivm.address_space<ub>>
      %res = ave.hir.vload <NORM> %subview_1[%c0] {functionType = #ave.func_dist_type<norm>} : memref<128xbf16, #map, #hivm.address_space<ub>> into vector<128xbf16>
      %subview_2 = memref.subview %subview_0[0, 0, 0] [8, 1, 16] [1, 1, 1] : memref<8x1x16xbf16, strided<[272, 16, 1], offset: ?>, #hivm.address_space<ub>> to memref<8x16xbf16, #map10, #hivm.address_space<ub>>
      %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb16>} : vector<128xi1>
      ave.hir.store_with_stride %subview_2[%c0, %c0], %c272, %0, %res {functionType = #ave.func_dist_type<norm>} : memref<8x16xbf16, #map10, #hivm.address_space<ub>>, vector<128xi1>, vector<128xbf16>
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_10_outlined_vf_0(%arg0: memref<8xf32, #hivm.address_space<ub>>, %arg1: memref<8xf32, #hivm.address_space<ub>>, %arg2: memref<8x128xf32, #hivm.address_space<ub>>, %arg3: memref<8x128xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %c128 = arith.constant 128 : index
    %c64 = arith.constant 64 : index
    %c8 = arith.constant 8 : index
    %c1 = arith.constant 1 : index
    %cst = arith.constant 0.693147182 : f32
    scf.for %arg4 = %c0 to %c8 step %c1 {
      %subview = memref.subview %arg0[%arg4] [1] [1] : memref<8xf32, #hivm.address_space<ub>> to memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %subview_0 = memref.subview %arg1[%arg4] [1] [1] : memref<8xf32, #hivm.address_space<ub>> to memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %res = ave.hir.vload <BRC_B32> %subview[%c0] {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>} : memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xf32>
      %res_1 = ave.hir.vload <BRC_B32> %subview_0[%c0] {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>} : memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xf32>
      %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %1 = ave.hir.vsub %res, %res_1, %0 : vector<64xf32>, vector<64xi1>
      %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %3 = ave.hir.vmuls %1, %cst, %2 : vector<64xf32>, f32, vector<64xi1>
      %4 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %5 = ave.hir.vexp %3, %4 : vector<64xf32>, vector<64xi1>
      scf.for %arg5 = %c0 to %c128 step %c64 {
        %subview_2 = memref.subview %arg2[%arg4, %arg5] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_3 = memref.subview %arg3[%arg4, %arg5] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_4 = memref.subview %subview_2[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %res_5 = ave.hir.vload <NORM> %subview_4[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>
        %6 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %7 = ave.hir.vmul %res_5, %5, %6 : vector<64xf32>, vector<64xi1>
        %subview_6 = memref.subview %subview_3[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %8 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        ave.hir.masked_store <NORM_B32> %subview_6[%c0], %8, %7 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xf32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
      }
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_11_outlined_vf_0(%arg0: memref<1x128xi32, #hivm.address_space<ub>>, %arg1: memref<1x128xi32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %c128 = arith.constant 128 : index
    %c64 = arith.constant 64 : index
    %c-1_i32 = arith.constant -1 : i32
    scf.for %arg2 = %c0 to %c128 step %c64 {
      %subview = memref.subview %arg0[0, %arg2] [1, 64] [1, 1] : memref<1x128xi32, #hivm.address_space<ub>> to memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_0 = memref.subview %arg1[0, %arg2] [1, 64] [1, 1] : memref<1x128xi32, #hivm.address_space<ub>> to memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_1 = memref.subview %subview[0, 0] [1, 64] [1, 1] : memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xi32, #map, #hivm.address_space<ub>>
      %res = ave.hir.vload <NORM> %subview_1[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xi32, #map, #hivm.address_space<ub>> into vector<64xi32>
      %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %1 = ave.hir.vmuls %res, %c-1_i32, %0 : vector<64xi32>, i32, vector<64xi1>
      %subview_2 = memref.subview %subview_0[0, 0] [1, 64] [1, 1] : memref<1x64xi32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xi32, #map, #hivm.address_space<ub>>
      %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      ave.hir.masked_store <NORM_B32> %subview_2[%c0], %2, %1 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xi32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi32>
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_12_outlined_vf_0(%arg0: memref<1xf32, #hivm.address_space<ub>>, %arg1: memref<1xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %cst = arith.constant 1.44269502 : f32
    %0 = ave.hir.pge <VL1> {functionType = #ave.func_dist_type<pb32>, mask_op_idx = 0 : i32} : vector<64xi1>
    %res = ave.hir.vload <BRC_B32> %arg0[%c0] {functionType = #ave.func_dist_type<norm>} : memref<1xf32, #hivm.address_space<ub>> into vector<64xf32>
    %1 = ave.hir.vmuls %res, %cst, %0 : vector<64xf32>, f32, vector<64xi1>
    ave.hir.masked_store <ONEPT_B32> %arg1[%c0], %0, %1 {functionType = #ave.func_dist_type<norm>} : memref<1xf32, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_0(%arg0: memref<1x8x128xbf16, #hivm.address_space<ub>>) attributes {hfusion.has_fill, hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %c8 = arith.constant 8 : index
    %c1 = arith.constant 1 : index
    %cst = arith.constant 0.000000e+00 : bf16
    %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb16>} : vector<128xi1>
    %1 = ave.hir.broadcast %cst, %0 : bf16, vector<128xi1> -> vector<128xbf16>
    scf.for %arg1 = %c0 to %c8 step %c1 {
      %subview = memref.subview %arg0[0, %arg1, 0] [1, 1, 128] [1, 1, 1] : memref<1x8x128xbf16, #hivm.address_space<ub>> to memref<1x1x128xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_0 = memref.subview %subview[0, 0, 0] [1, 1, 128] [1, 1, 1] : memref<1x1x128xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>> to memref<128xbf16, #map, #hivm.address_space<ub>>
      %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb16>} : vector<128xi1>
      ave.hir.masked_store <NORM_B16> %subview_0[%c0], %2, %1 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<128xbf16, #map, #hivm.address_space<ub>>, vector<128xi1>, vector<128xbf16>
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_2(%arg0: memref<8x128xf32, #hivm.address_space<ub>>) attributes {hfusion.has_fill, hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %c128 = arith.constant 128 : index
    %c64 = arith.constant 64 : index
    %c8 = arith.constant 8 : index
    %c1 = arith.constant 1 : index
    %cst = arith.constant 0.000000e+00 : f32
    %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %1 = ave.hir.broadcast %cst, %0 : f32, vector<64xi1> -> vector<64xf32>
    scf.for %arg1 = %c0 to %c8 step %c1 {
      scf.for %arg2 = %c0 to %c128 step %c64 {
        %subview = memref.subview %arg0[%arg1, %arg2] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_0 = memref.subview %subview[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        ave.hir.masked_store <NORM_B32> %subview_0[%c0], %2, %1 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xf32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
      }
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_3(%arg0: memref<1x8x128xf32, #hivm.address_space<ub>>, %arg1: memref<1x8x128xbf16, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c1 = arith.constant 1 : index
    %c8 = arith.constant 8 : index
    %c64 = arith.constant 64 : index
    %c128 = arith.constant 128 : index
    %c0 = arith.constant 0 : index
    scf.for %arg2 = %c0 to %c8 step %c1 {
      scf.for %arg3 = %c0 to %c128 step %c64 {
        %subview = memref.subview %arg0[0, %arg2, %arg3] [1, 1, 64] [1, 1, 1] : memref<1x8x128xf32, #hivm.address_space<ub>> to memref<1x1x64xf32, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_0 = memref.subview %arg1[0, %arg2, %arg3] [1, 1, 64] [1, 1, 1] : memref<1x8x128xbf16, #hivm.address_space<ub>> to memref<1x1x64xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_1 = memref.subview %subview[0, 0, 0] [1, 1, 64] [1, 1, 1] : memref<1x1x64xf32, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %res = ave.hir.vload <NORM> %subview_1[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>
        %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %1 = ave.hir.vtruncf %res, <rint>, false, <part_even>, %0 {functionType = #ave.func_dist_type<even>} : vector<64xf32>, vector<64xbf16>, vector<64xi1>
        %subview_2 = memref.subview %subview_0[0, 0, 0] [1, 1, 64] [1, 1, 1] : memref<1x1x64xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xbf16, #map, #hivm.address_space<ub>>
        %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %3 = builtin.unrealized_conversion_cast %1 : vector<64xbf16> to vector<128xbf16>
        %4 = llvm.bitcast %3 : vector<128xbf16> to vector<64xf32>
        ave.hir.masked_store <PK_B32> %subview_2[%c0], %2, %4 {functionType = #ave.func_dist_type<pk>, hivm.is_continuous} : memref<64xbf16, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
      }
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_4(%arg0: memref<128xi32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %c128 = arith.constant 128 : index
    %c64 = arith.constant 64 : index
    %c0_i32 = arith.constant 0 : i32
    %0 = ave.hir.vci %c0_i32, <INCREASE> : i32, vector<64xi32>
    scf.for %arg1 = %c0 to %c128 step %c64 {
      %subview = memref.subview %arg0[%arg1] [64] [1] : memref<128xi32, #hivm.address_space<ub>> to memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %1 = arith.index_cast %arg1 : index to i32
      %2 = ave.hir.scalar_broadcast %1 : i32 -> vector<64xi32>
      %3 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %4 = ave.hir.vadd %2, %0, %3 : vector<64xi32>, vector<64xi1>
      %5 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      ave.hir.masked_store <NORM_B32> %subview[%c0], %5, %4 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi32>
    }
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_5(%arg0: memref<8xf32, #hivm.address_space<ub>>) attributes {hfusion.has_fill, hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %cst = arith.constant 0xFF800000 : f32
    %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %1 = ave.hir.broadcast %cst, %0 : f32, vector<64xi1> -> vector<64xf32>
    %2 = ave.hir.pge <VL8> {functionType = #ave.func_dist_type<pb32>, mask_op_idx = 0 : i32} : vector<64xi1>
    ave.hir.masked_store <NORM_B32> %arg0[%c0], %2, %1 {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv(%arg0: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg1: memref<?xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<?xbf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xbf16, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xbf16, #hivm.address_space<gm>>, %arg5: memref<?xbf16, #hivm.address_space<gm>>, %arg6: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg7: memref<?xbf16, #hivm.address_space<gm>> {tt.tensor_kind = 1 : i32}, %arg8: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg9: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg10: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg11: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg12: memref<?xi32, #hivm.address_space<gm>> {tt.tensor_kind = 0 : i32}, %arg13: i32, %arg14: i32, %arg15: i32, %arg16: i32, %arg17: f32, %arg18: i32, %arg19: i32, %arg20: i32, %arg21: i32, %arg22: i32, %arg23: i32, %arg24: i32, %arg25: i32, %arg26: i32, %arg27: i32, %arg28: i32, %arg29: i32, %arg30: i32, %arg31: i32, %arg32: i32, %arg33: i32, %arg34: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, func_dyn_memref_args = dense<[true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]> : vector<35xi1>, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.part_of_mix, hivm.vf_mode = #hivm.vf_mode<SIMD>, mix_mode = "mix", parallel_mode = "simd"} {
    %c5_i64 = arith.constant 5 : i64
    %c4_i64 = arith.constant 4 : i64
    %c52128_i64 = arith.constant 52128 : i64
    %c37728_i64 = arith.constant 37728 : i64
    %c576_i64 = arith.constant 576 : i64
    %c41824_i64 = arith.constant 41824 : i64
    %c52096_i64 = arith.constant 52096 : i64
    %c24544_i64 = arith.constant 24544 : i64
    %c52064_i64 = arith.constant 52064 : i64
    %c47968_i64 = arith.constant 47968 : i64
    %c11584_i64 = arith.constant 11584 : i64
    %c73728_i64 = arith.constant 73728 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c43872_i64 = arith.constant 43872 : i64
    %c7488_i64 = arith.constant 7488 : i64
    %c10_i32 = arith.constant 10 : i32
    %c3_i64 = arith.constant 3 : i64
    %c1 = arith.constant 1 : index
    %c28_i32 = arith.constant 28 : i32
    %c1_i32 = arith.constant 1 : i32
    %c1_i64 = arith.constant 1 : i64
    %c128_i32 = arith.constant 128 : i32
    %c0_i32 = arith.constant 0 : i32
    %cst = arith.constant 0.000000e+00 : bf16
    %c16 = arith.constant 16 : index
    %c128 = arith.constant 128 : index
    %c8 = arith.constant 8 : index
    %c32_i64 = arith.constant 32 : i64
    %c64_i64 = arith.constant 64 : i64
    %c2624_i64 = arith.constant 2624 : i64
    %c3136_i64 = arith.constant 3136 : i64
    %c33632_i64 = arith.constant 33632 : i64
    %c33600_i64 = arith.constant 33600 : i64
    %c33568_i64 = arith.constant 33568 : i64
    %c15680_i64 = arith.constant 15680 : i64
    %c24576_i64 = arith.constant 24576 : i64
    %c19776_i64 = arith.constant 19776 : i64
    %c20288_i64 = arith.constant 20288 : i64
    %c20320_i64 = arith.constant 20320 : i64
    %c20352_i64 = arith.constant 20352 : i64
    %c20384_i64 = arith.constant 20384 : i64
    %c24480_i64 = arith.constant 24480 : i64
    %c24512_i64 = arith.constant 24512 : i64
    %c25088_i64 = arith.constant 25088 : i64
    %c29184_i64 = arith.constant 29184 : i64
    %c29216_i64 = arith.constant 29216 : i64
    %c2_i64 = arith.constant 2 : i64
    %c5_i32 = arith.constant 5 : i32
    %c2_i32 = arith.constant 2 : i32
    %c4_i32 = arith.constant 4 : i32
    %c0 = arith.constant 0 : index
    %c0_i64 = arith.constant 0 : i64
    %alloca = memref.alloca() : memref<1xi64>
    memref.store %c0_i64, %alloca[%c0] : memref<1xi64>
    %alloca_0 = memref.alloca() : memref<1xi64>
    memref.store %c0_i64, %alloca_0[%c0] : memref<1xi64>
    %0 = hivm.hir.pointer_cast(%c37728_i64) : memref<1x8x128xbf16, #hivm.address_space<ub>>
    %1 = hivm.hir.pointer_cast(%c52128_i64) : memref<1x8x128xbf16, #hivm.address_space<ub>>
    %2 = hivm.hir.pointer_cast(%c576_i64) : memref<1x8x128xbf16, #hivm.address_space<ub>>
    %3 = hivm.hir.pointer_cast(%c41824_i64) : memref<1x8x128xbf16, #hivm.address_space<ub>>
    %4 = hivm.hir.pointer_cast(%c24544_i64) : memref<8xf32, #hivm.address_space<ub>>
    %5 = hivm.hir.pointer_cast(%c52064_i64) : memref<8xf32, #hivm.address_space<ub>>
    %6 = hivm.hir.pointer_cast(%c52096_i64) : memref<8xf32, #hivm.address_space<ub>>
    %7 = hivm.hir.pointer_cast(%c52064_i64) : memref<8xf32, #hivm.address_space<ub>>
    %8 = hivm.hir.pointer_cast(%c52096_i64) : memref<8xf32, #hivm.address_space<ub>>
    %9 = hivm.hir.pointer_cast(%c24544_i64) : memref<8xf32, #hivm.address_space<ub>>
    %10 = hivm.hir.pointer_cast(%c47968_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %11 = hivm.hir.pointer_cast(%c11584_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %12 = hivm.hir.pointer_cast(%c73728_i64) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
    %13 = hivm.hir.pointer_cast(%c4096_i64) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
    %14 = hivm.hir.pointer_cast(%c43872_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %15 = hivm.hir.pointer_cast(%c7488_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %16 = hivm.hir.pointer_cast(%c37728_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %17 = hivm.hir.pointer_cast(%c52128_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %alloca_1 = memref.alloca() : memref<1xi64>
    memref.store %c0_i64, %alloca_1[%c0] : memref<1xi64>
    %18 = arith.muli %arg32, %arg33 : i32
    %19 = arith.muli %18, %arg34 : i32
    %20 = hivm.hir.get_block_idx -> i64
    %21 = arith.trunci %20 : i64 to i32
    %22 = hivm.hir.pointer_cast(%c0_i64) : memref<1xf32, #hivm.address_space<ub>>
    memref.store %arg17, %22[%c0] : memref<1xf32, #hivm.address_space<ub>>
    hivm.hir.set_flag[<PIPE_S>, <PIPE_V>, <EVENT_ID0>]
    %23 = hivm.hir.get_sub_block_idx -> i64
    %24 = arith.index_cast %23 : i64 to index
    %25 = affine.apply #map11()[%24]
    %26 = hivm.hir.pointer_cast(%c32_i64) : memref<8xf32, #hivm.address_space<ub>>
    call @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_5(%26) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>) -> ()
    %27 = hivm.hir.pointer_cast(%c0_i64) : memref<1xf32, #hivm.address_space<ub>>
    hivm.hir.wait_flag[<PIPE_S>, <PIPE_V>, <EVENT_ID0>]
    call @_gqa_sparse_fwd_kernel_mix_aiv_fused_12_outlined_vf_0(%22, %27) {hivm.vector_function, no_inline} : (memref<1xf32, #hivm.address_space<ub>>, memref<1xf32, #hivm.address_space<ub>>) -> ()
    hivm.hir.set_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
    %28 = memref.load %27[%c0] {"DuplicateTensorExtractForCube::visitedLabel" = 1 : i32, markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xf32, #hivm.address_space<ub>>
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = 2
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = 3
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = 4
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = 5
    scf.for %arg35 = %21 to %19 step %c28_i32  : i32 {
      hivm.hir.set_ctrl false at ctrl[60]
      hivm.hir.set_ctrl true at ctrl[48]
      %29 = arith.remsi %arg35, %arg32 : i32
      %30 = arith.divsi %arg35, %arg32 : i32
      %31 = arith.remsi %30, %arg33 : i32
      %32 = arith.divsi %arg35, %18 : i32
      %33 = arith.remsi %32, %arg34 : i32
      %34 = arith.muli %31, %arg14 : i32
      %35 = arith.index_cast %33 : i32 to index
      %reinterpret_cast = memref.reinterpret_cast %arg9 to offset: [%35], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %36 = affine.apply #map1()[%35]
      %37 = memref.load %reinterpret_cast[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_2 = memref.reinterpret_cast %arg9 to offset: [%36], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %38 = memref.load %reinterpret_cast_2[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %39 = arith.subi %38, %37 : i32
      %reinterpret_cast_3 = memref.reinterpret_cast %arg10 to offset: [%35], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %40 = memref.load %reinterpret_cast_3[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_4 = memref.reinterpret_cast %arg10 to offset: [%36], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %41 = memref.load %reinterpret_cast_4[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %42 = arith.subi %41, %40 : i32
      %reinterpret_cast_5 = memref.reinterpret_cast %arg11 to offset: [%35], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %43 = memref.load %reinterpret_cast_5[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_6 = memref.reinterpret_cast %arg12 to offset: [%35], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %44 = memref.load %reinterpret_cast_6[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %45 = arith.cmpi sge, %29, %42 : i32
      scf.if %45 {
      } else {
        %46 = arith.subi %42, %29 : i32
        %47 = arith.minsi %46, %c1_i32 : i32
        %48 = hivm.hir.pointer_cast(%c64_i64) : memref<128xi32, #hivm.address_space<ub>>
        func.call @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_4(%48) {hivm.vector_function, no_inline} : (memref<128xi32, #hivm.address_space<ub>>) -> ()
        %49 = arith.muli %31, %arg27 : i32
        %50 = arith.muli %37, %arg18 : i32
        %51 = arith.index_cast %50 : i32 to index
        %52 = arith.muli %34, %arg19 : i32
        %53 = arith.index_cast %52 : i32 to index
        %expand_shape = memref.expand_shape %48 [[0, 1]] output_shape [1, 128] : memref<128xi32, #hivm.address_space<ub>> into memref<1x128xi32, #hivm.address_space<ub>>
        %54 = arith.muli %37, %arg29 : i32
        %55 = arith.index_cast %54 : i32 to index
        %56 = arith.muli %34, %arg30 : i32
        %57 = arith.index_cast %56 : i32 to index
        %58 = arith.extsi %49 : i32 to i64
        %59 = arith.index_cast %arg18 : i32 to index
        %60 = arith.index_cast %arg19 : i32 to index
        %61 = arith.index_cast %39 : i32 to index
        %62 = arith.index_cast %arg14 : i32 to index
        %63 = arith.index_cast %arg15 : i32 to index
        %64 = arith.maxsi %59, %c1 : index
        %65 = arith.maxsi %62, %c0 : index
        %66 = arith.minsi %65, %c16 : index
        %67 = arith.maxsi %63, %c0 : index
        %68 = arith.minsi %67, %c128 : index
        %69 = arith.minsi %66, %c0 : index
        %70 = affine.apply #map5()[%66, %69]
        %71 = arith.minsi %68, %c0 : index
        %72 = affine.apply #map5()[%68, %71]
        %73 = arith.cmpi slt, %70, %c16 : index
        %74 = arith.cmpi slt, %72, %c128 : index
        %75 = arith.remui %71, %c16 : index
        %76 = hivm.hir.pointer_cast(%c64_i64) : memref<1x128xi32, #hivm.address_space<ub>>
        func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_11_outlined_vf_0(%expand_shape, %76) {hivm.vector_function, no_inline} : (memref<1x128xi32, #hivm.address_space<ub>>, memref<1x128xi32, #hivm.address_space<ub>>) -> ()
        %77 = arith.index_cast %arg29 : i32 to index
        %78 = arith.index_cast %arg30 : i32 to index
        %79 = arith.maxsi %77, %c1 : index
        %80 = arith.minsi %25, %70 : index
        %81 = affine.apply #map12()[%80, %66, %69]
        %82 = arith.minsi %81, %c8 : index
        %83 = affine.apply #map13()[%24]
        %84 = arith.maxsi %69, %25 : index
        %85 = arith.minsi %66, %83 : index
        %86 = arith.maxsi %84, %85 : index
        %87 = affine.apply #map5()[%86, %84]
        %88 = affine.apply #map14()[%84, %24]
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID1>]
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID2>]
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID3>]
        hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
        hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID2>]
        scf.for %arg36 = %c0_i32 to %47 step %c1_i32  : i32 {
          %89 = memref.load %alloca_0[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
          %90 = arith.remui %89, %c2_i64 : i64
          %91 = arith.index_cast %90 : i64 to index
          %92 = arith.cmpi eq, %90, %c1_i64 : i64
          %93 = arith.select %92, %1, %0 : memref<1x8x128xbf16, #hivm.address_space<ub>>
          %94 = arith.select %92, %3, %2 : memref<1x8x128xbf16, #hivm.address_space<ub>>
          %95 = arith.select %92, %17, %16 : memref<8x128xf32, #hivm.address_space<ub>>
          %96 = arith.index_cast %91 : index to i1
          %97 = arith.select %96, %c2_i64, %c3_i64 : i64
          %98 = arith.select %96, %c1_i64, %c2_i64 : i64
          %99 = arith.addi %29, %arg36 : i32
          %100 = arith.addi %40, %99 : i32
          %101 = arith.muli %100, %arg28 : i32
          %102 = arith.extsi %101 : i32 to i64
          %103 = arith.addi %102, %58 : i64
          %104 = arith.addi %44, %99 : i32
          %105 = arith.addi %104, %c128_i32 : i32
          %106 = arith.divsi %105, %c128_i32 : i32
          %107 = arith.minsi %arg16, %106 : i32
          %108 = arith.maxsi %99, %c0_i32 : i32
          %109 = arith.index_cast %108 : i32 to index
          %110 = affine.apply #map15()[%109, %59, %51, %53]
          %111 = affine.apply #map15()[%109, %77, %55, %57]
          %112 = affine.apply #map5()[%61, %109]
          %reinterpret_cast_7 = memref.reinterpret_cast %arg2 to offset: [%110], sizes: [1, 16, 128], strides: [%64, %60, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>
          %113 = arith.maxsi %112, %c0 : index
          %114 = arith.minsi %113, %c1 : index
          %115 = arith.subi %c0_i32, %99 : i32
          %116 = arith.maxsi %115, %c0_i32 : i32
          %117 = arith.index_cast %116 : i32 to index
          %118 = arith.minsi %117, %114 : index
          %119 = affine.apply #map5()[%114, %118]
          %120 = arith.cmpi slt, %119, %c1 : index
          %121 = arith.ori %120, %73 : i1
          %122 = arith.ori %121, %74 : i1
          %subview = memref.subview %reinterpret_cast_7[0, %25, 0] [%119, %82, %72] [1, 1, 1] : memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>
          %subview_8 = memref.subview %94[%118, %88, %71] [%119, %87, %72] [1, 1, 1] : memref<1x8x128xbf16, #hivm.address_space<ub>> to memref<?x?x?xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>
          scf.if %122 {
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_0(%94) {hivm.vector_function, no_inline} : (memref<1x8x128xbf16, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
          } {hivm.unlikely_condition}
          hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, %98]
          hivm.hir.load ins(%subview : memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_8 : memref<?x?x?xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>) pad_mode = <PadValue> pad_value = %cst : bf16 left_padding_num = %75 : index
          hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
          %123 = hivm.hir.pointer_cast(%c2624_i64) : memref<1x128xi32, #hivm.address_space<ub>>
          func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_8_outlined_vf_0(%76, %104, %123) {hivm.vector_function, no_inline} : (memref<1x128xi32, #hivm.address_space<ub>>, i32, memref<1x128xi32, #hivm.address_space<ub>>) -> ()
          %collapse_shape = memref.collapse_shape %94 [[0, 1], [2]] : memref<1x8x128xbf16, #hivm.address_space<ub>> into memref<8x128xbf16, #hivm.address_space<ub>>
          %124 = hivm.hir.pointer_cast(%c3136_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
          %subview_9 = memref.subview %124[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
          hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID1>]
          hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
          func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_9_outlined_vf_0(%collapse_shape, %subview_9) {hivm.vector_function, no_inline} : (memref<8x128xbf16, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
          hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
          hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, %98]
          %expand_shape_10 = memref.expand_shape %subview_9 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
          %125 = hivm.hir.pointer_cast(%c0_i64) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
          %subview_11 = memref.subview %125[0, 0, %25, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
          %collapse_shape_12 = memref.collapse_shape %expand_shape_10 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
          %collapse_shape_13 = memref.collapse_shape %subview_11 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
          hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 0
          hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
          hivm.hir.copy ins(%collapse_shape_12 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_13 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
          hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID1>]
          hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 0
          %expand_shape_14 = memref.expand_shape %123 [[0], [1, 2]] output_shape [1, 1, 128] : memref<1x128xi32, #hivm.address_space<ub>> into memref<1x1x128xi32, #hivm.address_space<ub>>
          %126 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
          func.call @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_2(%126) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>) -> ()
          %127 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
          hivm.hir.copy ins(%26 : memref<8xf32, #hivm.address_space<ub>>) outs(%127 : memref<8xf32, #hivm.address_space<ub>>)
          %128 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
          hivm.hir.copy ins(%26 : memref<8xf32, #hivm.address_space<ub>>) outs(%128 : memref<8xf32, #hivm.address_space<ub>>)
          %129 = arith.addi %107, %c5_i32 : i32
          %130 = arith.cmpi sgt, %107, %c0_i32 : i32
          %131 = arith.select %130, %129, %c0_i32 : i32
          %132 = arith.cmpi sge, %131, %c10_i32 : i32
          %133:3 = scf.if %132 -> (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) {
            %135 = memref.load %alloca_1[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
            %136 = arith.addi %135, %c1_i64 : i64
            memref.store %136, %alloca_1[%c0] : memref<1xi64>
            %137 = arith.addi %135, %c2_i64 : i64
            memref.store %137, %alloca_1[%c0] : memref<1xi64>
            %138 = arith.remui %137, %c2_i64 : i64
            %139 = arith.index_cast %138 : i64 to index
            %140 = affine.apply #map16()[%139]
            %141 = arith.index_cast %140 : index to i64
            %142 = affine.apply #map17()[%139]
            %143 = arith.index_cast %142 : index to i64
            %144 = arith.remui %137, %c3_i64 : i64
            %145 = arith.cmpi eq, %144, %c1_i64 : i64
            %146 = arith.cmpi eq, %144, %c2_i64 : i64
            %147 = arith.select %145, %c52064_i64, %c24544_i64 : i64
            %148 = arith.select %146, %c52096_i64, %147 : i64
            %149 = hivm.hir.pointer_cast(%148) : memref<8xf32, #hivm.address_space<ub>>
            %150 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %151 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %152 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
            %153 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
            %154 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
            %155 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
            %156 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            %157 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
            %158 = arith.cmpi eq, %138, %c1_i64 : i64
            %159 = arith.select %158, %c11584_i64, %c47968_i64 : i64
            %160 = hivm.hir.pointer_cast(%159) : memref<8x128xf32, #hivm.address_space<ub>>
            %161 = arith.select %158, %c4096_i64, %c73728_i64 : i64
            %162 = hivm.hir.pointer_cast(%161) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %subview_19 = memref.subview %162[0, 0, %25, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
            %163 = arith.index_cast %103 : i64 to index
            %reinterpret_cast_20 = memref.reinterpret_cast %arg6 to offset: [%163], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %164 = memref.load %reinterpret_cast_20[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %165 = arith.addi %103, %c1_i64 : i64
            %166 = arith.muli %164, %c128_i32 : i32
            %167 = arith.index_cast %166 : i32 to index
            %168 = affine.apply #map4()[%167]
            %169 = arith.index_cast %43 : i32 to index
            %170 = arith.maxsi %167, %169 : index
            %171 = arith.minsi %168, %170 : index
            %172 = affine.apply #map5()[%171, %167]
            %173 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %166, %157, %173, %156, %155) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
            %subview_21 = memref.subview %173[0, 0] [1, %172] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %subview_22 = memref.subview %156[0, 0] [1, %172] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %collapse_shape_23 = memref.collapse_shape %subview_21 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            %collapse_shape_24 = memref.collapse_shape %subview_22 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            hivm.hir.copy ins(%collapse_shape_23 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_24 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%127, %154, %153, %152, %151, %150) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_25 = memref.collapse_shape %157 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
            %collapse_shape_26 = memref.collapse_shape %150 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %174 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_25, %160, %156, %28, %174) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %141
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%174, %152, %collapse_shape_26) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_27 = memref.collapse_shape %151 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %175 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%154, %collapse_shape_26, %155, %175) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %176 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
            %subview_28 = memref.subview %176[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
            hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%175, %174, %collapse_shape_27, %subview_28) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            %expand_shape_29 = memref.expand_shape %subview_28 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
            %collapse_shape_30 = memref.collapse_shape %expand_shape_29 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
            %collapse_shape_31 = memref.collapse_shape %subview_19 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %143
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            hivm.hir.copy ins(%collapse_shape_30 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_31 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
            hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            %177 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%127, %175, %128, %collapse_shape_27, %153, %149, %177) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %178 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
            hivm.hir.copy ins(%175 : memref<8xf32, #hivm.address_space<ub>>) outs(%178 : memref<8xf32, #hivm.address_space<ub>>)
            %179 = arith.addi %135, %c3_i64 : i64
            memref.store %179, %alloca_1[%c0] : memref<1xi64>
            %180 = arith.remui %179, %c2_i64 : i64
            %181 = arith.index_cast %180 : i64 to index
            %182 = affine.apply #map16()[%181]
            %183 = arith.index_cast %182 : index to i64
            %184 = affine.apply #map17()[%181]
            %185 = arith.index_cast %184 : index to i64
            %186 = arith.remui %179, %c3_i64 : i64
            %187 = arith.cmpi eq, %186, %c1_i64 : i64
            %188 = arith.cmpi eq, %186, %c2_i64 : i64
            %189 = arith.select %187, %c52064_i64, %c24544_i64 : i64
            %190 = arith.select %188, %c52096_i64, %189 : i64
            %191 = hivm.hir.pointer_cast(%190) : memref<8xf32, #hivm.address_space<ub>>
            %192 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %193 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %194 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
            %195 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
            %196 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
            %197 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
            %198 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            %199 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
            %200 = arith.cmpi eq, %180, %c1_i64 : i64
            %201 = arith.select %200, %c11584_i64, %c47968_i64 : i64
            %202 = hivm.hir.pointer_cast(%201) : memref<8x128xf32, #hivm.address_space<ub>>
            %203 = arith.select %200, %c4096_i64, %c73728_i64 : i64
            %204 = hivm.hir.pointer_cast(%203) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %subview_32 = memref.subview %204[0, 0, %25, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
            %205 = arith.index_cast %165 : i64 to index
            %reinterpret_cast_33 = memref.reinterpret_cast %arg6 to offset: [%205], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %206 = memref.load %reinterpret_cast_33[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %207 = arith.addi %103, %c2_i64 : i64
            %208 = arith.muli %206, %c128_i32 : i32
            %209 = arith.index_cast %208 : i32 to index
            %210 = affine.apply #map4()[%209]
            %211 = arith.maxsi %209, %169 : index
            %212 = arith.minsi %210, %211 : index
            %213 = affine.apply #map5()[%212, %209]
            %214 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %208, %199, %214, %198, %197) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
            %subview_34 = memref.subview %214[0, 0] [1, %213] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %subview_35 = memref.subview %198[0, 0] [1, %213] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %collapse_shape_36 = memref.collapse_shape %subview_34 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            %collapse_shape_37 = memref.collapse_shape %subview_35 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            hivm.hir.copy ins(%collapse_shape_36 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_37 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%178, %196, %195, %194, %193, %192) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_38 = memref.collapse_shape %199 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
            %collapse_shape_39 = memref.collapse_shape %192 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %215 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_38, %202, %198, %28, %215) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %183
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%215, %194, %collapse_shape_39) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_40 = memref.collapse_shape %193 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %216 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%196, %collapse_shape_39, %197, %216) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %217 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
            %subview_41 = memref.subview %217[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
            hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%216, %215, %collapse_shape_40, %subview_41) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            %expand_shape_42 = memref.expand_shape %subview_41 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
            %collapse_shape_43 = memref.collapse_shape %expand_shape_42 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
            %collapse_shape_44 = memref.collapse_shape %subview_32 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %185
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            hivm.hir.copy ins(%collapse_shape_43 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_44 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
            hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            %218 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%178, %216, %177, %collapse_shape_40, %195, %191, %218) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %219 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
            hivm.hir.copy ins(%216 : memref<8xf32, #hivm.address_space<ub>>) outs(%219 : memref<8xf32, #hivm.address_space<ub>>)
            %220 = arith.addi %135, %c4_i64 : i64
            memref.store %220, %alloca_1[%c0] : memref<1xi64>
            %221 = arith.remui %220, %c2_i64 : i64
            %222 = arith.index_cast %221 : i64 to index
            %223 = affine.apply #map18()[%222]
            %224 = arith.index_cast %223 : index to i64
            %225 = affine.apply #map16()[%222]
            %226 = arith.index_cast %225 : index to i64
            %227 = affine.apply #map17()[%222]
            %228 = arith.index_cast %227 : index to i64
            %229 = arith.remui %220, %c3_i64 : i64
            %230 = arith.cmpi eq, %229, %c1_i64 : i64
            %231 = arith.cmpi eq, %229, %c2_i64 : i64
            %232 = arith.select %230, %c52096_i64, %c52064_i64 : i64
            %233 = arith.select %231, %c24544_i64, %232 : i64
            %234 = arith.select %230, %c52064_i64, %c24544_i64 : i64
            %235 = arith.select %231, %c52096_i64, %234 : i64
            %236 = hivm.hir.pointer_cast(%235) : memref<8xf32, #hivm.address_space<ub>>
            %237 = hivm.hir.pointer_cast(%233) : memref<8xf32, #hivm.address_space<ub>>
            %238 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %239 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %240 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
            %241 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
            %242 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
            %243 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
            %244 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            %245 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
            %246 = arith.cmpi eq, %221, %c1_i64 : i64
            %247 = arith.select %246, %c11584_i64, %c47968_i64 : i64
            %248 = hivm.hir.pointer_cast(%247) : memref<8x128xf32, #hivm.address_space<ub>>
            %249 = arith.select %246, %c4096_i64, %c73728_i64 : i64
            %250 = hivm.hir.pointer_cast(%249) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %251 = arith.select %246, %c7488_i64, %c43872_i64 : i64
            %252 = hivm.hir.pointer_cast(%251) : memref<8x128xf32, #hivm.address_space<ub>>
            %subview_45 = memref.subview %250[0, 0, %25, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
            %253 = arith.index_cast %207 : i64 to index
            %reinterpret_cast_46 = memref.reinterpret_cast %arg6 to offset: [%253], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %254 = memref.load %reinterpret_cast_46[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %255 = arith.addi %103, %c3_i64 : i64
            %256 = arith.muli %254, %c128_i32 : i32
            %257 = arith.index_cast %256 : i32 to index
            %258 = affine.apply #map4()[%257]
            %259 = arith.maxsi %257, %169 : index
            %260 = arith.minsi %258, %259 : index
            %261 = affine.apply #map5()[%260, %257]
            %262 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %256, %245, %262, %244, %243) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
            %subview_47 = memref.subview %262[0, 0] [1, %261] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %subview_48 = memref.subview %244[0, 0] [1, %261] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %collapse_shape_49 = memref.collapse_shape %subview_47 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            %collapse_shape_50 = memref.collapse_shape %subview_48 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            hivm.hir.copy ins(%collapse_shape_49 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_50 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%219, %242, %241, %240, %239, %238) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_51 = memref.collapse_shape %245 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
            %collapse_shape_52 = memref.collapse_shape %238 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %263 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_51, %248, %244, %28, %263) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %226
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%263, %240, %collapse_shape_52) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_53 = memref.collapse_shape %239 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %264 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%242, %collapse_shape_52, %243, %264) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %265 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
            %subview_54 = memref.subview %265[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
            hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%264, %263, %collapse_shape_53, %subview_54) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            %expand_shape_55 = memref.expand_shape %subview_54 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
            %collapse_shape_56 = memref.collapse_shape %expand_shape_55 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
            %collapse_shape_57 = memref.collapse_shape %subview_45 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %228
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            hivm.hir.copy ins(%collapse_shape_56 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_57 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
            hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            %266 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%219, %264, %218, %collapse_shape_53, %241, %236, %266) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %267 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
            hivm.hir.copy ins(%264 : memref<8xf32, #hivm.address_space<ub>>) outs(%267 : memref<8xf32, #hivm.address_space<ub>>)
            %268 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%237, %252, %126, %268) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %224
            %269 = arith.addi %135, %c5_i64 : i64
            memref.store %269, %alloca_1[%c0] : memref<1xi64>
            %270 = arith.subi %131, %c5_i32 : i32
            %271:5 = scf.for %arg37 = %c5_i32 to %270 step %c1_i32 iter_args(%arg38 = %267, %arg39 = %266, %arg40 = %268, %arg41 = %255, %arg42 = %255) -> (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, i64, i64)  : i32 {
              %408 = memref.load %alloca_1[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
              %409 = arith.remui %408, %c2_i64 : i64
              %410 = arith.index_cast %409 : i64 to index
              %411 = affine.apply #map18()[%410]
              %412 = arith.index_cast %411 : index to i64
              %413 = affine.apply #map16()[%410]
              %414 = arith.index_cast %413 : index to i64
              %415 = affine.apply #map17()[%410]
              %416 = arith.index_cast %415 : index to i64
              %417 = arith.remui %408, %c3_i64 : i64
              %418 = arith.cmpi eq, %417, %c1_i64 : i64
              %419 = arith.cmpi eq, %417, %c2_i64 : i64
              %420 = arith.select %418, %c52096_i64, %c52064_i64 : i64
              %421 = arith.select %419, %c24544_i64, %420 : i64
              %422 = arith.select %418, %c52064_i64, %c24544_i64 : i64
              %423 = arith.select %419, %c52096_i64, %422 : i64
              %424 = hivm.hir.pointer_cast(%423) : memref<8xf32, #hivm.address_space<ub>>
              %425 = hivm.hir.pointer_cast(%421) : memref<8xf32, #hivm.address_space<ub>>
              %426 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
              %427 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
              %428 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
              %429 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
              %430 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
              %431 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
              %432 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
              %433 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
              %434 = arith.cmpi eq, %409, %c1_i64 : i64
              %435 = arith.select %434, %c11584_i64, %c47968_i64 : i64
              %436 = hivm.hir.pointer_cast(%435) : memref<8x128xf32, #hivm.address_space<ub>>
              %437 = arith.select %434, %c4096_i64, %c73728_i64 : i64
              %438 = hivm.hir.pointer_cast(%437) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
              %439 = arith.select %434, %c7488_i64, %c43872_i64 : i64
              %440 = hivm.hir.pointer_cast(%439) : memref<8x128xf32, #hivm.address_space<ub>>
              %subview_86 = memref.subview %438[0, 0, %25, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
              %441 = arith.index_cast %arg41 : i64 to index
              %reinterpret_cast_87 = memref.reinterpret_cast %arg6 to offset: [%441], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %442 = memref.load %reinterpret_cast_87[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %443 = arith.addi %arg41, %c1_i64 : i64
              %444 = arith.muli %442, %c128_i32 : i32
              %445 = arith.index_cast %444 : i32 to index
              %446 = affine.apply #map4()[%445]
              %447 = arith.maxsi %445, %169 : index
              %448 = arith.minsi %446, %447 : index
              %449 = affine.apply #map5()[%448, %445]
              %450 = arith.index_cast %arg42 : i64 to index
              %reinterpret_cast_88 = memref.reinterpret_cast %arg6 to offset: [%450], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %451 = memref.load %reinterpret_cast_88[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %452 = arith.muli %451, %c128_i32 : i32
              %453 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %452, %433, %453, %432, %431) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
              %subview_89 = memref.subview %453[0, 0] [1, %449] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
              %subview_90 = memref.subview %432[0, 0] [1, %449] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
              %collapse_shape_91 = memref.collapse_shape %subview_89 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
              %collapse_shape_92 = memref.collapse_shape %subview_90 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
              hivm.hir.copy ins(%collapse_shape_91 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_92 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
              %454 = arith.addi %arg42, %c1_i64 : i64
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%arg38, %430, %429, %428, %427, %426) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
              %collapse_shape_93 = memref.collapse_shape %433 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
              %collapse_shape_94 = memref.collapse_shape %426 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
              %455 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
              hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_93, %436, %432, %28, %455) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
              hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %414
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%455, %428, %collapse_shape_94) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
              %collapse_shape_95 = memref.collapse_shape %427 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
              %456 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%430, %collapse_shape_94, %431, %456) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
              %457 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
              %subview_96 = memref.subview %457[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
              hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%456, %455, %collapse_shape_95, %subview_96) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
              hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
              %expand_shape_97 = memref.expand_shape %subview_96 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
              %collapse_shape_98 = memref.collapse_shape %expand_shape_97 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
              %collapse_shape_99 = memref.collapse_shape %subview_86 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
              hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %416
              hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
              hivm.hir.copy ins(%collapse_shape_98 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_99 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
              hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
              hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
              %458 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%arg38, %456, %arg39, %collapse_shape_95, %429, %424, %458) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
              %459 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
              hivm.hir.copy ins(%456 : memref<8xf32, #hivm.address_space<ub>>) outs(%459 : memref<8xf32, #hivm.address_space<ub>>)
              %460 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
              hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%425, %440, %arg40, %460) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
              hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %412
              %461 = arith.addi %408, %c1_i64 : i64
              memref.store %461, %alloca_1[%c0] : memref<1xi64>
              scf.yield %459, %458, %460, %443, %454 : memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, i64, i64
            }
            %272 = memref.load %alloca_1[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
            %273 = arith.remui %272, %c2_i64 : i64
            %274 = arith.index_cast %273 : i64 to index
            %275 = affine.apply #map18()[%274]
            %276 = arith.index_cast %275 : index to i64
            %277 = affine.apply #map16()[%274]
            %278 = arith.index_cast %277 : index to i64
            %279 = affine.apply #map17()[%274]
            %280 = arith.index_cast %279 : index to i64
            %281 = arith.remui %272, %c3_i64 : i64
            %282 = arith.cmpi eq, %281, %c1_i64 : i64
            %283 = arith.cmpi eq, %281, %c2_i64 : i64
            %284 = arith.select %282, %c52096_i64, %c52064_i64 : i64
            %285 = arith.select %283, %c24544_i64, %284 : i64
            %286 = arith.select %282, %c52064_i64, %c24544_i64 : i64
            %287 = arith.select %283, %c52096_i64, %286 : i64
            %288 = hivm.hir.pointer_cast(%287) : memref<8xf32, #hivm.address_space<ub>>
            %289 = hivm.hir.pointer_cast(%285) : memref<8xf32, #hivm.address_space<ub>>
            %290 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %291 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %292 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
            %293 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
            %294 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
            %295 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
            %296 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            %297 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
            %298 = arith.cmpi eq, %273, %c1_i64 : i64
            %299 = arith.select %298, %c11584_i64, %c47968_i64 : i64
            %300 = hivm.hir.pointer_cast(%299) : memref<8x128xf32, #hivm.address_space<ub>>
            %301 = arith.select %298, %c4096_i64, %c73728_i64 : i64
            %302 = hivm.hir.pointer_cast(%301) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %303 = arith.select %298, %c7488_i64, %c43872_i64 : i64
            %304 = hivm.hir.pointer_cast(%303) : memref<8x128xf32, #hivm.address_space<ub>>
            %subview_58 = memref.subview %302[0, 0, %25, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
            %305 = arith.index_cast %271#3 : i64 to index
            %reinterpret_cast_59 = memref.reinterpret_cast %arg6 to offset: [%305], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %306 = memref.load %reinterpret_cast_59[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %307 = arith.addi %271#3, %c1_i64 : i64
            %308 = arith.muli %306, %c128_i32 : i32
            %309 = arith.index_cast %308 : i32 to index
            %310 = affine.apply #map4()[%309]
            %311 = arith.maxsi %309, %169 : index
            %312 = arith.minsi %310, %311 : index
            %313 = affine.apply #map5()[%312, %309]
            %314 = arith.index_cast %271#4 : i64 to index
            %reinterpret_cast_60 = memref.reinterpret_cast %arg6 to offset: [%314], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %315 = memref.load %reinterpret_cast_60[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %316 = arith.muli %315, %c128_i32 : i32
            %317 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %316, %297, %317, %296, %295) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
            %subview_61 = memref.subview %317[0, 0] [1, %313] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %subview_62 = memref.subview %296[0, 0] [1, %313] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %collapse_shape_63 = memref.collapse_shape %subview_61 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            %collapse_shape_64 = memref.collapse_shape %subview_62 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            hivm.hir.copy ins(%collapse_shape_63 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_64 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
            %318 = arith.addi %271#4, %c1_i64 : i64
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%271#0, %294, %293, %292, %291, %290) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_65 = memref.collapse_shape %297 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
            %collapse_shape_66 = memref.collapse_shape %290 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %319 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_65, %300, %296, %28, %319) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %278
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%319, %292, %collapse_shape_66) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_67 = memref.collapse_shape %291 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %320 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%294, %collapse_shape_66, %295, %320) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %321 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
            %subview_68 = memref.subview %321[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
            hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%320, %319, %collapse_shape_67, %subview_68) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            %expand_shape_69 = memref.expand_shape %subview_68 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
            %collapse_shape_70 = memref.collapse_shape %expand_shape_69 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
            %collapse_shape_71 = memref.collapse_shape %subview_58 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %280
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            hivm.hir.copy ins(%collapse_shape_70 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_71 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
            hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            %322 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%271#0, %320, %271#1, %collapse_shape_67, %293, %288, %322) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %323 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
            hivm.hir.copy ins(%320 : memref<8xf32, #hivm.address_space<ub>>) outs(%323 : memref<8xf32, #hivm.address_space<ub>>)
            %324 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%289, %304, %271#2, %324) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %276
            %325 = arith.addi %272, %c1_i64 : i64
            memref.store %325, %alloca_1[%c0] : memref<1xi64>
            %326 = arith.remui %325, %c2_i64 : i64
            %327 = arith.index_cast %326 : i64 to index
            %328 = affine.apply #map18()[%327]
            %329 = arith.index_cast %328 : index to i64
            %330 = affine.apply #map16()[%327]
            %331 = arith.index_cast %330 : index to i64
            %332 = affine.apply #map17()[%327]
            %333 = arith.index_cast %332 : index to i64
            %334 = arith.remui %325, %c3_i64 : i64
            %335 = arith.cmpi eq, %334, %c1_i64 : i64
            %336 = arith.cmpi eq, %334, %c2_i64 : i64
            %337 = arith.select %335, %c52096_i64, %c52064_i64 : i64
            %338 = arith.select %336, %c24544_i64, %337 : i64
            %339 = arith.select %335, %c52064_i64, %c24544_i64 : i64
            %340 = arith.select %336, %c52096_i64, %339 : i64
            %341 = hivm.hir.pointer_cast(%340) : memref<8xf32, #hivm.address_space<ub>>
            %342 = hivm.hir.pointer_cast(%338) : memref<8xf32, #hivm.address_space<ub>>
            %343 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %344 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %345 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
            %346 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
            %347 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
            %348 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
            %349 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            %350 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
            %351 = arith.cmpi eq, %326, %c1_i64 : i64
            %352 = arith.select %351, %c11584_i64, %c47968_i64 : i64
            %353 = hivm.hir.pointer_cast(%352) : memref<8x128xf32, #hivm.address_space<ub>>
            %354 = arith.select %351, %c4096_i64, %c73728_i64 : i64
            %355 = hivm.hir.pointer_cast(%354) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %356 = arith.select %351, %c7488_i64, %c43872_i64 : i64
            %357 = hivm.hir.pointer_cast(%356) : memref<8x128xf32, #hivm.address_space<ub>>
            %subview_72 = memref.subview %355[0, 0, %25, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
            %358 = arith.index_cast %307 : i64 to index
            %reinterpret_cast_73 = memref.reinterpret_cast %arg6 to offset: [%358], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %359 = memref.load %reinterpret_cast_73[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %360 = arith.muli %359, %c128_i32 : i32
            %361 = arith.index_cast %360 : i32 to index
            %362 = affine.apply #map4()[%361]
            %363 = arith.maxsi %361, %169 : index
            %364 = arith.minsi %362, %363 : index
            %365 = affine.apply #map5()[%364, %361]
            %366 = arith.index_cast %318 : i64 to index
            %reinterpret_cast_74 = memref.reinterpret_cast %arg6 to offset: [%366], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %367 = memref.load %reinterpret_cast_74[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %368 = arith.muli %367, %c128_i32 : i32
            %369 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %368, %350, %369, %349, %348) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
            %subview_75 = memref.subview %369[0, 0] [1, %365] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %subview_76 = memref.subview %349[0, 0] [1, %365] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %collapse_shape_77 = memref.collapse_shape %subview_75 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            %collapse_shape_78 = memref.collapse_shape %subview_76 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            hivm.hir.copy ins(%collapse_shape_77 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_78 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%323, %347, %346, %345, %344, %343) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_79 = memref.collapse_shape %350 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
            %collapse_shape_80 = memref.collapse_shape %343 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %370 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_79, %353, %349, %28, %370) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %331
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%370, %345, %collapse_shape_80) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_81 = memref.collapse_shape %344 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %371 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%347, %collapse_shape_80, %348, %371) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %372 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
            %subview_82 = memref.subview %372[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
            hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%371, %370, %collapse_shape_81, %subview_82) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            %expand_shape_83 = memref.expand_shape %subview_82 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
            %collapse_shape_84 = memref.collapse_shape %expand_shape_83 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
            %collapse_shape_85 = memref.collapse_shape %subview_72 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %333
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            hivm.hir.copy ins(%collapse_shape_84 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_85 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
            hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            %373 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%323, %371, %322, %collapse_shape_81, %346, %341, %373) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %374 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
            hivm.hir.copy ins(%371 : memref<8xf32, #hivm.address_space<ub>>) outs(%374 : memref<8xf32, #hivm.address_space<ub>>)
            %375 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%342, %357, %324, %375) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %329
            %376 = arith.addi %272, %c2_i64 : i64
            memref.store %376, %alloca_1[%c0] : memref<1xi64>
            %377 = arith.remui %376, %c2_i64 : i64
            %378 = arith.index_cast %377 : i64 to index
            %379 = affine.apply #map18()[%378]
            %380 = arith.index_cast %379 : index to i64
            %381 = arith.remui %376, %c3_i64 : i64
            %382 = arith.cmpi eq, %381, %c1_i64 : i64
            %383 = arith.cmpi eq, %381, %c2_i64 : i64
            %384 = arith.select %382, %c52096_i64, %c52064_i64 : i64
            %385 = arith.select %383, %c24544_i64, %384 : i64
            %386 = hivm.hir.pointer_cast(%385) : memref<8xf32, #hivm.address_space<ub>>
            %387 = arith.cmpi eq, %377, %c1_i64 : i64
            %388 = arith.select %387, %c7488_i64, %c43872_i64 : i64
            %389 = hivm.hir.pointer_cast(%388) : memref<8x128xf32, #hivm.address_space<ub>>
            %390 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%386, %389, %375, %390) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %380
            %391 = arith.addi %272, %c3_i64 : i64
            memref.store %391, %alloca_1[%c0] : memref<1xi64>
            %392 = arith.remui %391, %c2_i64 : i64
            %393 = arith.index_cast %392 : i64 to index
            %394 = affine.apply #map18()[%393]
            %395 = arith.index_cast %394 : index to i64
            %396 = arith.remui %391, %c3_i64 : i64
            %397 = arith.cmpi eq, %396, %c1_i64 : i64
            %398 = arith.cmpi eq, %396, %c2_i64 : i64
            %399 = arith.select %397, %c52096_i64, %c52064_i64 : i64
            %400 = arith.select %398, %c24544_i64, %399 : i64
            %401 = hivm.hir.pointer_cast(%400) : memref<8xf32, #hivm.address_space<ub>>
            %402 = arith.cmpi eq, %392, %c1_i64 : i64
            %403 = arith.select %402, %c7488_i64, %c43872_i64 : i64
            %404 = hivm.hir.pointer_cast(%403) : memref<8x128xf32, #hivm.address_space<ub>>
            %405 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%401, %404, %390, %405) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %395
            %406 = arith.addi %272, %c4_i64 : i64
            memref.store %406, %alloca_1[%c0] : memref<1xi64>
            %407 = arith.addi %272, %c5_i64 : i64
            memref.store %407, %alloca_1[%c0] : memref<1xi64>
            scf.yield %374, %373, %405 : memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>
          } else {
            %135:5 = scf.for %arg37 = %c0_i32 to %131 step %c1_i32 iter_args(%arg38 = %127, %arg39 = %128, %arg40 = %126, %arg41 = %103, %arg42 = %103) -> (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, i64, i64)  : i32 {
              %136 = arith.subi %arg37, %c2_i32 : i32
              %137 = arith.subi %arg37, %c4_i32 : i32
              %138 = memref.load %alloca[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
              %139 = arith.remui %138, %c3_i64 : i64
              %140 = arith.remui %138, %c2_i64 : i64
              %141 = arith.index_cast %140 : i64 to index
              %142 = arith.cmpi eq, %140, %c1_i64 : i64
              %143 = arith.select %142, %13, %12 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
              %144 = affine.apply #map18()[%141]
              %145 = arith.index_cast %144 : index to i64
              %146 = affine.apply #map16()[%141]
              %147 = arith.index_cast %146 : index to i64
              %148 = affine.apply #map17()[%141]
              %149 = arith.index_cast %148 : index to i64
              %150 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
              %151 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
              %152 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
              %153 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
              %154 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
              %155 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
              %156 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
              %157 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
              %subview_19 = memref.subview %143[0, 0, %25, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
              %158 = arith.cmpi sge, %136, %c0_i32 : i32
              %159 = arith.cmpi slt, %136, %107 : i32
              %160 = arith.andi %158, %159 : i1
              %161:2 = scf.if %160 -> (i64, i64) {
                %168 = arith.index_cast %arg41 : i64 to index
                %reinterpret_cast_21 = memref.reinterpret_cast %arg6 to offset: [%168], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %169 = memref.load %reinterpret_cast_21[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %170 = arith.addi %arg41, %c1_i64 : i64
                %171 = arith.muli %169, %c128_i32 : i32
                %172 = arith.index_cast %171 : i32 to index
                %173 = affine.apply #map4()[%172]
                %174 = arith.index_cast %43 : i32 to index
                %175 = arith.maxsi %172, %174 : index
                %176 = arith.minsi %173, %175 : index
                %177 = affine.apply #map5()[%176, %172]
                %178 = arith.index_cast %arg42 : i64 to index
                %reinterpret_cast_22 = memref.reinterpret_cast %arg6 to offset: [%178], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %179 = memref.load %reinterpret_cast_22[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %180 = arith.muli %179, %c128_i32 : i32
                %181 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %180, %157, %181, %156, %155) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
                %subview_23 = memref.subview %181[0, 0] [1, %177] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
                %subview_24 = memref.subview %156[0, 0] [1, %177] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
                %collapse_shape_25 = memref.collapse_shape %subview_23 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
                %collapse_shape_26 = memref.collapse_shape %subview_24 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
                hivm.hir.copy ins(%collapse_shape_25 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_26 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
                %182 = arith.addi %arg42, %c1_i64 : i64
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%arg38, %154, %153, %152, %151, %150) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
                scf.yield %170, %182 : i64, i64
              } else {
                scf.yield %arg41, %arg42 : i64, i64
              }
              %collapse_shape_20 = memref.collapse_shape %157 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
              %162:2 = scf.if %160 -> (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) {
                %168 = arith.cmpi eq, %139, %c1_i64 : i64
                %169 = arith.select %168, %5, %4 : memref<8xf32, #hivm.address_space<ub>>
                %170 = arith.cmpi eq, %139, %c2_i64 : i64
                %171 = arith.select %170, %6, %169 : memref<8xf32, #hivm.address_space<ub>>
                %172 = arith.select %142, %11, %10 : memref<8x128xf32, #hivm.address_space<ub>>
                %collapse_shape_21 = memref.collapse_shape %150 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
                %173 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
                hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_20, %172, %156, %28, %173) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
                hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %147
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%173, %152, %collapse_shape_21) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
                %collapse_shape_22 = memref.collapse_shape %151 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
                %174 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%154, %collapse_shape_21, %155, %174) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
                %175 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
                %subview_23 = memref.subview %175[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
                hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%174, %173, %collapse_shape_22, %subview_23) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
                hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
                %expand_shape_24 = memref.expand_shape %subview_23 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
                %collapse_shape_25 = memref.collapse_shape %expand_shape_24 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
                %collapse_shape_26 = memref.collapse_shape %subview_19 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
                hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %149
                hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
                hivm.hir.copy ins(%collapse_shape_25 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_26 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
                hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
                hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
                %176 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%arg38, %174, %arg39, %collapse_shape_22, %153, %171, %176) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
                %177 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
                hivm.hir.copy ins(%174 : memref<8xf32, #hivm.address_space<ub>>) outs(%177 : memref<8xf32, #hivm.address_space<ub>>)
                scf.yield %177, %176 : memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>
              } else {
                scf.yield %arg38, %arg39 : memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>
              }
              %163 = arith.cmpi sge, %137, %c0_i32 : i32
              %164 = arith.cmpi slt, %137, %107 : i32
              %165 = arith.andi %163, %164 : i1
              %166 = scf.if %165 -> (memref<8x128xf32, #hivm.address_space<ub>>) {
                %168 = arith.cmpi eq, %139, %c1_i64 : i64
                %169 = arith.select %168, %8, %7 : memref<8xf32, #hivm.address_space<ub>>
                %170 = arith.cmpi eq, %139, %c2_i64 : i64
                %171 = arith.select %170, %9, %169 : memref<8xf32, #hivm.address_space<ub>>
                %172 = arith.select %142, %15, %14 : memref<8x128xf32, #hivm.address_space<ub>>
                %173 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
                hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%171, %172, %arg40, %173) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
                hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %145
                scf.yield %173 : memref<8x128xf32, #hivm.address_space<ub>>
              } else {
                scf.yield %arg40 : memref<8x128xf32, #hivm.address_space<ub>>
              }
              %167 = arith.addi %138, %c1_i64 : i64
              memref.store %167, %alloca[%c0] : memref<1xi64>
              scf.yield %162#0, %162#1, %166, %161#0, %161#1 : memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, i64, i64
            }
            scf.yield %135#0, %135#1, %135#2 : memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>
          }
          hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, %97]
          func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_10_outlined_vf_0(%133#0, %133#1, %133#2, %95) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
          %expand_shape_15 = memref.expand_shape %95 [[0, 1], [2]] output_shape [1, 8, 128] : memref<8x128xf32, #hivm.address_space<ub>> into memref<1x8x128xf32, #hivm.address_space<ub>>
          %reinterpret_cast_16 = memref.reinterpret_cast %arg7 to offset: [%111], sizes: [1, 16, 128], strides: [%79, %78, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>
          func.call @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_3(%expand_shape_15, %93) {hivm.vector_function, no_inline} : (memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x8x128xbf16, #hivm.address_space<ub>>) -> ()
          hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
          %subview_17 = memref.subview %93[%118, %88, %71] [%119, %87, %72] [1, 1, 1] : memref<1x8x128xbf16, #hivm.address_space<ub>> to memref<?x?x?xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>
          %subview_18 = memref.subview %reinterpret_cast_16[0, %25, 0] [%119, %82, %72] [1, 1, 1] : memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>
          hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
          hivm.hir.pipe_barrier[<PIPE_MTE3>]
          hivm.hir.store ins(%subview_17 : memref<?x?x?xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>) outs(%subview_18 : memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>) {tiled_op}
          hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, %97]
          %134 = arith.addi %89, %c1_i64 : i64
          memref.store %134, %alloca_0[%c0] : memref<1xi64>
        }
        hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
        hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID2>]
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID1>]
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID2>]
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID3>]
      }
      hivm.hir.set_ctrl true at ctrl[60]
    } {autoblockify.subloop}
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 0
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 3
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 4
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
}


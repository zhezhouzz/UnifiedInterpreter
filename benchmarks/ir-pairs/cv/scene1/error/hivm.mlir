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
    %c0_i32 = arith.constant 0 : i32
    %c128_i32 = arith.constant 128 : i32
    %c1_i64 = arith.constant 1 : i64
    %c16 = arith.constant 16 : index
    %cst = arith.constant 0.000000e+00 : bf16
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
        %34 = arith.muli %20, %arg27 : i32
        %35 = arith.extsi %arg20 : i32 to i64
        %36 = arith.muli %20, %arg21 : i32
        %37 = arith.index_cast %36 : i32 to index
        %38 = arith.extsi %34 : i32 to i64
        %39 = arith.index_cast %arg15 : i32 to index
        %40 = arith.maxsi %39, %c0 : index
        %41 = arith.minsi %40, %c128 : index
        hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
        hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID2>]
        hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID3>]
        hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID4>]
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID2>]
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID3>]
        scf.for %arg36 = %c0_i32 to %32 step %c1_i32  : i32 {
          %42 = arith.addi %18, %arg36 : i32
          %43 = arith.addi %25, %42 : i32
          %44 = arith.muli %43, %arg28 : i32
          %45 = arith.extsi %44 : i32 to i64
          %46 = arith.addi %45, %38 : i64
          %47 = arith.addi %29, %42 : i32
          %48 = arith.addi %47, %c128_i32 : i32
          %49 = arith.divsi %48, %c128_i32 : i32
          %50 = arith.minsi %arg16, %49 : i32
          %51 = hivm.hir.pointer_cast(%c0_i64) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
          hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 0
          %52 = arith.addi %50, %c5_i32 : i32
          %53 = arith.cmpi sgt, %50, %c0_i32 : i32
          %54 = arith.select %53, %52, %c0_i32 : i32
          %55 = arith.cmpi sge, %54, %c10_i32 : i32
          scf.if %55 {
            %56 = memref.load %alloca_0[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
            %57 = arith.addi %56, %c1_i64 : i64
            memref.store %57, %alloca_0[%c0] : memref<1xi64>
            %58 = arith.remui %57, %c2_i64 : i64
            %59 = arith.index_cast %58 : i64 to index
            %60 = arith.index_cast %59 : index to i1
            %61 = arith.xori %60, %true : i1
            %62 = arith.extui %61 : i1 to i64
            %63 = arith.select %60, %c1_i64, %c2_i64 : i64
            %64 = affine.apply #map2()[%59]
            %65 = arith.index_cast %64 : index to i64
            %66 = arith.cmpi eq, %58, %c1_i64 : i64
            %67 = arith.select %66, %c16384_i64, %c0_i64 : i64
            %68 = hivm.hir.pointer_cast(%67) : memref<8x1x16x16xf32, #hivm.address_space<cc>>
            %69 = arith.select %66, %c77824_i64, %c8192_i64 : i64
            %70 = hivm.hir.pointer_cast(%69) : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
            %71 = arith.select %66, %c47968_i64, %c11584_i64 : i64
            %72 = hivm.hir.pointer_cast(%71) : memref<8x128xf32, #hivm.address_space<ub>>
            %73 = arith.index_cast %46 : i64 to index
            %reinterpret_cast_4 = memref.reinterpret_cast %arg6 to offset: [%73], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %74 = memref.load %reinterpret_cast_4[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %75 = arith.addi %46, %c1_i64 : i64
            %76 = arith.muli %74, %c128_i32 : i32
            %77 = arith.index_cast %33 : i32 to index
            %78 = arith.index_cast %74 : i32 to index
            %79 = affine.apply #map3()[%77, %78]
            %reinterpret_cast_5 = memref.reinterpret_cast %arg8 to offset: [%79], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %80 = memref.load %reinterpret_cast_5[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %81 = arith.extsi %80 : i32 to i64
            %82 = arith.muli %81, %35 : i64
            %83 = arith.index_cast %82 : i64 to index
            %84 = affine.apply #map3()[%83, %37]
            %85 = arith.index_cast %arg22 : i32 to index
            %reinterpret_cast_6 = memref.reinterpret_cast %arg3 to offset: [%84], sizes: [128, 128], strides: [%85, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %86 = arith.index_cast %76 : i32 to index
            %87 = affine.apply #map4()[%86]
            %88 = arith.index_cast %28 : i32 to index
            %89 = arith.maxsi %86, %88 : index
            %90 = arith.minsi %87, %89 : index
            %91 = affine.apply #map5()[%90, %86]
            %92 = arith.minsi %91, %c128 : index
            %93 = arith.maxsi %92, %c0 : index
            %94 = arith.minsi %41, %c128 : index
            %95 = arith.maxsi %94, %c0 : index
            %96 = arith.cmpi slt, %93, %c128 : index
            %97 = arith.cmpi slt, %95, %c128 : index
            %98 = arith.ori %96, %97 : i1
            %subview = memref.subview %reinterpret_cast_6[0, 0] [%93, %95] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
            %99 = affine.apply #map6(%93)
            %100 = affine.apply #map6(%95)
            %subview_7 = memref.subview %70[0, 0, 0, 0] [%100, %99, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
            scf.if %98 {
              hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              %collapse_shape = memref.collapse_shape %70 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
              hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
              hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
              hivm.hir.pipe_barrier[<PIPE_MTE2>]
            } {hivm.unlikely_condition}
            hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %63]
            hivm.hir.nd2nz {dst_continuous} ins(%subview : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_7 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
            hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
            hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %62]
            hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%51, %70, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%68 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %63, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %65
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%68 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%72 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %62]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
            %101 = arith.addi %56, %c2_i64 : i64
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
            %117 = arith.index_cast %75 : i64 to index
            %reinterpret_cast_8 = memref.reinterpret_cast %arg6 to offset: [%117], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %118 = memref.load %reinterpret_cast_8[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %119 = arith.addi %46, %c2_i64 : i64
            %120 = arith.muli %118, %c128_i32 : i32
            %121 = arith.index_cast %118 : i32 to index
            %122 = affine.apply #map3()[%77, %121]
            %reinterpret_cast_9 = memref.reinterpret_cast %arg8 to offset: [%122], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %123 = memref.load %reinterpret_cast_9[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %124 = arith.extsi %123 : i32 to i64
            %125 = arith.muli %124, %35 : i64
            %126 = arith.index_cast %125 : i64 to index
            %127 = affine.apply #map3()[%126, %37]
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
            hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%51, %114, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%112 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %107, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %109
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%112 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%116 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %106]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
            %138 = arith.addi %56, %c3_i64 : i64
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
            %170 = arith.addi %46, %c3_i64 : i64
            %171 = arith.muli %169, %c128_i32 : i32
            %172 = arith.index_cast %169 : i32 to index
            %173 = affine.apply #map3()[%77, %172]
            %reinterpret_cast_14 = memref.reinterpret_cast %arg8 to offset: [%173], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %174 = memref.load %reinterpret_cast_14[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %175 = arith.extsi %174 : i32 to i64
            %176 = arith.muli %175, %35 : i64
            %177 = arith.index_cast %176 : i64 to index
            %178 = affine.apply #map3()[%177, %37]
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
            hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%51, %161, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%159 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %146, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %152
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%159 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%163 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %145]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
            %189 = memref.load %reinterpret_cast_4[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %190 = arith.muli %189, %c128_i32 : i32
            %191 = arith.index_cast %189 : i32 to index
            %192 = affine.apply #map3()[%77, %191]
            %reinterpret_cast_18 = memref.reinterpret_cast %arg8 to offset: [%192], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %193 = memref.load %reinterpret_cast_18[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %194 = arith.extsi %193 : i32 to i64
            %195 = arith.muli %194, %35 : i64
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
            %207 = affine.apply #map9()[%39, %196, %37]
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
            %208 = arith.addi %56, %c4_i64 : i64
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
            %240 = arith.addi %46, %c4_i64 : i64
            %241 = arith.muli %239, %c128_i32 : i32
            %242 = arith.index_cast %239 : i32 to index
            %243 = affine.apply #map3()[%77, %242]
            %reinterpret_cast_23 = memref.reinterpret_cast %arg8 to offset: [%243], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %244 = memref.load %reinterpret_cast_23[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %245 = arith.extsi %244 : i32 to i64
            %246 = arith.muli %245, %35 : i64
            %247 = arith.index_cast %246 : i64 to index
            %248 = affine.apply #map3()[%247, %37]
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
            hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%51, %231, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%229 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %216, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
            hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %222
            hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
            hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%229 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%233 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
            hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %215]
            hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
            %259 = memref.load %reinterpret_cast_8[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %260 = arith.muli %259, %c128_i32 : i32
            %261 = arith.index_cast %259 : i32 to index
            %262 = affine.apply #map3()[%77, %261]
            %reinterpret_cast_27 = memref.reinterpret_cast %arg8 to offset: [%262], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %263 = memref.load %reinterpret_cast_27[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %264 = arith.extsi %263 : i32 to i64
            %265 = arith.muli %264, %35 : i64
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
            %277 = affine.apply #map9()[%39, %266, %37]
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
            %278 = arith.addi %56, %c5_i64 : i64
            memref.store %278, %alloca_0[%c0] : memref<1xi64>
            %279 = arith.subi %54, %c5_i32 : i32
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
              %469 = affine.apply #map3()[%77, %468]
              %reinterpret_cast_52 = memref.reinterpret_cast %arg8 to offset: [%469], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %470 = memref.load %reinterpret_cast_52[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %471 = arith.extsi %470 : i32 to i64
              %472 = arith.muli %471, %35 : i64
              %473 = arith.index_cast %472 : i64 to index
              %474 = affine.apply #map3()[%473, %37]
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
              hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%51, %457, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%455 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %442, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
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
              %490 = affine.apply #map3()[%77, %489]
              %reinterpret_cast_57 = memref.reinterpret_cast %arg8 to offset: [%490], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %491 = memref.load %reinterpret_cast_57[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %492 = arith.extsi %491 : i32 to i64
              %493 = arith.muli %492, %35 : i64
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
              %505 = affine.apply #map9()[%39, %494, %37]
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
            %315 = affine.apply #map3()[%77, %314]
            %reinterpret_cast_32 = memref.reinterpret_cast %arg8 to offset: [%315], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %316 = memref.load %reinterpret_cast_32[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %317 = arith.extsi %316 : i32 to i64
            %318 = arith.muli %317, %35 : i64
            %319 = arith.index_cast %318 : i64 to index
            %320 = affine.apply #map3()[%319, %37]
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
            hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%51, %304, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%302 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %289, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
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
            %336 = affine.apply #map3()[%77, %335]
            %reinterpret_cast_37 = memref.reinterpret_cast %arg8 to offset: [%336], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %337 = memref.load %reinterpret_cast_37[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %338 = arith.extsi %337 : i32 to i64
            %339 = arith.muli %338, %35 : i64
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
            %351 = affine.apply #map9()[%39, %340, %37]
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
            %376 = affine.apply #map3()[%77, %375]
            %reinterpret_cast_42 = memref.reinterpret_cast %arg8 to offset: [%376], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %377 = memref.load %reinterpret_cast_42[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %378 = arith.extsi %377 : i32 to i64
            %379 = arith.muli %378, %35 : i64
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
            %391 = affine.apply #map9()[%39, %380, %37]
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
            %415 = affine.apply #map3()[%77, %414]
            %reinterpret_cast_47 = memref.reinterpret_cast %arg8 to offset: [%415], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %416 = memref.load %reinterpret_cast_47[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %417 = arith.extsi %416 : i32 to i64
            %418 = arith.muli %417, %35 : i64
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
            %430 = affine.apply #map9()[%39, %419, %37]
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
            %56:2 = scf.for %arg37 = %c0_i32 to %54 step %c1_i32 iter_args(%arg38 = %46, %arg39 = %46) -> (i64, i64)  : i32 {
              %57 = arith.subi %arg37, %c1_i32 : i32
              %58 = arith.subi %arg37, %c3_i32 : i32
              %59 = memref.load %alloca[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
              %60 = arith.remui %59, %c2_i64 : i64
              %61 = arith.index_cast %60 : i64 to index
              %62 = arith.cmpi eq, %60, %c1_i64 : i64
              %63 = arith.select %62, %3, %2 : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
              %64 = arith.select %62, %7, %6 : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>
              %65 = arith.index_cast %61 : index to i1
              %66 = arith.select %65, %c2_i64, %c3_i64 : i64
              %67 = arith.select %65, %c3_i64, %c4_i64 : i64
              %68 = arith.xori %65, %true : i1
              %69 = arith.extui %68 : i1 to i64
              %70 = arith.select %65, %c1_i64, %c2_i64 : i64
              %71 = affine.apply #map7()[%61]
              %72 = arith.index_cast %71 : index to i64
              %73 = affine.apply #map8()[%61]
              %74 = arith.index_cast %73 : index to i64
              %75 = affine.apply #map2()[%61]
              %76 = arith.index_cast %75 : index to i64
              %77 = arith.cmpi sge, %57, %c0_i32 : i32
              %78 = arith.cmpi slt, %57, %50 : i32
              %79 = arith.andi %77, %78 : i1
              %80 = scf.if %79 -> (i64) {
                %86 = arith.select %62, %5, %4 : memref<8x1x16x16xf32, #hivm.address_space<cc>>
                %87 = arith.select %62, %9, %8 : memref<8x128xf32, #hivm.address_space<ub>>
                %88 = arith.index_cast %arg38 : i64 to index
                %reinterpret_cast_4 = memref.reinterpret_cast %arg6 to offset: [%88], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %89 = memref.load %reinterpret_cast_4[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %90 = arith.addi %arg38, %c1_i64 : i64
                %91 = arith.muli %89, %c128_i32 : i32
                %92 = arith.index_cast %33 : i32 to index
                %93 = arith.index_cast %89 : i32 to index
                %94 = affine.apply #map3()[%92, %93]
                %reinterpret_cast_5 = memref.reinterpret_cast %arg8 to offset: [%94], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %95 = memref.load %reinterpret_cast_5[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %96 = arith.extsi %95 : i32 to i64
                %97 = arith.muli %96, %35 : i64
                %98 = arith.index_cast %97 : i64 to index
                %99 = affine.apply #map3()[%98, %37]
                %100 = arith.index_cast %arg22 : i32 to index
                %reinterpret_cast_6 = memref.reinterpret_cast %arg3 to offset: [%99], sizes: [128, 128], strides: [%100, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
                %101 = arith.index_cast %91 : i32 to index
                %102 = affine.apply #map4()[%101]
                %103 = arith.index_cast %28 : i32 to index
                %104 = arith.maxsi %101, %103 : index
                %105 = arith.minsi %102, %104 : index
                %106 = affine.apply #map5()[%105, %101]
                %107 = arith.minsi %106, %c128 : index
                %108 = arith.maxsi %107, %c0 : index
                %109 = arith.minsi %41, %c128 : index
                %110 = arith.maxsi %109, %c0 : index
                %111 = arith.cmpi slt, %108, %c128 : index
                %112 = arith.cmpi slt, %110, %c128 : index
                %113 = arith.ori %111, %112 : i1
                %subview = memref.subview %reinterpret_cast_6[0, 0] [%108, %110] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
                %114 = affine.apply #map6(%108)
                %115 = affine.apply #map6(%110)
                %subview_7 = memref.subview %64[0, 0, 0, 0] [%115, %114, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
                scf.if %113 {
                  hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                  %collapse_shape = memref.collapse_shape %64 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
                  hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                  hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
                  hivm.hir.pipe_barrier[<PIPE_MTE2>]
                } {hivm.unlikely_condition}
                hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %70]
                hivm.hir.nd2nz {dst_continuous} ins(%subview : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_7 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
                hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
                hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %69]
                hivm.hir.mmadL1 {already_set_real_mkn, b_transpose, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%51, %64, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%86 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %70, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
                hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
                hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %76
                hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
                hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%86 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%87 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
                hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %69]
                hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 2
                scf.yield %90 : i64
              } else {
                scf.yield %arg38 : i64
              }
              %81 = arith.cmpi sge, %58, %c0_i32 : i32
              %82 = arith.cmpi slt, %58, %50 : i32
              %83 = arith.andi %81, %82 : i1
              %84 = scf.if %83 -> (i64) {
                %86 = arith.select %62, %1, %0 : memref<8x1x16x16xf32, #hivm.address_space<cc>>
                %87 = arith.select %62, %11, %10 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
                %88 = arith.select %62, %13, %12 : memref<8x128xf32, #hivm.address_space<ub>>
                %89 = arith.index_cast %arg39 : i64 to index
                %reinterpret_cast_4 = memref.reinterpret_cast %arg6 to offset: [%89], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %90 = memref.load %reinterpret_cast_4[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %91 = arith.addi %arg39, %c1_i64 : i64
                %92 = arith.muli %90, %c128_i32 : i32
                %93 = arith.index_cast %33 : i32 to index
                %94 = arith.index_cast %90 : i32 to index
                %95 = affine.apply #map3()[%93, %94]
                %reinterpret_cast_5 = memref.reinterpret_cast %arg8 to offset: [%95], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %96 = memref.load %reinterpret_cast_5[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %97 = arith.extsi %96 : i32 to i64
                %98 = arith.muli %97, %35 : i64
                %99 = arith.index_cast %98 : i64 to index
                %100 = arith.index_cast %arg22 : i32 to index
                %101 = arith.index_cast %92 : i32 to index
                %102 = affine.apply #map4()[%101]
                %103 = arith.index_cast %28 : i32 to index
                %104 = arith.maxsi %101, %103 : index
                %105 = arith.minsi %102, %104 : index
                %106 = affine.apply #map5()[%105, %101]
                %107 = arith.minsi %106, %c128 : index
                %108 = arith.maxsi %107, %c0 : index
                %109 = arith.minsi %41, %c128 : index
                %110 = arith.maxsi %109, %c0 : index
                %111 = arith.cmpi slt, %108, %c128 : index
                %112 = arith.cmpi slt, %110, %c128 : index
                %113 = arith.ori %111, %112 : i1
                %114 = affine.apply #map6(%108)
                %115 = affine.apply #map6(%110)
                %116 = affine.apply #map9()[%39, %99, %37]
                %reinterpret_cast_6 = memref.reinterpret_cast %arg3 to offset: [%116], sizes: [128, 128], strides: [%100, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
                %subview = memref.subview %reinterpret_cast_6[0, 0] [%108, %110] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>
                %subview_7 = memref.subview %63[0, 0, 0, 0] [%115, %114, 16, 16] [1, 1, 1, 1] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> to memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>
                scf.if %113 {
                  hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                  %collapse_shape = memref.collapse_shape %63 [[0, 1, 2, 3]] : memref<8x8x16x16xbf16, #hivm.address_space<cbuf>> into memref<16384xbf16, #hivm.address_space<cbuf>>
                  hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
                  hivm.hir.vbrc ins(%cst : bf16) outs(%collapse_shape : memref<16384xbf16, #hivm.address_space<cbuf>>)
                  hivm.hir.pipe_barrier[<PIPE_MTE2>]
                } {hivm.unlikely_condition}
                hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, %67]
                hivm.hir.nd2nz {dst_continuous} ins(%subview : memref<?x?xbf16, strided<[?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_7 : memref<?x?x16x16xbf16, strided<[2048, 256, 16, 1]>, #hivm.address_space<cbuf>>)
                hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
                hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
                hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, %66]
                hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%87, %63, %true, %c16, %c128, %c128 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>, memref<8x8x16x16xbf16, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%86 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) sync_related_args(%c-1_i64, %c0_i64, %c-1_i64, %67, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64)
                hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
                hivm.hir.sync_block_set[<CUBE>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %72
                hivm.hir.sync_block_wait[<CUBE>, <PIPE_V>, <PIPE_FIX>] flag = %74
                hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
                hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%86 : memref<8x1x16x16xf32, #hivm.address_space<cc>>) outs(%88 : memref<8x128xf32, #hivm.address_space<ub>>) dual_dst_mode = <ROW_SPLIT>
                hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, %66]
                hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_V>] flag = 1
                scf.yield %91 : i64
              } else {
                scf.yield %arg39 : i64
              }
              %85 = arith.addi %59, %c1_i64 : i64
              memref.store %85, %alloca[%c0] : memref<1xi64>
              scf.yield %80, %84 : i64, i64
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
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%arg0: memref<8xf32, #hivm.address_space<ub>>, %arg1: memref<8xf32, #hivm.address_space<ub>>, %arg2: memref<8xf32, #hivm.address_space<ub>>, %arg3: memref<8xf32, #hivm.address_space<ub>>, %arg4: memref<8xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %cst = arith.constant 0.693147182 : f32
    %0 = ave.hir.pge <VL8> {functionType = #ave.func_dist_type<pb32>, mask_op_idx = 0 : i32} : vector<64xi1>
    %res = ave.hir.vload <NORM> %arg0[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %res_0 = ave.hir.vload <NORM> %arg1[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %res_1 = ave.hir.vload <NORM> %arg2[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %res_2 = ave.hir.vload <NORM> %arg3[%c0] {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>> into vector<64xf32>
    %1 = ave.hir.vsub %res_0, %res, %0 : vector<64xf32>, vector<64xi1>
    %2 = ave.hir.vmuls %1, %cst, %0 : vector<64xf32>, f32, vector<64xi1>
    %3 = ave.hir.vexp %2, %0 : vector<64xf32>, vector<64xi1>
    %4 = ave.hir.vadd %3, %res_1, %0 : vector<64xf32>, vector<64xi1>
    %5 = ave.hir.vln %4, %0 : vector<64xf32>, vector<64xi1>
    %6 = ave.hir.vdiv %5, %res_2, %0 : vector<64xf32>, vector<64xi1>
    %7 = ave.hir.vadd %res, %6, %0 : vector<64xf32>, vector<64xi1>
    ave.hir.masked_store <NORM_B32> %arg4[%c0], %0, %7 {functionType = #ave.func_dist_type<norm>} : memref<8xf32, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
    return
  }
  func.func @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%arg0: memref<8xf32, #hivm.address_space<ub>>, %arg1: memref<8xf32, #hivm.address_space<ub>>, %arg2: memref<8x128xf32, #hivm.address_space<ub>>, %arg3: memref<8x128xf32, #hivm.address_space<ub>>, %arg4: memref<8x128xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %c128 = arith.constant 128 : index
    %c64 = arith.constant 64 : index
    %c8 = arith.constant 8 : index
    %c1 = arith.constant 1 : index
    %cst = arith.constant 0.693147182 : f32
    scf.for %arg5 = %c0 to %c8 step %c1 {
      %subview = memref.subview %arg0[%arg5] [1] [1] : memref<8xf32, #hivm.address_space<ub>> to memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %subview_0 = memref.subview %arg1[%arg5] [1] [1] : memref<8xf32, #hivm.address_space<ub>> to memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %res = ave.hir.vload <BRC_B32> %subview[%c0] {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>} : memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xf32>
      %res_1 = ave.hir.vload <BRC_B32> %subview_0[%c0] {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>} : memref<1xf32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xf32>
      %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %1 = ave.hir.vsub %res, %res_1, %0 : vector<64xf32>, vector<64xi1>
      %2 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %3 = ave.hir.vmuls %1, %cst, %2 : vector<64xf32>, f32, vector<64xi1>
      %4 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
      %5 = ave.hir.vexp %3, %4 : vector<64xf32>, vector<64xi1>
      scf.for %arg6 = %c0 to %c128 step %c64 {
        %subview_2 = memref.subview %arg2[%arg5, %arg6] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_3 = memref.subview %arg3[%arg5, %arg6] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_4 = memref.subview %arg4[%arg5, %arg6] [1, 64] [1, 1] : memref<8x128xf32, #hivm.address_space<ub>> to memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>>
        %subview_5 = memref.subview %subview_2[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %res_6 = ave.hir.vload <NORM> %subview_5[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>
        %subview_7 = memref.subview %subview_3[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %res_8 = ave.hir.vload <NORM> %subview_7[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xf32, #map, #hivm.address_space<ub>> into vector<64xf32>
        %6 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %7 = ave.hir.vmul %res_8, %5, %6 : vector<64xf32>, vector<64xi1>
        %8 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        %9 = ave.hir.vadd %res_6, %7, %8 : vector<64xf32>, vector<64xi1>
        %subview_9 = memref.subview %subview_4[0, 0] [1, 64] [1, 1] : memref<1x64xf32, strided<[128, 1], offset: ?>, #hivm.address_space<ub>> to memref<64xf32, #map, #hivm.address_space<ub>>
        %10 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
        ave.hir.masked_store <NORM_B32> %subview_9[%c0], %10, %9 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xf32, #map, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
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
    %c52128_i64 = arith.constant 52128 : i64
    %c37728_i64 = arith.constant 37728 : i64
    %c576_i64 = arith.constant 576 : i64
    %c41824_i64 = arith.constant 41824 : i64
    %c24544_i64 = arith.constant 24544 : i64
    %c52064_i64 = arith.constant 52064 : i64
    %c52096_i64 = arith.constant 52096 : i64
    %c47968_i64 = arith.constant 47968 : i64
    %c11584_i64 = arith.constant 11584 : i64
    %c73728_i64 = arith.constant 73728 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c43872_i64 = arith.constant 43872 : i64
    %c7488_i64 = arith.constant 7488 : i64
    %c5_i64 = arith.constant 5 : i64
    %c4_i64 = arith.constant 4 : i64
    %c10_i32 = arith.constant 10 : i32
    %c3_i64 = arith.constant 3 : i64
    %c1 = arith.constant 1 : index
    %c28_i32 = arith.constant 28 : i32
    %c1_i32 = arith.constant 1 : i32
    %cst = arith.constant 0.000000e+00 : bf16
    %c16 = arith.constant 16 : index
    %c1_i64 = arith.constant 1 : i64
    %c128_i32 = arith.constant 128 : i32
    %c0_i32 = arith.constant 0 : i32
    %c128 = arith.constant 128 : index
    %c8 = arith.constant 8 : index
    %c32_i64 = arith.constant 32 : i64
    %c64_i64 = arith.constant 64 : i64
    %c2624_i64 = arith.constant 2624 : i64
    %c3136_i64 = arith.constant 3136 : i64
    %c33632_i64 = arith.constant 33632 : i64
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
    %c33600_i64 = arith.constant 33600 : i64
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
    %7 = hivm.hir.pointer_cast(%c52096_i64) : memref<8xf32, #hivm.address_space<ub>>
    %8 = hivm.hir.pointer_cast(%c24544_i64) : memref<8xf32, #hivm.address_space<ub>>
    %9 = hivm.hir.pointer_cast(%c52064_i64) : memref<8xf32, #hivm.address_space<ub>>
    %10 = hivm.hir.pointer_cast(%c24544_i64) : memref<8xf32, #hivm.address_space<ub>>
    %11 = hivm.hir.pointer_cast(%c52064_i64) : memref<8xf32, #hivm.address_space<ub>>
    %12 = hivm.hir.pointer_cast(%c52096_i64) : memref<8xf32, #hivm.address_space<ub>>
    %13 = hivm.hir.pointer_cast(%c52064_i64) : memref<8xf32, #hivm.address_space<ub>>
    %14 = hivm.hir.pointer_cast(%c52096_i64) : memref<8xf32, #hivm.address_space<ub>>
    %15 = hivm.hir.pointer_cast(%c24544_i64) : memref<8xf32, #hivm.address_space<ub>>
    %16 = hivm.hir.pointer_cast(%c47968_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %17 = hivm.hir.pointer_cast(%c11584_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %18 = hivm.hir.pointer_cast(%c73728_i64) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
    %19 = hivm.hir.pointer_cast(%c4096_i64) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
    %20 = hivm.hir.pointer_cast(%c43872_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %21 = hivm.hir.pointer_cast(%c7488_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %22 = hivm.hir.pointer_cast(%c52096_i64) : memref<8xf32, #hivm.address_space<ub>>
    %23 = hivm.hir.pointer_cast(%c24544_i64) : memref<8xf32, #hivm.address_space<ub>>
    %24 = hivm.hir.pointer_cast(%c52064_i64) : memref<8xf32, #hivm.address_space<ub>>
    %25 = hivm.hir.pointer_cast(%c37728_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %26 = hivm.hir.pointer_cast(%c52128_i64) : memref<8x128xf32, #hivm.address_space<ub>>
    %alloca_1 = memref.alloca() : memref<1xi64>
    memref.store %c0_i64, %alloca_1[%c0] : memref<1xi64>
    %27 = arith.muli %arg32, %arg33 : i32
    %28 = arith.muli %27, %arg34 : i32
    %29 = hivm.hir.get_block_idx -> i64
    %30 = arith.trunci %29 : i64 to i32
    %31 = hivm.hir.pointer_cast(%c0_i64) : memref<1xf32, #hivm.address_space<ub>>
    memref.store %arg17, %31[%c0] : memref<1xf32, #hivm.address_space<ub>>
    hivm.hir.set_flag[<PIPE_S>, <PIPE_V>, <EVENT_ID0>]
    %32 = hivm.hir.get_sub_block_idx -> i64
    %33 = arith.index_cast %32 : i64 to index
    %34 = affine.apply #map11()[%33]
    %35 = hivm.hir.pointer_cast(%c32_i64) : memref<8xf32, #hivm.address_space<ub>>
    call @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_5(%35) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>) -> ()
    %36 = hivm.hir.pointer_cast(%c0_i64) : memref<1xf32, #hivm.address_space<ub>>
    hivm.hir.wait_flag[<PIPE_S>, <PIPE_V>, <EVENT_ID0>]
    call @_gqa_sparse_fwd_kernel_mix_aiv_fused_12_outlined_vf_0(%31, %36) {hivm.vector_function, no_inline} : (memref<1xf32, #hivm.address_space<ub>>, memref<1xf32, #hivm.address_space<ub>>) -> ()
    hivm.hir.set_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
    %37 = memref.load %36[%c0] {"DuplicateTensorExtractForCube::visitedLabel" = 1 : i32, markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xf32, #hivm.address_space<ub>>
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = 2
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = 3
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = 4
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = 5
    scf.for %arg35 = %30 to %28 step %c28_i32  : i32 {
      hivm.hir.set_ctrl false at ctrl[60]
      hivm.hir.set_ctrl true at ctrl[48]
      %38 = arith.remsi %arg35, %arg32 : i32
      %39 = arith.divsi %arg35, %arg32 : i32
      %40 = arith.remsi %39, %arg33 : i32
      %41 = arith.divsi %arg35, %27 : i32
      %42 = arith.remsi %41, %arg34 : i32
      %43 = arith.muli %40, %arg14 : i32
      %44 = arith.index_cast %42 : i32 to index
      %reinterpret_cast = memref.reinterpret_cast %arg9 to offset: [%44], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %45 = affine.apply #map1()[%44]
      %46 = memref.load %reinterpret_cast[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_2 = memref.reinterpret_cast %arg9 to offset: [%45], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %47 = memref.load %reinterpret_cast_2[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %48 = arith.subi %47, %46 : i32
      %reinterpret_cast_3 = memref.reinterpret_cast %arg10 to offset: [%44], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %49 = memref.load %reinterpret_cast_3[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_4 = memref.reinterpret_cast %arg10 to offset: [%45], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %50 = memref.load %reinterpret_cast_4[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %51 = arith.subi %50, %49 : i32
      %reinterpret_cast_5 = memref.reinterpret_cast %arg11 to offset: [%44], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %52 = memref.load %reinterpret_cast_5[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %reinterpret_cast_6 = memref.reinterpret_cast %arg12 to offset: [%44], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %53 = memref.load %reinterpret_cast_6[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
      %54 = arith.cmpi sge, %38, %51 : i32
      scf.if %54 {
      } else {
        %55 = arith.subi %51, %38 : i32
        %56 = arith.minsi %55, %c1_i32 : i32
        %57 = hivm.hir.pointer_cast(%c64_i64) : memref<128xi32, #hivm.address_space<ub>>
        func.call @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_4(%57) {hivm.vector_function, no_inline} : (memref<128xi32, #hivm.address_space<ub>>) -> ()
        %58 = arith.muli %40, %arg27 : i32
        %59 = arith.muli %46, %arg18 : i32
        %60 = arith.muli %43, %arg19 : i32
        %61 = arith.index_cast %59 : i32 to index
        %62 = arith.index_cast %60 : i32 to index
        %expand_shape = memref.expand_shape %57 [[0, 1]] output_shape [1, 128] : memref<128xi32, #hivm.address_space<ub>> into memref<1x128xi32, #hivm.address_space<ub>>
        %63 = arith.muli %46, %arg29 : i32
        %64 = arith.muli %43, %arg30 : i32
        %65 = arith.index_cast %63 : i32 to index
        %66 = arith.index_cast %64 : i32 to index
        %67 = arith.extsi %58 : i32 to i64
        %68 = arith.index_cast %arg18 : i32 to index
        %69 = arith.index_cast %arg19 : i32 to index
        %70 = arith.index_cast %48 : i32 to index
        %71 = arith.index_cast %arg14 : i32 to index
        %72 = arith.index_cast %arg15 : i32 to index
        %73 = arith.maxsi %68, %c1 : index
        %74 = arith.maxsi %71, %c0 : index
        %75 = arith.minsi %74, %c16 : index
        %76 = arith.maxsi %72, %c0 : index
        %77 = arith.minsi %76, %c128 : index
        %78 = arith.minsi %75, %c0 : index
        %79 = affine.apply #map5()[%75, %78]
        %80 = arith.minsi %77, %c0 : index
        %81 = affine.apply #map5()[%77, %80]
        %82 = arith.cmpi slt, %79, %c16 : index
        %83 = arith.cmpi slt, %81, %c128 : index
        %84 = arith.remui %80, %c16 : index
        %85 = hivm.hir.pointer_cast(%c64_i64) : memref<1x128xi32, #hivm.address_space<ub>>
        func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_11_outlined_vf_0(%expand_shape, %85) {hivm.vector_function, no_inline} : (memref<1x128xi32, #hivm.address_space<ub>>, memref<1x128xi32, #hivm.address_space<ub>>) -> ()
        %86 = arith.index_cast %arg29 : i32 to index
        %87 = arith.index_cast %arg30 : i32 to index
        %88 = arith.maxsi %86, %c1 : index
        %89 = arith.minsi %34, %79 : index
        %90 = affine.apply #map12()[%89, %75, %78]
        %91 = arith.minsi %90, %c8 : index
        %92 = affine.apply #map13()[%33]
        %93 = arith.maxsi %78, %34 : index
        %94 = arith.minsi %75, %92 : index
        %95 = arith.maxsi %93, %94 : index
        %96 = affine.apply #map5()[%95, %93]
        %97 = affine.apply #map14()[%93, %33]
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID1>]
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID2>]
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID3>]
        hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
        hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID2>]
        scf.for %arg36 = %c0_i32 to %56 step %c1_i32  : i32 {
          %98 = memref.load %alloca_0[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
          %99 = arith.remui %98, %c2_i64 : i64
          %100 = arith.index_cast %99 : i64 to index
          %101 = arith.cmpi eq, %99, %c1_i64 : i64
          %102 = arith.select %101, %1, %0 : memref<1x8x128xbf16, #hivm.address_space<ub>>
          %103 = arith.select %101, %3, %2 : memref<1x8x128xbf16, #hivm.address_space<ub>>
          %104 = arith.remui %98, %c3_i64 : i64
          %105 = arith.cmpi eq, %104, %c1_i64 : i64
          %106 = arith.select %105, %5, %4 : memref<8xf32, #hivm.address_space<ub>>
          %107 = arith.cmpi eq, %104, %c2_i64 : i64
          %108 = arith.select %107, %6, %106 : memref<8xf32, #hivm.address_space<ub>>
          %109 = arith.select %105, %8, %7 : memref<8xf32, #hivm.address_space<ub>>
          %110 = arith.select %107, %9, %109 : memref<8xf32, #hivm.address_space<ub>>
          %111 = arith.select %105, %23, %22 : memref<8xf32, #hivm.address_space<ub>>
          %112 = arith.select %107, %24, %111 : memref<8xf32, #hivm.address_space<ub>>
          %113 = arith.select %101, %26, %25 : memref<8x128xf32, #hivm.address_space<ub>>
          %114 = arith.index_cast %100 : index to i1
          %115 = arith.select %114, %c2_i64, %c3_i64 : i64
          %116 = arith.select %114, %c1_i64, %c2_i64 : i64
          %117 = arith.addi %38, %arg36 : i32
          %118 = arith.addi %49, %117 : i32
          %119 = arith.muli %118, %arg28 : i32
          %120 = arith.extsi %119 : i32 to i64
          %121 = arith.addi %120, %67 : i64
          %122 = arith.addi %53, %117 : i32
          %123 = arith.addi %122, %c128_i32 : i32
          %124 = arith.divsi %123, %c128_i32 : i32
          %125 = arith.minsi %arg16, %124 : i32
          %126 = arith.maxsi %117, %c0_i32 : i32
          %127 = arith.index_cast %126 : i32 to index
          %128 = affine.apply #map15()[%127, %68, %61, %62]
          %129 = affine.apply #map15()[%127, %86, %65, %66]
          %130 = affine.apply #map5()[%70, %127]
          %reinterpret_cast_7 = memref.reinterpret_cast %arg2 to offset: [%128], sizes: [1, 16, 128], strides: [%73, %69, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>
          %131 = arith.maxsi %130, %c0 : index
          %132 = arith.minsi %131, %c1 : index
          %133 = arith.subi %c0_i32, %117 : i32
          %134 = arith.maxsi %133, %c0_i32 : i32
          %135 = arith.index_cast %134 : i32 to index
          %136 = arith.minsi %135, %132 : index
          %137 = affine.apply #map5()[%132, %136]
          %138 = arith.cmpi slt, %137, %c1 : index
          %139 = arith.ori %138, %82 : i1
          %140 = arith.ori %139, %83 : i1
          %subview = memref.subview %reinterpret_cast_7[0, %34, 0] [%137, %91, %81] [1, 1, 1] : memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>
          %subview_8 = memref.subview %103[%136, %97, %80] [%137, %96, %81] [1, 1, 1] : memref<1x8x128xbf16, #hivm.address_space<ub>> to memref<?x?x?xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>
          scf.if %140 {
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_0(%103) {hivm.vector_function, no_inline} : (memref<1x8x128xbf16, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
          } {hivm.unlikely_condition}
          hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, %116]
          hivm.hir.load ins(%subview : memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>) outs(%subview_8 : memref<?x?x?xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>) pad_mode = <PadValue> pad_value = %cst : bf16 left_padding_num = %84 : index
          hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
          %141 = hivm.hir.pointer_cast(%c2624_i64) : memref<1x128xi32, #hivm.address_space<ub>>
          func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_8_outlined_vf_0(%85, %122, %141) {hivm.vector_function, no_inline} : (memref<1x128xi32, #hivm.address_space<ub>>, i32, memref<1x128xi32, #hivm.address_space<ub>>) -> ()
          %collapse_shape = memref.collapse_shape %103 [[0, 1], [2]] : memref<1x8x128xbf16, #hivm.address_space<ub>> into memref<8x128xbf16, #hivm.address_space<ub>>
          %142 = hivm.hir.pointer_cast(%c3136_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
          %subview_9 = memref.subview %142[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
          hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID1>]
          hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
          func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_9_outlined_vf_0(%collapse_shape, %subview_9) {hivm.vector_function, no_inline} : (memref<8x128xbf16, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
          hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
          hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, %116]
          %expand_shape_10 = memref.expand_shape %subview_9 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
          %143 = hivm.hir.pointer_cast(%c0_i64) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
          %subview_11 = memref.subview %143[0, 0, %34, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
          %collapse_shape_12 = memref.collapse_shape %expand_shape_10 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
          %collapse_shape_13 = memref.collapse_shape %subview_11 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
          hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = 0
          hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
          hivm.hir.copy ins(%collapse_shape_12 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_13 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
          hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID1>]
          hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 0
          %expand_shape_14 = memref.expand_shape %141 [[0], [1, 2]] output_shape [1, 1, 128] : memref<1x128xi32, #hivm.address_space<ub>> into memref<1x1x128xi32, #hivm.address_space<ub>>
          %144 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
          func.call @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_2(%144) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>) -> ()
          hivm.hir.copy ins(%35 : memref<8xf32, #hivm.address_space<ub>>) outs(%108 : memref<8xf32, #hivm.address_space<ub>>)
          %145 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
          hivm.hir.copy ins(%35 : memref<8xf32, #hivm.address_space<ub>>) outs(%145 : memref<8xf32, #hivm.address_space<ub>>)
          %146 = arith.addi %125, %c5_i32 : i32
          %147 = arith.cmpi sgt, %125, %c0_i32 : i32
          %148 = arith.select %147, %146, %c0_i32 : i32
          %149 = arith.cmpi sge, %148, %c10_i32 : i32
          %150:2 = scf.if %149 -> (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) {
            %152 = memref.load %alloca_1[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
            %153 = arith.addi %121, %c1_i64 : i64
            %154 = arith.addi %152, %c1_i64 : i64
            memref.store %154, %alloca_1[%c0] : memref<1xi64>
            %155 = arith.addi %121, %c2_i64 : i64
            %156 = arith.addi %152, %c2_i64 : i64
            memref.store %156, %alloca_1[%c0] : memref<1xi64>
            %157 = arith.remui %156, %c2_i64 : i64
            %158 = arith.index_cast %157 : i64 to index
            %159 = affine.apply #map16()[%158]
            %160 = arith.index_cast %159 : index to i64
            %161 = affine.apply #map17()[%158]
            %162 = arith.index_cast %161 : index to i64
            %163 = arith.remui %156, %c3_i64 : i64
            %164 = arith.cmpi eq, %163, %c1_i64 : i64
            %165 = arith.cmpi eq, %163, %c2_i64 : i64
            %166 = arith.select %164, %c52064_i64, %c24544_i64 : i64
            %167 = arith.select %165, %c52096_i64, %166 : i64
            %168 = hivm.hir.pointer_cast(%167) : memref<8xf32, #hivm.address_space<ub>>
            %169 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %170 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %171 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
            %172 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
            %173 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
            %174 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
            %175 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            %176 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
            %177 = arith.cmpi eq, %157, %c1_i64 : i64
            %178 = arith.select %177, %c11584_i64, %c47968_i64 : i64
            %179 = hivm.hir.pointer_cast(%178) : memref<8x128xf32, #hivm.address_space<ub>>
            %180 = arith.select %177, %c4096_i64, %c73728_i64 : i64
            %181 = hivm.hir.pointer_cast(%180) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %subview_19 = memref.subview %181[0, 0, %34, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
            %182 = arith.addi %121, %c3_i64 : i64
            %183 = arith.index_cast %121 : i64 to index
            %reinterpret_cast_20 = memref.reinterpret_cast %arg6 to offset: [%183], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %184 = memref.load %reinterpret_cast_20[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %185 = arith.muli %184, %c128_i32 : i32
            %186 = arith.index_cast %185 : i32 to index
            %187 = affine.apply #map4()[%186]
            %188 = arith.index_cast %52 : i32 to index
            %189 = arith.maxsi %186, %188 : index
            %190 = arith.minsi %187, %189 : index
            %191 = affine.apply #map5()[%190, %186]
            %192 = arith.index_cast %155 : i64 to index
            %reinterpret_cast_21 = memref.reinterpret_cast %arg6 to offset: [%192], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %193 = memref.load %reinterpret_cast_21[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %194 = arith.muli %193, %c128_i32 : i32
            %195 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %194, %176, %195, %175, %174) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
            %subview_22 = memref.subview %195[0, 0] [1, %191] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %subview_23 = memref.subview %175[0, 0] [1, %191] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %collapse_shape_24 = memref.collapse_shape %subview_22 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            %collapse_shape_25 = memref.collapse_shape %subview_23 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            hivm.hir.copy ins(%collapse_shape_24 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_25 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%108, %173, %172, %171, %170, %169) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_26 = memref.collapse_shape %176 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
            %collapse_shape_27 = memref.collapse_shape %169 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %196 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_26, %179, %175, %37, %196) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %160
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%196, %171, %collapse_shape_27) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_28 = memref.collapse_shape %170 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %197 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%173, %collapse_shape_27, %174, %197) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %198 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
            %subview_29 = memref.subview %198[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
            hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%197, %196, %collapse_shape_28, %subview_29) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            %expand_shape_30 = memref.expand_shape %subview_29 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
            %collapse_shape_31 = memref.collapse_shape %expand_shape_30 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
            %collapse_shape_32 = memref.collapse_shape %subview_19 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %162
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            hivm.hir.copy ins(%collapse_shape_31 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_32 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
            hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            %199 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%197, %145, %collapse_shape_28, %172, %199) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %200 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
            hivm.hir.copy ins(%197 : memref<8xf32, #hivm.address_space<ub>>) outs(%200 : memref<8xf32, #hivm.address_space<ub>>)
            hivm.hir.copy ins(%200 : memref<8xf32, #hivm.address_space<ub>>) outs(%168 : memref<8xf32, #hivm.address_space<ub>>)
            %201 = arith.addi %152, %c3_i64 : i64
            memref.store %201, %alloca_1[%c0] : memref<1xi64>
            %202 = arith.remui %201, %c2_i64 : i64
            %203 = arith.index_cast %202 : i64 to index
            %204 = affine.apply #map16()[%203]
            %205 = arith.index_cast %204 : index to i64
            %206 = affine.apply #map17()[%203]
            %207 = arith.index_cast %206 : index to i64
            %208 = arith.remui %201, %c3_i64 : i64
            %209 = arith.cmpi eq, %208, %c1_i64 : i64
            %210 = arith.cmpi eq, %208, %c2_i64 : i64
            %211 = arith.select %209, %c52064_i64, %c24544_i64 : i64
            %212 = arith.select %210, %c52096_i64, %211 : i64
            %213 = hivm.hir.pointer_cast(%212) : memref<8xf32, #hivm.address_space<ub>>
            %214 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %215 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %216 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
            %217 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
            %218 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
            %219 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
            %220 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            %221 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
            %222 = arith.cmpi eq, %202, %c1_i64 : i64
            %223 = arith.select %222, %c11584_i64, %c47968_i64 : i64
            %224 = hivm.hir.pointer_cast(%223) : memref<8x128xf32, #hivm.address_space<ub>>
            %225 = arith.select %222, %c4096_i64, %c73728_i64 : i64
            %226 = hivm.hir.pointer_cast(%225) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %subview_33 = memref.subview %226[0, 0, %34, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
            %227 = arith.addi %121, %c4_i64 : i64
            %228 = arith.index_cast %153 : i64 to index
            %reinterpret_cast_34 = memref.reinterpret_cast %arg6 to offset: [%228], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %229 = memref.load %reinterpret_cast_34[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %230 = arith.muli %229, %c128_i32 : i32
            %231 = arith.index_cast %230 : i32 to index
            %232 = affine.apply #map4()[%231]
            %233 = arith.maxsi %231, %188 : index
            %234 = arith.minsi %232, %233 : index
            %235 = affine.apply #map5()[%234, %231]
            %236 = arith.index_cast %182 : i64 to index
            %reinterpret_cast_35 = memref.reinterpret_cast %arg6 to offset: [%236], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %237 = memref.load %reinterpret_cast_35[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %238 = arith.muli %237, %c128_i32 : i32
            %239 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %238, %221, %239, %220, %219) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
            %subview_36 = memref.subview %239[0, 0] [1, %235] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %subview_37 = memref.subview %220[0, 0] [1, %235] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %collapse_shape_38 = memref.collapse_shape %subview_36 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            %collapse_shape_39 = memref.collapse_shape %subview_37 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            hivm.hir.copy ins(%collapse_shape_38 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_39 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%108, %218, %217, %216, %215, %214) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_40 = memref.collapse_shape %221 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
            %collapse_shape_41 = memref.collapse_shape %214 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %240 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_40, %224, %220, %37, %240) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %205
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%240, %216, %collapse_shape_41) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_42 = memref.collapse_shape %215 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %241 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%218, %collapse_shape_41, %219, %241) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %242 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
            %subview_43 = memref.subview %242[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
            hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%241, %240, %collapse_shape_42, %subview_43) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            %expand_shape_44 = memref.expand_shape %subview_43 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
            %collapse_shape_45 = memref.collapse_shape %expand_shape_44 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
            %collapse_shape_46 = memref.collapse_shape %subview_33 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %207
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            hivm.hir.copy ins(%collapse_shape_45 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_46 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
            hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            %243 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%241, %199, %collapse_shape_42, %217, %243) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %244 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
            hivm.hir.copy ins(%241 : memref<8xf32, #hivm.address_space<ub>>) outs(%244 : memref<8xf32, #hivm.address_space<ub>>)
            hivm.hir.copy ins(%244 : memref<8xf32, #hivm.address_space<ub>>) outs(%213 : memref<8xf32, #hivm.address_space<ub>>)
            %245 = arith.addi %152, %c4_i64 : i64
            memref.store %245, %alloca_1[%c0] : memref<1xi64>
            %246 = arith.remui %245, %c2_i64 : i64
            %247 = arith.index_cast %246 : i64 to index
            %248 = affine.apply #map18()[%247]
            %249 = arith.index_cast %248 : index to i64
            %250 = affine.apply #map16()[%247]
            %251 = arith.index_cast %250 : index to i64
            %252 = affine.apply #map17()[%247]
            %253 = arith.index_cast %252 : index to i64
            %254 = arith.remui %245, %c3_i64 : i64
            %255 = arith.cmpi eq, %254, %c1_i64 : i64
            %256 = arith.cmpi eq, %254, %c2_i64 : i64
            %257 = arith.select %255, %c52096_i64, %c52064_i64 : i64
            %258 = arith.select %256, %c24544_i64, %257 : i64
            %259 = arith.select %255, %c52064_i64, %c24544_i64 : i64
            %260 = arith.select %256, %c52096_i64, %259 : i64
            %261 = hivm.hir.pointer_cast(%260) : memref<8xf32, #hivm.address_space<ub>>
            %262 = hivm.hir.pointer_cast(%258) : memref<8xf32, #hivm.address_space<ub>>
            %263 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %264 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %265 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
            %266 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
            %267 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
            %268 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
            %269 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            %270 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
            %271 = arith.cmpi eq, %246, %c1_i64 : i64
            %272 = arith.select %271, %c11584_i64, %c47968_i64 : i64
            %273 = hivm.hir.pointer_cast(%272) : memref<8x128xf32, #hivm.address_space<ub>>
            %274 = arith.select %271, %c4096_i64, %c73728_i64 : i64
            %275 = hivm.hir.pointer_cast(%274) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %276 = arith.select %271, %c7488_i64, %c43872_i64 : i64
            %277 = hivm.hir.pointer_cast(%276) : memref<8x128xf32, #hivm.address_space<ub>>
            %subview_47 = memref.subview %275[0, 0, %34, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
            %278 = arith.addi %121, %c5_i64 : i64
            %279 = memref.load %reinterpret_cast_21[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %280 = arith.muli %279, %c128_i32 : i32
            %281 = arith.index_cast %280 : i32 to index
            %282 = affine.apply #map4()[%281]
            %283 = arith.maxsi %281, %188 : index
            %284 = arith.minsi %282, %283 : index
            %285 = affine.apply #map5()[%284, %281]
            %286 = arith.index_cast %227 : i64 to index
            %reinterpret_cast_48 = memref.reinterpret_cast %arg6 to offset: [%286], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %287 = memref.load %reinterpret_cast_48[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %288 = arith.muli %287, %c128_i32 : i32
            %289 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %288, %270, %289, %269, %268) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
            %subview_49 = memref.subview %289[0, 0] [1, %285] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %subview_50 = memref.subview %269[0, 0] [1, %285] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %collapse_shape_51 = memref.collapse_shape %subview_49 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            %collapse_shape_52 = memref.collapse_shape %subview_50 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            hivm.hir.copy ins(%collapse_shape_51 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_52 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%108, %267, %266, %265, %264, %263) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_53 = memref.collapse_shape %270 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
            %collapse_shape_54 = memref.collapse_shape %263 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %290 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_53, %273, %269, %37, %290) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %251
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%290, %265, %collapse_shape_54) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_55 = memref.collapse_shape %264 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %291 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%267, %collapse_shape_54, %268, %291) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %292 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
            %subview_56 = memref.subview %292[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
            hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%291, %290, %collapse_shape_55, %subview_56) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            %expand_shape_57 = memref.expand_shape %subview_56 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
            %collapse_shape_58 = memref.collapse_shape %expand_shape_57 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
            %collapse_shape_59 = memref.collapse_shape %subview_47 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %253
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            hivm.hir.copy ins(%collapse_shape_58 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_59 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
            hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            %293 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%291, %243, %collapse_shape_55, %266, %293) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %294 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
            hivm.hir.copy ins(%291 : memref<8xf32, #hivm.address_space<ub>>) outs(%294 : memref<8xf32, #hivm.address_space<ub>>)
            hivm.hir.copy ins(%294 : memref<8xf32, #hivm.address_space<ub>>) outs(%261 : memref<8xf32, #hivm.address_space<ub>>)
            %295 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%108, %262, %277, %144, %295) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %249
            %296 = arith.addi %152, %c5_i64 : i64
            memref.store %296, %alloca_1[%c0] : memref<1xi64>
            %297 = arith.subi %148, %c5_i32 : i32
            %298:5 = scf.for %arg37 = %c5_i32 to %297 step %c1_i32 iter_args(%arg38 = %278, %arg39 = %108, %arg40 = %293, %arg41 = %295, %arg42 = %182) -> (i64, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, i64)  : i32 {
              %433 = memref.load %alloca_1[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
              %434 = arith.remui %433, %c2_i64 : i64
              %435 = arith.index_cast %434 : i64 to index
              %436 = affine.apply #map18()[%435]
              %437 = arith.index_cast %436 : index to i64
              %438 = affine.apply #map16()[%435]
              %439 = arith.index_cast %438 : index to i64
              %440 = affine.apply #map17()[%435]
              %441 = arith.index_cast %440 : index to i64
              %442 = arith.remui %433, %c3_i64 : i64
              %443 = arith.cmpi eq, %442, %c1_i64 : i64
              %444 = arith.select %443, %c24544_i64, %c52096_i64 : i64
              %445 = arith.cmpi eq, %442, %c2_i64 : i64
              %446 = arith.select %445, %c52064_i64, %444 : i64
              %447 = hivm.hir.pointer_cast(%446) : memref<8xf32, #hivm.address_space<ub>>
              %448 = arith.select %443, %c52096_i64, %c52064_i64 : i64
              %449 = arith.select %445, %c24544_i64, %448 : i64
              %450 = arith.select %443, %c52064_i64, %c24544_i64 : i64
              %451 = arith.select %445, %c52096_i64, %450 : i64
              %452 = hivm.hir.pointer_cast(%451) : memref<8xf32, #hivm.address_space<ub>>
              %453 = hivm.hir.pointer_cast(%449) : memref<8xf32, #hivm.address_space<ub>>
              %454 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
              %455 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
              %456 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
              %457 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
              %458 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
              %459 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
              %460 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
              %461 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
              %462 = arith.cmpi eq, %434, %c1_i64 : i64
              %463 = arith.select %462, %c11584_i64, %c47968_i64 : i64
              %464 = hivm.hir.pointer_cast(%463) : memref<8x128xf32, #hivm.address_space<ub>>
              %465 = arith.select %462, %c4096_i64, %c73728_i64 : i64
              %466 = hivm.hir.pointer_cast(%465) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
              %467 = arith.select %462, %c7488_i64, %c43872_i64 : i64
              %468 = hivm.hir.pointer_cast(%467) : memref<8x128xf32, #hivm.address_space<ub>>
              %subview_87 = memref.subview %466[0, 0, %34, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
              %469 = arith.addi %arg38, %c1_i64 : i64
              %470 = arith.index_cast %arg42 : i64 to index
              %reinterpret_cast_88 = memref.reinterpret_cast %arg6 to offset: [%470], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %471 = memref.load %reinterpret_cast_88[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %472 = arith.addi %arg42, %c1_i64 : i64
              %473 = arith.muli %471, %c128_i32 : i32
              %474 = arith.index_cast %473 : i32 to index
              %475 = affine.apply #map4()[%474]
              %476 = arith.maxsi %474, %188 : index
              %477 = arith.minsi %475, %476 : index
              %478 = affine.apply #map5()[%477, %474]
              %479 = arith.index_cast %arg38 : i64 to index
              %reinterpret_cast_89 = memref.reinterpret_cast %arg6 to offset: [%479], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %480 = memref.load %reinterpret_cast_89[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
              %481 = arith.muli %480, %c128_i32 : i32
              %482 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %481, %461, %482, %460, %459) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
              %subview_90 = memref.subview %482[0, 0] [1, %478] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
              %subview_91 = memref.subview %460[0, 0] [1, %478] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
              %collapse_shape_92 = memref.collapse_shape %subview_90 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
              %collapse_shape_93 = memref.collapse_shape %subview_91 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
              hivm.hir.copy ins(%collapse_shape_92 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_93 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%arg39, %458, %457, %456, %455, %454) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
              %collapse_shape_94 = memref.collapse_shape %461 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
              %collapse_shape_95 = memref.collapse_shape %454 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
              %483 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
              hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_94, %464, %460, %37, %483) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
              hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %439
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%483, %456, %collapse_shape_95) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
              %collapse_shape_96 = memref.collapse_shape %455 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
              %484 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%458, %collapse_shape_95, %459, %484) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
              %485 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
              %subview_97 = memref.subview %485[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
              hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%484, %483, %collapse_shape_96, %subview_97) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
              hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
              %expand_shape_98 = memref.expand_shape %subview_97 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
              %collapse_shape_99 = memref.collapse_shape %expand_shape_98 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
              %collapse_shape_100 = memref.collapse_shape %subview_87 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
              hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %441
              hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
              hivm.hir.copy ins(%collapse_shape_99 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_100 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
              hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
              hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
              %486 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%484, %arg40, %collapse_shape_96, %457, %486) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
              %487 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
              hivm.hir.copy ins(%484 : memref<8xf32, #hivm.address_space<ub>>) outs(%487 : memref<8xf32, #hivm.address_space<ub>>)
              hivm.hir.copy ins(%487 : memref<8xf32, #hivm.address_space<ub>>) outs(%452 : memref<8xf32, #hivm.address_space<ub>>)
              %488 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
              hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
              func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%arg39, %453, %468, %arg41, %488) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
              hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %437
              %489 = arith.addi %433, %c1_i64 : i64
              memref.store %489, %alloca_1[%c0] : memref<1xi64>
              scf.yield %469, %447, %486, %488, %472 : i64, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, i64
            }
            %299 = memref.load %alloca_1[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
            %300 = arith.remui %299, %c2_i64 : i64
            %301 = arith.index_cast %300 : i64 to index
            %302 = affine.apply #map18()[%301]
            %303 = arith.index_cast %302 : index to i64
            %304 = affine.apply #map16()[%301]
            %305 = arith.index_cast %304 : index to i64
            %306 = affine.apply #map17()[%301]
            %307 = arith.index_cast %306 : index to i64
            %308 = arith.remui %299, %c3_i64 : i64
            %309 = arith.cmpi eq, %308, %c1_i64 : i64
            %310 = arith.cmpi eq, %308, %c2_i64 : i64
            %311 = arith.select %309, %c52096_i64, %c52064_i64 : i64
            %312 = arith.select %310, %c24544_i64, %311 : i64
            %313 = arith.select %309, %c52064_i64, %c24544_i64 : i64
            %314 = arith.select %310, %c52096_i64, %313 : i64
            %315 = hivm.hir.pointer_cast(%314) : memref<8xf32, #hivm.address_space<ub>>
            %316 = hivm.hir.pointer_cast(%312) : memref<8xf32, #hivm.address_space<ub>>
            %317 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %318 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %319 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
            %320 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
            %321 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
            %322 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
            %323 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            %324 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
            %325 = arith.cmpi eq, %300, %c1_i64 : i64
            %326 = arith.select %325, %c11584_i64, %c47968_i64 : i64
            %327 = hivm.hir.pointer_cast(%326) : memref<8x128xf32, #hivm.address_space<ub>>
            %328 = arith.select %325, %c4096_i64, %c73728_i64 : i64
            %329 = hivm.hir.pointer_cast(%328) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %330 = arith.select %325, %c7488_i64, %c43872_i64 : i64
            %331 = hivm.hir.pointer_cast(%330) : memref<8x128xf32, #hivm.address_space<ub>>
            %subview_60 = memref.subview %329[0, 0, %34, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
            %332 = arith.index_cast %298#4 : i64 to index
            %reinterpret_cast_61 = memref.reinterpret_cast %arg6 to offset: [%332], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %333 = memref.load %reinterpret_cast_61[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %334 = arith.addi %298#4, %c1_i64 : i64
            %335 = arith.muli %333, %c128_i32 : i32
            %336 = arith.index_cast %335 : i32 to index
            %337 = affine.apply #map4()[%336]
            %338 = arith.maxsi %336, %188 : index
            %339 = arith.minsi %337, %338 : index
            %340 = affine.apply #map5()[%339, %336]
            %341 = arith.index_cast %298#0 : i64 to index
            %reinterpret_cast_62 = memref.reinterpret_cast %arg6 to offset: [%341], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %342 = memref.load %reinterpret_cast_62[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %343 = arith.muli %342, %c128_i32 : i32
            %344 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %343, %324, %344, %323, %322) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
            %subview_63 = memref.subview %344[0, 0] [1, %340] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %subview_64 = memref.subview %323[0, 0] [1, %340] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %collapse_shape_65 = memref.collapse_shape %subview_63 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            %collapse_shape_66 = memref.collapse_shape %subview_64 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            hivm.hir.copy ins(%collapse_shape_65 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_66 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%298#1, %321, %320, %319, %318, %317) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_67 = memref.collapse_shape %324 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
            %collapse_shape_68 = memref.collapse_shape %317 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %345 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_67, %327, %323, %37, %345) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %305
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%345, %319, %collapse_shape_68) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_69 = memref.collapse_shape %318 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %346 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%321, %collapse_shape_68, %322, %346) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %347 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
            %subview_70 = memref.subview %347[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
            hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%346, %345, %collapse_shape_69, %subview_70) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            %expand_shape_71 = memref.expand_shape %subview_70 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
            %collapse_shape_72 = memref.collapse_shape %expand_shape_71 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
            %collapse_shape_73 = memref.collapse_shape %subview_60 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %307
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            hivm.hir.copy ins(%collapse_shape_72 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_73 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
            hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            %348 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%346, %298#2, %collapse_shape_69, %320, %348) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %349 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
            hivm.hir.copy ins(%346 : memref<8xf32, #hivm.address_space<ub>>) outs(%349 : memref<8xf32, #hivm.address_space<ub>>)
            hivm.hir.copy ins(%349 : memref<8xf32, #hivm.address_space<ub>>) outs(%315 : memref<8xf32, #hivm.address_space<ub>>)
            %350 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%298#1, %316, %331, %298#3, %350) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %303
            %351 = arith.addi %299, %c1_i64 : i64
            memref.store %351, %alloca_1[%c0] : memref<1xi64>
            %352 = arith.remui %351, %c2_i64 : i64
            %353 = arith.index_cast %352 : i64 to index
            %354 = affine.apply #map18()[%353]
            %355 = arith.index_cast %354 : index to i64
            %356 = affine.apply #map16()[%353]
            %357 = arith.index_cast %356 : index to i64
            %358 = affine.apply #map17()[%353]
            %359 = arith.index_cast %358 : index to i64
            %360 = arith.remui %351, %c3_i64 : i64
            %361 = arith.cmpi eq, %360, %c1_i64 : i64
            %362 = arith.cmpi eq, %360, %c2_i64 : i64
            %363 = arith.select %361, %c52096_i64, %c52064_i64 : i64
            %364 = arith.select %362, %c24544_i64, %363 : i64
            %365 = arith.select %361, %c52064_i64, %c24544_i64 : i64
            %366 = arith.select %362, %c52096_i64, %365 : i64
            %367 = hivm.hir.pointer_cast(%366) : memref<8xf32, #hivm.address_space<ub>>
            %368 = hivm.hir.pointer_cast(%364) : memref<8xf32, #hivm.address_space<ub>>
            %369 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %370 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
            %371 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
            %372 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
            %373 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
            %374 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
            %375 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            %376 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
            %377 = arith.cmpi eq, %352, %c1_i64 : i64
            %378 = arith.select %377, %c11584_i64, %c47968_i64 : i64
            %379 = hivm.hir.pointer_cast(%378) : memref<8x128xf32, #hivm.address_space<ub>>
            %380 = arith.select %377, %c4096_i64, %c73728_i64 : i64
            %381 = hivm.hir.pointer_cast(%380) : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
            %382 = arith.select %377, %c7488_i64, %c43872_i64 : i64
            %383 = hivm.hir.pointer_cast(%382) : memref<8x128xf32, #hivm.address_space<ub>>
            %subview_74 = memref.subview %381[0, 0, %34, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
            %384 = arith.index_cast %334 : i64 to index
            %reinterpret_cast_75 = memref.reinterpret_cast %arg6 to offset: [%384], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %385 = memref.load %reinterpret_cast_75[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %386 = arith.muli %385, %c128_i32 : i32
            %387 = arith.index_cast %386 : i32 to index
            %388 = affine.apply #map4()[%387]
            %389 = arith.maxsi %387, %188 : index
            %390 = arith.minsi %388, %389 : index
            %391 = affine.apply #map5()[%390, %387]
            %392 = memref.load %reinterpret_cast_62[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
            %393 = arith.muli %392, %c128_i32 : i32
            %394 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %393, %376, %394, %375, %374) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
            %subview_76 = memref.subview %394[0, 0] [1, %391] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %subview_77 = memref.subview %375[0, 0] [1, %391] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
            %collapse_shape_78 = memref.collapse_shape %subview_76 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            %collapse_shape_79 = memref.collapse_shape %subview_77 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
            hivm.hir.copy ins(%collapse_shape_78 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_79 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%298#1, %373, %372, %371, %370, %369) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_80 = memref.collapse_shape %376 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
            %collapse_shape_81 = memref.collapse_shape %369 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %395 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_80, %379, %375, %37, %395) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %357
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%395, %371, %collapse_shape_81) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %collapse_shape_82 = memref.collapse_shape %370 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
            %396 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%373, %collapse_shape_81, %374, %396) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %397 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
            %subview_83 = memref.subview %397[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
            hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%396, %395, %collapse_shape_82, %subview_83) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
            hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            %expand_shape_84 = memref.expand_shape %subview_83 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
            %collapse_shape_85 = memref.collapse_shape %expand_shape_84 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
            %collapse_shape_86 = memref.collapse_shape %subview_74 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %359
            hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
            hivm.hir.copy ins(%collapse_shape_85 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_86 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
            hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
            %398 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%396, %348, %collapse_shape_82, %372, %398) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
            %399 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
            hivm.hir.copy ins(%396 : memref<8xf32, #hivm.address_space<ub>>) outs(%399 : memref<8xf32, #hivm.address_space<ub>>)
            hivm.hir.copy ins(%399 : memref<8xf32, #hivm.address_space<ub>>) outs(%367 : memref<8xf32, #hivm.address_space<ub>>)
            %400 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%298#1, %368, %383, %350, %400) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %355
            %401 = arith.addi %299, %c2_i64 : i64
            memref.store %401, %alloca_1[%c0] : memref<1xi64>
            %402 = arith.remui %401, %c2_i64 : i64
            %403 = arith.index_cast %402 : i64 to index
            %404 = affine.apply #map18()[%403]
            %405 = arith.index_cast %404 : index to i64
            %406 = arith.remui %401, %c3_i64 : i64
            %407 = arith.cmpi eq, %406, %c1_i64 : i64
            %408 = arith.cmpi eq, %406, %c2_i64 : i64
            %409 = arith.select %407, %c52096_i64, %c52064_i64 : i64
            %410 = arith.select %408, %c24544_i64, %409 : i64
            %411 = hivm.hir.pointer_cast(%410) : memref<8xf32, #hivm.address_space<ub>>
            %412 = arith.cmpi eq, %402, %c1_i64 : i64
            %413 = arith.select %412, %c7488_i64, %c43872_i64 : i64
            %414 = hivm.hir.pointer_cast(%413) : memref<8x128xf32, #hivm.address_space<ub>>
            %415 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%298#1, %411, %414, %400, %415) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %405
            %416 = arith.addi %299, %c3_i64 : i64
            memref.store %416, %alloca_1[%c0] : memref<1xi64>
            %417 = arith.remui %416, %c2_i64 : i64
            %418 = arith.index_cast %417 : i64 to index
            %419 = affine.apply #map18()[%418]
            %420 = arith.index_cast %419 : index to i64
            %421 = arith.remui %416, %c3_i64 : i64
            %422 = arith.cmpi eq, %421, %c1_i64 : i64
            %423 = arith.cmpi eq, %421, %c2_i64 : i64
            %424 = arith.select %422, %c52096_i64, %c52064_i64 : i64
            %425 = arith.select %423, %c24544_i64, %424 : i64
            %426 = hivm.hir.pointer_cast(%425) : memref<8xf32, #hivm.address_space<ub>>
            %427 = arith.cmpi eq, %417, %c1_i64 : i64
            %428 = arith.select %427, %c7488_i64, %c43872_i64 : i64
            %429 = hivm.hir.pointer_cast(%428) : memref<8x128xf32, #hivm.address_space<ub>>
            %430 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
            hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
            func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%298#1, %426, %429, %415, %430) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
            hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %420
            %431 = arith.addi %299, %c4_i64 : i64
            memref.store %431, %alloca_1[%c0] : memref<1xi64>
            %432 = arith.addi %299, %c5_i64 : i64
            memref.store %432, %alloca_1[%c0] : memref<1xi64>
            scf.yield %398, %430 : memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>
          } else {
            %152:5 = scf.for %arg37 = %c0_i32 to %148 step %c1_i32 iter_args(%arg38 = %121, %arg39 = %108, %arg40 = %145, %arg41 = %144, %arg42 = %121) -> (i64, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, i64)  : i32 {
              %153 = arith.subi %arg37, %c2_i32 : i32
              %154 = arith.subi %arg37, %c4_i32 : i32
              %155 = memref.load %alloca[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi64>
              %156 = arith.remui %155, %c3_i64 : i64
              %157 = arith.remui %155, %c2_i64 : i64
              %158 = arith.index_cast %157 : i64 to index
              %159 = arith.cmpi eq, %157, %c1_i64 : i64
              %160 = arith.select %159, %19, %18 : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>>
              %161 = affine.apply #map18()[%158]
              %162 = arith.index_cast %161 : index to i64
              %163 = affine.apply #map16()[%158]
              %164 = arith.index_cast %163 : index to i64
              %165 = affine.apply #map17()[%158]
              %166 = arith.index_cast %165 : index to i64
              %167 = hivm.hir.pointer_cast(%c24512_i64) : memref<8x1xf32, #hivm.address_space<ub>>
              %168 = hivm.hir.pointer_cast(%c24480_i64) : memref<8x1xf32, #hivm.address_space<ub>>
              %169 = hivm.hir.pointer_cast(%c20384_i64) : memref<8x128xi32, #hivm.address_space<ub>>
              %170 = hivm.hir.pointer_cast(%c20352_i64) : memref<8xf32, #hivm.address_space<ub>>
              %171 = hivm.hir.pointer_cast(%c20320_i64) : memref<8xf32, #hivm.address_space<ub>>
              %172 = hivm.hir.pointer_cast(%c20288_i64) : memref<8xi32, #hivm.address_space<ub>>
              %173 = hivm.hir.pointer_cast(%c19776_i64) : memref<1x128xf32, #hivm.address_space<ub>>
              %174 = hivm.hir.pointer_cast(%c15680_i64) : memref<1x8x128xf32, #hivm.address_space<ub>>
              %subview_19 = memref.subview %160[0, 0, %34, 0] [8, 1, 8, 16] [1, 1, 1, 1] {to_be_bubbled_slice} : memref<8x1x16x16xbf16, #hivm.address_space<cbuf>> to memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>>
              %175 = arith.cmpi sge, %arg37, %c0_i32 : i32
              %176 = arith.cmpi slt, %arg37, %125 : i32
              %177 = arith.andi %175, %176 : i1
              %178 = scf.if %177 -> (i64) {
                %189 = arith.addi %arg38, %c1_i64 : i64
                scf.yield %189 : i64
              } else {
                scf.yield %arg38 : i64
              }
              %179 = arith.cmpi sge, %153, %c0_i32 : i32
              %180 = arith.cmpi slt, %153, %125 : i32
              %181 = arith.andi %179, %180 : i1
              %182 = scf.if %181 -> (i64) {
                %189 = arith.index_cast %arg42 : i64 to index
                %reinterpret_cast_21 = memref.reinterpret_cast %arg6 to offset: [%189], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %190 = memref.load %reinterpret_cast_21[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %191 = arith.addi %arg42, %c1_i64 : i64
                %192 = arith.muli %190, %c128_i32 : i32
                %193 = arith.index_cast %192 : i32 to index
                %194 = affine.apply #map4()[%193]
                %195 = arith.index_cast %52 : i32 to index
                %196 = arith.maxsi %193, %195 : index
                %197 = arith.minsi %194, %196 : index
                %198 = affine.apply #map5()[%197, %193]
                %199 = arith.index_cast %arg38 : i64 to index
                %reinterpret_cast_22 = memref.reinterpret_cast %arg6 to offset: [%199], sizes: [1], strides: [1] : memref<?xi32, #hivm.address_space<gm>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %200 = memref.load %reinterpret_cast_22[%c0] {markDCacheInvalidatePatternVisited = 0 : i32} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<gm>>
                %201 = arith.muli %200, %c128_i32 : i32
                %202 = hivm.hir.pointer_cast(%c24576_i64) : memref<1x128xf32, #hivm.address_space<ub>>
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_0_outlined_merged_merged_vf_0(%expand_shape_14, %201, %174, %202, %173, %172) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<1x1x128xi32, #hivm.address_space<ub>>, i32, memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>) -> ()
                %subview_23 = memref.subview %202[0, 0] [1, %198] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
                %subview_24 = memref.subview %173[0, 0] [1, %198] [1, 1] : memref<1x128xf32, #hivm.address_space<ub>> to memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>>
                %collapse_shape_25 = memref.collapse_shape %subview_23 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
                %collapse_shape_26 = memref.collapse_shape %subview_24 [[0, 1]] : memref<1x?xf32, strided<[128, 1]>, #hivm.address_space<ub>> into memref<?xf32, strided<[1]>, #hivm.address_space<ub>>
                hivm.hir.copy ins(%collapse_shape_25 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape_26 : memref<?xf32, strided<[1]>, #hivm.address_space<ub>>)
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_2_outlined_merged_merged_vf_0(%arg39, %171, %170, %169, %168, %167) {hivm.vector_function, no_inline, ptc_simdvf} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>, memref<8x1xf32, #hivm.address_space<ub>>) -> ()
                scf.yield %191 : i64
              } else {
                scf.yield %arg42 : i64
              }
              %collapse_shape_20 = memref.collapse_shape %174 [[0, 1], [2]] : memref<1x8x128xf32, #hivm.address_space<ub>> into memref<8x128xf32, #hivm.address_space<ub>>
              %183 = scf.if %181 -> (memref<8xf32, #hivm.address_space<ub>>) {
                %189 = arith.cmpi eq, %156, %c1_i64 : i64
                %190 = arith.select %189, %11, %10 : memref<8xf32, #hivm.address_space<ub>>
                %191 = arith.cmpi eq, %156, %c2_i64 : i64
                %192 = arith.select %191, %12, %190 : memref<8xf32, #hivm.address_space<ub>>
                %193 = arith.select %159, %17, %16 : memref<8x128xf32, #hivm.address_space<ub>>
                %collapse_shape_21 = memref.collapse_shape %167 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
                %194 = hivm.hir.pointer_cast(%c25088_i64) : memref<8x128xf32, #hivm.address_space<ub>>
                hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 2
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_0(%collapse_shape_20, %193, %173, %37, %194) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<1x128xf32, #hivm.address_space<ub>>, f32, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
                hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %164
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_4_outlined_vf_1(%194, %169, %collapse_shape_21) {hivm.vector_function, no_inline} : (memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
                %collapse_shape_22 = memref.collapse_shape %168 [[0, 1]] : memref<8x1xf32, #hivm.address_space<ub>> into memref<8xf32, #hivm.address_space<ub>>
                %195 = hivm.hir.pointer_cast(%c29184_i64) : memref<8xf32, #hivm.address_space<ub>>
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_0(%171, %collapse_shape_21, %172, %195) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xi32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
                %196 = hivm.hir.pointer_cast(%c29216_i64) : memref<8x17x16x1xbf16, #hivm.address_space<ub>>
                %subview_23 = memref.subview %196[0, 0, 0, 0] [8, 8, 16, 1] [1, 1, 1, 1] : memref<8x17x16x1xbf16, #hivm.address_space<ub>> to memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>
                hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_5_outlined_vf_1(%195, %194, %collapse_shape_22, %subview_23) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>>) -> ()
                hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
                %expand_shape_24 = memref.expand_shape %subview_23 [[0], [1, 2], [3]] output_shape [8, 1, 8, 16] : memref<8x8x16xbf16, strided<[272, 16, 1]>, #hivm.address_space<ub>> into memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>>
                %collapse_shape_25 = memref.collapse_shape %expand_shape_24 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[272, 128, 16, 1]>, #hivm.address_space<ub>> into memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>
                %collapse_shape_26 = memref.collapse_shape %subview_19 [[0, 1], [2, 3]] : memref<8x1x8x16xbf16, strided<[256, 256, 16, 1], offset: ?>, #hivm.address_space<cbuf>> into memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>
                hivm.hir.sync_block_wait[<VECTOR>, <PIPE_MTE1>, <PIPE_MTE3>] flag = %166
                hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
                hivm.hir.copy ins(%collapse_shape_25 : memref<8x128xbf16, strided<[272, 1]>, #hivm.address_space<ub>>) outs(%collapse_shape_26 : memref<8x128xbf16, strided<[256, 1], offset: ?>, #hivm.address_space<cbuf>>) {"hivm.inserted-copy", tiled_op}
                hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
                hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_MTE1>] flag = 1
                %197 = hivm.hir.pointer_cast(%c33568_i64) : memref<8xf32, #hivm.address_space<ub>>
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_6_outlined_vf_0(%195, %arg40, %collapse_shape_22, %170, %197) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>) -> ()
                %198 = hivm.hir.pointer_cast(%c33600_i64) : memref<8xf32, #hivm.address_space<ub>>
                hivm.hir.copy ins(%195 : memref<8xf32, #hivm.address_space<ub>>) outs(%198 : memref<8xf32, #hivm.address_space<ub>>)
                hivm.hir.copy ins(%198 : memref<8xf32, #hivm.address_space<ub>>) outs(%192 : memref<8xf32, #hivm.address_space<ub>>)
                scf.yield %197 : memref<8xf32, #hivm.address_space<ub>>
              } else {
                scf.yield %arg40 : memref<8xf32, #hivm.address_space<ub>>
              }
              %184 = arith.cmpi sge, %154, %c0_i32 : i32
              %185 = arith.cmpi slt, %154, %125 : i32
              %186 = arith.andi %184, %185 : i1
              %187 = scf.if %186 -> (memref<8x128xf32, #hivm.address_space<ub>>) {
                %189 = arith.cmpi eq, %156, %c1_i64 : i64
                %190 = arith.select %189, %14, %13 : memref<8xf32, #hivm.address_space<ub>>
                %191 = arith.cmpi eq, %156, %c2_i64 : i64
                %192 = arith.select %191, %15, %190 : memref<8xf32, #hivm.address_space<ub>>
                %193 = arith.select %159, %21, %20 : memref<8x128xf32, #hivm.address_space<ub>>
                %194 = hivm.hir.pointer_cast(%c33632_i64) : memref<8x128xf32, #hivm.address_space<ub>>
                hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_V>] flag = 1
                func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_7_outlined_vf_0(%arg39, %192, %193, %arg41, %194) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
                hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_FIX>] flag = %162
                scf.yield %194 : memref<8x128xf32, #hivm.address_space<ub>>
              } else {
                scf.yield %arg41 : memref<8x128xf32, #hivm.address_space<ub>>
              }
              %188 = arith.addi %155, %c1_i64 : i64
              memref.store %188, %alloca[%c0] : memref<1xi64>
              scf.yield %178, %110, %183, %187, %182 : i64, memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, i64
            }
            scf.yield %152#2, %152#3 : memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>
          }
          hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, %115]
          func.call @_gqa_sparse_fwd_kernel_mix_aiv_fused_10_outlined_vf_0(%112, %150#0, %150#1, %113) {hivm.vector_function, no_inline} : (memref<8xf32, #hivm.address_space<ub>>, memref<8xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>, memref<8x128xf32, #hivm.address_space<ub>>) -> ()
          %expand_shape_15 = memref.expand_shape %113 [[0, 1], [2]] output_shape [1, 8, 128] : memref<8x128xf32, #hivm.address_space<ub>> into memref<1x8x128xf32, #hivm.address_space<ub>>
          %reinterpret_cast_16 = memref.reinterpret_cast %arg7 to offset: [%129], sizes: [1, 16, 128], strides: [%88, %87, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>
          func.call @_gqa_sparse_fwd_kernel_mix_aiv_outlined_vf_3(%expand_shape_15, %102) {hivm.vector_function, no_inline} : (memref<1x8x128xf32, #hivm.address_space<ub>>, memref<1x8x128xbf16, #hivm.address_space<ub>>) -> ()
          hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
          %subview_17 = memref.subview %102[%136, %97, %80] [%137, %96, %81] [1, 1, 1] : memref<1x8x128xbf16, #hivm.address_space<ub>> to memref<?x?x?xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>
          %subview_18 = memref.subview %reinterpret_cast_16[0, %34, 0] [%137, %91, %81] [1, 1, 1] : memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>
          hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
          hivm.hir.pipe_barrier[<PIPE_MTE3>]
          hivm.hir.store ins(%subview_17 : memref<?x?x?xbf16, strided<[1024, 128, 1], offset: ?>, #hivm.address_space<ub>>) outs(%subview_18 : memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>, #hivm.address_space<gm>>) {tiled_op}
          hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, %115]
          %151 = arith.addi %98, %c1_i64 : i64
          memref.store %151, %alloca_0[%c0] : memref<1xi64>
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


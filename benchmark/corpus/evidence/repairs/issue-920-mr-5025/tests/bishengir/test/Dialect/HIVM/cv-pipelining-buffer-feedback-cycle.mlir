// RUN: bishengir-opt %s -cv-pipelining="pipeline-mode=skew enable-preload=true set-depth-in-unroll-mode=2 bypass-shape-registry=true" | FileCheck %s

// The vector work item hands L1 tiles to the cube work item and consumes the
// cube's fixpipe result from UB, so the two work items form a feedback cycle on
// local staging buffers. No stage assignment can skew that: the leading item
// would always read the buffer the trailing item has not written yet, so the
// loop is left unpipelined.

// The same cycle still has to be caught when hivm-hoist-tightly-coupled-alloc
// has moved one of the local allocs out of the loop: the buffer is local
// staging, not GM, so it is not covered by markOutputs.

// CHECK-LABEL: func.func @feedback_cycle
// CHECK-NOT: hivm.cv_pipelined_loop
// CHECK-LABEL: func.func @feedback_cycle_hoisted
// CHECK-NOT: hivm.cv_pipelined_loop
// CHECK-LABEL: func.func @forwarding_only
// CHECK: scope.scope
// CHECK: } {hivm.loop_core_type = #hivm.tcore_type<VECTOR>, hivm.max_preload_num = 2 : i32, hivm.preload_num = 1 : i32, no_inline}
// CHECK: } {hivm.loop_core_type = #hivm.tcore_type<CUBE>, hivm.max_preload_num = 2 : i32, hivm.preload_num = 0 : i32, no_inline}
module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @feedback_cycle(%arg0: memref<?xi8> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg1: memref<?xi8> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<?xf32> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg4: i32, %arg5: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, func_dyn_memref_args = dense<[true, true, true, true, false, false]> : vector<6xi1>, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<MIX>, mix_mode = "mix", parallel_mode = "simd"} {
    %cst = arith.constant 0.000000e+00 : f32
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c32 = arith.constant 32 : index
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %c4_i32 = arith.constant 4 : i32
    %true = arith.constant true
    scf.for %iv = %c0_i32 to %c4_i32 step %c1_i32 : i32 {
      %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [%c0], sizes: [32], strides: [1] : memref<?xf32> to memref<32xf32, strided<[1], offset: ?>>
      %alloc = memref.alloc() : memref<32xf32>
      hivm.hir.load ins(%reinterpret_cast : memref<32xf32, strided<[1], offset: ?>>) outs(%alloc : memref<32xf32>) eviction_policy = <EvictFirst> core_type = <VECTOR>
      %x = bufferization.to_tensor %alloc restrict writable : memref<32xf32>
      %expanded = tensor.expand_shape %x [[0, 1]] output_shape [1, 32] : tensor<32xf32> into tensor<1x32xf32>
      %9 = tensor.empty() : tensor<16x32xf32>
      %10 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>} ins(%cst : f32) outs(%9 : tensor<16x32xf32>) -> tensor<16x32xf32>
      %inserted_slice = tensor.insert_slice %expanded into %10[0, 0] [1, 32] [1, 1] : tensor<1x32xf32> into tensor<16x32xf32>
      %expanded_2 = tensor.expand_shape %inserted_slice [[0], [1, 2]] output_shape [16, 4, 8] : tensor<16x32xf32> into tensor<16x4x8xf32>
      %11 = tensor.empty() : tensor<4x16x8xf32>
      %12 = hivm.hir.vtranspose ins(%expanded_2 : tensor<16x4x8xf32>) outs(%11 : tensor<4x16x8xf32>) permutation = [1, 0, 2] -> tensor<4x16x8xf32>
      %expanded_3 = tensor.expand_shape %12 [[0], [1, 2], [3]] output_shape [4, 1, 16, 8] : tensor<4x16x8xf32> into tensor<4x1x16x8xf32>
      %alloc_4 = memref.alloc() : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>
      annotation.mark %alloc_4 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<1>} : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>
      %13 = bufferization.to_tensor %alloc_4 restrict writable : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>
      hivm.hir.copy ins(%expanded_3 : tensor<4x1x16x8xf32>) outs(%alloc_4 : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
      %expanded_5 = tensor.expand_shape %x [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %14 = tensor.empty() : tensor<32x8xf32>
      %15 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>} ins(%cst : f32) outs(%14 : tensor<32x8xf32>) -> tensor<32x8xf32>
      %inserted_slice_6 = tensor.insert_slice %expanded_5 into %15[0, 0] [32, 1] [1, 1] : tensor<32x1xf32> into tensor<32x8xf32>
      %expanded_7 = tensor.expand_shape %inserted_slice_6 [[0], [1, 2]] output_shape [32, 1, 8] : tensor<32x8xf32> into tensor<32x1x8xf32>
      %16 = tensor.empty() : tensor<1x32x8xf32>
      %17 = hivm.hir.vtranspose ins(%expanded_7 : tensor<32x1x8xf32>) outs(%16 : tensor<1x32x8xf32>) permutation = [1, 0, 2] -> tensor<1x32x8xf32>
      %expanded_8 = tensor.expand_shape %17 [[0], [1, 2], [3]] output_shape [1, 2, 16, 8] : tensor<1x32x8xf32> into tensor<1x2x16x8xf32>
      %alloc_9 = memref.alloc() : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>
      annotation.mark %alloc_9 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<2>} : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>
      %18 = bufferization.to_tensor %alloc_9 restrict writable : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>
      hivm.hir.copy ins(%expanded_8 : tensor<1x2x16x8xf32>) outs(%alloc_9 : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
      %19 = tensor.empty() : tensor<1x1x16x16xf32>
      %20 = hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%13, %18, %true, %c1, %c32, %c1 : tensor<4x1x16x8xf32>, tensor<1x2x16x8xf32>, i1, index, index, index) outs(%19 : tensor<1x1x16x16xf32>) -> tensor<1x1x16x16xf32>
      %alloc_10 = memref.alloc() : memref<1x1xf32, #hivm.address_space<ub>>
      annotation.mark %alloc_10 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>} : memref<1x1xf32, #hivm.address_space<ub>>
      %memspacecast = memref.memory_space_cast %alloc_10 : memref<1x1xf32, #hivm.address_space<ub>> to memref<1x1xf32>
      %21 = bufferization.to_tensor %memspacecast restrict writable : memref<1x1xf32>
      hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%20 : tensor<1x1x16x16xf32>) outs(%alloc_10 : memref<1x1xf32, #hivm.address_space<ub>>)
      %collapsed = tensor.collapse_shape %21 [[0, 1]] : tensor<1x1xf32> into tensor<1xf32>
      %extracted = tensor.extract %collapsed[%c0] : tensor<1xf32>
      %reinterpret_cast_11 = memref.reinterpret_cast %arg3 to offset: [%c0], sizes: [32], strides: [1] : memref<?xf32> to memref<32xf32, strided<[1], offset: ?>>
      %22 = tensor.empty() : tensor<32xf32>
      %23 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>} ins(%extracted : f32) outs(%22 : tensor<32xf32>) -> tensor<32xf32>
      hivm.hir.store ins(%23 : tensor<32xf32>) outs(%reinterpret_cast_11 : memref<32xf32, strided<[1], offset: ?>>) {autoblockify.dma}
    }
    return
  }

  func.func @feedback_cycle_hoisted(%arg0: memref<?xi8> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg1: memref<?xi8> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<?xf32> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg4: i32, %arg5: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, func_dyn_memref_args = dense<[true, true, true, true, false, false]> : vector<6xi1>, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<MIX>, mix_mode = "mix", parallel_mode = "simd"} {
    %cst = arith.constant 0.000000e+00 : f32
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c32 = arith.constant 32 : index
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %c4_i32 = arith.constant 4 : i32
    %true = arith.constant true
    %alloc_10 = memref.alloc() : memref<1x1xf32, #hivm.address_space<ub>>
    annotation.mark %alloc_10 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>} : memref<1x1xf32, #hivm.address_space<ub>>
    scf.for %iv = %c0_i32 to %c4_i32 step %c1_i32 : i32 {
      %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [%c0], sizes: [32], strides: [1] : memref<?xf32> to memref<32xf32, strided<[1], offset: ?>>
      %alloc = memref.alloc() : memref<32xf32>
      hivm.hir.load ins(%reinterpret_cast : memref<32xf32, strided<[1], offset: ?>>) outs(%alloc : memref<32xf32>) eviction_policy = <EvictFirst> core_type = <VECTOR>
      %x = bufferization.to_tensor %alloc restrict writable : memref<32xf32>
      %expanded = tensor.expand_shape %x [[0, 1]] output_shape [1, 32] : tensor<32xf32> into tensor<1x32xf32>
      %9 = tensor.empty() : tensor<16x32xf32>
      %10 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>} ins(%cst : f32) outs(%9 : tensor<16x32xf32>) -> tensor<16x32xf32>
      %inserted_slice = tensor.insert_slice %expanded into %10[0, 0] [1, 32] [1, 1] : tensor<1x32xf32> into tensor<16x32xf32>
      %expanded_2 = tensor.expand_shape %inserted_slice [[0], [1, 2]] output_shape [16, 4, 8] : tensor<16x32xf32> into tensor<16x4x8xf32>
      %11 = tensor.empty() : tensor<4x16x8xf32>
      %12 = hivm.hir.vtranspose ins(%expanded_2 : tensor<16x4x8xf32>) outs(%11 : tensor<4x16x8xf32>) permutation = [1, 0, 2] -> tensor<4x16x8xf32>
      %expanded_3 = tensor.expand_shape %12 [[0], [1, 2], [3]] output_shape [4, 1, 16, 8] : tensor<4x16x8xf32> into tensor<4x1x16x8xf32>
      %alloc_4 = memref.alloc() : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>
      annotation.mark %alloc_4 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<1>} : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>
      %13 = bufferization.to_tensor %alloc_4 restrict writable : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>
      hivm.hir.copy ins(%expanded_3 : tensor<4x1x16x8xf32>) outs(%alloc_4 : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
      %expanded_5 = tensor.expand_shape %x [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %14 = tensor.empty() : tensor<32x8xf32>
      %15 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>} ins(%cst : f32) outs(%14 : tensor<32x8xf32>) -> tensor<32x8xf32>
      %inserted_slice_6 = tensor.insert_slice %expanded_5 into %15[0, 0] [32, 1] [1, 1] : tensor<32x1xf32> into tensor<32x8xf32>
      %expanded_7 = tensor.expand_shape %inserted_slice_6 [[0], [1, 2]] output_shape [32, 1, 8] : tensor<32x8xf32> into tensor<32x1x8xf32>
      %16 = tensor.empty() : tensor<1x32x8xf32>
      %17 = hivm.hir.vtranspose ins(%expanded_7 : tensor<32x1x8xf32>) outs(%16 : tensor<1x32x8xf32>) permutation = [1, 0, 2] -> tensor<1x32x8xf32>
      %expanded_8 = tensor.expand_shape %17 [[0], [1, 2], [3]] output_shape [1, 2, 16, 8] : tensor<1x32x8xf32> into tensor<1x2x16x8xf32>
      %alloc_9 = memref.alloc() : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>
      annotation.mark %alloc_9 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<2>} : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>
      %18 = bufferization.to_tensor %alloc_9 restrict writable : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>
      hivm.hir.copy ins(%expanded_8 : tensor<1x2x16x8xf32>) outs(%alloc_9 : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
      %19 = tensor.empty() : tensor<1x1x16x16xf32>
      %20 = hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%13, %18, %true, %c1, %c32, %c1 : tensor<4x1x16x8xf32>, tensor<1x2x16x8xf32>, i1, index, index, index) outs(%19 : tensor<1x1x16x16xf32>) -> tensor<1x1x16x16xf32>
      %memspacecast = memref.memory_space_cast %alloc_10 : memref<1x1xf32, #hivm.address_space<ub>> to memref<1x1xf32>
      %21 = bufferization.to_tensor %memspacecast restrict writable : memref<1x1xf32>
      hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%20 : tensor<1x1x16x16xf32>) outs(%alloc_10 : memref<1x1xf32, #hivm.address_space<ub>>)
      %collapsed = tensor.collapse_shape %21 [[0, 1]] : tensor<1x1xf32> into tensor<1xf32>
      %extracted = tensor.extract %collapsed[%c0] : tensor<1xf32>
      %reinterpret_cast_11 = memref.reinterpret_cast %arg3 to offset: [%c0], sizes: [32], strides: [1] : memref<?xf32> to memref<32xf32, strided<[1], offset: ?>>
      %22 = tensor.empty() : tensor<32xf32>
      %23 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>} ins(%extracted : f32) outs(%22 : tensor<32xf32>) -> tensor<32xf32>
      hivm.hir.store ins(%23 : tensor<32xf32>) outs(%reinterpret_cast_11 : memref<32xf32, strided<[1], offset: ?>>) {autoblockify.dma}
    }
    return
  }

  func.func @forwarding_only(%arg0: memref<?xi8> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg1: memref<?xi8> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<?xf32> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg4: i32, %arg5: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, func_dyn_memref_args = dense<[true, true, true, true, false, false]> : vector<6xi1>, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<MIX>, mix_mode = "mix", parallel_mode = "simd"} {
    %cst = arith.constant 0.000000e+00 : f32
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c32 = arith.constant 32 : index
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %c4_i32 = arith.constant 4 : i32
    %true = arith.constant true
    scf.for %iv = %c0_i32 to %c4_i32 step %c1_i32 : i32 {
      %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [%c0], sizes: [32], strides: [1] : memref<?xf32> to memref<32xf32, strided<[1], offset: ?>>
      %alloc = memref.alloc() : memref<32xf32>
      hivm.hir.load ins(%reinterpret_cast : memref<32xf32, strided<[1], offset: ?>>) outs(%alloc : memref<32xf32>) eviction_policy = <EvictFirst> core_type = <VECTOR>
      %x = bufferization.to_tensor %alloc restrict writable : memref<32xf32>
      %expanded = tensor.expand_shape %x [[0, 1]] output_shape [1, 32] : tensor<32xf32> into tensor<1x32xf32>
      %9 = tensor.empty() : tensor<16x32xf32>
      %10 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>} ins(%cst : f32) outs(%9 : tensor<16x32xf32>) -> tensor<16x32xf32>
      %inserted_slice = tensor.insert_slice %expanded into %10[0, 0] [1, 32] [1, 1] : tensor<1x32xf32> into tensor<16x32xf32>
      %expanded_2 = tensor.expand_shape %inserted_slice [[0], [1, 2]] output_shape [16, 4, 8] : tensor<16x32xf32> into tensor<16x4x8xf32>
      %11 = tensor.empty() : tensor<4x16x8xf32>
      %12 = hivm.hir.vtranspose ins(%expanded_2 : tensor<16x4x8xf32>) outs(%11 : tensor<4x16x8xf32>) permutation = [1, 0, 2] -> tensor<4x16x8xf32>
      %expanded_3 = tensor.expand_shape %12 [[0], [1, 2], [3]] output_shape [4, 1, 16, 8] : tensor<4x16x8xf32> into tensor<4x1x16x8xf32>
      %alloc_4 = memref.alloc() : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>
      annotation.mark %alloc_4 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<1>} : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>
      %13 = bufferization.to_tensor %alloc_4 restrict writable : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>
      hivm.hir.copy ins(%expanded_3 : tensor<4x1x16x8xf32>) outs(%alloc_4 : memref<4x1x16x8xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
      %expanded_5 = tensor.expand_shape %x [[0, 1]] output_shape [32, 1] : tensor<32xf32> into tensor<32x1xf32>
      %14 = tensor.empty() : tensor<32x8xf32>
      %15 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>} ins(%cst : f32) outs(%14 : tensor<32x8xf32>) -> tensor<32x8xf32>
      %inserted_slice_6 = tensor.insert_slice %expanded_5 into %15[0, 0] [32, 1] [1, 1] : tensor<32x1xf32> into tensor<32x8xf32>
      %expanded_7 = tensor.expand_shape %inserted_slice_6 [[0], [1, 2]] output_shape [32, 1, 8] : tensor<32x8xf32> into tensor<32x1x8xf32>
      %16 = tensor.empty() : tensor<1x32x8xf32>
      %17 = hivm.hir.vtranspose ins(%expanded_7 : tensor<32x1x8xf32>) outs(%16 : tensor<1x32x8xf32>) permutation = [1, 0, 2] -> tensor<1x32x8xf32>
      %expanded_8 = tensor.expand_shape %17 [[0], [1, 2], [3]] output_shape [1, 2, 16, 8] : tensor<1x32x8xf32> into tensor<1x2x16x8xf32>
      %alloc_9 = memref.alloc() : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>
      annotation.mark %alloc_9 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<2>} : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>
      %18 = bufferization.to_tensor %alloc_9 restrict writable : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>
      hivm.hir.copy ins(%expanded_8 : tensor<1x2x16x8xf32>) outs(%alloc_9 : memref<1x2x16x8xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
      %19 = tensor.empty() : tensor<1x1x16x16xf32>
      %20 = hivm.hir.mmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C} ins(%13, %18, %true, %c1, %c32, %c1 : tensor<4x1x16x8xf32>, tensor<1x2x16x8xf32>, i1, index, index, index) outs(%19 : tensor<1x1x16x16xf32>) -> tensor<1x1x16x16xf32>
      %alloc_10 = memref.alloc() : memref<1x1xf32, #hivm.address_space<ub>>
      hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%20 : tensor<1x1x16x16xf32>) outs(%alloc_10 : memref<1x1xf32, #hivm.address_space<ub>>)
      %reinterpret_cast_11 = memref.reinterpret_cast %arg3 to offset: [%c0], sizes: [32], strides: [1] : memref<?xf32> to memref<32xf32, strided<[1], offset: ?>>
      %22 = tensor.empty() : tensor<32xf32>
      %23 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>} ins(%cst : f32) outs(%22 : tensor<32xf32>) -> tensor<32xf32>
      hivm.hir.store ins(%23 : tensor<32xf32>) outs(%reinterpret_cast_11 : memref<32xf32, strided<[1], offset: ?>>) {autoblockify.dma}
    }
    return
  }
}

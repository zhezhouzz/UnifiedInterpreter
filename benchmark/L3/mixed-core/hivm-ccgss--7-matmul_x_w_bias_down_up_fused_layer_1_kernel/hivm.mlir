module {
  func.func @matmul_x_w_bias_down_up_fused_layer_1_kernel(%arg0: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}, %arg1: memref<?xi8> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<?xf16> {tt.divisibility = 16 : i32}, %arg3: memref<?xf16> {tt.divisibility = 16 : i32}, %arg4: memref<?xf16> {tt.divisibility = 16 : i32}, %arg5: memref<?xf16> {tt.divisibility = 16 : i32}, %arg6: memref<?xf16> {tt.divisibility = 16 : i32}, %arg7: memref<?xf16> {tt.divisibility = 16 : i32}, %arg8: memref<?xf16> {tt.divisibility = 16 : i32}, %arg9: i32 {tt.divisibility = 16 : i32}, %arg10: i32 {tt.divisibility = 16 : i32}, %arg11: i32 {tt.divisibility = 16 : i32}, %arg12: i32 {tt.divisibility = 16 : i32}, %arg13: i32 {tt.divisibility = 16 : i32}, %arg14: i32 {tt.divisibility = 16 : i32}, %arg15: i32 {tt.divisibility = 16 : i32}, %arg16: i32 {tt.divisibility = 16 : i32}, %arg17: i32, %arg18: i32, %arg19: i32) attributes {WorkspaceArgIdx = 0 : i64, func_dyn_memref_args = dense<[false, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false]> : vector<20xi1>, global_kernel = "local", hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<MIX>, mix_mode = "mix"} {
    %alloca = memref.alloca() : memref<1xi64>
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    memref.store %c0_i64, %alloca[%c0] : memref<1xi64>
    %c1_i64 = arith.constant 1 : i64
    %c0_i64_0 = arith.constant 0 : i64
    %c0_i64_1 = arith.constant 0 : i64
    %c0_i64_2 = arith.constant 0 : i64
    %c1_i64_3 = arith.constant 1 : i64
    hivm.hir.set_ffts_base_addr %arg0
    %true = arith.constant true
    %c31_i32 = arith.constant 31 : i32
    %c0_i32 = arith.constant 0 : i32
    %c32_i32 = arith.constant 32 : i32
    %c0_4 = arith.constant 0 : index
    %c32 = arith.constant 32 : index
    %cst = arith.constant 0.000000e+00 : f16
    %c64 = arith.constant 64 : index
    %c1_i32 = arith.constant 1 : i32
    %0 = hivm.hir.get_block_idx -> i64
    %1 = arith.trunci %0 : i64 to i32
    %2 = arith.divsi %1, %arg19 : i32
    %3 = arith.remsi %2, %arg18 : i32
    %4 = arith.muli %arg19, %arg18 : i32
    %5 = arith.divsi %1, %4 : i32
    %6 = arith.remsi %5, %arg17 : i32
    hivm.hir.set_mask_norm
    %7 = arith.muli %6, %c32_i32 : i32
    %8 = arith.muli %3, %c32_i32 : i32
    %9 = arith.index_cast %7 : i32 to index
    %10 = arith.index_cast %arg12 : i32 to index
    %11 = arith.muli %9, %10 : index
    %12 = arith.index_cast %8 : i32 to index
    %13 = arith.index_cast %arg14 : i32 to index
    %14 = arith.addi %arg11, %c31_i32 : i32
    %15 = arith.divsi %14, %c32_i32 : i32
    %16 = arith.muli %arg13, %c32_i32 : i32
    %17 = arith.muli %arg14, %c32_i32 : i32
    %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [%11], sizes: [32, 32], strides: [%10, 1] : memref<?xf16> to memref<32x32xf16, strided<[?, 1], offset: ?>>
    %cast = memref.cast %reinterpret_cast : memref<32x32xf16, strided<[?, 1], offset: ?>> to memref<32x32xf16, strided<[?, ?], offset: ?>>
    %reinterpret_cast_5 = memref.reinterpret_cast %arg5 to offset: [0], sizes: [32, 64], strides: [%13, 1] : memref<?xf16> to memref<32x64xf16, strided<[?, 1]>>
    %cast_6 = memref.cast %reinterpret_cast_5 : memref<32x64xf16, strided<[?, 1]>> to memref<32x64xf16, strided<[?, ?], offset: ?>>
    %18 = tensor.empty() : tensor<32x64xf32>
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    %19:9 = scf.for %arg20 = %c0_i32 to %15 step %c1_i32 iter_args(%arg21 = %18, %arg22 = %cast, %arg23 = %cast_6, %arg24 = %11, %arg25 = %c0_4, %arg26 = %12, %arg27 = %c0_4, %arg28 = %c0_4, %arg29 = %c0_4) -> (tensor<32x64xf32>, memref<32x32xf16, strided<[?, ?], offset: ?>>, memref<32x64xf16, strided<[?, ?], offset: ?>>, index, index, index, index, index, index)  : i32 {
      %c0_14 = arith.constant 0 : index
      %47 = memref.load %alloca[%c0_14] : memref<1xi64>
      %48 = arith.index_cast %47 : i64 to index
      %49 = arith.index_cast %48 : index to i64
      %c0_i64_15 = arith.constant 0 : i64
      %c1_i64_16 = arith.constant 1 : i64
      %50 = arith.muli %arg20, %c32_i32 : i32
      %alloc_17 = memref.alloc() : memref<32x32xf16>
      %51 = arith.addi %9, %c32 : index
      %52 = arith.index_cast %arg9 : i32 to index
      %53 = arith.maxsi %9, %52 : index
      %54 = arith.minsi %51, %53 : index
      %55 = arith.subi %54, %9 : index
      %56 = arith.index_cast %50 : i32 to index
      %57 = arith.addi %56, %c32 : index
      %58 = arith.index_cast %arg11 : i32 to index
      %59 = arith.maxsi %56, %58 : index
      %60 = arith.minsi %57, %59 : index
      %61 = arith.subi %60, %56 : index
      %62 = arith.minsi %55, %c32 : index
      %63 = arith.minsi %61, %c32 : index
      %subview_18 = memref.subview %arg22[0, 0] [%62, %63] [1, 1] : memref<32x32xf16, strided<[?, ?], offset: ?>> to memref<?x?xf16, strided<[?, ?], offset: ?>>
      %subview_19 = memref.subview %alloc_17[0, 0] [%62, %63] [1, 1] : memref<32x32xf16> to memref<?x?xf16, strided<[32, 1]>>
      hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.load ins(%subview_18 : memref<?x?xf16, strided<[?, ?], offset: ?>>) outs(%subview_19 : memref<?x?xf16, strided<[32, 1]>>) pad_mode = <PadValue> pad_value = %cst : f16 left_padding_num = %c0_4 : index
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
      %64 = bufferization.to_tensor %alloc_17 restrict writable : memref<32x32xf16>
      %alloc_20 = memref.alloc() : memref<32x64xf16>
      %subview_21 = memref.subview %arg23[0, 0] [%61, 64] [1, 1] : memref<32x64xf16, strided<[?, ?], offset: ?>> to memref<?x64xf16, strided<[?, ?], offset: ?>>
      %subview_22 = memref.subview %alloc_20[0, 0] [%61, 64] [1, 1] : memref<32x64xf16> to memref<?x64xf16, strided<[64, 1]>>
      hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
      hivm.hir.load ins(%subview_21 : memref<?x64xf16, strided<[?, ?], offset: ?>>) outs(%subview_22 : memref<?x64xf16, strided<[64, 1]>>) pad_mode = <PadValue> pad_value = %cst : f16 left_padding_num = %c0_4 : index
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID1>]
      %65 = bufferization.to_tensor %alloc_20 restrict writable : memref<32x64xf16>
      %66 = arith.cmpi eq, %arg20, %c0_i32 : i32
      %c-1_i64_23 = arith.constant -1 : i64
      %67 = hivm.hir.mmadL1 ins(%64, %65, %66, %62, %63, %c64 : tensor<32x32xf16>, tensor<32x64xf16>, i1, index, index, index) outs(%arg21 : tensor<32x64xf32>) sync_related_args(%c0_i64_2, %c1_i64_3, %c0_i64_0, %c1_i64, %49, %c0_i64_15, %c1_i64_16 : i64, i64, i64, i64, i64, i64, i64) -> tensor<32x64xf32>
      %68 = arith.addi %arg24, %c32 : index
      %69 = arith.addi %68, %arg25 : index
      %reinterpret_cast_24 = memref.reinterpret_cast %arg2 to offset: [%69], sizes: [32, 32], strides: [%10, 1] : memref<?xf16> to memref<32x32xf16, strided<[?, 1], offset: ?>>
      %cast_25 = memref.cast %reinterpret_cast_24 : memref<32x32xf16, strided<[?, 1], offset: ?>> to memref<32x32xf16, strided<[?, ?], offset: ?>>
      %70 = arith.index_cast %16 : i32 to index
      %71 = arith.addi %arg26, %70 : index
      %72 = arith.addi %71, %arg27 : index
      %73 = arith.index_cast %17 : i32 to index
      %74 = arith.addi %arg28, %73 : index
      %75 = arith.addi %74, %arg29 : index
      %reinterpret_cast_26 = memref.reinterpret_cast %arg5 to offset: [%75], sizes: [32, 64], strides: [%13, 1] : memref<?xf16> to memref<32x64xf16, strided<[?, 1], offset: ?>>
      %cast_27 = memref.cast %reinterpret_cast_26 : memref<32x64xf16, strided<[?, 1], offset: ?>> to memref<32x64xf16, strided<[?, ?], offset: ?>>
      %c1_i64_28 = arith.constant 1 : i64
      %76 = arith.addi %47, %c1_i64_28 : i64
      %c0_29 = arith.constant 0 : index
      memref.store %76, %alloca[%c0_29] : memref<1xi64>
      scf.yield %67, %cast_25, %cast_27, %69, %c0_4, %72, %c0_4, %75, %c0_4 : tensor<32x64xf32>, memref<32x32xf16, strided<[?, ?], offset: ?>>, memref<32x64xf16, strided<[?, ?], offset: ?>>, index, index, index, index, index, index
    }
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
    %20 = arith.muli %9, %c64 : index
    %reinterpret_cast_7 = memref.reinterpret_cast %arg8 to offset: [%20], sizes: [32, 64], strides: [64, 1] : memref<?xf16> to memref<32x64xf16, strided<[64, 1], offset: ?>>
    %21 = memref_ext.alloc_workspace() from %arg1 offset = [%c0_4] : from memref<?xi8> to memref<32x64xf16>
    %22 = bufferization.to_tensor %21 restrict writable : memref<32x64xf16>
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
    %23 = hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>, pre_quant = #hivm.fixpipe_pre_quant_mode<F322F16>} ins(%19#0 : tensor<32x64xf32>) outs(%22 : tensor<32x64xf16>) -> tensor<32x64xf16>
    hivm.hir.set_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID0>]
    %24 = tensor.empty() : tensor<32x64xf16>
    hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID0>]
    %25 = hivm.hir.load ins(%23 : tensor<32x64xf16>) outs(%24 : tensor<32x64xf16>) -> tensor<32x64xf16>
    %26 = tensor.empty() : tensor<32x64xf16>
    %27 = hivm.hir.load ins(%23 : tensor<32x64xf16>) outs(%26 : tensor<32x64xf16>) -> tensor<32x64xf16>
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%25 : tensor<32x64xf16>) outs(%reinterpret_cast_7 : memref<32x64xf16, strided<[64, 1], offset: ?>>)
    %28 = arith.index_cast %arg15 : i32 to index
    %reinterpret_cast_8 = memref.reinterpret_cast %arg6 to offset: [%12], sizes: [64, 32], strides: [%28, 1] : memref<?xf16> to memref<64x32xf16, strided<[?, 1], offset: ?>>
    %alloc = memref.alloc() : memref<64x32xf16>
    %29 = arith.addi %12, %c32 : index
    %30 = arith.index_cast %arg10 : i32 to index
    %31 = arith.maxsi %12, %30 : index
    %32 = arith.minsi %29, %31 : index
    %33 = arith.subi %32, %12 : index
    %subview = memref.subview %reinterpret_cast_8[0, 0] [64, %33] [1, 1] : memref<64x32xf16, strided<[?, 1], offset: ?>> to memref<64x?xf16, strided<[?, 1], offset: ?>>
    %subview_9 = memref.subview %alloc[0, 0] [64, %33] [1, 1] : memref<64x32xf16> to memref<64x?xf16, strided<[32, 1]>>
    hivm.hir.load ins(%subview : memref<64x?xf16, strided<[?, 1], offset: ?>>) outs(%subview_9 : memref<64x?xf16, strided<[32, 1]>>) pad_mode = <PadValue> pad_value = %cst : f16 left_padding_num = %c0_4 : index
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
    %34 = bufferization.to_tensor %alloc restrict writable : memref<64x32xf16>
    %35 = tensor.empty() : tensor<32x32xf32>
    %c-1_i64 = arith.constant -1 : i64
    %c0_i64_10 = arith.constant 0 : i64
    %c1_i64_11 = arith.constant 1 : i64
    %36 = hivm.hir.mmadL1 ins(%27, %34, %true, %c32, %c64, %33 : tensor<32x64xf16>, tensor<64x32xf16>, i1, index, index, index) outs(%35 : tensor<32x32xf32>) sync_related_args(%c-1_i64, %c0_i64_1, %c-1_i64, %c-1_i64, %c-1_i64, %c0_i64_10, %c1_i64_11 : i64, i64, i64, i64, i64, i64, i64) -> tensor<32x32xf32>
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    %37 = arith.index_cast %arg16 : i32 to index
    %38 = arith.muli %9, %37 : index
    %39 = arith.addi %38, %12 : index
    %reinterpret_cast_12 = memref.reinterpret_cast %arg7 to offset: [%39], sizes: [32, 32], strides: [%37, 1] : memref<?xf16> to memref<32x32xf16, strided<[?, 1], offset: ?>>
    %40 = arith.addi %9, %c32 : index
    %41 = arith.index_cast %arg9 : i32 to index
    %42 = arith.maxsi %9, %41 : index
    %43 = arith.minsi %40, %42 : index
    %44 = arith.subi %43, %9 : index
    %45 = arith.minsi %44, %c32 : index
    %46 = arith.minsi %33, %c32 : index
    %extracted_slice = tensor.extract_slice %36[0, 0] [%45, %46] [1, 1] : tensor<32x32xf32> to tensor<?x?xf32>
    %subview_13 = memref.subview %reinterpret_cast_12[0, 0] [%45, %46] [1, 1] : memref<32x32xf16, strided<[?, 1], offset: ?>> to memref<?x?xf16, strided<[?, 1], offset: ?>>
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>, pre_quant = #hivm.fixpipe_pre_quant_mode<F322F16>} ins(%extracted_slice : tensor<?x?xf32>) outs(%subview_13 : memref<?x?xf16, strided<[?, 1], offset: ?>>)
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
}


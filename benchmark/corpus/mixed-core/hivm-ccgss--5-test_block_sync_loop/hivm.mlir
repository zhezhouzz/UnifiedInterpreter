module {
  func.func @test_block_sync_loop(%arg0: memref<16xf32>, %arg1: memref<16xf32>, %arg2: memref<256xf32>, %arg3: memref<256xf32>, %arg4: i1, %arg5: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}) attributes {hacc.always_inline, hfusion.fusion_kind = #hfusion.fusion_kind<MIX_CV>, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %c0_i64 = arith.constant 0 : i64
    %c1_i64 = arith.constant 1 : i64
    hivm.hir.set_ffts_base_addr %arg5
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %c256 = arith.constant 256 : index
    %alloc = memref.alloc() : memref<16xf32>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32>) outs(%alloc : memref<16xf32>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
    %alloc_0 = memref.alloc() : memref<16xf32>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32>) outs(%alloc_0 : memref<16xf32>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID1>]
    %alloc_1 = memref.alloc() : memref<256xf32>
    %c-1_i64 = arith.constant -1 : i64
    %c0_i64_2 = arith.constant 0 : i64
    %c1_i64_3 = arith.constant 1 : i64
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.mmadL1 ins(%alloc, %alloc_0, %true, %c16, %c256, %c16 : memref<16xf32>, memref<16xf32>, i1, index, index, index) outs(%alloc_1 : memref<256xf32>) sync_related_args(%c0_i64, %c1_i64, %c-1_i64, %c-1_i64, %c-1_i64, %c0_i64_2, %c1_i64_3 : i64, i64, i64, i64, i64, i64, i64)
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%alloc_1 : memref<256xf32>) outs(%arg2 : memref<256xf32>)
    hivm.hir.set_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID0>]
    %0 = bufferization.to_tensor %arg2 restrict writable : memref<256xf32>
    %1 = tensor.empty() : tensor<256xf32>
    hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID0>]
    %2 = hivm.hir.load ins(%0 : tensor<256xf32>) outs(%1 : tensor<256xf32>) -> tensor<256xf32>
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    %3 = tensor.empty() : tensor<256xf32>
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    %4 = hivm.hir.vsub ins(%2, %2 : tensor<256xf32>, tensor<256xf32>) outs(%3 : tensor<256xf32>) -> tensor<256xf32>
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    %5 = tensor.empty() : tensor<256xf32>
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    %6 = hivm.hir.store ins(%4 : tensor<256xf32>) outs(%5 : tensor<256xf32>) -> tensor<256xf32>
    return
  }
}


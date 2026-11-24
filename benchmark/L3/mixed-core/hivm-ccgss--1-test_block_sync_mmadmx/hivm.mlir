module {
  func.func @test_block_sync_mmadmx(%arg0: memref<32xf8E5M2, #hivm.address_space<gm>>, %arg1: memref<32xf8E5M2, #hivm.address_space<gm>>, %arg2: memref<2xui8, #hivm.address_space<gm>>, %arg3: memref<2xui8, #hivm.address_space<gm>>, %arg4: memref<1024xf32, #hivm.address_space<gm>>, %arg5: memref<1024xf32, #hivm.address_space<gm>>, %arg6: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}) attributes {hacc.always_inline, hfusion.fusion_kind = #hfusion.fusion_kind<MIX_CV>, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %c0_i64 = arith.constant 0 : i64
    %c1_i64 = arith.constant 1 : i64
    %c2_i64 = arith.constant 2 : i64
    hivm.hir.set_ffts_base_addr %arg6
    %c64_i64 = arith.constant 64 : i64
    %c128_i64 = arith.constant 128 : i64
    %c192_i64 = arith.constant 192 : i64
    %true = arith.constant true
    %c32 = arith.constant 32 : index
    %c32_0 = arith.constant 32 : index
    %c0_i64_1 = arith.constant 0 : i64
    %alloc = memref.alloc() : memref<32xf8E5M2, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<32xf8E5M2, #hivm.address_space<gm>>) outs(%alloc : memref<32xf8E5M2, #hivm.address_space<cbuf>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
    %0 = hivm.hir.pointer_cast(%c64_i64) : memref<32xf8E5M2, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg1 : memref<32xf8E5M2, #hivm.address_space<gm>>) outs(%0 : memref<32xf8E5M2, #hivm.address_space<cbuf>>)
    %1 = hivm.hir.pointer_cast(%c128_i64) : memref<2xui8, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg2 : memref<2xui8, #hivm.address_space<gm>>) outs(%1 : memref<2xui8, #hivm.address_space<cbuf>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID1>]
    %2 = hivm.hir.pointer_cast(%c192_i64) : memref<2xui8, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg3 : memref<2xui8, #hivm.address_space<gm>>) outs(%2 : memref<2xui8, #hivm.address_space<cbuf>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID2>]
    %3 = hivm.hir.pointer_cast(%c0_i64_1) : memref<1024xf32, #hivm.address_space<cc>>
    %c-1_i64 = arith.constant -1 : i64
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.mmadmxL1 ins(%alloc, %0, %1, %2, %true, %c32, %c32_0, %c32 : memref<32xf8E5M2, #hivm.address_space<cbuf>>, memref<32xf8E5M2, #hivm.address_space<cbuf>>, memref<2xui8, #hivm.address_space<cbuf>>, memref<2xui8, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%3 : memref<1024xf32, #hivm.address_space<cc>>) sync_related_args(%c0_i64, %c1_i64, %c-1_i64, %c2_i64, %c-1_i64, %c-1_i64, %c-1_i64, %c-1_i64 : i64, i64, i64, i64, i64, i64, i64, i64)
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%3 : memref<1024xf32, #hivm.address_space<cc>>) outs(%arg4 : memref<1024xf32, #hivm.address_space<gm>>)
    hivm.hir.set_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID0>]
    %alloc_2 = memref.alloc() : memref<1024xf32, #hivm.address_space<ub>>
    %alloc_3 = memref.alloc() : memref<1024xf32, #hivm.address_space<ub>>
    hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.load ins(%arg4 : memref<1024xf32, #hivm.address_space<gm>>) outs(%alloc_2 : memref<1024xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vadd ins(%alloc_2, %alloc_3 : memref<1024xf32, #hivm.address_space<ub>>, memref<1024xf32, #hivm.address_space<ub>>) outs(%alloc_2 : memref<1024xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%alloc_2 : memref<1024xf32, #hivm.address_space<ub>>) outs(%arg5 : memref<1024xf32, #hivm.address_space<gm>>)
    return
  }
}


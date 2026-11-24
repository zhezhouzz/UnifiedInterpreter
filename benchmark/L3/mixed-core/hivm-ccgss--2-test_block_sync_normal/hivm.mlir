module {
  func.func @test_block_sync_normal(%arg0: memref<16xf32, #hivm.address_space<gm>>, %arg1: memref<16xf32, #hivm.address_space<gm>>, %arg2: memref<256xf32, #hivm.address_space<gm>>, %arg3: memref<256xf32, #hivm.address_space<gm>>, %arg4: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}) attributes {hacc.always_inline, hfusion.fusion_kind = #hfusion.fusion_kind<MIX_CV>, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %c0_i64 = arith.constant 0 : i64
    %c1_i64 = arith.constant 1 : i64
    hivm.hir.set_ffts_base_addr %arg4
    %c64_i64 = arith.constant 64 : i64
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %c256 = arith.constant 256 : index
    %c0_i64_0 = arith.constant 0 : i64
    %alloc = memref.alloc() : memref<16xf32, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%alloc : memref<16xf32, #hivm.address_space<cbuf>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
    %0 = hivm.hir.pointer_cast(%c64_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%0 : memref<16xf32, #hivm.address_space<cbuf>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID1>]
    %1 = hivm.hir.pointer_cast(%c0_i64_0) : memref<256xf32, #hivm.address_space<cc>>
    %c-1_i64 = arith.constant -1 : i64
    %c0_i64_1 = arith.constant 0 : i64
    %c1_i64_2 = arith.constant 1 : i64
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.mmadL1 ins(%alloc, %0, %true, %c16, %c256, %c16 : memref<16xf32, #hivm.address_space<cbuf>>, memref<16xf32, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%1 : memref<256xf32, #hivm.address_space<cc>>) sync_related_args(%c0_i64, %c1_i64, %c-1_i64, %c-1_i64, %c-1_i64, %c0_i64_1, %c1_i64_2 : i64, i64, i64, i64, i64, i64, i64)
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%1 : memref<256xf32, #hivm.address_space<cc>>) outs(%arg2 : memref<256xf32, #hivm.address_space<gm>>)
    hivm.hir.set_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID0>]
    %alloc_3 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %alloc_4 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.load ins(%arg2 : memref<256xf32, #hivm.address_space<gm>>) outs(%alloc_3 : memref<256xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vadd ins(%alloc_3, %alloc_4 : memref<256xf32, #hivm.address_space<ub>>, memref<256xf32, #hivm.address_space<ub>>) outs(%alloc_3 : memref<256xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%alloc_3 : memref<256xf32, #hivm.address_space<ub>>) outs(%arg3 : memref<256xf32, #hivm.address_space<gm>>)
    return
  }
}


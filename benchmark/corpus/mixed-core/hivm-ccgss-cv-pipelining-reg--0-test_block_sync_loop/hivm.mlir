module {
  func.func @test_block_sync_loop(%arg0: memref<16xf32, #hivm.address_space<gm>>, %arg1: memref<?xf32, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<256xf32, #hivm.address_space<gm>>, %arg3: memref<256xf32, #hivm.address_space<gm>>, %arg4: memref<256xf32, #hivm.address_space<gm>>, %arg5: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}) attributes {hacc.always_inline, hfusion.fusion_kind = #hfusion.fusion_kind<MIX_CV>, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %alloca = memref.alloca() : memref<1xi64>
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    memref.store %c0_i64, %alloca[%c0] : memref<1xi64>
    %alloca_0 = memref.alloca() : memref<1xi64>
    %c0_i64_1 = arith.constant 0 : i64
    %c0_2 = arith.constant 0 : index
    memref.store %c0_i64_1, %alloca_0[%c0_2] : memref<1xi64>
    %c5_i64 = arith.constant 5 : i64
    %c4_i64 = arith.constant 4 : i64
    %c3_i64 = arith.constant 3 : i64
    %c2_i64 = arith.constant 2 : i64
    %c1_i64 = arith.constant 1 : i64
    %c0_i64_3 = arith.constant 0 : i64
    %c0_i64_4 = arith.constant 0 : i64
    %c1_i64_5 = arith.constant 1 : i64
    %c0_i64_6 = arith.constant 0 : i64
    %c1_i64_7 = arith.constant 1 : i64
    %c0_i64_8 = arith.constant 0 : i64
    %c1_i64_9 = arith.constant 1 : i64
    hivm.hir.set_ffts_base_addr %arg5
    %c64_i64 = arith.constant 64 : i64
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %c256 = arith.constant 256 : index
    %c0_i64_10 = arith.constant 0 : i64
    %c1024_i64 = arith.constant 1024 : i64
    %c2048_i64 = arith.constant 2048 : i64
    %c0_11 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %c4 = arith.constant 4 : index
    %c1024 = arith.constant 1024 : index
    %c2048 = arith.constant 2048 : index
    %true_12 = arith.constant true
    %alloc = memref.alloc() : memref<16xf32, #hivm.address_space<cbuf>>
    %alloc_13 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %alloc_14 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %0 = hivm.hir.pointer_cast(%c0_i64_10) : memref<16xf32, #hivm.address_space<cbuf>>
    %1 = hivm.hir.pointer_cast(%c0_i64_10) : memref<256xf32, #hivm.address_space<cc>>
    %alloc_15 = memref.alloc() : memref<16xf32, #hivm.address_space<cbuf>>
    %alloc_16 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %alloc_17 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %2 = hivm.hir.pointer_cast(%c1024_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    %3 = hivm.hir.pointer_cast(%c1024_i64) : memref<256xf32, #hivm.address_space<cc>>
    %alloc_18 = memref.alloc() : memref<16xf32, #hivm.address_space<cbuf>>
    %alloc_19 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %alloc_20 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %4 = hivm.hir.pointer_cast(%c2048_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    %5 = hivm.hir.pointer_cast(%c2048_i64) : memref<256xf32, #hivm.address_space<cc>>
    %6 = memref_ext.alloc_workspace() from %arg1 offset = [%c0_11] : from memref<?xf32, #hivm.address_space<gm>> to memref<256xf32, #hivm.address_space<gm>>
    %7 = memref_ext.alloc_workspace() from %arg1 offset = [%c1024] : from memref<?xf32, #hivm.address_space<gm>> to memref<256xf32, #hivm.address_space<gm>>
    %8 = memref_ext.alloc_workspace() from %arg1 offset = [%c2048] : from memref<?xf32, #hivm.address_space<gm>> to memref<256xf32, #hivm.address_space<gm>>
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID2>]
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID3>]
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID4>]
    hivm.hir.set_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID5>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID2>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    scf.for %arg6 = %c0_11 to %c16 step %c4 {
      %c0_21 = arith.constant 0 : index
      %9 = memref.load %alloca_0[%c0_21] : memref<1xi64>
      %10 = arith.index_cast %9 : i64 to index
      %11 = arith.index_cast %10 : index to i64
      %c0_i64_22 = arith.constant 0 : i64
      %c1_i64_23 = arith.constant 1 : i64
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID0>]
      scf.for %arg7 = %c0_11 to %c2 step %c1 {
        %c0_26 = arith.constant 0 : index
        %13 = memref.load %alloca[%c0_26] : memref<1xi64>
        %14 = arith.index_cast %13 : i64 to index
        %15 = arith.index_cast %14 : index to i64
        %c0_i64_27 = arith.constant 0 : i64
        %c1_i64_28 = arith.constant 1 : i64
        hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%alloc : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%0 : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID1>]
        hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
        %c-1_i64 = arith.constant -1 : i64
        hivm.hir.mmadL1 ins(%alloc, %0, %true, %c16, %c256, %c16 : memref<16xf32, #hivm.address_space<cbuf>>, memref<16xf32, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%1 : memref<256xf32, #hivm.address_space<cc>>) sync_related_args(%c0_i64_8, %c1_i64_9, %c0_i64_3, %c1_i64, %15, %c0_i64_27, %c1_i64_28 : i64, i64, i64, i64, i64, i64, i64)
        hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
        hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%1 : memref<256xf32, #hivm.address_space<cc>>) outs(%7 : memref<256xf32, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID2>]
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%alloc_18 : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID3>]
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%4 : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID1>]
        hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
        %c-1_i64_29 = arith.constant -1 : i64
        %c0_i64_30 = arith.constant 0 : i64
        %c1_i64_31 = arith.constant 1 : i64
        hivm.hir.mmadL1 ins(%alloc_18, %4, %true, %c16, %c256, %c16 : memref<16xf32, #hivm.address_space<cbuf>>, memref<16xf32, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%5 : memref<256xf32, #hivm.address_space<cc>>) sync_related_args(%c0_i64_6, %c1_i64_7, %c2_i64, %c3_i64, %15, %c0_i64_30, %c1_i64_31 : i64, i64, i64, i64, i64, i64, i64)
        hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
        hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%5 : memref<256xf32, #hivm.address_space<cc>>) outs(%6 : memref<256xf32, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
        %c1_i64_32 = arith.constant 1 : i64
        %16 = arith.addi %13, %c1_i64_32 : i64
        %c0_33 = arith.constant 0 : index
        memref.store %16, %alloca[%c0_33] : memref<1xi64>
      } {multibuffer_unroll_factor = 2 : i32}
      hivm.hir.set_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID1>]
      scf.if %true_12 {
        hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID4>]
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%alloc_15 : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID5>]
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%2 : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID1>]
        hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID2>]
        %c-1_i64 = arith.constant -1 : i64
        hivm.hir.mmadL1 ins(%alloc_15, %2, %true, %c16, %c256, %c16 : memref<16xf32, #hivm.address_space<cbuf>>, memref<16xf32, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%3 : memref<256xf32, #hivm.address_space<cc>>) sync_related_args(%c0_i64_4, %c1_i64_5, %c4_i64, %c5_i64, %11, %c0_i64_22, %c1_i64_23 : i64, i64, i64, i64, i64, i64, i64)
        hivm.hir.set_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID1>]
        hivm.hir.wait_flag[<PIPE_M>, <PIPE_FIX>, <EVENT_ID0>]
        hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%3 : memref<256xf32, #hivm.address_space<cc>>) outs(%8 : memref<256xf32, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID2>]
      } else {
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID1>]
      }
      hivm.hir.set_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID1>]
      scf.for %arg7 = %c0_11 to %c2 step %c1 {
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        hivm.hir.load ins(%7 : memref<256xf32, #hivm.address_space<gm>>) outs(%alloc_13 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
        hivm.hir.vadd ins(%alloc_13, %alloc_14 : memref<256xf32, #hivm.address_space<ub>>, memref<256xf32, #hivm.address_space<ub>>) outs(%alloc_13 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.store ins(%alloc_13 : memref<256xf32, #hivm.address_space<ub>>) outs(%arg2 : memref<256xf32, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      } {multibuffer_unroll_factor = 2 : i32}
      scf.for %arg7 = %c0_11 to %c2 step %c1 {
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        hivm.hir.load ins(%6 : memref<256xf32, #hivm.address_space<gm>>) outs(%alloc_19 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
        hivm.hir.vadd ins(%alloc_19, %alloc_20 : memref<256xf32, #hivm.address_space<ub>>, memref<256xf32, #hivm.address_space<ub>>) outs(%alloc_19 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.store ins(%alloc_19 : memref<256xf32, #hivm.address_space<ub>>) outs(%arg3 : memref<256xf32, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      } {multibuffer_unroll_factor = 2 : i32}
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_MTE2>, <EVENT_ID0>]
      scf.if %true_12 {
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
        hivm.hir.load ins(%8 : memref<256xf32, #hivm.address_space<gm>>) outs(%alloc_16 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID1>]
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
        hivm.hir.vadd ins(%alloc_16, %alloc_17 : memref<256xf32, #hivm.address_space<ub>>, memref<256xf32, #hivm.address_space<ub>>) outs(%alloc_16 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.store ins(%alloc_16 : memref<256xf32, #hivm.address_space<ub>>) outs(%arg4 : memref<256xf32, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
      } else {
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID1>]
      }
      %c1_i64_24 = arith.constant 1 : i64
      %12 = arith.addi %9, %c1_i64_24 : i64
      %c0_25 = arith.constant 0 : index
      memref.store %12, %alloca_0[%c0_25] : memref<1xi64>
    } {cv_unrolled_loop}
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID1>]
    hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_M>, <EVENT_ID2>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID2>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID3>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID4>]
    hivm.hir.wait_flag[<PIPE_MTE1>, <PIPE_MTE2>, <EVENT_ID5>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_FIX>, <EVENT_ID1>]
    return
  }
}


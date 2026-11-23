
module {
  func.func @test_block_sync_loop(%arg0: memref<16xf32, #hivm.address_space<gm>>, %arg1: memref<?xf32, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<256xf32, #hivm.address_space<gm>>, %arg3: memref<256xf32, #hivm.address_space<gm>>, %arg4: memref<256xf32, #hivm.address_space<gm>>, %arg5: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}) attributes {hacc.always_inline, hfusion.fusion_kind = #hfusion.fusion_kind<MIX_CV>, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    hivm.hir.set_ffts_base_addr %arg5
    %c64_i64 = arith.constant 64 : i64
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %c256 = arith.constant 256 : index
    %c0_i64 = arith.constant 0 : i64
    %c1024_i64 = arith.constant 1024 : i64
    %c2048_i64 = arith.constant 2048 : i64
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %c4 = arith.constant 4 : index
    %c1024 = arith.constant 1024 : index
    %c2048 = arith.constant 2048 : index
    %true_0 = arith.constant true
    %alloc = memref.alloc() : memref<16xf32, #hivm.address_space<cbuf>>
    %alloc_1 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %alloc_2 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    %1 = hivm.hir.pointer_cast(%c0_i64) : memref<256xf32, #hivm.address_space<cc>>
    %alloc_3 = memref.alloc() : memref<16xf32, #hivm.address_space<cbuf>>
    %alloc_4 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %alloc_5 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %2 = hivm.hir.pointer_cast(%c1024_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    %3 = hivm.hir.pointer_cast(%c1024_i64) : memref<256xf32, #hivm.address_space<cc>>
    %alloc_6 = memref.alloc() : memref<16xf32, #hivm.address_space<cbuf>>
    %alloc_7 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %alloc_8 = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    %4 = hivm.hir.pointer_cast(%c2048_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    %5 = hivm.hir.pointer_cast(%c2048_i64) : memref<256xf32, #hivm.address_space<cc>>
    %alloc_workspace_0 = memref_ext.alloc_workspace() from %arg1 offset = [%c0] : from memref<?xf32, #hivm.address_space<gm>> to memref<256xf32, #hivm.address_space<gm>>
    %alloc_workspace_1 = memref_ext.alloc_workspace() from %arg1 offset = [%c1024] : from memref<?xf32, #hivm.address_space<gm>> to memref<256xf32, #hivm.address_space<gm>>
    %alloc_workspace_2 = memref_ext.alloc_workspace() from %arg1 offset = [%c2048] : from memref<?xf32, #hivm.address_space<gm>> to memref<256xf32, #hivm.address_space<gm>>
    scf.for %arg8 = %c0 to %c16 step %c4 {
      scf.for %arg9 = %c0 to %c2 step %c1 {
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%alloc : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%0 : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.mmadL1 ins(%alloc, %0, %true, %c16, %c256, %c16 : memref<16xf32, #hivm.address_space<cbuf>>, memref<16xf32, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%1 : memref<256xf32, #hivm.address_space<cc>>)
        hivm.hir.fixpipe {enable_nz2nd} ins(%1 : memref<256xf32, #hivm.address_space<cc>>) outs(%alloc_workspace_1 : memref<256xf32, #hivm.address_space<gm>>)
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%alloc_6 : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%4 : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.mmadL1 ins(%alloc_6, %4, %true, %c16, %c256, %c16 : memref<16xf32, #hivm.address_space<cbuf>>, memref<16xf32, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%5 : memref<256xf32, #hivm.address_space<cc>>)
        hivm.hir.fixpipe {enable_nz2nd} ins(%5 : memref<256xf32, #hivm.address_space<cc>>) outs(%alloc_workspace_0 : memref<256xf32, #hivm.address_space<gm>>)
      } {multibuffer_unroll_factor = 2 : i32}
      scf.if %true_0 {
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%alloc_3 : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%2 : memref<16xf32, #hivm.address_space<cbuf>>)
        hivm.hir.mmadL1 ins(%alloc_3, %2, %true, %c16, %c256, %c16 : memref<16xf32, #hivm.address_space<cbuf>>, memref<16xf32, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%3 : memref<256xf32, #hivm.address_space<cc>>)
        hivm.hir.fixpipe {enable_nz2nd} ins(%3 : memref<256xf32, #hivm.address_space<cc>>) outs(%alloc_workspace_2 : memref<256xf32, #hivm.address_space<gm>>)
      }
      scf.for %arg9 = %c0 to %c2 step %c1 {
        hivm.hir.load ins(%alloc_workspace_1 : memref<256xf32, #hivm.address_space<gm>>) outs(%alloc_1 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.vadd ins(%alloc_1, %alloc_2 : memref<256xf32, #hivm.address_space<ub>>, memref<256xf32, #hivm.address_space<ub>>) outs(%alloc_1 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.store ins(%alloc_1 : memref<256xf32, #hivm.address_space<ub>>) outs(%arg2 : memref<256xf32, #hivm.address_space<gm>>)
      } {multibuffer_unroll_factor = 2 : i32}
      scf.for %arg9 = %c0 to %c2 step %c1 {
        hivm.hir.load ins(%alloc_workspace_0 : memref<256xf32, #hivm.address_space<gm>>) outs(%alloc_7 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.vadd ins(%alloc_7, %alloc_8 : memref<256xf32, #hivm.address_space<ub>>, memref<256xf32, #hivm.address_space<ub>>) outs(%alloc_7 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.store ins(%alloc_7 : memref<256xf32, #hivm.address_space<ub>>) outs(%arg3 : memref<256xf32, #hivm.address_space<gm>>)
      } {multibuffer_unroll_factor = 2 : i32}
      scf.if %true_0 {
        hivm.hir.load ins(%alloc_workspace_2 : memref<256xf32, #hivm.address_space<gm>>) outs(%alloc_4 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.vadd ins(%alloc_4, %alloc_5 : memref<256xf32, #hivm.address_space<ub>>, memref<256xf32, #hivm.address_space<ub>>) outs(%alloc_4 : memref<256xf32, #hivm.address_space<ub>>)
        hivm.hir.store ins(%alloc_4 : memref<256xf32, #hivm.address_space<ub>>) outs(%arg4 : memref<256xf32, #hivm.address_space<gm>>)
      }
    } {cv_unrolled_loop}
    return
  }
}

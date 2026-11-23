module {
  func.func @kern3_backup() attributes {hivm.backup_function, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    hivm.hir.anchor {id = 0 : i64}
    hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_S>] flag = 0
    hivm.hir.anchor {id = 1 : i64}
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_S>] flag = 0
    hivm.hir.anchor {id = 2 : i64}
    return
  }
  func.func @kern3_mix_aic(%arg0: memref<16xf32, #hivm.address_space<gm>>, %arg1: memref<256xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    %c0_i64 = arith.constant 0 : i64
    %c64_i64 = arith.constant 64 : i64
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %c256 = arith.constant 256 : index
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%0 : memref<16xf32, #hivm.address_space<cbuf>>)
    %1 = hivm.hir.pointer_cast(%c64_i64) : memref<256xf32, #hivm.address_space<cc>>
    hivm.hir.mmadL1 ins(%0, %0, %true, %c16, %c256, %c16 : memref<16xf32, #hivm.address_space<cbuf>>, memref<16xf32, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%1 : memref<256xf32, #hivm.address_space<cc>>)
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%1 : memref<256xf32, #hivm.address_space<cc>>) outs(%arg1 : memref<256xf32, #hivm.address_space<gm>>)
    hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_S>] flag = 0
    hivm.hir.anchor {id = 1 : i64}
    hivm.hir.anchor {id = 2 : i64}
    return
  }
  func.func @kern3_mix_aiv(%arg0: memref<16xf32, #hivm.address_space<gm>>, %arg1: memref<256xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    hivm.hir.anchor {id = 1 : i64}
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<256xf32, #hivm.address_space<ub>>
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_S>] flag = 0
    hivm.hir.load ins(%arg1 : memref<256xf32, #hivm.address_space<gm>>) outs(%0 : memref<256xf32, #hivm.address_space<ub>>)
    hivm.hir.store ins(%0 : memref<256xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<256xf32, #hivm.address_space<gm>>)
    hivm.hir.anchor {id = 2 : i64}
    return
  }
}


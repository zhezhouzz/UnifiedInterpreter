module {
  func.func @kern8_backup() attributes {hivm.backup_function, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    hivm.hir.anchor {id = 0 : i64}
    hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_S>] flag = 3
    hivm.hir.anchor {id = 1 : i64}
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_S>] flag = 3
    hivm.hir.anchor {id = 2 : i64}
    return
  }
  func.func @kern8_mix_aic(%arg0: memref<256xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    %c64_i64 = arith.constant 64 : i64
    %0 = hivm.hir.pointer_cast(%c64_i64) : memref<256xf32, #hivm.address_space<cc>>
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%0 : memref<256xf32, #hivm.address_space<cc>>) outs(%arg0 : memref<256xf32, #hivm.address_space<gm>>)
    hivm.hir.anchor {id = 1 : i64}
    hivm.hir.anchor {id = 2 : i64}
    return
  }
  func.func @kern8_mix_aiv(%arg0: memref<256xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    hivm.hir.anchor {id = 1 : i64}
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<256xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<256xf32, #hivm.address_space<gm>>) outs(%0 : memref<256xf32, #hivm.address_space<ub>>)
    hivm.hir.anchor {id = 2 : i64}
    return
  }
}


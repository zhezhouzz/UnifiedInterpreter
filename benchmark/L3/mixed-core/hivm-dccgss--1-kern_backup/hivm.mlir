module {
  func.func @kern_backup() attributes {hivm.backup_function, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    hivm.hir.anchor {id = 0 : i64}
    hivm.hir.anchor {id = 1 : i64}
    hivm.hir.anchor {id = 2 : i64}
    return
  }
  func.func @kern_mix_aic(%arg0: memref<?xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<?xf32, #hivm.address_space<gm>>) outs(%0 : memref<16xf32, #hivm.address_space<cbuf>>)
    hivm.hir.anchor {id = 1 : i64}
    hivm.hir.anchor {id = 2 : i64}
    return
  }
  func.func @kern_mix_aiv(%arg0: memref<?xf32, #hivm.address_space<gm>>, %arg1: memref<?xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    hivm.hir.anchor {id = 1 : i64}
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<?xf32, #hivm.address_space<gm>>) outs(%0 : memref<16xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%0 : memref<16xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<?xf32, #hivm.address_space<gm>>)
    hivm.hir.anchor {id = 2 : i64}
    return
  }
}


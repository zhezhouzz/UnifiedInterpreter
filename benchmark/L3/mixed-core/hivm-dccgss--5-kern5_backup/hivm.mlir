module {
  func.func @kern5_backup() attributes {hivm.backup_function, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    hivm.hir.anchor {id = 0 : i64}
    hivm.hir.anchor {id = 1 : i64}
    return
  }
  func.func @kern5_mix_aic(%arg0: memref<?xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<?xf32, #hivm.address_space<gm>>) outs(%0 : memref<16xf32, #hivm.address_space<cbuf>>)
    hivm.hir.anchor {id = 1 : i64}
    return
  }
  func.func @kern5_mix_aiv(%arg0: memref<?xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<ub>>
    %1 = hivm.hir.pointer_cast(%c4096_i64) : memref<16xf32, #hivm.address_space<ub>>
    hivm.hir.vadd ins(%0, %1 : memref<16xf32, #hivm.address_space<ub>>, memref<16xf32, #hivm.address_space<ub>>) outs(%1 : memref<16xf32, #hivm.address_space<ub>>)
    hivm.hir.anchor {id = 1 : i64}
    return
  }
}


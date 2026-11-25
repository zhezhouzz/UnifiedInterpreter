module {
  func.func @kern6_backup(%arg0: i1) attributes {hivm.backup_function, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    hivm.hir.anchor {id = 0 : i64}
    scf.if %arg0 {
      hivm.hir.anchor {id = 1 : i64}
    }
    hivm.hir.anchor {id = 2 : i64}
    return
  }
  func.func @kern6_mix_aic(%arg0: i1) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    scf.if %arg0 {
      hivm.hir.anchor {id = 1 : i64}
    }
    hivm.hir.anchor {id = 2 : i64}
    return
  }
  func.func @kern6_mix_aiv(%arg0: i1, %arg1: memref<?xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    %c0_i64 = arith.constant 0 : i64
    scf.if %arg0 {
      %0 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<ub>>
      hivm.hir.load ins(%arg1 : memref<?xf32, #hivm.address_space<gm>>) outs(%0 : memref<16xf32, #hivm.address_space<ub>>)
      hivm.hir.anchor {id = 1 : i64}
    }
    hivm.hir.anchor {id = 2 : i64}
    return
  }
}


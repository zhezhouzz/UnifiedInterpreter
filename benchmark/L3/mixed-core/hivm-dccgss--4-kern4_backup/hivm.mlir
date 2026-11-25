module {
  func.func @kern4_backup(%arg0: index) attributes {hivm.backup_function, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    hivm.hir.anchor {id = 0 : i64}
    scf.for %arg1 = %arg0 to %arg0 step %arg0 {
      hivm.hir.anchor {id = 1 : i64}
      hivm.hir.anchor {id = 2 : i64}
    }
    hivm.hir.anchor {id = 3 : i64}
    return
  }
  func.func @kern4_mix_aic(%arg0: index) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    scf.for %arg1 = %arg0 to %arg0 step %arg0 {
      hivm.hir.anchor {id = 1 : i64}
      hivm.hir.anchor {id = 2 : i64}
    }
    hivm.hir.anchor {id = 3 : i64}
    return
  }
  func.func @kern4_mix_aiv(%arg0: index, %arg1: memref<?xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.part_of_mix} {
    hivm.hir.anchor {id = 0 : i64}
    %c0_i64 = arith.constant 0 : i64
    %c2048_i64 = arith.constant 2048 : i64
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    scf.for %arg2 = %arg0 to %arg0 step %arg0 {
      hivm.hir.anchor {id = 1 : i64}
      %0 = hivm.hir.pointer_cast(%c0_i64, %c2048_i64) : memref<16xf32, #hivm.address_space<ub>>
      annotation.mark %0 {hivm.multi_buffer = 2 : i32} : memref<16xf32, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.load ins(%arg1 : memref<?xf32, #hivm.address_space<gm>>) outs(%0 : memref<16xf32, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%0 : memref<16xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<?xf32, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.anchor {id = 2 : i64}
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.anchor {id = 3 : i64}
    return
  }
}


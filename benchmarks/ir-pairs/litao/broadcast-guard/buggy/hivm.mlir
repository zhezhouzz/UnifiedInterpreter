module {
  func.func @producer() attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_S>] flag = 0
    return
  }
  func.func @consumer() attributes {hivm.func_core_type = #hivm.func_core_type<AIV>} {
    %c1_i64 = arith.constant 1 : i64
    %0 = hivm.hir.get_sub_block_idx -> i64
    %1 = arith.cmpi slt, %0, %c1_i64 : i64
    scf.if %1 {
      hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_S>] flag = 0
    }
    return
  }
}


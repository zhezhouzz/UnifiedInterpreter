module {
  func.func @producer() attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_S>] flag = 0
    return
  }
  func.func @consumer() attributes {hivm.func_core_type = #hivm.func_core_type<AIV>} {
    %index = hivm.hir.get_sub_block_idx -> i64
    %limit = arith.constant 2 : i64
    %active = arith.cmpi slt, %index, %limit : i64
    scf.if %active {
      hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_S>] flag = 0
    }
    return
  }
}

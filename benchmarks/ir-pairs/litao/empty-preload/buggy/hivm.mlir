module {
  func.func @producer() attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    return
  }
  func.func @consumer() attributes {hivm.func_core_type = #hivm.func_core_type<AIV>} {
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_S>] flag = 0
    return
  }
}


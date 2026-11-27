module {
  func.func @producer(%trips: index) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %zero = arith.constant 0 : index
    %one = arith.constant 1 : index
    hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_MTE2>] flag = 0
    return
  }
  func.func @consumer(%trips: index) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>} {
    %zero = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %i = %zero to %trips step %one {
      hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_MTE2>] flag = 0
    }
    return
  }
}

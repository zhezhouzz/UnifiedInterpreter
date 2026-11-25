module {
  func.func @producer(%arg0: index) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    scf.for %arg1 = %c0 to %arg0 step %c1 {
      hivm.hir.sync_block_set[<CUBE>, <PIPE_FIX>, <PIPE_MTE2>] flag = 0
    }
    return
  }
  func.func @consumer(%arg0: index) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    scf.for %arg1 = %c0 to %arg0 step %c1 {
      hivm.hir.sync_block_wait[<VECTOR>, <PIPE_FIX>, <PIPE_MTE2>] flag = 0
    }
    return
  }
}


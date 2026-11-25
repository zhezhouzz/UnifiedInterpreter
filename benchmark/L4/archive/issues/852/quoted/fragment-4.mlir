hivm.hir.sync_block_set[<CUBE>, <PIPE_S>, <PIPE_S>] flag = 14 ffts_base_addr = %arg0
%counter_delay_limit = arith.constant 100000 : index
scf.for %counter_delay_i = %c0 to %counter_delay_limit step %c1 {
  hivm.hir.pipe_barrier[<PIPE_ALL>]
}

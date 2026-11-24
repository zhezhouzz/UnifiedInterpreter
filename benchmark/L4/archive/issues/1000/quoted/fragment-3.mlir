hivm.hir.load ins(%src : memref<16xf32, #hivm.address_space<gm>>)
  outs(%value : memref<16xf32, #hivm.address_space<ub>>)

hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]

hivm.hir.custom {gm_addr_args_indices = array<i32: 0>, ...}
    "__builtin_indirect_atomic"
    ins(%atomic_dst, %offsets, %value, %mask : ...)
    outs(%atomic_out : memref<16xf32, #hivm.address_space<ub>>)

hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]

hivm.hir.load ins(%atomic_dst : memref<16xf32, #hivm.address_space<gm>>)
  outs(%reloaded : memref<16xf32, #hivm.address_space<ub>>)

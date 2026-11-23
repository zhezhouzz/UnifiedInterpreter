hivm.hir.custom {gm_addr_args_indices = array<i32: 0>, ...}
    "__builtin_indirect_atomic"
    ins(%atomic_dst, %offsets, %value, %mask : ...)
    outs(%atomic_out : memref<16xf32, #hivm.address_space<ub>>)

// Incorrect: no set_flag / wait_flag here

hivm.hir.load ins(%atomic_dst : memref<16xf32, #hivm.address_space<gm>>)
  outs(%reloaded : memref<16xf32, #hivm.address_space<ub>>)

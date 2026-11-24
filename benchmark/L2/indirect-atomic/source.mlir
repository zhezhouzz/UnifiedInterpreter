module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @indirect_atomic_add_read_modify_write(%arg0: memref<16xf32, #hivm.address_space<gm>>, %arg1: memref<16xf32, #hivm.address_space<gm>>, %arg2: memref<16xi64, #hivm.address_space<ub>>, %arg3: memref<16xi8, #hivm.address_space<ub>>, %arg4: memref<16xf32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<ub>>
    %1 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<ub>>
    %2 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%0 : memref<16xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.custom {extra_attr = "operate=add", gm_addr_args_indices = array<i32: 0>, hivm.pipe = #hivm.pipe<PIPE_V>, hivm.tcore_type = #hivm.tcore_type<VECTOR>, hivm.vf_mode = #hivm.vf_mode<SIMT>, symbol = "__builtin_indirect_atomic"} "__builtin_indirect_atomic" ins(%arg1, %arg2, %0, %arg3 : memref<16xf32, #hivm.address_space<gm>>, memref<16xi64, #hivm.address_space<ub>>, memref<16xf32, #hivm.address_space<ub>>, memref<16xi8, #hivm.address_space<ub>>) outs(%1 : memref<16xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.load ins(%arg1 : memref<16xf32, #hivm.address_space<gm>>) outs(%2 : memref<16xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%2 : memref<16xf32, #hivm.address_space<ub>>) outs(%arg4 : memref<16xf32, #hivm.address_space<gm>>)
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
}


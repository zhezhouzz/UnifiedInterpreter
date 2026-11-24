module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @indirect_atomic_add_read_modify_write(
      %src: memref<16xf32, #hivm.address_space<gm>>,
      %atomic_dst: memref<16xf32, #hivm.address_space<gm>>,
      %offsets: memref<16xi64, #hivm.address_space<ub>>,
      %mask: memref<16xi8, #hivm.address_space<ub>>,
      %result: memref<16xf32, #hivm.address_space<gm>>)
      attributes {hacc.entry,
                  hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0_i64 = arith.constant 0 : i64
    %value = hivm.hir.pointer_cast(%c0_i64) :
      memref<16xf32, #hivm.address_space<ub>>
    %atomic_out = hivm.hir.pointer_cast(%c0_i64) :
      memref<16xf32, #hivm.address_space<ub>>
    %reloaded = hivm.hir.pointer_cast(%c0_i64) :
      memref<16xf32, #hivm.address_space<ub>>

    hivm.hir.load ins(%src : memref<16xf32, #hivm.address_space<gm>>)
      outs(%value : memref<16xf32, #hivm.address_space<ub>>)

    hivm.hir.custom {extra_attr = "operate=add",
                     gm_addr_args_indices = array<i32: 0>,
                     hivm.pipe = #hivm.pipe<PIPE_V>,
                     hivm.tcore_type = #hivm.tcore_type<VECTOR>,
                     hivm.vf_mode = #hivm.vf_mode<SIMT>,
                     symbol = "__builtin_indirect_atomic"}
        "__builtin_indirect_atomic"
        ins(%atomic_dst, %offsets, %value, %mask :
            memref<16xf32, #hivm.address_space<gm>>,
            memref<16xi64, #hivm.address_space<ub>>,
            memref<16xf32, #hivm.address_space<ub>>,
            memref<16xi8, #hivm.address_space<ub>>)
        outs(%atomic_out : memref<16xf32, #hivm.address_space<ub>>)

    hivm.hir.load ins(%atomic_dst : memref<16xf32, #hivm.address_space<gm>>)
      outs(%reloaded : memref<16xf32, #hivm.address_space<ub>>)

    hivm.hir.store ins(%reloaded : memref<16xf32, #hivm.address_space<ub>>)
      outs(%result : memref<16xf32, #hivm.address_space<gm>>)
    return
  }
}

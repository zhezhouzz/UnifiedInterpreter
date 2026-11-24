
module {
  func.func @test_custom_macro_graph_sync_solver(
      %arg0: memref<16xf16, #hivm.address_space<gm>>,
      %arg1: memref<16xf16, #hivm.address_space<gm>>)
      attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0_i64 = arith.constant 0 : i64
    %c32_i64 = arith.constant 32 : i64
    %c0 = arith.constant 0 : index
    %c2 = arith.constant 2 : index
    %c1 = arith.constant 1 : index
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<16xf16, #hivm.address_space<ub>>
    %1 = hivm.hir.pointer_cast(%c32_i64) : memref<16xf16, #hivm.address_space<ub>>
    annotation.mark %0 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%0 : memref<16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg1 : memref<16xf16, #hivm.address_space<gm>>) outs(%1 : memref<16xf16, #hivm.address_space<ub>>)
    scf.for %i = %c0 to %c2 step %c1 {
      hivm.hir.custom_macro
          {hivm.tcore_type = #hivm.tcore_type<VECTOR>,
           hivm.pipe_in = #hivm.pipe<PIPE_MTE2>,
           hivm.pipe_out = #hivm.pipe<PIPE_V>,
           symbol = "k_custom_macro_gss",
           sync_event_slots = [
             #hivm.sync_event_slot<#hivm.pipe<PIPE_MTE2>, #hivm.pipe<PIPE_MTE1>, wait>
           ]}
          "user.macro_gss"
          ins(%0, %1 : memref<16xf16, #hivm.address_space<ub>>, memref<16xf16, #hivm.address_space<ub>>)
          outs(%0 : memref<16xf16, #hivm.address_space<ub>>)
    }
    return
  }
}

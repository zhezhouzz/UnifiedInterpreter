module {
  func.func @test_scope_scope_multi_result_stride_align(%arg0: memref<2x15xf16, #hivm.address_space<gm>>, %arg1: memref<2x15xf16, #hivm.address_space<gm>>) {
    %0:2 = scope.scope : () -> (memref<2x15xf16, #hivm.address_space<ub>>, memref<2x15xf16, #hivm.address_space<ub>>) {
      %alloc = memref.alloc() {alignment = 64 : i64} : memref<2x15xf16, #hivm.address_space<ub>>
      %alloc_0 = memref.alloc() {alignment = 64 : i64} : memref<2x15xf16, #hivm.address_space<ub>>
      annotation.mark %alloc {hivm.stride_align_dims = array<i32: 1>, hivm.stride_align_value_in_byte = array<i32: 32>} : memref<2x15xf16, #hivm.address_space<ub>>
      annotation.mark %alloc_0 {hivm.stride_align_dims = array<i32: 1>, hivm.stride_align_value_in_byte = array<i32: 32>} : memref<2x15xf16, #hivm.address_space<ub>>
      hivm.hir.vexp ins(%alloc : memref<2x15xf16, #hivm.address_space<ub>>) outs(%alloc_0 : memref<2x15xf16, #hivm.address_space<ub>>)
      scope.return %alloc, %alloc_0 : memref<2x15xf16, #hivm.address_space<ub>>, memref<2x15xf16, #hivm.address_space<ub>>
    }
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%0#0 : memref<2x15xf16, #hivm.address_space<ub>>) outs(%arg0 : memref<2x15xf16, #hivm.address_space<gm>>)
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%0#1 : memref<2x15xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<2x15xf16, #hivm.address_space<gm>>)
    return
  }
}


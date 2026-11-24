
func.func @test_scope_scope_multi_result_stride_align(%arg0: memref<2x15xf16, #hivm.address_space<gm>>, %arg1: memref<2x15xf16, #hivm.address_space<gm>>) {
  %result:2 = scope.scope : () -> (memref<2x15xf16, #hivm.address_space<ub>>, memref<2x15xf16, #hivm.address_space<ub>>) {
    %alloc0 = memref.alloc() {alignment = 64 : i64} : memref<2x15xf16, #hivm.address_space<ub>>
    %alloc1 = memref.alloc() {alignment = 64 : i64} : memref<2x15xf16, #hivm.address_space<ub>>
    annotation.mark %alloc0 {hivm.stride_align_dims = array<i32: 1>, hivm.stride_align_value_in_byte = array<i32: 32>} : memref<2x15xf16, #hivm.address_space<ub>>
    annotation.mark %alloc1 {hivm.stride_align_dims = array<i32: 1>, hivm.stride_align_value_in_byte = array<i32: 32>} : memref<2x15xf16, #hivm.address_space<ub>>
    hivm.hir.vexp ins(%alloc0 : memref<2x15xf16, #hivm.address_space<ub>>) outs(%alloc1 : memref<2x15xf16, #hivm.address_space<ub>>)
    scope.return %alloc0, %alloc1 : memref<2x15xf16, #hivm.address_space<ub>>, memref<2x15xf16, #hivm.address_space<ub>>
  }
  hivm.hir.store ins(%result#0 : memref<2x15xf16, #hivm.address_space<ub>>) outs(%arg0 : memref<2x15xf16, #hivm.address_space<gm>>)
  hivm.hir.store ins(%result#1 : memref<2x15xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<2x15xf16, #hivm.address_space<gm>>)
  return
}

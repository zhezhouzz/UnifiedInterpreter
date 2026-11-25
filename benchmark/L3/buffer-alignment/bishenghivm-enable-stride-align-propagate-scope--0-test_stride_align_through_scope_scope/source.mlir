

func.func @test_stride_align_through_scope_scope(%arg0: memref<2x15xf16, #hivm.address_space<gm>>) {
  %result = scope.scope : () -> memref<2x15xf16, #hivm.address_space<ub>> {
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<2x15xf16, #hivm.address_space<ub>>
    annotation.mark %alloc {hivm.stride_align_dims = array<i32: 1>, hivm.stride_align_value_in_byte = array<i32: 32>} : memref<2x15xf16, #hivm.address_space<ub>>
    scope.return %alloc : memref<2x15xf16, #hivm.address_space<ub>>
  }
  hivm.hir.store ins(%result : memref<2x15xf16, #hivm.address_space<ub>>) outs(%arg0 : memref<2x15xf16, #hivm.address_space<gm>>)
  return
}

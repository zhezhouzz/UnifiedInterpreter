func.func @vector_sum(%arg0: memref<32xf32, #hivm.address_space<gm>>, %arg1: memref<32xf32, #hivm.address_space<gm>>, %arg2: memref<32xf32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
  %c0 = arith.constant 0 : i64
  %b0 = hivm.hir.pointer_cast(%c0) : memref<32xf32, #hivm.address_space<ub>>
  %c1 = arith.constant 256 : i64
  %b1 = hivm.hir.pointer_cast(%c1) : memref<32xf32, #hivm.address_space<ub>>
  %c2 = arith.constant 512 : i64
  %b2 = hivm.hir.pointer_cast(%c2) : memref<32xf32, #hivm.address_space<ub>>
  hivm.hir.load ins(%arg0 : memref<32xf32, #hivm.address_space<gm>>) outs(%b0 : memref<32xf32, #hivm.address_space<ub>>)
  hivm.hir.load ins(%arg1 : memref<32xf32, #hivm.address_space<gm>>) outs(%b1 : memref<32xf32, #hivm.address_space<ub>>)
  hivm.hir.vadd ins(%b0, %b1 : memref<32xf32, #hivm.address_space<ub>>, memref<32xf32, #hivm.address_space<ub>>) outs(%b2 : memref<32xf32, #hivm.address_space<ub>>)
  hivm.hir.store ins(%b2 : memref<32xf32, #hivm.address_space<ub>>) outs(%arg2 : memref<32xf32, #hivm.address_space<gm>>)
  return
}

func.func @normalize_row(%arg0: memref<32xf32, #hivm.address_space<gm>>, %arg1: memref<32xf32, #hivm.address_space<gm>>, %arg2: memref<32xf32, #hivm.address_space<gm>>, %arg3: memref<32xf32, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
  %c0 = arith.constant 0 : i64
  %b0 = hivm.hir.pointer_cast(%c0) : memref<32xf32, #hivm.address_space<ub>>
  %c1 = arith.constant 256 : i64
  %b1 = hivm.hir.pointer_cast(%c1) : memref<32xf32, #hivm.address_space<ub>>
  %c2 = arith.constant 512 : i64
  %b2 = hivm.hir.pointer_cast(%c2) : memref<32xf32, #hivm.address_space<ub>>
  %c3 = arith.constant 768 : i64
  %b3 = hivm.hir.pointer_cast(%c3) : memref<32xf32, #hivm.address_space<ub>>
  %c4 = arith.constant 1024 : i64
  %b4 = hivm.hir.pointer_cast(%c4) : memref<32xf32, #hivm.address_space<ub>>
  hivm.hir.load ins(%arg0 : memref<32xf32, #hivm.address_space<gm>>) outs(%b0 : memref<32xf32, #hivm.address_space<ub>>)
  hivm.hir.load ins(%arg1 : memref<32xf32, #hivm.address_space<gm>>) outs(%b1 : memref<32xf32, #hivm.address_space<ub>>)
  hivm.hir.load ins(%arg2 : memref<32xf32, #hivm.address_space<gm>>) outs(%b2 : memref<32xf32, #hivm.address_space<ub>>)
  hivm.hir.vsub ins(%b1, %b2 : memref<32xf32, #hivm.address_space<ub>>, memref<32xf32, #hivm.address_space<ub>>) outs(%b3 : memref<32xf32, #hivm.address_space<ub>>)
  hivm.hir.vmul ins(%b3, %b0 : memref<32xf32, #hivm.address_space<ub>>, memref<32xf32, #hivm.address_space<ub>>) outs(%b4 : memref<32xf32, #hivm.address_space<ub>>)
  hivm.hir.store ins(%b4 : memref<32xf32, #hivm.address_space<ub>>) outs(%arg3 : memref<32xf32, #hivm.address_space<gm>>)
  return
}


func.func @while_signature_immutability(%arg0: memref<8xf32, #hivm.address_space<gm>>,
                                        %arg1: memref<8xf32, #hivm.address_space<gm>>,
                                        %arg2: i32,
                                        %arg3: i64) {
  %true = arith.constant true

  %r:3 = scf.while (%c0_i1 = %true, %c0_i32 = %arg2, %c0_i64 = %arg3) :
      (i1, i32, i64) -> (i1, i32, i64) {
    scf.condition(%c0_i1) %c0_i1, %c0_i32, %c0_i64 : i1, i32, i64
  } do {
  ^bb0(%c1_i1: i1, %c1_i32: i32, %c1_i64: i64):
    %tmp = memref.alloc() : memref<8xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<8xf32, #hivm.address_space<gm>>)
                  outs(%tmp : memref<8xf32, #hivm.address_space<ub>>)
    hivm.hir.store ins(%tmp : memref<8xf32, #hivm.address_space<ub>>)
                   outs(%arg1 : memref<8xf32, #hivm.address_space<gm>>)
    scf.yield %c1_i1, %c1_i32, %c1_i64 : i1, i32, i64
  }
  return
}

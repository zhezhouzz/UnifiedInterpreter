
module {
  func.func @while_gss_basic(%arg0: memref<16xf16, #hivm.address_space<gm>>,
                             %arg1: memref<16xf16, #hivm.address_space<gm>>) {
    %c32_i64 = arith.constant 32 : i64
    %c0_i64 = arith.constant 0 : i64
    %true = arith.constant true



    %r = scf.while (%cond = %true) : (i1) -> i1 {
      scf.condition(%cond) %cond : i1
    } do {
    ^bb0(%cin: i1):
      %3 = hivm.hir.pointer_cast(%c0_i64, %c32_i64) : memref<16xf16, #hivm.address_space<ub>>
      annotation.mark %3 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>)
                    outs(%3 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.store ins(%3 : memref<16xf16, #hivm.address_space<ub>>)
                     outs(%arg1 : memref<16xf16, #hivm.address_space<gm>>)
      scf.yield %cin : i1
    }
    return
  }
}

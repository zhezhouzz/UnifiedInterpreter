
module {
  func.func @sync_solver_sibling_if_backward(%n: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %c0_i64 = arith.constant 0 : i64
    %c1_i64 = arith.constant 1 : i64
    %gm = hivm.hir.pointer_cast(%c0_i64) : memref<1xi1, #hivm.address_space<gm>>
    %ub = hivm.hir.pointer_cast(%c1_i64) : memref<1xi1, #hivm.address_space<ub>>

    scf.for %arg0 = %c0 to %n step %c1 {
      scf.if %true {
        hivm.hir.load ins(%gm : memref<1xi1, #hivm.address_space<gm>>) outs(%ub : memref<1xi1, #hivm.address_space<ub>>)
      }

      scf.if %true {
        hivm.hir.store ins(%ub : memref<1xi1, #hivm.address_space<ub>>) outs(%gm : memref<1xi1, #hivm.address_space<gm>>)
      }
    }
    return
  }
}

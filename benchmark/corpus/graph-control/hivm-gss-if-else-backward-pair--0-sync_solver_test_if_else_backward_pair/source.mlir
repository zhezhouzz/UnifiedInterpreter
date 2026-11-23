
module {
  func.func @sync_solver_test_if_else_backward_pair(%arg0: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %false = arith.constant false
    %c0_i64 = arith.constant 0 : i64
    %c1_i64 = arith.constant 1 : i64
    %c2_i64 = arith.constant 2 : i64
    %c3_i64 = arith.constant 3 : i64
    %c4_i64 = arith.constant 4 : i64
    %c5_i64 = arith.constant 5 : i64

    scf.for %arg1 = %c0 to %arg0 step %c1 {
       %9 = hivm.hir.pointer_cast(%c0_i64, %c1_i64) : memref<1xi1, #hivm.address_space<gm>>
      %10 = hivm.hir.pointer_cast(%c2_i64, %c3_i64) : memref<1xi1, #hivm.address_space<ub>>
      scf.if %false {
        hivm.hir.load ins(%9 : memref<1xi1, #hivm.address_space<gm>>) outs(%10 : memref<1xi1, #hivm.address_space<ub>>)
      } else {
        hivm.hir.store ins(%10 : memref<1xi1, #hivm.address_space<ub>>) outs(%9 : memref<1xi1, #hivm.address_space<gm>>)
      }
    }

    scf.for %arg1 = %c0 to %arg0 step %c1 {
      %0 = hivm.hir.pointer_cast(%c4_i64) : memref<1xi1, #hivm.address_space<gm>>
      %1 = hivm.hir.pointer_cast(%c5_i64) : memref<1xi1, #hivm.address_space<ub>>
      scf.if %false {
        hivm.hir.load ins(%0 : memref<1xi1, #hivm.address_space<gm>>) outs(%1 : memref<1xi1, #hivm.address_space<ub>>)
      } else {
        hivm.hir.store ins(%1 : memref<1xi1, #hivm.address_space<ub>>) outs(%0 : memref<1xi1, #hivm.address_space<gm>>)
      }
    }
    return
  }
}

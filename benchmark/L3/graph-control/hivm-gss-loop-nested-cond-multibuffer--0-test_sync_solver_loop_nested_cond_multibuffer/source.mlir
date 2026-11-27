

module {
  func.func @test_sync_solver_loop_nested_cond_multibuffer(%n: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %c0_i64 = arith.constant 0 : i64
    %c1_i64 = arith.constant 1 : i64
    %c2_i64 = arith.constant 2 : i64
    %c3_i64 = arith.constant 3 : i64
    %c4_i64 = arith.constant 4 : i64

    scf.for %arg0 = %c0 to %n step %c1 {
      scf.if %true {
        %rd0 = hivm.hir.pointer_cast(%c0_i64, %c3_i64, %c1_i64) : memref<1xi1, #hivm.address_space<gm>>
        %wr0 = hivm.hir.pointer_cast(%c1_i64, %c0_i64) : memref<1xi1, #hivm.address_space<ub>>
        hivm.hir.load ins(%rd0 : memref<1xi1, #hivm.address_space<gm>>) outs(%wr0 : memref<1xi1, #hivm.address_space<ub>>)

        %rd1 = hivm.hir.pointer_cast(%c2_i64, %c1_i64) : memref<1xi1, #hivm.address_space<ub>>
        %wr1 = hivm.hir.pointer_cast(%c1_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.store ins(%rd1 : memref<1xi1, #hivm.address_space<ub>>) outs(%wr1 : memref<1xi1, #hivm.address_space<gm>>)

        %rd2 = hivm.hir.pointer_cast(%c1_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        %wr2 = hivm.hir.pointer_cast(%c1_i64, %c3_i64, %c0_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.store ins(%rd2 : memref<1xi1, #hivm.address_space<ub>>) outs(%wr2 : memref<1xi1, #hivm.address_space<gm>>)

        %rd3 = hivm.hir.pointer_cast(%c1_i64, %c3_i64, %c2_i64) : memref<1xi1, #hivm.address_space<gm>>
        %wr3 = hivm.hir.pointer_cast(%c0_i64, %c1_i64) : memref<1xi1, #hivm.address_space<ub>>
        hivm.hir.load ins(%rd3 : memref<1xi1, #hivm.address_space<gm>>) outs(%wr3 : memref<1xi1, #hivm.address_space<ub>>)

        %rd4 = hivm.hir.pointer_cast(%c1_i64) : memref<1xi1, #hivm.address_space<ub>>
        %wr4 = hivm.hir.pointer_cast(%c0_i64, %c4_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.store ins(%rd4 : memref<1xi1, #hivm.address_space<ub>>) outs(%wr4 : memref<1xi1, #hivm.address_space<gm>>)

        %rd5 = hivm.hir.pointer_cast(%c2_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        %wr5 = hivm.hir.pointer_cast(%c2_i64, %c3_i64, %c0_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.store ins(%rd5 : memref<1xi1, #hivm.address_space<ub>>) outs(%wr5 : memref<1xi1, #hivm.address_space<gm>>)

        %rd6 = hivm.hir.pointer_cast(%c2_i64, %c0_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        %wr6 = hivm.hir.pointer_cast(%c1_i64, %c3_i64, %c0_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.store ins(%rd6 : memref<1xi1, #hivm.address_space<ub>>) outs(%wr6 : memref<1xi1, #hivm.address_space<gm>>)

        %rd7 = hivm.hir.pointer_cast(%c1_i64, %c0_i64, %c4_i64) : memref<1xi1, #hivm.address_space<gm>>
        %wr7 = hivm.hir.pointer_cast(%c0_i64, %c3_i64) : memref<1xi1, #hivm.address_space<ub>>
        hivm.hir.load ins(%rd7 : memref<1xi1, #hivm.address_space<gm>>) outs(%wr7 : memref<1xi1, #hivm.address_space<ub>>)

        %rd8 = hivm.hir.pointer_cast(%c2_i64, %c3_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        %wr8 = hivm.hir.pointer_cast(%c3_i64, %c4_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.store ins(%rd8 : memref<1xi1, #hivm.address_space<ub>>) outs(%wr8 : memref<1xi1, #hivm.address_space<gm>>)

        %rd9 = hivm.hir.pointer_cast(%c3_i64) : memref<1xi1, #hivm.address_space<gm>>
        %wr9 = hivm.hir.pointer_cast(%c2_i64, %c1_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        hivm.hir.load ins(%rd9 : memref<1xi1, #hivm.address_space<gm>>) outs(%wr9 : memref<1xi1, #hivm.address_space<ub>>)

        %rd10 = hivm.hir.pointer_cast(%c2_i64, %c3_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        %wr10 = hivm.hir.pointer_cast(%c2_i64, %c3_i64, %c4_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.store ins(%rd10 : memref<1xi1, #hivm.address_space<ub>>) outs(%wr10 : memref<1xi1, #hivm.address_space<gm>>)

        scf.if %true {
          %rd11 = hivm.hir.pointer_cast(%c1_i64, %c2_i64) : memref<1xi1, #hivm.address_space<ub>>
          %wr11 = hivm.hir.pointer_cast(%c2_i64) : memref<1xi1, #hivm.address_space<gm>>
          hivm.hir.store ins(%rd11 : memref<1xi1, #hivm.address_space<ub>>) outs(%wr11 : memref<1xi1, #hivm.address_space<gm>>)
        }
      }
    }
    return
  }
}

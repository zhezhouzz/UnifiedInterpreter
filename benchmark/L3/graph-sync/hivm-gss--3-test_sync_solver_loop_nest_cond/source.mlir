module {
  func.func @test_sync_solver_loop_nest_cond(%arg0: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg1: memref<16x16x16xf16, #hivm.address_space<gm>>, %arg2: memref<16x16x16xf16, #hivm.address_space<gm>>) {
    %c16384_i64 = arith.constant 16384 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c0 = arith.constant 0 : index
    %c1024 = arith.constant 1024 : index
    %c128 = arith.constant 128 : index
    %c0_i64 = arith.constant 0 : i64
    %false = arith.constant false
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<16x16x16xf16, #hivm.address_space<ub>>
    scf.for %arg3 = %c0 to %c1024 step %c128 {
      scf.for %arg4 = %c0 to %c1024 step %c128 {
        scf.if %false {
          hivm.hir.load ins(%arg0 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%0 : memref<16x16x16xf16, #hivm.address_space<ub>>)

          hivm.hir.store ins(%0 : memref<16x16x16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16x16x16xf16, #hivm.address_space<gm>>)
        }
      }

      hivm.hir.load ins(%arg1 : memref<16x16x16xf16, #hivm.address_space<gm>>) outs(%0 : memref<16x16x16xf16, #hivm.address_space<ub>>)

      hivm.hir.store ins(%0 : memref<16x16x16xf16, #hivm.address_space<ub>>) outs(%arg2 : memref<16x16x16xf16, #hivm.address_space<gm>>)
    }
    return
  }
}

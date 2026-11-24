module {
  func.func @test_injcet_sync_if_else(%arg0: memref<16x16x16xf16, #hivm.address_space<gm>>,
                                 %arg1: memref<16x16x16xf16, #hivm.address_space<gm>>,
                                 %arg2: memref<16x16x16xf16, #hivm.address_space<gm>>,
                                 %arg3: memref<16x16x16xf16, #hivm.address_space<gm>>,
                                 %arg4: i1) {
    %c16384_i64 = arith.constant 16384 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) [] : memref<16x16x16xf16, #hivm.address_space<ub>>
    %2 = hivm.hir.pointer_cast(%c0_i64) [] : memref<16x16x16xf16, #hivm.address_space<ub>>
    %4 = hivm.hir.pointer_cast(%c8192_i64) [] : memref<16x16x16xf16, #hivm.address_space<ub>>
    %5 = hivm.hir.pointer_cast(%c16384_i64) [] : memref<16x16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                  outs(%0 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg1 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                  outs(%2 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg2 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                  outs(%4 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg3 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                  outs(%5 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    %6 = scf.if %arg4 -> (memref<16x16x16xf16, #hivm.address_space<ub>>) {
      hivm.hir.vadd ins(%0, %4 : memref<16x16x16xf16, #hivm.address_space<ub>>,
                    memref<16x16x16xf16, #hivm.address_space<ub>>)
                    outs(%0 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      scf.yield %0 : memref<16x16x16xf16, #hivm.address_space<ub>>
    } else {
      hivm.hir.vadd ins(%2, %5 : memref<16x16x16xf16, #hivm.address_space<ub>>,
                    memref<16x16x16xf16, #hivm.address_space<ub>>)
                    outs(%2 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      scf.yield %2 : memref<16x16x16xf16, #hivm.address_space<ub>>
    }
    hivm.hir.store ins(%6 : memref<16x16x16xf16, #hivm.address_space<ub>>)
                  outs(%arg3 : memref<16x16x16xf16, #hivm.address_space<gm>>)
    return
  }
}

module {
  func.func @test_infer_plan_memory_if_yield(%alloc2 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                             %alloc4 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                             %alloc6 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                             %alloc8 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                             %cond: i1) {
    %alloc1 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc3 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc5 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc7 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc9 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc10 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%alloc2 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                 outs(%alloc1 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%alloc4 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                  outs(%alloc5 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%alloc6 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                  outs(%alloc9 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%alloc8 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                  outs(%alloc10 : memref<16x16x16xf16, #hivm.address_space<ub>>)

    %0 = scf.if %cond -> (memref<16x16x16xf16, #hivm.address_space<ub>>) {
      hivm.hir.vadd ins(%alloc1, %alloc9 : memref<16x16x16xf16, #hivm.address_space<ub>>,
                        memref<16x16x16xf16, #hivm.address_space<ub>>)
                    outs(%alloc3 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      scf.yield %alloc3: memref<16x16x16xf16, #hivm.address_space<ub>>
    } else {
      hivm.hir.vadd ins(%alloc5, %alloc10 : memref<16x16x16xf16, #hivm.address_space<ub>>,
                        memref<16x16x16xf16, #hivm.address_space<ub>>)
          outs(%alloc7 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      scf.yield %alloc7 : memref<16x16x16xf16, #hivm.address_space<ub>>
    }
    hivm.hir.store ins(%0 : memref<16x16x16xf16, #hivm.address_space<ub>>)
                   outs(%alloc8 : memref<16x16x16xf16, #hivm.address_space<gm>>)
    return
  }
}

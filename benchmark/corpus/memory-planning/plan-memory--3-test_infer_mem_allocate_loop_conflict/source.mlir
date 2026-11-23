module {
  func.func @test_infer_mem_allocate_loop_conflict(%alloc2 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                                   %alloc4 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                                   %alloc6 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                                   %alloc8 : memref<16x16x16xf16, #hivm.address_space<gm>>) {
    %start = arith.constant 0 : index
    %end = arith.constant 1024 : index
    %step = arith.constant 128 : index
    scf.for %iv = %start to %end step %step {
      %alloc1 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
      %alloc3 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
      %alloc5 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
      %alloc7 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
      hivm.hir.load ins(%alloc2 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                     outs(%alloc1 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      hivm.hir.vadd ins(%alloc1, %alloc1 : memref<16x16x16xf16, #hivm.address_space<ub>>,
                        memref<16x16x16xf16, #hivm.address_space<ub>>)
                    outs(%alloc3 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      hivm.hir.store ins(%alloc3 : memref<16x16x16xf16, #hivm.address_space<ub>>)
                     outs(%alloc4 : memref<16x16x16xf16, #hivm.address_space<gm>>)
      hivm.hir.load ins(%alloc6 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                    outs(%alloc5 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      hivm.hir.vadd ins(%alloc5, %alloc5 : memref<16x16x16xf16, #hivm.address_space<ub>>,
                        memref<16x16x16xf16, #hivm.address_space<ub>>)
                    outs(%alloc7 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      hivm.hir.store ins(%alloc7 : memref<16x16x16xf16, #hivm.address_space<ub>>)
                     outs(%alloc8 : memref<16x16x16xf16, #hivm.address_space<gm>>)
    }
    return
  }
}

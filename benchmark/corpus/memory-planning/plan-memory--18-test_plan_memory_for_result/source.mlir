module {
  func.func @test_plan_memory_for_result(%arg0: memref<16x16x16xf16, #hivm.address_space<gm>>,
                                         %arg1: memref<16x16x16xf16, #hivm.address_space<gm>>,
                                         %arg2: memref<16x16x16xf16, #hivm.address_space<gm>>,
                                         %arg3: memref<16x16x16xf16, #hivm.address_space<gm>>) ->
                                         memref<16x16x16xf16, #hivm.address_space<ub>> {
    %0 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %1 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %2 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %3 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %4 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                  outs(%0 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg1 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                      outs(%1 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%arg3 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                      outs(%4 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.vadd ins(%0, %1 : memref<16x16x16xf16, #hivm.address_space<ub>>,
                      memref<16x16x16xf16, #hivm.address_space<ub>>)
                      outs(%2 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    %c128 = arith.constant 128 : index
    %c1024 = arith.constant 1024 : index
    %c0 = arith.constant 0 : index
    %5 = scf.for %arg4 = %c0 to %c1024 step %c128 iter_args(%arg5 = %4) ->
         (memref<16x16x16xf16, #hivm.address_space<ub>>) {
      hivm.hir.vadd ins(%0, %arg5 : memref<16x16x16xf16, #hivm.address_space<ub>>,
                        memref<16x16x16xf16, #hivm.address_space<ub>>)
                    outs(%3 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      scf.yield %3 : memref<16x16x16xf16, #hivm.address_space<ub>>
    }
    hivm.hir.store ins(%2 : memref<16x16x16xf16, #hivm.address_space<ub>>)
                   outs(%arg2 : memref<16x16x16xf16, #hivm.address_space<gm>>)
    return %5 : memref<16x16x16xf16, #hivm.address_space<ub>>
  }
}

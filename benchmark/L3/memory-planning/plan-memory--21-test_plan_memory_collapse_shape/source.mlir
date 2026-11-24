module {
  func.func @test_plan_memory_collapse_shape(%alloc2 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                             %alloc4 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                             %alloc6 : memref<256x16xf16, #hivm.address_space<gm>>) {
    %alloc1 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc3 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    %alloc5 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%alloc2 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                  outs(%alloc1 : memref<16x16x16xf16, #hivm.address_space<ub>>)
    hivm.hir.load ins(%alloc4 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                  outs(%alloc3 : memref<16x16x16xf16, #hivm.address_space<ub>>)

    hivm.hir.vadd ins(%alloc1, %alloc3: memref<16x16x16xf16, #hivm.address_space<ub>>,
                      memref<16x16x16xf16, #hivm.address_space<ub>>)
                  outs(%alloc5: memref<16x16x16xf16, #hivm.address_space<ub>>)
    %0 = memref.collapse_shape %alloc5 [[0, 1], [2]] :
         memref<16x16x16xf16, #hivm.address_space<ub>> into memref<256x16xf16, #hivm.address_space<ub>>
    hivm.hir.store ins(%0: memref<256x16xf16, #hivm.address_space<ub>>)
                   outs(%alloc6: memref<256x16xf16, #hivm.address_space<gm>>)
    return
  }
}

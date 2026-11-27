module {
  func.func @test_plan_memory_subview_in_loop(%arg0 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                              %arg1 : memref<16x16x16xf16, #hivm.address_space<gm>>,
                                              %arg2 : memref<16x2x16xf16, #hivm.address_space<gm>>) {
    %start = arith.constant 0 : index
    %end = arith.constant 1024 : index
    %step = arith.constant 128 : index
    scf.for %iv = %start to %end step %step {
      %alloc_0 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
      annotation.mark %alloc_0 {hivm.multi_buffer = 2 : i32} : memref<16x16x16xf16, #hivm.address_space<ub>>
      %alloc_1 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
      annotation.mark %alloc_1 {hivm.multi_buffer = 2 : i32} : memref<16x16x16xf16, #hivm.address_space<ub>>
      %alloc_2 = memref.alloc() : memref<16x16x16xf16, #hivm.address_space<ub>>
      annotation.mark %alloc_2 {hivm.multi_buffer = 2 : i32} : memref<16x16x16xf16, #hivm.address_space<ub>>
      hivm.hir.load ins(%arg0 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                    outs(%alloc_0 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      hivm.hir.load ins(%arg1 : memref<16x16x16xf16, #hivm.address_space<gm>>)
                    outs(%alloc_1 : memref<16x16x16xf16, #hivm.address_space<ub>>)
      hivm.hir.vadd ins(%alloc_0, %alloc_1: memref<16x16x16xf16, #hivm.address_space<ub>>,
                        memref<16x16x16xf16, #hivm.address_space<ub>>)
            outs(%alloc_2: memref<16x16x16xf16, #hivm.address_space<ub>>)
      %subview = memref.subview %alloc_2[0, 0, 0] [16, 2, 16] [1, 1, 1] :
          memref<16x16x16xf16, #hivm.address_space<ub>> to
          memref<16x2x16xf16, strided<[256, 16, 1]>, #hivm.address_space<ub>>

      hivm.hir.store ins(%subview: memref<16x2x16xf16, strided<[256, 16, 1]>, #hivm.address_space<ub>>)
                    outs(%arg2: memref<16x2x16xf16, #hivm.address_space<gm>>)
    }
    return
  }
}

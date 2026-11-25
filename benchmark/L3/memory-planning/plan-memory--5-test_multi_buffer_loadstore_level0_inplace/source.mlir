module {
  func.func @test_multi_buffer_loadstore_level0_inplace(%arg0 : memref<24576xf32, #hivm.address_space<gm>>,
                                                        %arg1 : memref<24576xf32, #hivm.address_space<gm>>) {
    %start = arith.constant 0 : index
    %end = arith.constant 1024 : index
    %step = arith.constant 128 : index
    scf.for %iv = %start to %end step %step {
      %alloc_0 = memref.alloc() : memref<24576xf32, #hivm.address_space<ub>>
      annotation.mark %alloc_0 {hivm.multi_buffer = 2 : i32} : memref<24576xf32, #hivm.address_space<ub>>
      %alloc_1 = memref.alloc() : memref<24576xf32, #hivm.address_space<ub>>
      annotation.mark %alloc_1 {hivm.multi_buffer = 2 : i32} : memref<24576xf32, #hivm.address_space<ub>>
      hivm.hir.load ins(%arg0 : memref<24576xf32, #hivm.address_space<gm>>)
                     outs(%alloc_0 : memref<24576xf32, #hivm.address_space<ub>>)
      hivm.hir.vadd ins(%alloc_0, %alloc_0 : memref<24576xf32, #hivm.address_space<ub>>,
                        memref<24576xf32, #hivm.address_space<ub>>)
                    outs(%alloc_1 : memref<24576xf32, #hivm.address_space<ub>>)
      hivm.hir.store ins(%alloc_1 : memref<24576xf32, #hivm.address_space<ub>>)
                     outs(%arg1 : memref<24576xf32, #hivm.address_space<gm>>)
    }
    return
  }
}

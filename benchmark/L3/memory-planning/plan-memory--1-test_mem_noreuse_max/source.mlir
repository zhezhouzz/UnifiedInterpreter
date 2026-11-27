module {
  func.func @test_mem_noreuse_max(%src : memref<16384xi64, #hivm.address_space<gm>>,
                                  %dst : memref<16384xi32, #hivm.address_space<gm>>) {
    %alloc = memref.alloc() : memref<16384xi64, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<16384xi32, #hivm.address_space<ub>>
    %alloc_1 = memref.alloc() : memref<0xi64, #hivm.address_space<ub>>
    hivm.hir.load ins(%src : memref<16384xi64, #hivm.address_space<gm>>)
                  outs(%alloc : memref<16384xi64, #hivm.address_space<ub>>)
    hivm.hir.vcast ins(%alloc : memref<16384xi64, #hivm.address_space<ub>>)
                  outs(%alloc_0 : memref<16384xi32, #hivm.address_space<ub>>)
                  temp_buffer (%alloc_1 : memref<0xi64, #hivm.address_space<ub>>) round_mode = <truncwithoverflow>
    hivm.hir.store ins(%alloc_0 : memref<16384xi32,#hivm.address_space<ub>>)
                   outs(%dst: memref<16384xi32,#hivm.address_space<gm>>)
    return
  }
}

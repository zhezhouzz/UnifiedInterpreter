module {
  func.func @test_select_init_iter_no_reuse_yield(
      %src0: memref<64xf32, #hivm.address_space<gm>>,
      %src1: memref<64xf32, #hivm.address_space<gm>>,
      %tmp_src: memref<64xf32, #hivm.address_space<gm>>,
      %dst: memref<64xf32, #hivm.address_space<gm>>,
      %cond: i1) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %init0 = memref.alloc() : memref<64xf32, #hivm.address_space<ub>>
    %init1 = memref.alloc() : memref<64xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%src0 : memref<64xf32, #hivm.address_space<gm>>)
                  outs(%init0 : memref<64xf32, #hivm.address_space<ub>>)
    hivm.hir.load ins(%src1 : memref<64xf32, #hivm.address_space<gm>>)
                  outs(%init1 : memref<64xf32, #hivm.address_space<ub>>)
    %init = arith.select %cond, %init0, %init1 : memref<64xf32, #hivm.address_space<ub>>
    %acc = scf.for %i = %c0 to %c2 step %c1 iter_args(%iter = %init)
        -> (memref<64xf32, #hivm.address_space<ub>>) {
      %tmp = memref.alloc() : memref<64xf32, #hivm.address_space<ub>>
      hivm.hir.load ins(%tmp_src : memref<64xf32, #hivm.address_space<gm>>)
                    outs(%tmp : memref<64xf32, #hivm.address_space<ub>>)
      %out = memref.alloc() : memref<64xf32, #hivm.address_space<ub>>
      hivm.hir.vadd ins(%iter, %tmp : memref<64xf32, #hivm.address_space<ub>>,
                                      memref<64xf32, #hivm.address_space<ub>>)
                    outs(%out : memref<64xf32, #hivm.address_space<ub>>)
      scf.yield %out : memref<64xf32, #hivm.address_space<ub>>
    }
    hivm.hir.store ins(%acc : memref<64xf32, #hivm.address_space<ub>>)
                   outs(%dst : memref<64xf32, #hivm.address_space<gm>>)
    return
  }
}

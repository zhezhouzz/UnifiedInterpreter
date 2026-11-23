module {
  func.func @test_mem_memref_load_store(%arg0: memref<1024xf16, #hivm.address_space<gm>>, %arg1: memref<1024xf16, #hivm.address_space<gm>>) {
    %c2048_i64 = arith.constant 2048 : i64
    %c0 = arith.constant 0 : index
    %c1024 = arith.constant 1024 : index
    %c1 = arith.constant 1 : index
    %c0_i64 = arith.constant 0 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<1024xf16, #hivm.address_space<ub>>
    %1 = hivm.hir.pointer_cast(%c2048_i64) : memref<1024xf16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<1024xf16, #hivm.address_space<gm>>) outs(%0 : memref<1024xf16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_S>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_S>, <EVENT_ID0>]
    scf.for %arg2 = %c0 to %c1024 step %c1 {
      %2 = memref.load %0[%arg2] : memref<1024xf16, #hivm.address_space<ub>>
      %3 = memref.load %0[%arg2] : memref<1024xf16, #hivm.address_space<ub>>
      %4 = arith.addf %2, %3 : f16
      memref.store %4, %1[%arg2] : memref<1024xf16, #hivm.address_space<ub>>
    }
    hivm.hir.set_flag[<PIPE_S>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_S>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%1 : memref<1024xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<1024xf16, #hivm.address_space<gm>>)
    return
  }
}


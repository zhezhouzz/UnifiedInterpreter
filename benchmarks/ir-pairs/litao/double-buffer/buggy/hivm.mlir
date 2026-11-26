module {
  func.func @kernel(%arg0: memref<32xf32, #hivm.address_space<gm>>, %arg1: memref<32xf32, #hivm.address_space<gm>>, %arg2: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %c0_i64 = arith.constant 0 : i64
    %c256_i64 = arith.constant 256 : i64
    %c512_i64 = arith.constant 512 : i64
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<32xf32, #hivm.address_space<ub>>
    %1 = hivm.hir.pointer_cast(%c256_i64) : memref<32xf32, #hivm.address_space<ub>>
    %2 = hivm.hir.pointer_cast(%c512_i64) : memref<32xf32, #hivm.address_space<ub>>
    scf.for %arg3 = %c0 to %arg2 step %c1 {
      %3 = arith.cmpi eq, %arg3, %c1 : index
      %4 = arith.cmpi eq, %arg3, %c0 : index
      %5 = arith.cmpi eq, %arg3, %c2 : index
      %6 = arith.select %3, %1, %0 : memref<32xf32, #hivm.address_space<ub>>
      %7 = arith.select %5, %arg1, %arg0 : memref<32xf32, #hivm.address_space<gm>>
      hivm.hir.load ins(%7 : memref<32xf32, #hivm.address_space<gm>>) outs(%6 : memref<32xf32, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
      hivm.hir.vabs ins(%6 : memref<32xf32, #hivm.address_space<ub>>) outs(%2 : memref<32xf32, #hivm.address_space<ub>>)
      scf.if %4 {
        hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
      }
    }
    return
  }
}


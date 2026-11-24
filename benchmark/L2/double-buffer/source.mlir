func.func @kernel(%first: memref<32xf32, #hivm.address_space<gm>>, %next: memref<32xf32, #hivm.address_space<gm>>, %count: index) {
  %zero = arith.constant 0 : index
  %one = arith.constant 1 : index
  %two = arith.constant 2 : index
  %addr0 = arith.constant 0 : i64
  %addr1 = arith.constant 256 : i64
  %addr2 = arith.constant 512 : i64
  %slotA = hivm.hir.pointer_cast(%addr0) : memref<32xf32, #hivm.address_space<ub>>
  %slotB = hivm.hir.pointer_cast(%addr1) : memref<32xf32, #hivm.address_space<ub>>
  %out = hivm.hir.pointer_cast(%addr2) : memref<32xf32, #hivm.address_space<ub>>
  scf.for %i = %zero to %count step %one {
    %middle = arith.cmpi eq, %i, %one : index
    %firstRound = arith.cmpi eq, %i, %zero : index
    %reuse = arith.cmpi eq, %i, %two : index
    %slot = arith.select %middle, %slotB, %slotA : memref<32xf32, #hivm.address_space<ub>>
    %input = arith.select %reuse, %next, %first : memref<32xf32, #hivm.address_space<gm>>
    scf.if %reuse {
      hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
    }
    hivm.hir.load ins(%input : memref<32xf32, #hivm.address_space<gm>>) outs(%slot : memref<32xf32, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vabs ins(%slot : memref<32xf32, #hivm.address_space<ub>>) outs(%out : memref<32xf32, #hivm.address_space<ub>>)
    scf.if %firstRound {
      hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
    }
  }
  return
}

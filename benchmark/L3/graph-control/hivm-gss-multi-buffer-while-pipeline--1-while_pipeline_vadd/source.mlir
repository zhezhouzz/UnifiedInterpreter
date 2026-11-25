
func.func @while_pipeline_vadd(%arg0: memref<8xf32, #hivm.address_space<gm>>,
                               %arg1: memref<8xf32, #hivm.address_space<gm>>) {
  %true = arith.constant true


  %r = scf.while (%cond = %true) : (i1) -> i1 {
    scf.condition(%cond) %cond : i1
  } do {
  ^bb0(%cin: i1):
    %tmp = memref.alloc() : memref<8xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<8xf32, #hivm.address_space<gm>>)
                  outs(%tmp : memref<8xf32, #hivm.address_space<ub>>)
    hivm.hir.vadd ins(%tmp, %tmp : memref<8xf32, #hivm.address_space<ub>>,
                                   memref<8xf32, #hivm.address_space<ub>>)
                  outs(%tmp : memref<8xf32, #hivm.address_space<ub>>)
    hivm.hir.store ins(%tmp : memref<8xf32, #hivm.address_space<ub>>)
                   outs(%arg1 : memref<8xf32, #hivm.address_space<gm>>)
    scf.yield %cin : i1
  }
  return
}

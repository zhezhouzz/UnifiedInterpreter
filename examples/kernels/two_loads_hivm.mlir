#gm = #hivm.address_space<gm>
#ub = #hivm.address_space<ub>
func.func @two_loads(%a: memref<1xf32, #gm>, %b: memref<1xf32, #gm>,
                     %dst: memref<1xf32, #ub>, %n: index) {
  %zero = arith.constant 0 : index
  %one = arith.constant 1 : index
  scf.for %i = %zero to %n step %one {
    hivm.hir.load ins(%a : memref<1xf32, #gm>) outs(%dst : memref<1xf32, #ub>)
    hivm.hir.load ins(%b : memref<1xf32, #gm>) outs(%dst : memref<1xf32, #ub>)
  }
  return
}

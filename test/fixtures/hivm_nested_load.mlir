#gm = #hivm.address_space<gm>
#ub = #hivm.address_space<ub>
func.func @nested_load(%src: memref<1xf32, #gm>, %dst: memref<1xf32, #ub>) {
  %one = arith.constant 1 : index
  %two = arith.constant 2 : index
  %five = arith.constant 5 : index
  scf.for %i = %one to %five step %two {
    scf.for %j = %one to %five step %two {
      hivm.hir.load ins(%src : memref<1xf32, #gm>) outs(%dst : memref<1xf32, #ub>)
    }
  }
  return
}

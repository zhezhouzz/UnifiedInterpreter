#gm = #hivm.address_space<gm>
#ub = #hivm.address_space<ub>
func.func @prefix_boundary(%src: memref<1xf32, #gm>, %dst: memref<1xf32, #ub>, %value: f32) {
  %zero = arith.constant 0 : index
  hivm.hir.pipe_barrier[<PIPE_ALL>]
  hivm.hir.load ins(%src : memref<1xf32, #gm>) outs(%dst : memref<1xf32, #ub>)
  memref.store %value, %dst[%zero] : memref<1xf32, #ub>
  return
}

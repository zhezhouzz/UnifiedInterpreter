func.func @vf_inplace_reuse_reachable_through_load(
    %arg0: memref<2x32xf32, #hivm.address_space<ub>>,
    %arg1: memref<2x32xf32, #hivm.address_space<ub>>) attributes {hivm.vector_function} {
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f32
  %0 = vector.transfer_read %arg0[%c0, %c0], %cst {in_bounds = [true, true]} : memref<2x32xf32, #hivm.address_space<ub>>, vector<2x32xf32>
  vector.transfer_write %0, %arg1[%c0, %c0] {in_bounds = [true, true]} : vector<2x32xf32>, memref<2x32xf32, #hivm.address_space<ub>>
  return
}

func.func @plan_memory_vf_no_inplace_reuse_with_reshape_user(
    %arg0: memref<2x32xf32, #hivm.address_space<gm>>,
    %arg1: memref<2x32xf32, #hivm.address_space<gm>>) {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %cst = arith.constant 0.000000e+00 : f32
  scf.for %i = %c0 to %c1 step %c1 {
    %input = memref.alloc() : memref<2x32xf32, #hivm.address_space<ub>>
    %inputSubview = memref.subview %input[0, 0] [2, 32] [1, 1] : memref<2x32xf32, #hivm.address_space<ub>> to memref<2x32xf32, strided<[32, 1]>, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<2x32xf32, #hivm.address_space<gm>>) outs(%inputSubview : memref<2x32xf32, strided<[32, 1]>, #hivm.address_space<ub>>) pad_mode = <PadValue> pad_value = %cst : f32 left_padding_num = %c0 : index
    %inputCollapsed = memref.collapse_shape %input [[0, 1]] : memref<2x32xf32, #hivm.address_space<ub>> into memref<64xf32, #hivm.address_space<ub>>
    %output = memref.alloc() : memref<2x32xf32, #hivm.address_space<ub>>
    func.call @vf_inplace_reuse_reachable_through_load(%input, %output) {hivm.vector_function} : (memref<2x32xf32, #hivm.address_space<ub>>, memref<2x32xf32, #hivm.address_space<ub>>) -> ()
    hivm.hir.store ins(%output : memref<2x32xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<2x32xf32, #hivm.address_space<gm>>)
  }
  return
}

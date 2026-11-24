func.func @simple_reusable_vf(
    %arg0: memref<64xf32, #hivm.address_space<ub>>,
    %arg1: memref<64xf32, #hivm.address_space<ub>>) attributes {hivm.vector_function} {
  %cst = arith.constant dense<0.693147182> : vector<64xf32>
  %cst_0 = arith.constant 0.000000e+00 : f32
  %c0 = arith.constant 0 : index
  %0 = vector.transfer_read %arg0[%c0], %cst_0 {in_bounds = [true]} : memref<64xf32, #hivm.address_space<ub>>, vector<64xf32>
  %1 = math.log %0 : vector<64xf32>
  vector.transfer_write %1, %arg1[%c0] {in_bounds = [true]} : vector<64xf32>, memref<64xf32, #hivm.address_space<ub>>
  return
}

func.func @not_inplace_reuse_when_reach_load_and_store_0(
  %arg0: memref<64xf32, #hivm.address_space<gm>>,
  %arg1: memref<64xf32, #hivm.address_space<gm>>
) {
  %cst = arith.constant 0.000000e+00 : f32
  %c0 = arith.constant 0 : index
  %alloc_0 = memref.alloc() : memref<128xf32, #hivm.address_space<ub>>
  %subview_0 = memref.subview %alloc_0[0] [64] [1] : memref<128xf32, #hivm.address_space<ub>> to memref<64xf32, #hivm.address_space<ub>>
  hivm.hir.load ins(%arg0 : memref<64xf32, #hivm.address_space<gm>>)
                outs(%subview_0 : memref<64xf32, #hivm.address_space<ub>>) pad_mode = <PadValue> pad_value = %cst : f32 left_padding_num = %c0 : index
  %alloc_1 = memref.alloc() : memref<128xf32, #hivm.address_space<ub>>
  %subview_1 = memref.subview %alloc_1[0] [64] [1] : memref<128xf32, #hivm.address_space<ub>> to memref<64xf32, #hivm.address_space<ub>>
  call @simple_reusable_vf(%subview_0, %subview_1) {hivm.vector_function} :
       (memref<64xf32, #hivm.address_space<ub>>, memref<64xf32, #hivm.address_space<ub>>) -> ()
  %alloc_2 = memref.alloc() : memref<128xf32, #hivm.address_space<ub>>
  %subview_2 = memref.subview %alloc_2[0] [64] [1] : memref<128xf32, #hivm.address_space<ub>> to memref<64xf32, #hivm.address_space<ub>>
  call @simple_reusable_vf(%subview_1, %subview_2) {hivm.vector_function} :
       (memref<64xf32, #hivm.address_space<ub>>, memref<64xf32, #hivm.address_space<ub>>) -> ()
  hivm.hir.store ins(%subview_2 : memref<64xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<64xf32, #hivm.address_space<gm>>)
  return
}

func.func @simple_not_reusable_vf(
    %arg0: memref<64xf32, #hivm.address_space<ub>>,
    %arg1: memref<64xf32, #hivm.address_space<ub>>) attributes {hivm.vector_function} {
  %cst = arith.constant dense<0.693147182> : vector<64xf32>
  %cst_0 = arith.constant 0.000000e+00 : f32
  %c0 = arith.constant 0 : index
  %0 = vector.transfer_read %arg0[%c0], %cst_0 {in_bounds = [true]} : memref<64xf32, #hivm.address_space<ub>>, vector<64xf32>
  %1 = vector.transfer_read %arg1[%c0], %cst_0 {in_bounds = [true]} : memref<64xf32, #hivm.address_space<ub>>, vector<64xf32>
  %2 = arith.mulf %0, %1 : vector<64xf32>
  vector.transfer_write %2, %arg1[%c0] {in_bounds = [true]} : vector<64xf32>, memref<64xf32, #hivm.address_space<ub>>
  return
}

func.func @can_inplace_reuse_when_not_reach_load_or_store_0(
  %arg0: memref<64xf32, #hivm.address_space<gm>>,
  %arg1: memref<64xf32, #hivm.address_space<gm>>
) {
  %cst = arith.constant 0.000000e+00 : f32
  %c0 = arith.constant 0 : index
  %alloc_0 = memref.alloc() : memref<128xf32, #hivm.address_space<ub>>
  %subview_0 = memref.subview %alloc_0[0] [64] [1] : memref<128xf32, #hivm.address_space<ub>> to memref<64xf32, #hivm.address_space<ub>>
  hivm.hir.load ins(%arg0 : memref<64xf32, #hivm.address_space<gm>>)
                outs(%subview_0 : memref<64xf32, #hivm.address_space<ub>>) pad_mode = <PadValue> pad_value = %cst : f32 left_padding_num = %c0 : index
  %alloc_1 = memref.alloc() : memref<128xf32, #hivm.address_space<ub>>
  %subview_1 = memref.subview %alloc_1[0] [64] [1] : memref<128xf32, #hivm.address_space<ub>> to memref<64xf32, #hivm.address_space<ub>>
  call @simple_reusable_vf(%subview_0, %subview_1) {hivm.vector_function} :
       (memref<64xf32, #hivm.address_space<ub>>, memref<64xf32, #hivm.address_space<ub>>) -> ()
  %alloc_2 = memref.alloc() : memref<128xf32, #hivm.address_space<ub>>
  %subview_2 = memref.subview %alloc_2[0] [64] [1] : memref<128xf32, #hivm.address_space<ub>> to memref<64xf32, #hivm.address_space<ub>>
  call @simple_not_reusable_vf(%subview_1, %subview_2) {hivm.vector_function} :
       (memref<64xf32, #hivm.address_space<ub>>, memref<64xf32, #hivm.address_space<ub>>) -> ()
  hivm.hir.store ins(%subview_2 : memref<64xf32, #hivm.address_space<ub>>) outs(%arg1 : memref<64xf32, #hivm.address_space<gm>>)
  return
}

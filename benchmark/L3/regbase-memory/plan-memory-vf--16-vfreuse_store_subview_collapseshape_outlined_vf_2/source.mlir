func.func @vfreuse_store_subview_collapseshape_outlined_vf_2(%arg0: memref<64xbf16, #hivm.address_space<ub>>, %arg1: memref<64x320xbf16, #hivm.address_space<ub>>, %arg2: memref<64x320xbf16, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
  %cst = arith.constant dense<1.000000e+00> : vector<1x64xf32>
  %cst_0 = arith.constant dense<-1.000000e+00> : vector<1x64xf32>
  %cst_1 = arith.constant 0.000000e+00 : bf16
  %c1 = arith.constant 1 : index
  %c64 = arith.constant 64 : index
  %c320 = arith.constant 320 : index
  %c0 = arith.constant 0 : index
  scf.for %arg3 = %c0 to %c64 step %c1 {
  %subview = memref.subview %arg0[%arg3] [1] [1] : memref<64xbf16, #hivm.address_space<ub>> to memref<1xbf16, strided<[1], offset: ?>, #hivm.address_space<ub>>
    scf.for %arg4 = %c0 to %c320 step %c64 {
      %subview_2 = memref.subview %arg1[%arg3, %arg4] [1, 64] [1, 1] : memref<64x320xbf16, #hivm.address_space<ub>> to memref<1x64xbf16, strided<[320, 1], offset: ?>, #hivm.address_space<ub>>
      %subview_3 = memref.subview %arg2[%arg3, %arg4] [1, 64] [1, 1] : memref<64x320xbf16, #hivm.address_space<ub>> to memref<1x64xbf16, strided<[320, 1], offset: ?>, #hivm.address_space<ub>>
      %0 = vector.transfer_read %subview_2[%c0, %c0], %cst_1 {in_bounds = [true, true]} : memref<1x64xbf16, strided<[320, 1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xbf16>
      %1 = vector.transfer_read %subview[%c0], %cst_1 {in_bounds = [true, true], permutation_map = affine_map<(d0) -> (d0, 0)>} : memref<1xbf16, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<1x64xbf16>
      %2 = arith.extf %1 {enable_saturate = false, round_mode = #hfusion.round_mode<rint>} : vector<1x64xbf16> to vector<1x64xf32>
      %3 = arith.mulf %2, %cst_0 : vector<1x64xf32>
      %4 = math.exp %3 : vector<1x64xf32>
      %5 = arith.addf %4, %cst : vector<1x64xf32>
      %6 = arith.divf %cst, %5 : vector<1x64xf32>
      %7 = arith.extf %0 {enable_saturate = false, round_mode = #hfusion.round_mode<rint>} : vector<1x64xbf16> to vector<1x64xf32>
      %8 = arith.mulf %7, %6 : vector<1x64xf32>
      %9 = arith.truncf %8 {enable_saturate = false, round_mode = #hfusion.round_mode<rint>} : vector<1x64xf32> to vector<1x64xbf16>
      vector.transfer_write %9, %subview_3[%c0, %c0] {in_bounds = [true, true]} : vector<1x64xbf16>, memref<1x64xbf16, strided<[320, 1], offset: ?>, #hivm.address_space<ub>>
    }
  }
  return
}
func.func @vfreuse_store_subview_collapseshape(%arg2: memref<?xbf16, #hivm.address_space<gm>>, %18: index) {
  %c0_i32 = arith.constant 0 : i32
  %c1_i32 = arith.constant 1 : i32
  %c59_i32 = arith.constant 59 : i32
  %cst = arith.constant 0.000000e+00 : bf16
  %c0 = arith.constant 0 : index
  scf.for %arg9 = %c0_i32 to %c59_i32 step %c1_i32  : i32 {
    %14 = arith.index_cast %arg9 : i32 to index
    %alloc = memref.alloc() : memref<64x320xbf16, #hivm.address_space<ub>>
    %alloc_3 = memref.alloc() : memref<64xbf16, #hivm.address_space<ub>>
    %alloc_6 = memref.alloc() {alignment = 64 : i64} : memref<64x320xbf16, #hivm.address_space<ub>>
    %subview_0 = memref.subview %alloc[0, 0] [%18, 320] [1, 1] : memref<64x320xbf16, #hivm.address_space<ub>> to memref<?x320xbf16, strided<[320, 1]>, #hivm.address_space<ub>>
    %collapse_shape_1 = memref.collapse_shape %subview_0 [[0, 1]] : memref<?x320xbf16, strided<[320, 1]>, #hivm.address_space<ub>> into memref<?xbf16, strided<[1]>, #hivm.address_space<ub>>
    %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [%14], sizes: [64, 320], strides: [320, 1] : memref<?xbf16, #hivm.address_space<gm>> to memref<64x320xbf16, strided<[320, 1], offset: ?>, #hivm.address_space<gm>>
    %subview = memref.subview %reinterpret_cast[0, 0] [%18, 320] [1, 1] : memref<64x320xbf16, strided<[320, 1], offset: ?>, #hivm.address_space<gm>> to memref<?x320xbf16, strided<[320, 1], offset: ?>, #hivm.address_space<gm>>
    %collapse_shape = memref.collapse_shape %subview [[0, 1]] : memref<?x320xbf16, strided<[320, 1], offset: ?>, #hivm.address_space<gm>> into memref<?xbf16, strided<[1], offset: ?>, #hivm.address_space<gm>>
    hivm.hir.load ins(%collapse_shape : memref<?xbf16, strided<[1], offset: ?>, #hivm.address_space<gm>>) outs(%collapse_shape_1 : memref<?xbf16, strided<[1]>, #hivm.address_space<ub>>) pad_mode = <PadValue> pad_value = %cst : bf16 left_padding_num = %c0 : index eviction_policy = <EvictFirst>
    func.call @vfreuse_store_subview_collapseshape_outlined_vf_2(%alloc_3, %alloc, %alloc_6) {hivm.vector_function, no_inline} : (memref<64xbf16, #hivm.address_space<ub>>, memref<64x320xbf16, #hivm.address_space<ub>>, memref<64x320xbf16, #hivm.address_space<ub>>) -> ()
    %subview_7 = memref.subview %alloc_6[0, 0] [%18, 320] [1, 1] : memref<64x320xbf16, #hivm.address_space<ub>> to memref<?x320xbf16, strided<[320, 1]>, #hivm.address_space<ub>>
    %collapse_shape_8 = memref.collapse_shape %subview_7 [[0, 1]] : memref<?x320xbf16, strided<[320, 1]>, #hivm.address_space<ub>> into memref<?xbf16, strided<[1]>, #hivm.address_space<ub>>
    hivm.hir.store ins(%collapse_shape_8 : memref<?xbf16, strided<[1]>, #hivm.address_space<ub>>) outs(%collapse_shape : memref<?xbf16, strided<[1], offset: ?>, #hivm.address_space<gm>>)
  }
  return
}

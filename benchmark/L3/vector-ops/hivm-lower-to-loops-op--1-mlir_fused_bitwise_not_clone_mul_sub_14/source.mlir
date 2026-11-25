func.func @mlir_fused_bitwise_not_clone_mul_sub_14(%arg0: memref<1x16384xi64, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<input>, hacc.input_idx = #hacc.input_idx<0>}, %arg1: memref<16384x1xi8, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<input>, hacc.input_idx = #hacc.input_idx<1>}, %arg2: memref<16384x1xi64, #hivm.address_space<gm>> {hacc.arg_type = #hacc.arg_type<output>, hacc.output_idx = #hacc.output_idx<0>}) attributes {enable_auto_mark_buffer_size, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hacc.get_tiling_struct_size_function = #hacc.get_tiling_struct_size_function<@mlir_fused_bitwise_not_clone_mul_sub_14_get_tiling_struct_size_function>, hacc.block_dim = 1 : i64, hfusion.fusion_kind = #hfusion.fusion_kind<PURE_ELEMWISE>, hivm.func_core_type = #hivm.func_core_type<AIV>} {
  %c80256_i64 = arith.constant 80256 : i64
  %c79040_i64 = arith.constant 79040 : i64
  %c155648_i64 = arith.constant 155648 : i64
  %c77824_i64 = arith.constant 77824 : i64
  %c0_i64 = arith.constant 0 : i64
  %cst = arith.constant 0.000000e+00 : f16
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c2 = arith.constant 2 : index
  hivm.hir.set_mask_norm
  %collapse_shape = memref.collapse_shape %arg0 [[0, 1]] : memref<1x16384xi64, #hivm.address_space<gm>> into memref<16384xi64, #hivm.address_space<gm>>
  %collapse_shape_0 = memref.collapse_shape %arg1 [[0, 1]] : memref<16384x1xi8, #hivm.address_space<gm>> into memref<16384xi8, #hivm.address_space<gm>>
  %collapse_shape_1 = memref.collapse_shape %arg2 [[0, 1]] : memref<16384x1xi64, #hivm.address_space<gm>> into memref<16384xi64, #hivm.address_space<gm>>
  scf.for %arg3 = %c0 to %c2 step %c1 {
    %0 = affine.apply affine_map<()[s0] -> (s0 * 9728)>()[%arg3]
    %1 = affine.min affine_map<()[s0] -> (s0 * -9728 + 16384, 9728)>()[%arg3]
    %subview = memref.subview %collapse_shape[%0] [%1] [1] : memref<16384xi64, #hivm.address_space<gm>> to memref<?xi64, strided<[1], offset: ?>, #hivm.address_space<gm>>
    %2 = hivm.hir.pointer_cast(%c0_i64) : memref<77824xi8, #hivm.address_space<ub>>
    %view = memref.view %2[%c0][%1] : memref<77824xi8, #hivm.address_space<ub>> to memref<?xi64, #hivm.address_space<ub>>
    hivm.hir.load ins(%subview : memref<?xi64, strided<[1], offset: ?>, #hivm.address_space<gm>>) outs(%view : memref<?xi64, #hivm.address_space<ub>>)
    %subview_2 = memref.subview %collapse_shape_0[%0] [%1] [1] : memref<16384xi8, #hivm.address_space<gm>> to memref<?xi8, strided<[1], offset: ?>, #hivm.address_space<gm>>
    %3 = hivm.hir.pointer_cast(%c77824_i64) : memref<9728xi8, #hivm.address_space<ub>>
    %view_3 = memref.view %3[%c0][%1] : memref<9728xi8, #hivm.address_space<ub>> to memref<?xi8, #hivm.address_space<ub>>
    hivm.hir.load ins(%subview_2 : memref<?xi8, strided<[1], offset: ?>, #hivm.address_space<gm>>) outs(%view_3 : memref<?xi8, #hivm.address_space<ub>>)
    %subview_4 = memref.subview %collapse_shape_1[%0] [%1] [1] : memref<16384xi64, #hivm.address_space<gm>> to memref<?xi64, strided<[1], offset: ?>, #hivm.address_space<gm>>
    %4 = hivm.hir.pointer_cast(%c155648_i64) : memref<19456xi8, #hivm.address_space<ub>>
    %view_5 = memref.view %4[%c0][%1] : memref<19456xi8, #hivm.address_space<ub>> to memref<?xf16, #hivm.address_space<ub>>
    hivm.hir.vcast ins(%view_3 : memref<?xi8, #hivm.address_space<ub>>) outs(%view_5 : memref<?xf16, #hivm.address_space<ub>>)
    %5 = hivm.hir.pointer_cast(%c77824_i64) : memref<1216xi8, #hivm.address_space<ub>>
    %view_6 = memref.view %5[%c0][%1] : memref<1216xi8, #hivm.address_space<ub>> to memref<?xi1, #hivm.address_space<ub>>
    hivm.hir.vcmp ins(%view_5, %cst : memref<?xf16, #hivm.address_space<ub>>, f16) outs(%view_6 : memref<?xi1, #hivm.address_space<ub>>) compare_mode = <ne>
    %6 = hivm.hir.pointer_cast(%c79040_i64) : memref<1216xi8, #hivm.address_space<ub>>
    %view_7 = memref.view %6[%c0][%1] : memref<1216xi8, #hivm.address_space<ub>> to memref<?xi1, #hivm.address_space<ub>>
    hivm.hir.vnot ins(%view_6 : memref<?xi1, #hivm.address_space<ub>>) outs(%view_7 : memref<?xi1, #hivm.address_space<ub>>)
    %7 = hivm.hir.pointer_cast(%c80256_i64) : memref<19456xi8, #hivm.address_space<ub>>
    %view_8 = memref.view %7[%c0][%1] : memref<19456xi8, #hivm.address_space<ub>> to memref<?xf16, #hivm.address_space<ub>>
    %8 = hivm.hir.pointer_cast(%c77824_i64) : memref<48xf16, #hivm.address_space<ub>>
    hivm.hir.vcast ins(%view_7 : memref<?xi1, #hivm.address_space<ub>>) outs(%view_8 : memref<?xf16, #hivm.address_space<ub>>) temp_buffer(%8 : memref<48xf16, #hivm.address_space<ub>>) round_mode = <trunc>
    %9 = hivm.hir.pointer_cast(%c155648_i64) : memref<38912xi8, #hivm.address_space<ub>>
    %view_9 = memref.view %9[%c0][%1] : memref<38912xi8, #hivm.address_space<ub>> to memref<?xf32, #hivm.address_space<ub>>
    hivm.hir.vcast ins(%view_8 : memref<?xf16, #hivm.address_space<ub>>) outs(%view_9 : memref<?xf32, #hivm.address_space<ub>>)
    %10 = hivm.hir.pointer_cast(%c77824_i64) : memref<77824xi8, #hivm.address_space<ub>>
    %view_10 = memref.view %10[%c0][%1] : memref<77824xi8, #hivm.address_space<ub>> to memref<?xi64, #hivm.address_space<ub>>
    hivm.hir.vcast ins(%view_9 : memref<?xf32, #hivm.address_space<ub>>) outs(%view_10 : memref<?xi64, #hivm.address_space<ub>>) round_mode = <trunc>
    %11 = hivm.hir.pointer_cast(%c77824_i64) : memref<77824xi8, #hivm.address_space<ub>>
    %view_11 = memref.view %11[%c0][%1] : memref<77824xi8, #hivm.address_space<ub>> to memref<?xi64, #hivm.address_space<ub>>
    hivm.hir.vmul ins(%view, %view_10 : memref<?xi64, #hivm.address_space<ub>>, memref<?xi64, #hivm.address_space<ub>>) outs(%view_11 : memref<?xi64, #hivm.address_space<ub>>)
    hivm.hir.store ins(%view_11 : memref<?xi64, #hivm.address_space<ub>>) outs(%subview_4 : memref<?xi64, strided<[1], offset: ?>, #hivm.address_space<gm>>) atomic = <none>
  } {__tiled_for___2}
  return
}


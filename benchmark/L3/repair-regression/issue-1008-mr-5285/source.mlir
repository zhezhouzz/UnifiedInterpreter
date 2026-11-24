func.func @matmul_mix_aiv_with_bind_sub_block_tag(%arg0: tensor<64x64xf32>, %arg1: memref<32x64xf16>) attributes {WorkspaceArgIdx = 0 : i64, func_dyn_memref_args = dense<[false, true, true, true, true, false, false, false, false, false, false, false, false, false]> : vector<14xi1>, global_kernel = "local", hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.part_of_mix, mix_mode = "mix"} {
  %cst = arith.constant 1.000000e+00 : f32
  %cst_0 = arith.constant 0.00999999977 : f32
  %c2 = arith.constant 2 : i32
  %c0 = arith.constant 0 : i32
  %c1 = arith.constant 1 : i32
  %cst_1 = arith.constant 0.000000e+00 : f32
  %c32_i32 = arith.constant 32 : i32
  %0 = tensor.empty() : tensor<32x64xf32>
  scf.for %arg2 = %c0 to %c2 step %c1 : i32{
    %2 = arith.muli %arg2, %c32_i32 : i32
    %3 = arith.index_cast %2 : i32 to index
    %extracted_slice = tensor.extract_slice %arg0[%3, 0] [32, 64] [1, 1] : tensor<64x64xf32> to tensor<32x64xf32>
    %4 = hivm.hir.vadd ins(%extracted_slice, %cst : tensor<32x64xf32>, f32) outs(%0 : tensor<32x64xf32>) -> tensor<32x64xf32>
    %5 = tensor.empty() : tensor<32x64xf16>
    %6 = hivm.hir.vcast ins(%4 : tensor<32x64xf32>) outs(%5 : tensor<32x64xf16>) -> tensor<32x64xf16>
    bufferization.materialize_in_destination %6 in writable %arg1 : (tensor<32x64xf16>, memref<32x64xf16>) -> ()
  } {bind_sub_block = true}
  return
}

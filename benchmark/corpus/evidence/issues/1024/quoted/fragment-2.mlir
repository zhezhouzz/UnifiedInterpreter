func.func @..._outlined_vf_1(%arg0: memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>) {
  %cst  = arith.constant dense<0xFF800000> : vector<64xf32>
  %mask = vector.constant_mask [4] : vector<64xi1>
  vector.transfer_write %cst, %arg0[...], %mask { in_bounds = [true] }
      : vector<64xf32>, memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
}

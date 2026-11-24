module {
  func.func @gapped_rows(%arg0: vector<16x4xf32>, %arg1: memref<16x4xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    vector.transfer_write %arg0, %arg1[%c0, %c0] {in_bounds = [true, true]} : vector<16x4xf32>, memref<16x4xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }
}

// -----
module {
  func.func @gapped_planes(%arg0: vector<4x2x16xf16>, %arg1: memref<4x2x16xf16, strided<[1024, 16, 1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    vector.transfer_write %arg0, %arg1[%c0, %c0, %c0] {in_bounds = [true, true, true]} : vector<4x2x16xf16>, memref<4x2x16xf16, strided<[1024, 16, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }
}

// -----
module {
  func.func @partial_native_block(%arg0: vector<4x4xf32>, %arg1: memref<4x8xf32, strided<[16, 1]>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    vector.transfer_write %arg0, %arg1[%c0, %c0] {in_bounds = [true, true]} : vector<4x4xf32>, memref<4x8xf32, strided<[16, 1]>, #hivm.address_space<ub>>
    return
  }
}


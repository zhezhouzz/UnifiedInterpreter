// RUN: bishengir-opt %s --split-input-file --convert-vector-to-hivmave --verify-diagnostics

module {
  func.func @gapped_rows(%v: vector<16x4xf32>,
      %dst: memref<16x4xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    // expected-error @below {{cannot flatten noncontiguous transfer_write lanes to an AVE store}}
    vector.transfer_write %v, %dst[%c0, %c0] {in_bounds = [true, true]}
        : vector<16x4xf32>, memref<16x4xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }
}

// -----

module {
  func.func @gapped_planes(%v: vector<4x2x16xf16>,
      %dst: memref<4x2x16xf16, strided<[1024, 16, 1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    // expected-error @below {{cannot flatten noncontiguous transfer_write lanes to an AVE store}}
    vector.transfer_write %v, %dst[%c0, %c0, %c0] {in_bounds = [true, true, true]}
        : vector<4x2x16xf16>, memref<4x2x16xf16, strided<[1024, 16, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }
}

// -----

module {
  func.func @partial_native_block(%v: vector<4x4xf32>,
      %dst: memref<4x8xf32, strided<[16, 1]>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    // expected-error @below {{cannot flatten noncontiguous transfer_write lanes to an AVE store}}
    vector.transfer_write %v, %dst[%c0, %c0] {in_bounds = [true, true]}
        : vector<4x4xf32>, memref<4x8xf32, strided<[16, 1]>, #hivm.address_space<ub>>
    return
  }
}

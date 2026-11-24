// RUN: bishengir-opt %s --hacc-append-device-spec=target=Ascend960DT_968B7 --convert-vector-to-hivmave --verify-each | FileCheck %s

module {
  // CHECK-LABEL: func.func @one_row
  // CHECK: ave.hir.masked_store <NORM_B32>
  func.func @one_row(%v: vector<1x8xf32>,
      %dst: memref<?x16xf32, strided<[?, 1], offset: ?>, #hivm.address_space<ub>>, %row: index) {
    %c0 = arith.constant 0 : index
    vector.transfer_write %v, %dst[%row, %c0] {in_bounds = [true, true]}
        : vector<1x8xf32>, memref<?x16xf32, strided<[?, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }

  // CHECK-LABEL: func.func @strided_blocks
  // CHECK: ave.hir.store_with_stride
  func.func @strided_blocks(%v: vector<4x8xf32>,
      %dst: memref<4x8xf32, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    vector.transfer_write %v, %dst[%c0, %c0] {in_bounds = [true, true]}
        : vector<4x8xf32>, memref<4x8xf32, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }

  // CHECK-LABEL: func.func @first_lane
  // CHECK: ave.hir.masked_store <ONEPT_B32>
  func.func @first_lane(%v: vector<2x32xf32>,
      %dst: memref<2x32xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %mask1d = vector.constant_mask [1] : vector<64xi1>
    %mask = vector.shape_cast %mask1d : vector<64xi1> to vector<2x32xi1>
    vector.transfer_write %v, %dst[%c0, %c0], %mask {in_bounds = [true, true]}
        : vector<2x32xf32>, memref<2x32xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }

  // CHECK-LABEL: func.func @first_row_prefix
  // CHECK: ave.hir.masked_store <NORM_B32>
  func.func @first_row_prefix(%v: vector<2x32xf32>,
      %dst: memref<2x32xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %flat = ave.hir.pge <VL8> : vector<64xi1>
    %mask = vector.shape_cast %flat : vector<64xi1> to vector<2x32xi1>
    vector.transfer_write %v, %dst[%c0, %c0], %mask {in_bounds = [true, true]}
        : vector<2x32xf32>, memref<2x32xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }

}

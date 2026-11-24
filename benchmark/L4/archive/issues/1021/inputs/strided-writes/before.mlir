module {
  func.func @one_row(%arg0: vector<1x8xf32>, %arg1: memref<?x16xf32, strided<[?, 1], offset: ?>, #hivm.address_space<ub>>, %arg2: index) {
    %c0 = arith.constant 0 : index
    vector.transfer_write %arg0, %arg1[%arg2, %c0] {in_bounds = [true, true]} : vector<1x8xf32>, memref<?x16xf32, strided<[?, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }
  func.func @strided_blocks(%arg0: vector<4x8xf32>, %arg1: memref<4x8xf32, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    vector.transfer_write %arg0, %arg1[%c0, %c0] {in_bounds = [true, true]} : vector<4x8xf32>, memref<4x8xf32, strided<[16, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }
  func.func @first_lane(%arg0: vector<2x32xf32>, %arg1: memref<2x32xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %0 = vector.constant_mask [1] : vector<64xi1>
    %1 = vector.shape_cast %0 : vector<64xi1> to vector<2x32xi1>
    vector.transfer_write %arg0, %arg1[%c0, %c0], %1 {in_bounds = [true, true]} : vector<2x32xf32>, memref<2x32xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }
  func.func @first_row_prefix(%arg0: vector<2x32xf32>, %arg1: memref<2x32xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>) {
    %c0 = arith.constant 0 : index
    %0 = ave.hir.pge <VL8> : vector<64xi1>
    %1 = vector.shape_cast %0 : vector<64xi1> to vector<2x32xi1>
    vector.transfer_write %arg0, %arg1[%c0, %c0], %1 {in_bounds = [true, true]} : vector<2x32xf32>, memref<2x32xf32, strided<[64, 1], offset: ?>, #hivm.address_space<ub>>
    return
  }
}


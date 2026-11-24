module {
  func.func @pb16(%arg0: memref<32xi1, strided<[1], offset: 32>, #hivm.address_space<ub>>, %arg1: memref<256xi1, #hivm.address_space<ub>>, %arg2: vector<128xi1>) {
    %c0 = arith.constant 0 : index
    %c32 = arith.constant 32 : index
    %res, %new_true_shape = ave.hir.plt %c32 {functionType = #ave.func_dist_type<pb16>} : vector<128xi1>, index
    %0 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb16>} : vector<128xi1>
    ave.hir.masked_store <NORM_B8> %arg0[%c0], %res, %arg2 {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<pb16>} : memref<32xi1, strided<[1], offset: 32>, #hivm.address_space<ub>>, vector<128xi1>, vector<128xi1>
    ave.hir.masked_store <NORM_B8> %arg1[%c0], %0, %arg2 {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<pb16>} : memref<256xi1, #hivm.address_space<ub>>, vector<128xi1>, vector<128xi1>
    return
  }
  func.func @pb32(%arg0: memref<16xi1, strided<[1], offset: 16>, #hivm.address_space<ub>>, %arg1: memref<256xi1, #hivm.address_space<ub>>, %arg2: vector<64xi1>) {
    %c0 = arith.constant 0 : index
    %0 = ave.hir.pge <VL16> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    %1 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
    ave.hir.masked_store <NORM_B8> %arg0[%c0], %0, %arg2 {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<pb32>} : memref<16xi1, strided<[1], offset: 16>, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi1>
    ave.hir.masked_store <NORM_B8> %arg1[%c0], %1, %arg2 {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<pb32>} : memref<256xi1, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi1>
    return
  }
}


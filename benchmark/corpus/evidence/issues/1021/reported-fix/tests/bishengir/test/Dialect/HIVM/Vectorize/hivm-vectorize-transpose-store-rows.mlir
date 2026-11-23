// RUN: bishengir-opt %s --split-input-file --hacc-append-device-spec=target=Ascend960DT_968B7 --hivm-vectorize=phase=buffers --verify-each | FileCheck %s
// RUN: bishengir-opt %s --split-input-file --hacc-append-device-spec=target=Ascend950PR_9579 --hivm-vectorize=phase=buffers --verify-each | FileCheck %s

module {
  // CHECK-LABEL: func.func private @transpose2d_fused_0(
  // CHECK: vector.transfer_write {{.*}} : vector<1x64xf32>, memref<1x64xf32
  func.func @transpose2d(%src: memref<64x16xf32, #hivm.address_space<ub>>, %dst: memref<16x64xf32, #hivm.address_space<ub>>) {
    hivm.hir.vtranspose ins(%src : memref<64x16xf32, #hivm.address_space<ub>>)
        outs(%dst : memref<16x64xf32, #hivm.address_space<ub>>) permutation = [1, 0]
    return
  }

}

// -----

module {
  // CHECK-LABEL: func.func private @transpose3d_fused_0(
  // CHECK: vector.transfer_write {{.*}} : vector<1x1x16xf16>, memref<1x1x16xf16
  func.func @transpose3d(%src: memref<64x4x16xf16, #hivm.address_space<ub>>, %dst: memref<4x64x16xf16, #hivm.address_space<ub>>) {
    hivm.hir.vtranspose ins(%src : memref<64x4x16xf16, #hivm.address_space<ub>>)
        outs(%dst : memref<4x64x16xf16, #hivm.address_space<ub>>) permutation = [1, 0, 2]
    return
  }
}

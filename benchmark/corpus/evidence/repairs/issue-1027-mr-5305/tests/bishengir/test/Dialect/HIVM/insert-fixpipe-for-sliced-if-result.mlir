// RUN: bishengir-opt -hivm-insert-fixpipe %s | FileCheck %s
// RUN: bishengir-opt -hivm-insert-fixpipe -hivm-insert-fixpipe %s | FileCheck %s

module attributes {hacc.target = #hacc.target<"Ascend910B4">} {
  // The converting fixpipe reads L0C through its slice. The other slice
  // needs a transfer before the store can read it.
  // CHECK-LABEL: func.func @sliced_if_result
  // CHECK: %[[ACC:.*]] = scf.if
  // CHECK: %[[COPY:.*]] = hivm.hir.fixpipe {{.*}}ins(%[[ACC]] :
  // CHECK: %[[RAW_TILE:.*]] = tensor.extract_slice %[[ACC]][
  // CHECK: hivm.hir.fixpipe {{.*}}F322BF16{{.*}}ins(%[[RAW_TILE]] :
  // CHECK: %[[COPIED_TILE:.*]] = tensor.extract_slice %[[COPY]][
  // CHECK: hivm.hir.store ins(%[[COPIED_TILE]] :
  func.func @sliced_if_result(%cond: i1, %lhs: tensor<64x64xf32>,
      %rhs: tensor<64x64xf32>, %offset: index, %size: index,
      %bf16_out: memref<?x64xbf16>, %f32_out: memref<?x64xf32>) {
    %acc = scf.if %cond -> tensor<64x64xf32> {
      scf.yield %lhs : tensor<64x64xf32>
    } else {
      scf.yield %rhs : tensor<64x64xf32>
    } {hivm.remain_in_l0c = [0 : i32]}
    %raw_tile = tensor.extract_slice %acc[%offset, 0] [%size, 64] [1, 1]
        : tensor<64x64xf32> to tensor<?x64xf32>
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>, pre_quant = #hivm.fixpipe_pre_quant_mode<F322BF16>}
        ins(%raw_tile : tensor<?x64xf32>) outs(%bf16_out : memref<?x64xbf16>)
    %tile = tensor.extract_slice %acc[0, 0] [%size, 64] [1, 1]
        : tensor<64x64xf32> to tensor<?x64xf32>
    hivm.hir.store ins(%tile : tensor<?x64xf32>) outs(%f32_out : memref<?x64xf32>)
    return
  }
}

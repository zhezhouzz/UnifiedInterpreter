// RUN: bishengir-opt %s --hivm-propagate-convert-layout="allow-agnostic-ops=false" --canonicalize --split-input-file | FileCheck %s --check-prefix=PROP
// RUN: bishengir-opt %s --hivm-propagate-convert-layout="allow-agnostic-ops=false" --canonicalize --hivm-combine-optimized-convert-layout --split-input-file | FileCheck %s --check-prefix=COMBINE

// A shared GM input feeds a rank-2 dot and a rank-3 Vector broadcast.
// PROP-LABEL: func.func @dot_broadcast(
// PROP-SAME: %[[GM:[^:]+]]: memref<1x1x1xf16>
// PROP: %[[BUF:.*]] = memref.alloc() : memref<1x1xf16>
// PROP: %[[MATRIX:.*]] = memref.collapse_shape %[[GM]] {{.*}} into memref<1x1xf16>
// PROP: hivm.hir.load ins(%[[MATRIX]] : memref<1x1xf16>) outs(%[[BUF]] : memref<1x1xf16>) core_type = <CUBE>
// PROP: hivm.hir.load ins(%[[GM]] : memref<1x1x1xf16>) {{.*}}core_type = <VECTOR>
// PROP: %[[TENSOR:.*]] = bufferization.to_tensor %[[BUF]] restrict writable
// PROP: hivm.hir.convert_layout %[[TENSOR]]
// COMBINE-LABEL: func.func @dot_broadcast(
// COMBINE-SAME: %[[LEFT:[^:]+]]: memref<1x1x1xf16>, %[[RIGHT:[^:]+]]: memref<1x1xf16>
// COMBINE: %[[MATRIX:.*]] = memref.collapse_shape %[[LEFT]] {{.*}} into memref<1x1xf16>
// COMBINE: hivm.hir.nd2nz {{.*}}ins(%[[MATRIX]] : memref<1x1xf16>) outs(%[[A:[^ ]+]] : memref<1x1x16x16xf16>)
// COMBINE: %[[LHS:.*]] = bufferization.to_tensor %[[A]] restrict writable
// COMBINE: hivm.hir.load ins(%[[LEFT]] : memref<1x1x1xf16>) outs(%[[V:[^ ]+]] : memref<1x1x1xf16>) core_type = <VECTOR>
// COMBINE: %[[VECTOR:.*]] = bufferization.to_tensor %[[V]] restrict writable
// COMBINE: hivm.hir.nd2nz {{.*}}ins(%[[RIGHT]] : memref<1x1xf16>) outs(%[[B:[^ ]+]] : memref<1x1x16x16xf16>)
// COMBINE: %[[RHS:.*]] = bufferization.to_tensor %[[B]] restrict writable
// COMBINE: hivm.hir.mmadL1 ins(%[[LHS]], %[[RHS]],
// COMBINE: hivm.hir.vbrc ins(%[[VECTOR]]
module attributes {hacc.target = #hacc.target<"Ascend910B4">} {
  func.func @dot_broadcast(%left: memref<1x1x1xf16>, %gm: memref<1x1xf16>)
      -> (tensor<1x1x16x16xf32>, tensor<231x1x1xf16>) {
    %true = arith.constant true
    %one = arith.constant 1 : index
    %cubeBuf = memref.alloc() : memref<1x1x1xf16>
    %vectorBuf = memref.alloc() : memref<1x1x1xf16>
    hivm.hir.load ins(%left : memref<1x1x1xf16>) outs(%cubeBuf : memref<1x1x1xf16>) core_type = <CUBE>
    hivm.hir.load ins(%left : memref<1x1x1xf16>) outs(%vectorBuf : memref<1x1x1xf16>) core_type = <VECTOR>
    %cube = bufferization.to_tensor %cubeBuf restrict writable : memref<1x1x1xf16>
    %vector = bufferization.to_tensor %vectorBuf restrict writable : memref<1x1x1xf16>
    %lhs = tensor.collapse_shape %cube [[0, 1], [2]] : tensor<1x1x1xf16> into tensor<1x1xf16>
    %a = hivm.hir.convert_layout %lhs output_shape [1, 1, 16, 16]
        {srcLayout = #hivm.data_layout<ND>, dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>}
        : (tensor<1x1xf16>) -> tensor<1x1x16x16xf16>
    %buf = memref.alloc() : memref<1x1xf16>
    hivm.hir.load ins(%gm : memref<1x1xf16>) outs(%buf : memref<1x1xf16>) core_type = <CUBE>
    %rhs = bufferization.to_tensor %buf restrict writable : memref<1x1xf16>
    %b = hivm.hir.convert_layout %rhs output_shape [1, 1, 16, 16]
        {srcLayout = #hivm.data_layout<ND>, dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>}
        : (tensor<1x1xf16>) -> tensor<1x1x16x16xf16>
    %acc = tensor.empty() : tensor<1x1x16x16xf32>
    %dot = hivm.hir.mmadL1 ins(%a, %b, %true, %one, %one, %one : tensor<1x1x16x16xf16>, tensor<1x1x16x16xf16>, i1, index, index, index)
        outs(%acc : tensor<1x1x16x16xf32>) -> tensor<1x1x16x16xf32>
    %out = tensor.empty() : tensor<231x1x1xf16>
    %brc = hivm.hir.vbrc ins(%vector : tensor<1x1x1xf16>) outs(%out : tensor<231x1x1xf16>) broadcast_dims = [0] -> tensor<231x1x1xf16>
    return %dot, %brc : tensor<1x1x16x16xf32>, tensor<231x1x1xf16>
  }
}

// -----

// Both views read the value of GM before the intervening store.
// PROP-LABEL: func.func @shared_load_collapse(
// PROP-SAME: %[[GM:[^:]+]]: memref<2x3x16xf16, strided<[96, 32, 1], offset: ?>>
// PROP: hivm.hir.load ins(%[[GM]] :
// PROP: %[[MATRIX:.*]] = memref.collapse_shape %[[GM]] {{.*}} into memref<6x16xf16, strided<[32, 1], offset: ?>>
// PROP: hivm.hir.load ins(%[[MATRIX]] :
// PROP: memref.store {{.*}}, %[[GM]]
// PROP: hivm.hir.convert_layout
// COMBINE-LABEL: func.func @shared_load_collapse(
// COMBINE-SAME: %[[GM:[^:]+]]: memref<2x3x16xf16, strided<[96, 32, 1], offset: ?>>
// COMBINE: hivm.hir.load ins(%[[GM]] : {{.*}}) outs(%[[ND:[^ ]+]] :
// COMBINE: %[[MATRIX:.*]] = memref.collapse_shape %[[GM]] {{.*}} into memref<6x16xf16, strided<[32, 1], offset: ?>>
// COMBINE: hivm.hir.nd2nz {{.*}}ins(%[[MATRIX]] : {{.*}}) outs(%[[L1:[^ ]+]] :
// COMBINE: %[[PACKED:.*]] = bufferization.to_tensor %[[L1]] restrict writable
// COMBINE: %[[ORIGINAL:.*]] = bufferization.to_tensor %[[ND]] restrict writable
// COMBINE: memref.store {{.*}}, %[[GM]]
// COMBINE: return %[[PACKED]], %[[ORIGINAL]]
func.func @shared_load_collapse(%gm: memref<2x3x16xf16, strided<[96, 32, 1], offset: ?>>)
    -> (tensor<1x1x16x16xf16>, tensor<2x3x16xf16>) {
  %c0 = arith.constant 0 : index
  %zero = arith.constant 0.0 : f16
  %buf = memref.alloc() : memref<2x3x16xf16>
  hivm.hir.load ins(%gm : memref<2x3x16xf16, strided<[96, 32, 1], offset: ?>>) outs(%buf : memref<2x3x16xf16>)
  %tensor = bufferization.to_tensor %buf restrict writable : memref<2x3x16xf16>
  memref.store %zero, %gm[%c0, %c0, %c0] : memref<2x3x16xf16, strided<[96, 32, 1], offset: ?>>
  %matrix = tensor.collapse_shape %tensor [[0, 1], [2]] : tensor<2x3x16xf16> into tensor<6x16xf16>
  %packed = hivm.hir.convert_layout %matrix output_shape [1, 1, 16, 16]
      {srcLayout = #hivm.data_layout<ND>, dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>}
      : (tensor<6x16xf16>) -> tensor<1x1x16x16xf16>
  return %packed, %tensor : tensor<1x1x16x16xf16>, tensor<2x3x16xf16>
}

// -----

// Rows 2 and 3 are separated by a gap in GM. Only the local tensor is dense.
// PROP-LABEL: func.func @noncontiguous_load_collapse(
// PROP: hivm.hir.load
// PROP: %[[ND:.*]] = tensor.collapse_shape
// PROP: hivm.hir.convert_layout %[[ND]]
// COMBINE-LABEL: func.func @noncontiguous_load_collapse(
// COMBINE: hivm.hir.load
// COMBINE: %[[ND:.*]] = tensor.collapse_shape
// COMBINE: hivm.hir.convert_layout %[[ND]]
func.func @noncontiguous_load_collapse(%src: memref<2x3x16xf16, strided<[64, 16, 1]>>)
    -> tensor<1x1x16x16xf16> {
  %buf = memref.alloc() : memref<2x3x16xf16>
  hivm.hir.load ins(%src : memref<2x3x16xf16, strided<[64, 16, 1]>>) outs(%buf : memref<2x3x16xf16>)
  %tensor = bufferization.to_tensor %buf restrict writable : memref<2x3x16xf16>
  %matrix = tensor.collapse_shape %tensor [[0, 1], [2]] : tensor<2x3x16xf16> into tensor<6x16xf16>
  %packed = hivm.hir.convert_layout %matrix output_shape [1, 1, 16, 16]
      {srcLayout = #hivm.data_layout<ND>, dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>}
      : (tensor<6x16xf16>) -> tensor<1x1x16x16xf16>
  return %packed : tensor<1x1x16x16xf16>
}

// -----

// PROP-LABEL: func.func @expand_loaded_vector(
// PROP-SAME: %[[GM:[^:]+]]: memref<1024xf32>
// PROP: %[[BUF:.*]] = memref.alloc() : memref<32x32xf32>
// PROP: %[[MATRIX:.*]] = memref.expand_shape %[[GM]] {{.*}} into memref<32x32xf32>
// PROP: hivm.hir.load ins(%[[MATRIX]] : memref<32x32xf32>) outs(%[[BUF]] :
// PROP: %[[TENSOR:.*]] = bufferization.to_tensor %[[BUF]] restrict writable
// PROP: hivm.hir.convert_layout %[[TENSOR]]
// COMBINE-LABEL: func.func @expand_loaded_vector(
// COMBINE: %[[MATRIX:.*]] = memref.expand_shape
// COMBINE: hivm.hir.nd2nz {{.*}}ins(%[[MATRIX]] : memref<32x32xf32>)
// COMBINE-NOT: hivm.hir.convert_layout
// COMBINE: return
func.func @expand_loaded_vector(%gm: memref<1024xf32>) -> tensor<4x2x16x8xf32> {
  %buf = memref.alloc() : memref<1024xf32>
  hivm.hir.load ins(%gm : memref<1024xf32>) outs(%buf : memref<1024xf32>)
  %tensor = bufferization.to_tensor %buf restrict writable : memref<1024xf32>
  %matrix = tensor.expand_shape %tensor [[0, 1]] output_shape [32, 32] : tensor<1024xf32> into tensor<32x32xf32>
  %packed = hivm.hir.convert_layout %matrix output_shape [4, 2, 16, 8]
      {dstLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 8]>, srcLayout = #hivm.data_layout<ND>}
      : (tensor<32x32xf32>) -> tensor<4x2x16x8xf32>
  return %packed : tensor<4x2x16x8xf32>
}

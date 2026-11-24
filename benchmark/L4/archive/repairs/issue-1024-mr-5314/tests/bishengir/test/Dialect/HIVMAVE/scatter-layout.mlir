// RUN: bishengir-opt %s -hacc-append-device-spec=target=Ascend950PR_9579 -analyze-vector-layout -remove-vector-layout-attr -ave-normalize-ops -canonicalize -convert-hivmave-to-ave-intrin -canonicalize | FileCheck %s

// A scatter is a result-less vector sink. It must constrain the data,
// element-index vector and predicate to B32 instead of falling through the
// generic result-based solver. Keep this test in the layout pipeline rather
// than testing only the final scatter-to-intrinsic conversion.
// CHECK-LABEL: func.func @scatter_layout_i32
// CHECK: "hivm_regbaseintrins.intr.hivm.pge.b32"
// CHECK: "hivm_regbaseintrins.intr.hivm.vscatter_v64s32_v300"
// CHECK-NOT: ave.hir.vscatter
func.func @scatter_layout_i32(%base: memref<128xi32, #hivm.address_space<ub>>, %index: vector<64xi32>, %val: vector<64xi32>) {
  %c0 = arith.constant 0 : index
  %mask = ave.hir.pge <ALL> : vector<64xi1>
  ave.hir.vscatter %base[%c0][%index], %mask, %val : memref<128xi32, #hivm.address_space<ub>>, vector<64xi32>, vector<64xi1>, vector<64xi32>
  return
}

// CHECK-LABEL: func.func @scatter_layout_f32
// CHECK: "hivm_regbaseintrins.intr.hivm.pge.b32"
// CHECK: llvm.bitcast
// CHECK: "hivm_regbaseintrins.intr.hivm.vscatter_v64s32_v300"
// CHECK-NOT: ave.hir.vscatter
func.func @scatter_layout_f32(%base: memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>, %index: vector<64xi32>, %val: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  %mask = ave.hir.pge <VL4> : vector<64xi1>
  ave.hir.vscatter %base[%c0][%index], %mask, %val : memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>, vector<64xi32>, vector<64xi1>, vector<64xf32>
  return
}

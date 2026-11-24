// RUN: bishengir-opt %s -convert-vector-to-hivmave | FileCheck %s
// RUN: bishengir-opt %s -hacc-append-device-spec=target=Ascend950PR_9579 -convert-vector-to-hivmave -convert-arith-to-hivmave -analyze-vector-layout -remove-vector-layout-attr -ave-normalize-ops -canonicalize -convert-hivmave-to-ave-intrin -canonicalize | FileCheck %s --check-prefix=INTRIN

// The scatter indices are element offsets lane*stride for all 64 lanes; the
// mask (VL4) still gates which lanes write, and the -inf data is preserved.
// CHECK-LABEL: @column_mask4
// CHECK-DAG: %[[DATA:.*]] = arith.constant dense<0xFF800000> : vector<64xf32>
// CHECK-DAG: %[[MASK:.*]] = ave.hir.pge <VL4>
// CHECK-DAG: %[[IDX:.*]] = arith.constant dense<[0, 8192, 16384, 24576,
// CHECK-SAME: 507904, 516096]> : vector<64xi32>
// CHECK: ave.hir.vscatter %arg0[%{{.*}}] [%[[IDX]]], %[[MASK]], %[[DATA]]
// CHECK-NOT: ave.hir.masked_store
// INTRIN-LABEL: @column_mask4
// INTRIN: "hivm_regbaseintrins.intr.hivm.vscatter_v64s32_v300"
func.func @column_mask4(%dst: memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>) {
  %c0 = arith.constant 0 : index
  %value = arith.constant dense<0xFF800000> : vector<64xf32>
  %m = vector.constant_mask [4] : vector<64xi1>
  vector.transfer_write %value, %dst[%c0], %m {in_bounds = [true]} : vector<64xf32>, memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
  return
}

// Dynamic/sparse/empty masks are not replaced with an unmasked write.
// CHECK-LABEL: @arbitrary_mask
// CHECK-SAME: %[[MASK:[a-zA-Z0-9_]+]]: vector<64xi1>
// CHECK: ave.hir.vscatter {{.*}}, %[[MASK]],
// CHECK-NOT: ave.hir.masked_store
// INTRIN-LABEL: @arbitrary_mask
// INTRIN: "hivm_regbaseintrins.intr.hivm.vscatter_v64s32_v300"
func.func @arbitrary_mask(%dst: memref<?xf32, strided<[2], offset: 7>, #hivm.address_space<ub>>, %start: index, %value: vector<64xf32>, %mask: vector<64xi1>) {
  vector.transfer_write %value, %dst[%start], %mask {in_bounds = [true]} : vector<64xf32>, memref<?xf32, strided<[2], offset: 7>, #hivm.address_space<ub>>
  return
}

// A one-element shape is not a proof of a single active lane. The runtime
// contract restricts %active to 0 or 1: inactive tail lanes are masked off, so
// in_bounds is truthful. The compiler cannot establish VL1 from the argument.
// CHECK-LABEL: @shape_one_runtime_mask
// CHECK: ave.hir.vscatter
// CHECK-NOT: ave.hir.masked_store
// INTRIN-LABEL: @shape_one_runtime_mask
// INTRIN: "hivm_regbaseintrins.intr.hivm.vscatter_v64s32_v300"
func.func @shape_one_runtime_mask(%dst: memref<1xf32, strided<[2], offset: ?>, #hivm.address_space<ub>>, %value: vector<64xf32>, %active: index) {
  %c0 = arith.constant 0 : index
  %mask = vector.create_mask %active : vector<64xi1>
  vector.transfer_write %value, %dst[%c0], %mask {in_bounds = [true]} : vector<64xf32>, memref<1xf32, strided<[2], offset: ?>, #hivm.address_space<ub>>
  return
}

// A dynamic stride is left to the existing unaligned lowering: it must not be
// intercepted as a scatter nor hard-failed. This is the shape bufferization
// produces for small runtime-strided buffers (e.g. the i64->i32 library cast),
// which the pipeline already lowers correctly.
// CHECK-LABEL: @dynamic_stride
// CHECK-NOT: ave.hir.vscatter
// CHECK: ave.hir.masked_store
func.func @dynamic_stride(%dst: memref<64xf32, strided<[?], offset: ?>, #hivm.address_space<ub>>, %value: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  vector.transfer_write %value, %dst[%c0] {in_bounds = [true]} : vector<64xf32>, memref<64xf32, strided<[?], offset: ?>, #hivm.address_space<ub>>
  return
}

// CHECK-LABEL: @unit_stride
// CHECK: ave.hir.masked_store <NORM_B32>
// CHECK-NOT: ave.hir.vscatter
func.func @unit_stride(%dst: memref<64xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>, %value: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  vector.transfer_write %value, %dst[%c0] {in_bounds = [true]} : vector<64xf32>, memref<64xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
  return
}

// A lane-zero-only write is independent of the spacing between other lanes.
// CHECK-LABEL: @one_lane
// CHECK: ave.hir.masked_store <ONEPT_B32>
// CHECK-NOT: ave.hir.vscatter
func.func @one_lane(%dst: memref<1xf32, strided<[?], offset: ?>, #hivm.address_space<ub>>, %value: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  %m = vector.constant_mask [1] : vector<64xi1>
  vector.transfer_write %value, %dst[%c0], %m {in_bounds = [true]} : vector<64xf32>, memref<1xf32, strided<[?], offset: ?>, #hivm.address_space<ub>>
  return
}

// A static non-unit stride with a create_mask of constant length 1 writes only
// lane zero, so it stays a masked contiguous store instead of being promoted
// to a scatter (the create_mask length-1 is recognized by writesOnlyFirstLane).
// CHECK-LABEL: @static_stride_one_lane_create_mask
// CHECK: ave.hir.masked_store <NORM_B32>
// CHECK-NOT: ave.hir.vscatter
func.func @static_stride_one_lane_create_mask(%dst: memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>, %value: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %m = vector.create_mask %c1 : vector<64xi1>
  vector.transfer_write %value, %dst[%c0], %m {in_bounds = [true]} : vector<64xf32>, memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
  return
}

// A static strided store with no mask lowers to a scatter across all 64 lanes,
// with an all-ones predicate supplied for the absent mask.
// CHECK-LABEL: @no_mask_scatter
// CHECK: %[[MASK:.*]] = ave.hir.pge <ALL>
// CHECK: %[[IDX:.*]] = arith.constant dense<[0, 8192, 16384, 24576,
// CHECK-SAME: 507904, 516096]> : vector<64xi32>
// CHECK: ave.hir.vscatter %arg0[%{{.*}}] [%[[IDX]]], %[[MASK]], %arg1
// CHECK-NOT: ave.hir.masked_store
func.func @no_mask_scatter(%dst: memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>, %value: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  vector.transfer_write %value, %dst[%c0] {in_bounds = [true]} : vector<64xf32>, memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
  return
}

// An i32 column store (same shape as the f32 case) also lowers to a scatter:
// the data register is already i32, so the intrinsic needs no bitcast on the
// value operand. This exercises the i32 widening of the dtype gate.
// CHECK-LABEL: @i32_column_scatter
// CHECK: %[[MASK:.*]] = ave.hir.pge <VL4>
// CHECK: %[[IDX:.*]] = arith.constant dense<[0, 8192, 16384, 24576,
// CHECK-SAME: 507904, 516096]> : vector<64xi32>
// CHECK: ave.hir.vscatter %arg0[%{{.*}}] [%[[IDX]]], %[[MASK]], %arg1
// CHECK-NOT: ave.hir.masked_store
// INTRIN-LABEL: @i32_column_scatter
// INTRIN: "hivm_regbaseintrins.intr.hivm.vscatter_v64s32_v300"
func.func @i32_column_scatter(%dst: memref<4xi32, strided<[8192], offset: ?>, #hivm.address_space<ub>>, %value: vector<64xi32>) {
  %c0 = arith.constant 0 : index
  %m = vector.constant_mask [4] : vector<64xi1>
  vector.transfer_write %value, %dst[%c0], %m {in_bounds = [true]} : vector<64xi32>, memref<4xi32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
  return
}

// A shape-only UCC chain must preserve the lane-zero proof. In particular,
// f16 cannot use the scatter fallback, so losing the proof rejects this store.
// CHECK-LABEL: @ucc_lane_zero
// CHECK: ave.hir.masked_store <ONEPT_B16>
// CHECK-NOT: ave.hir.vscatter
func.func @ucc_lane_zero(%dst: memref<128xf16, strided<[2]>, #hivm.address_space<ub>>, %value: vector<128xf16>) {
  %c0 = arith.constant 0 : index
  %m = vector.constant_mask [1] : vector<128xi1>
  %u = builtin.unrealized_conversion_cast %m : vector<128xi1> to vector<1x128xi1>
  %v = builtin.unrealized_conversion_cast %u : vector<1x128xi1> to vector<128xi1>
  vector.transfer_write %value, %dst[%c0], %v {in_bounds = [true]} : vector<128xf16>, memref<128xf16, strided<[2]>, #hivm.address_space<ub>>
  return
}

// Rank one is not a lane-zero proof: all four active lanes still scatter.
// CHECK-LABEL: @ucc_multiple_lanes
// CHECK: ave.hir.vscatter
// CHECK-NOT: ave.hir.masked_store
func.func @ucc_multiple_lanes(%dst: memref<64xf32, strided<[2]>, #hivm.address_space<ub>>, %value: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  %m = vector.constant_mask [4] : vector<64xi1>
  %u = builtin.unrealized_conversion_cast %m : vector<64xi1> to vector<1x64xi1>
  %v = builtin.unrealized_conversion_cast %u : vector<1x64xi1> to vector<64xi1>
  vector.transfer_write %value, %dst[%c0], %v {in_bounds = [true]} : vector<64xf32>, memref<64xf32, strided<[2]>, #hivm.address_space<ub>>
  return
}

// RUN: bishengir-opt %s -split-input-file -convert-vector-to-hivmave -verify-diagnostics
// Only a statically non-contiguous (stride > 1) UB store is intercepted. These
// are the cases that provably cannot become a correct contiguous masked store
// and for which scatter is not applicable; each must be diagnosed up front
// rather than silently flattened. Dynamic strides are intentionally NOT here:
// they fall through to the existing unaligned lowering (see the positive test).
func.func @index_overflow(%dst: memref<64xf32, strided<[34087043], offset: ?>, #hivm.address_space<ub>>, %value: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  // expected-error @+1 {{rank-1 strided transfer_write scatter indices exceed signed i32 range}}
  vector.transfer_write %value, %dst[%c0] {in_bounds = [true]} : vector<64xf32>, memref<64xf32, strided<[34087043], offset: ?>, #hivm.address_space<ub>>
  return
}
// -----
func.func @out_of_bounds(%dst: memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>, %value: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  // expected-error @+1 {{rank-1 strided transfer_write requires rank-1 identity in-bounds access}}
  vector.transfer_write %value, %dst[%c0] : vector<64xf32>, memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
  return
}
// -----
func.func @unsupported_type(%dst: memref<128xf16, strided<[2], offset: ?>, #hivm.address_space<ub>>, %value: vector<128xf16>) {
  %c0 = arith.constant 0 : index
  // expected-error @+1 {{rank-1 strided transfer_write requires UB vector<64x{f32,i32}> scatter}}
  vector.transfer_write %value, %dst[%c0] {in_bounds = [true]} : vector<128xf16>, memref<128xf16, strided<[2], offset: ?>, #hivm.address_space<ub>>
  return
}
// -----
// A shape-one source alone does not imply that the compiler can prove VL1.
// Callers supply a mask with no active lanes beyond lane zero.
func.func @shape_one_not_single_lane(%dst: memref<1xf16, strided<[2], offset: ?>, #hivm.address_space<ub>>, %value: vector<128xf16>, %mask: vector<128xi1>) {
  %c0 = arith.constant 0 : index
  // expected-error @+1 {{rank-1 strided transfer_write requires UB vector<64x{f32,i32}> scatter}}
  vector.transfer_write %value, %dst[%c0], %mask {in_bounds = [true]} : vector<128xf16>, memref<1xf16, strided<[2], offset: ?>, #hivm.address_space<ub>>
  return
}
// -----
func.func @wrong_space(%dst: memref<64xf32, strided<[2], offset: ?>, #hivm.address_space<gm>>, %value: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  // expected-error @+1 {{rank-1 strided transfer_write requires UB vector<64x{f32,i32}> scatter}}
  vector.transfer_write %value, %dst[%c0] {in_bounds = [true]} : vector<64xf32>, memref<64xf32, strided<[2], offset: ?>, #hivm.address_space<gm>>
  return
}
// -----
// Even a minimum scalable length of 64 is not the fixed hardware vector64.
func.func @scalable_vector(%dst: memref<?xf32, strided<[2], offset: ?>, #hivm.address_space<ub>>, %value: vector<[64]xf32>) {
  %c0 = arith.constant 0 : index
  // expected-error @+1 {{rank-1 strided transfer_write requires UB vector<64x{f32,i32}> scatter}}
  vector.transfer_write %value, %dst[%c0] {in_bounds = [true]} : vector<[64]xf32>, memref<?xf32, strided<[2], offset: ?>, #hivm.address_space<ub>>
  return
}
// -----
// A negative static stride is non-contiguous but cannot be expressed as an
// in-range forward scatter, so it is rejected up front rather than silently
// flattened into a contiguous store.
func.func @negative_stride(%dst: memref<64xf32, strided<[-2], offset: ?>, #hivm.address_space<ub>>, %value: vector<64xf32>) {
  %c0 = arith.constant 0 : index
  // expected-error @+1 {{rank-1 strided transfer_write with negative stride is not supported}}
  vector.transfer_write %value, %dst[%c0] {in_bounds = [true]} : vector<64xf32>, memref<64xf32, strided<[-2], offset: ?>, #hivm.address_space<ub>>
  return
}

// -----
// A single-input UCC that changes the lane count is not a shape-only cast.
func.func @ucc_changes_lane_count(%dst: memref<128xf16, strided<[2]>, #hivm.address_space<ub>>, %value: vector<128xf16>) {
  %c0 = arith.constant 0 : index
  %m = vector.constant_mask [1] : vector<64xi1>
  %u = builtin.unrealized_conversion_cast %m : vector<64xi1> to vector<128xi1>
  // expected-error @+1 {{rank-1 strided transfer_write requires UB vector<64x{f32,i32}> scatter}}
  vector.transfer_write %value, %dst[%c0], %u {in_bounds = [true]} : vector<128xf16>, memref<128xf16, strided<[2]>, #hivm.address_space<ub>>
  return
}

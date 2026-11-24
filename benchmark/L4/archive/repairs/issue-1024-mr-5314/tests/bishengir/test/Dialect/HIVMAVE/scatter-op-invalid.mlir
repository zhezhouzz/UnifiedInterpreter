// RUN: bishengir-opt %s -split-input-file -verify-diagnostics

// A scatter must carry one scalar base index per buffer dimension. The
// lowering re-checks this, but the verifier makes it an IR-level invariant so
// a future pattern cannot build a malformed scatter and have it survive until
// conversion.
func.func @scatter_missing_base_index(%base: memref<128xi32, #hivm.address_space<ub>>, %index: vector<64xi32>, %mask: vector<64xi1>, %val: vector<64xi32>) {
  // expected-error @+1 {{requires one scalar index per buffer dimension}}
  ave.hir.vscatter %base[][%index], %mask, %val : memref<128xi32, #hivm.address_space<ub>>, vector<64xi32>, vector<64xi1>, vector<64xi32>
  return
}

// -----

// index_vec and the scattered value must agree in lane count: one element is
// scattered per index lane. A 32-lane value against 64 index lanes is
// malformed regardless of element width, and the verifier rejects it without
// pinning the op to a hardware-specific 64xi32 shape.
func.func @scatter_lane_count_mismatch(%base: memref<128xi32, #hivm.address_space<ub>>, %c0: index, %index: vector<64xi32>, %mask: vector<64xi1>, %val: vector<32xi32>) {
  // expected-error @+1 {{requires index_vec and value to have the same number of lanes}}
  ave.hir.vscatter %base[%c0][%index], %mask, %val : memref<128xi32, #hivm.address_space<ub>>, vector<64xi32>, vector<64xi1>, vector<32xi32>
  return
}

// -----

// A well-formed scatter parses and verifies: rank-1 base with one scalar
// index, matching index_vec and value lane counts.
func.func @scatter_valid(%base: memref<128xi32, #hivm.address_space<ub>>, %c0: index, %index: vector<64xi32>, %mask: vector<64xi1>, %val: vector<64xi32>) {
  ave.hir.vscatter %base[%c0][%index], %mask, %val : memref<128xi32, #hivm.address_space<ub>>, vector<64xi32>, vector<64xi1>, vector<64xi32>
  return
}

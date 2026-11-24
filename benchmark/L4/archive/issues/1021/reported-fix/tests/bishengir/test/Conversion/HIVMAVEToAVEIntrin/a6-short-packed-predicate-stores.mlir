// RUN: bishengir-opt -hacc-append-device-spec=target=Ascend960DT_968B7 -convert-hivmave-to-ave-intrin -cse %s | FileCheck %s
// RUN: bishengir-opt -hacc-append-device-spec=target=Ascend910_9589 -convert-hivmave-to-ave-intrin -cse %s | FileCheck %s --check-prefix=A5 --implicit-check-not=hivm.vstus

#pb16 = #ave.func_dist_type<pb16>
#pb32 = #ave.func_dist_type<pb32>
#unaligned = #ave.unaligned_ub_access
!row16 = memref<16xi1, strided<[1], offset: 16>, #hivm.address_space<ub>>
!row32 = memref<32xi1, strided<[1], offset: 32>, #hivm.address_space<ub>>
!full = memref<256xi1, #hivm.address_space<ub>>

// A 32-bit PB16 row starts at byte four. The flush must consume the alignment
// state and the updated pointer from the four-byte store.
// CHECK-LABEL: @pb16
// CHECK: %[[FOUR:.*]] = llvm.mlir.constant(4 : i32)
// CHECK: %[[WRITE:.*]] = "hivm_regbaseintrins.intr.hivm.vstus.post.s32"({{.*}}, %[[FOUR]], %{{[^)]+}})
// CHECK-DAG: %[[TAIL:.*]] = llvm.extractvalue %[[WRITE]][0]
// CHECK-DAG: %[[NEXT:.*]] = llvm.extractvalue %[[WRITE]][1]
// CHECK: "hivm_regbaseintrins.intr.hivm.vstas"(%[[TAIL]], %[[NEXT]],
// CHECK: "hivm_regbaseintrins.intr.hivm.pstu.b16"
// A5-LABEL: @pb16
// A5-COUNT-2: "hivm_regbaseintrins.intr.hivm.pstu.b16"
func.func @pb16(%row: !row32, %full: !full, %data: vector<128xi1>) {
  %c0 = arith.constant 0 : index
  %c32 = arith.constant 32 : index
  %short, %rem = ave.hir.plt %c32 {functionType = #pb16} : vector<128xi1>, index
  %all = ave.hir.pge <ALL> {functionType = #pb16} : vector<128xi1>
  ave.hir.masked_store <NORM_B8> %row[%c0], %short, %data {ave.unaligned_ub_access = #unaligned, functionType = #pb16} : !row32, vector<128xi1>, vector<128xi1>
  ave.hir.masked_store <NORM_B8> %full[%c0], %all, %data {ave.unaligned_ub_access = #unaligned, functionType = #pb16} : !full, vector<128xi1>, vector<128xi1>
  return
}

// A 16-bit PB32 row at byte two must leave the following row untouched.
// CHECK-LABEL: @pb32
// CHECK: %[[TWO:.*]] = llvm.mlir.constant(2 : i32)
// CHECK: "hivm_regbaseintrins.intr.hivm.vstus.post.s32"({{.*}}, %[[TWO]], %{{[^)]+}})
// CHECK: "hivm_regbaseintrins.intr.hivm.vstas"
// CHECK: "hivm_regbaseintrins.intr.hivm.pstu.b32"
// A5-LABEL: @pb32
// A5-COUNT-2: "hivm_regbaseintrins.intr.hivm.pstu.b32"
func.func @pb32(%row: !row16, %full: !full, %data: vector<64xi1>) {
  %c0 = arith.constant 0 : index
  %short = ave.hir.pge <VL16> {functionType = #pb32} : vector<64xi1>
  %all = ave.hir.pge <ALL> {functionType = #pb32} : vector<64xi1>
  ave.hir.masked_store <NORM_B8> %row[%c0], %short, %data {ave.unaligned_ub_access = #unaligned, functionType = #pb32} : !row16, vector<64xi1>, vector<64xi1>
  ave.hir.masked_store <NORM_B8> %full[%c0], %all, %data {ave.unaligned_ub_access = #unaligned, functionType = #pb32} : !full, vector<64xi1>, vector<64xi1>
  return
}

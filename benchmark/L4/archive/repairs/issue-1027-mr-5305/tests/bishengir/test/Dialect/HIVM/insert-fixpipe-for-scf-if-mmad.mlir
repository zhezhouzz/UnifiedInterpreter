// RUN: bishengir-opt -hivm-insert-fixpipe %s -split-input-file | FileCheck %s --check-prefixes=CHECK,LOOP
// RUN: bishengir-opt -hivm-insert-fixpipe -hivm-insert-fixpipe %s -split-input-file | FileCheck %s --check-prefixes=CHECK,LOOP
// RUN: bishengir-opt -hivm-normalize-matmul %s | FileCheck %s --check-prefix=NORM
// RUN: bishengir-opt -pass-pipeline='builtin.module(func.func(hivm-normalize-matmul))' %s | FileCheck %s --check-prefix=NORM
// RUN: bishengir-opt -hivm-normalize-matmul -hivm-insert-fixpipe %s | FileCheck %s --check-prefix=LOOP

module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
// A mmad in each branch of an scf.if yields a single merged result. The fixpipe
// must be inserted once after the scf.if, so that the merged value keeps
// pointing at the L0C buffer for annotation.mark bind_buffer.
// CHECK-LABEL: func.func @single_fixpipe_after_scf_if
// CHECK: %[[IF:.*]] = scf.if
// CHECK: %[[THEN:.*]] = hivm.hir.mmadL1
// CHECK-NEXT: scf.yield %[[THEN]]
// CHECK: } else {
// CHECK: %[[ELSE:.*]] = hivm.hir.mmadL1
// CHECK-NEXT: scf.yield %[[ELSE]]
// CHECK: }
// CHECK: %[[FIX:.*]] = hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%[[IF]]
// CHECK: hivm.hir.store ins(%[[FIX]]
// CHECK-NEXT: annotation.mark %[[IF]] keys = ["bind_buffer"]
func.func @single_fixpipe_after_scf_if(
    %cond: i1,
    %arg0: memref<128x128xf16>,
    %arg1: memref<128x128xf16>,
    %arg3: memref<128x128xf32>) {
  %true = arith.constant true
  %false = arith.constant false
  %c128 = arith.constant 128 : index
  %alloc = memref.alloc() : memref<128x128xf32, #hivm.address_space<cc>>
  %a = bufferization.to_tensor %arg0 restrict writable : memref<128x128xf16>
  %b = bufferization.to_tensor %arg1 restrict writable : memref<128x128xf16>
  %res = scf.if %cond -> (tensor<128x128xf32>) {
    %memspacecast = memref.memory_space_cast %alloc : memref<128x128xf32, #hivm.address_space<cc>> to memref<128x128xf32>
    %acc = bufferization.to_tensor %memspacecast restrict writable : memref<128x128xf32>
    %mmad = hivm.hir.mmadL1 {already_set_real_mkn}
        ins(%a, %b, %false, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index)
        outs(%acc : tensor<128x128xf32>) -> tensor<128x128xf32>
    scf.yield %mmad : tensor<128x128xf32>
  } else {
    %init = tensor.empty() : tensor<128x128xf32>
    %mmad = hivm.hir.mmadL1 {already_set_real_mkn}
        ins(%a, %b, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index)
        outs(%init : tensor<128x128xf32>) -> tensor<128x128xf32>
    scf.yield %mmad : tensor<128x128xf32>
  }
  hivm.hir.store ins(%res : tensor<128x128xf32>) outs(%arg3 : memref<128x128xf32>) atomic = <add>
  annotation.mark %res keys = ["bind_buffer"] values = [%alloc : memref<128x128xf32, #hivm.address_space<cc>>] : tensor<128x128xf32>
  return
}

// Both arms also store their result. The bound result stays raw for the
// next matmul's C operand, while each store needs its own transfer.
// CHECK-LABEL: func.func @bound_accumulator_with_branch_users
// CHECK: %[[IF:.*]]:2 = scf.if
// CHECK: %[[THEN:.*]] = hivm.hir.mmadL1
// CHECK: %[[COPY:.*]] = hivm.hir.fixpipe {{.*}}ins(%[[THEN]] :
// CHECK: hivm.hir.store ins(%[[COPY]] :
// CHECK-NEXT: scf.yield {{.*}}, %[[THEN]] :
// CHECK: } else {
// CHECK: %[[ELSE:.*]] = hivm.hir.mmadL1
// CHECK: %[[ELSECOPY:.*]] = hivm.hir.fixpipe {{.*}}ins(%[[ELSE]] :
// CHECK: hivm.hir.store ins(%[[ELSECOPY]] :
// CHECK-NEXT: scf.yield {{.*}}, %[[ELSE]] :
// CHECK-NEXT: } {hivm.remain_in_l0c = [1 : i32]}
// CHECK: %[[OUTCOPY:.*]] = hivm.hir.fixpipe {{.*}}ins(%[[IF]]#1 :
// CHECK: annotation.mark %[[IF]]#1 keys = ["bind_buffer"]
// CHECK-NEXT: hivm.hir.store ins(%[[OUTCOPY]] :
// CHECK-NEXT: hivm.hir.mmadL1 {{.*}}outs(%[[IF]]#1 :
func.func @bound_accumulator_with_branch_users(
    %cond: i1, %a: tensor<128x128xf16>, %b: tensor<128x128xf16>,
    %left: tensor<128x128xf32>, %right: tensor<128x128xf32>,
    %out: memref<128x128xf32>) -> (tensor<128x128xf32>, tensor<128x128xf32>) {
  %true = arith.constant true
  %false = arith.constant false
  %c128 = arith.constant 128 : index
  %buf = memref.alloc() : memref<128x128xf32, #hivm.address_space<cc>>
  %res:2 = scf.if %cond -> (tensor<128x128xf32>, tensor<128x128xf32>) {
    %init = tensor.empty() : tensor<128x128xf32>
    %acc = hivm.hir.mmadL1 ins(%a, %b, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index)
        outs(%init : tensor<128x128xf32>) -> tensor<128x128xf32>
    hivm.hir.store ins(%acc : tensor<128x128xf32>) outs(%out : memref<128x128xf32>)
    scf.yield %left, %acc : tensor<128x128xf32>, tensor<128x128xf32>
  } else {
    %init = tensor.empty() : tensor<128x128xf32>
    %acc = hivm.hir.mmadL1 {b_transpose} ins(%a, %b, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index)
        outs(%init : tensor<128x128xf32>) -> tensor<128x128xf32>
    hivm.hir.store ins(%acc : tensor<128x128xf32>) outs(%out : memref<128x128xf32>)
    scf.yield %right, %acc : tensor<128x128xf32>, tensor<128x128xf32>
  }
  annotation.mark %res#1 keys = ["bind_buffer"] values = [%buf : memref<128x128xf32, #hivm.address_space<cc>>] : tensor<128x128xf32>
  hivm.hir.store ins(%res#1 : tensor<128x128xf32>) outs(%out : memref<128x128xf32>)
  %next = hivm.hir.mmadL1 ins(%a, %b, %false, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index)
      outs(%res#1 : tensor<128x128xf32>) -> tensor<128x128xf32>
  return %res#0, %next : tensor<128x128xf32>, tensor<128x128xf32>
}

// An explicit cube scope binds the join before it initializes a loop-carried C.
// NORM-LABEL: func.func @bound_if_initializes_loop
// NORM: scf.if
// NORM: %[[THEN:.*]] = hivm.hir.mmadL1 {{.*}}hivm.remain_in_l0c = [0 : i32]
// NORM-NEXT: scf.yield %[[THEN]]
// NORM: %[[ELSE:.*]] = hivm.hir.mmadL1 {{.*}}hivm.remain_in_l0c = [0 : i32]
// NORM-NEXT: scf.yield %[[ELSE]]
// NORM-NEXT: } {hivm.remain_in_l0c = [0 : i32]}
// LOOP-LABEL: func.func @bound_if_initializes_loop
// LOOP: %[[IF:.*]] = scf.if
// LOOP: %[[LOOP:.*]] = scf.for {{.*}} iter_args(%[[C:.*]] = %[[IF]])
// LOOP: hivm.hir.mmadL1 {{.*}}outs(%[[C]] :
// LOOP: %[[COPY:.*]] = hivm.hir.fixpipe {{.*}}ins(%[[LOOP]] :
// LOOP: hivm.hir.store ins(%[[COPY]] :
func.func @bound_if_initializes_loop(%cond: i1, %trips: index,
    %a: tensor<128x128xf16>, %b: tensor<128x128xf16>, %out: memref<128x128xf32>) {
  %true = arith.constant true
  %false = arith.constant false
  %c128 = arith.constant 128 : index
  %zero = arith.constant 0 : index
  %one = arith.constant 1 : index
  %buf = memref.alloc() : memref<128x128xf32, #hivm.address_space<cc>>
  scope.scope : () -> () {
    %init = tensor.empty() : tensor<128x128xf32>
    %res = scf.if %cond -> (tensor<128x128xf32>) {
      %then = hivm.hir.mmadL1 ins(%a, %b, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index)
          outs(%init : tensor<128x128xf32>) -> tensor<128x128xf32>
      scf.yield %then : tensor<128x128xf32>
    } else {
      %else = hivm.hir.mmadL1 {b_transpose} ins(%a, %b, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index)
          outs(%init : tensor<128x128xf32>) -> tensor<128x128xf32>
      scf.yield %else : tensor<128x128xf32>
    }
    annotation.mark %res keys = ["bind_buffer"] values = [%buf : memref<128x128xf32, #hivm.address_space<cc>>] : tensor<128x128xf32>
    %loop = scf.for %i = %zero to %trips step %one iter_args(%c = %res) -> (tensor<128x128xf32>) {
      %step = hivm.hir.mmadL1 ins(%a, %b, %false, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index)
          outs(%c : tensor<128x128xf32>) -> tensor<128x128xf32>
      scf.yield %step : tensor<128x128xf32>
    } {hivm.remain_in_l0c = [0 : i32]}
    hivm.hir.store ins(%loop : tensor<128x128xf32>) outs(%out : memref<128x128xf32>)
    scope.return
  } {hivm.tcore_type = #hivm.tcore_type<CUBE>, noinline}
  return
}

// Residency can be inferred without a binding. Each store needs its own copy.
// The unit residency attribute also covers the scalar result on older IR.
// CHECK-LABEL: func.func @resident_if_with_branch_stores
// CHECK: %[[IF:.*]]:2 = scf.if
// CHECK: %[[THEN:.*]] = hivm.hir.mmadL1
// CHECK: %[[TCOPY:.*]] = hivm.hir.fixpipe {{.*}}ins(%[[THEN]] :
// CHECK: hivm.hir.store ins(%[[TCOPY]] :
// CHECK-NEXT: scf.yield %[[THEN]]
// CHECK: %[[ELSE:.*]] = hivm.hir.mmadL1
// CHECK: %[[ECOPY:.*]] = hivm.hir.fixpipe {{.*}}ins(%[[ELSE]] :
// CHECK: hivm.hir.store ins(%[[ECOPY]] :
// CHECK-NEXT: scf.yield %[[ELSE]]
// CHECK: %[[COPY:.*]] = hivm.hir.fixpipe {{.*}}ins(%[[IF]]#0 :
// CHECK: hivm.hir.store ins(%[[COPY]] :
func.func @resident_if_with_branch_stores(%cond: i1,
    %a: tensor<128x128xf16>, %b: tensor<128x128xf16>, %out: memref<128x128xf32>, %left: index, %right: index) -> index {
  %true = arith.constant true
  %c128 = arith.constant 128 : index
  %init = tensor.empty() : tensor<128x128xf32>
  %res:2 = scf.if %cond -> (tensor<128x128xf32>, index) {
    %then = hivm.hir.mmadL1 {hivm.remain_in_l0c = [0 : i32]} ins(%a, %b, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index)
        outs(%init : tensor<128x128xf32>) -> tensor<128x128xf32>
    hivm.hir.store ins(%then : tensor<128x128xf32>) outs(%out : memref<128x128xf32>)
    scf.yield %then, %left : tensor<128x128xf32>, index
  } else {
    %else = hivm.hir.mmadL1 {b_transpose, hivm.remain_in_l0c = [0 : i32]} ins(%a, %b, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index)
        outs(%init : tensor<128x128xf32>) -> tensor<128x128xf32>
    hivm.hir.store ins(%else : tensor<128x128xf32>) outs(%out : memref<128x128xf32>)
    scf.yield %else, %right : tensor<128x128xf32>, index
  } {hivm.remain_in_l0c}
  hivm.hir.store ins(%res#0 : tensor<128x128xf32>) outs(%out : memref<128x128xf32>)
  return %res#1 : index
}

// A live shape query and two C users preserve the raw dynamic result.
// Neither branch needs a fixpipe or its insertion marker.
// CHECK-LABEL: func.func @bound_if_with_c_only_users
// CHECK: %[[IF:.*]] = scf.if
// CHECK: hivm.hir.mmadL1 {hivm.remain_in_l0c = [0 : i32]}
// CHECK: hivm.hir.mmadL1 {b_transpose, hivm.remain_in_l0c = [0 : i32]}
// CHECK: annotation.mark %[[IF]] keys = ["bind_buffer"]
// CHECK-NEXT: %[[DIM:.*]] = tensor.dim %[[IF]],
// CHECK: hivm.hir.mmadL1 {{.*}}outs(%[[IF]] :
// CHECK: hivm.hir.mmadL1 {{.*}}outs(%[[IF]] :
// CHECK: return {{.*}}, %[[DIM]]
func.func @bound_if_with_c_only_users(%cond: i1, %a: tensor<?x?xf16>, %b: tensor<?x?xf16>, %n: index)
    -> (tensor<?x?xf32>, tensor<?x?xf32>, index) {
  %zero = arith.constant 0 : index
  %new = arith.constant true
  %reuse = arith.constant false
  %l0c = memref.alloc(%n, %n) : memref<?x?xf32, #hivm.address_space<cc>>
  %join = scf.if %cond -> (tensor<?x?xf32>) {
    %init = tensor.empty(%n, %n) : tensor<?x?xf32>
    %then = hivm.hir.mmadL1 ins(%a, %b, %new, %n, %n, %n : tensor<?x?xf16>, tensor<?x?xf16>, i1, index, index, index)
        outs(%init : tensor<?x?xf32>) -> tensor<?x?xf32>
    scf.yield %then : tensor<?x?xf32>
  } else {
    %init = tensor.empty(%n, %n) : tensor<?x?xf32>
    %else = hivm.hir.mmadL1 {b_transpose} ins(%a, %b, %new, %n, %n, %n : tensor<?x?xf16>, tensor<?x?xf16>, i1, index, index, index)
        outs(%init : tensor<?x?xf32>) -> tensor<?x?xf32>
    scf.yield %else : tensor<?x?xf32>
  }
  annotation.mark %join keys = ["bind_buffer"] values = [%l0c : memref<?x?xf32, #hivm.address_space<cc>>] : tensor<?x?xf32>
  %size = tensor.dim %join, %zero : tensor<?x?xf32>
  %next = hivm.hir.mmadL1 ins(%a, %b, %reuse, %n, %n, %n : tensor<?x?xf16>, tensor<?x?xf16>, i1, index, index, index)
      outs(%join : tensor<?x?xf32>) -> tensor<?x?xf32>
  %other = hivm.hir.mmadL1 {a_transpose} ins(%a, %b, %reuse, %n, %n, %n : tensor<?x?xf16>, tensor<?x?xf16>, i1, index, index, index)
      outs(%join : tensor<?x?xf32>) -> tensor<?x?xf32>
  return %next, %other, %size : tensor<?x?xf32>, tensor<?x?xf32>, index
}
}

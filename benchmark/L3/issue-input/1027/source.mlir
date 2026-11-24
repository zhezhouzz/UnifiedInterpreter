module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
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

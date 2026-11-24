module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @single_fixpipe_after_scf_if(%arg0: i1, %arg1: memref<128x128xf16>, %arg2: memref<128x128xf16>, %arg3: memref<128x128xf32>) {
    %true = arith.constant true
    %false = arith.constant false
    %c128 = arith.constant 128 : index
    %alloc = memref.alloc() : memref<128x128xf32, #hivm.address_space<cc>>
    %0 = bufferization.to_tensor %arg1 restrict writable : memref<128x128xf16>
    %1 = bufferization.to_tensor %arg2 restrict writable : memref<128x128xf16>
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    %2 = scf.if %arg0 -> (tensor<128x128xf32>) {
      %memspacecast = memref.memory_space_cast %alloc : memref<128x128xf32, #hivm.address_space<cc>> to memref<128x128xf32>
      %3 = bufferization.to_tensor %memspacecast restrict writable : memref<128x128xf32>
      %4 = hivm.hir.mmadL1 {already_set_real_mkn} ins(%0, %1, %false, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%3 : tensor<128x128xf32>) -> tensor<128x128xf32>
      scf.yield %4 : tensor<128x128xf32>
    } else {
      %3 = tensor.empty() : tensor<128x128xf32>
      %4 = hivm.hir.mmadL1 {already_set_real_mkn} ins(%0, %1, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%3 : tensor<128x128xf32>) -> tensor<128x128xf32>
      scf.yield %4 : tensor<128x128xf32>
    }
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%2 : tensor<128x128xf32>) outs(%arg3 : memref<128x128xf32>) atomic = <add>
    annotation.mark %2 keys = ["bind_buffer"] values = [%alloc : memref<128x128xf32, #hivm.address_space<cc>>] : tensor<128x128xf32>
    return
  }
  func.func @bound_accumulator_with_branch_users(%arg0: i1, %arg1: tensor<128x128xf16>, %arg2: tensor<128x128xf16>, %arg3: tensor<128x128xf32>, %arg4: tensor<128x128xf32>, %arg5: memref<128x128xf32>) -> (tensor<128x128xf32>, tensor<128x128xf32>) {
    %true = arith.constant true
    %false = arith.constant false
    %c128 = arith.constant 128 : index
    %alloc = memref.alloc() : memref<128x128xf32, #hivm.address_space<cc>>
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    %0:2 = scf.if %arg0 -> (tensor<128x128xf32>, tensor<128x128xf32>) {
      %2 = tensor.empty() : tensor<128x128xf32>
      %3 = hivm.hir.mmadL1 ins(%arg1, %arg2, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%2 : tensor<128x128xf32>) -> tensor<128x128xf32>
      hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%3 : tensor<128x128xf32>) outs(%arg5 : memref<128x128xf32>)
      scf.yield %arg3, %3 : tensor<128x128xf32>, tensor<128x128xf32>
    } else {
      %2 = tensor.empty() : tensor<128x128xf32>
      %3 = hivm.hir.mmadL1 {b_transpose} ins(%arg1, %arg2, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%2 : tensor<128x128xf32>) -> tensor<128x128xf32>
      hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%3 : tensor<128x128xf32>) outs(%arg5 : memref<128x128xf32>)
      scf.yield %arg4, %3 : tensor<128x128xf32>, tensor<128x128xf32>
    }
    annotation.mark %0#1 keys = ["bind_buffer"] values = [%alloc : memref<128x128xf32, #hivm.address_space<cc>>] : tensor<128x128xf32>
    hivm.hir.pipe_barrier[<PIPE_MTE3>]
    hivm.hir.store ins(%0#1 : tensor<128x128xf32>) outs(%arg5 : memref<128x128xf32>)
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_M>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_M>, <EVENT_ID0>]
    %1 = hivm.hir.mmadL1 ins(%arg1, %arg2, %false, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%0#1 : tensor<128x128xf32>) -> tensor<128x128xf32>
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    return %0#0, %1 : tensor<128x128xf32>, tensor<128x128xf32>
  }
  func.func @bound_if_initializes_loop(%arg0: i1, %arg1: index, %arg2: tensor<128x128xf16>, %arg3: tensor<128x128xf16>, %arg4: memref<128x128xf32>) {
    %true = arith.constant true
    %false = arith.constant false
    %c128 = arith.constant 128 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %alloc = memref.alloc() : memref<128x128xf32, #hivm.address_space<cc>>
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    scope.scope : () -> () {
      %0 = tensor.empty() : tensor<128x128xf32>
      %1 = scf.if %arg0 -> (tensor<128x128xf32>) {
        %3 = hivm.hir.mmadL1 ins(%arg2, %arg3, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%0 : tensor<128x128xf32>) -> tensor<128x128xf32>
        scf.yield %3 : tensor<128x128xf32>
      } else {
        %3 = hivm.hir.mmadL1 {b_transpose} ins(%arg2, %arg3, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%0 : tensor<128x128xf32>) -> tensor<128x128xf32>
        scf.yield %3 : tensor<128x128xf32>
      }
      annotation.mark %1 keys = ["bind_buffer"] values = [%alloc : memref<128x128xf32, #hivm.address_space<cc>>] : tensor<128x128xf32>
      %2 = scf.for %arg5 = %c0 to %arg1 step %c1 iter_args(%arg6 = %1) -> (tensor<128x128xf32>) {
        %3 = hivm.hir.mmadL1 ins(%arg2, %arg3, %false, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%arg6 : tensor<128x128xf32>) -> tensor<128x128xf32>
        scf.yield %3 : tensor<128x128xf32>
      } {hivm.remain_in_l0c = [0 : i32]}
      hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%2 : tensor<128x128xf32>) outs(%arg4 : memref<128x128xf32>)
      scope.return
    } {hivm.tcore_type = #hivm.tcore_type<CUBE>, noinline}
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    return
  }
  func.func @resident_if_with_branch_stores(%arg0: i1, %arg1: tensor<128x128xf16>, %arg2: tensor<128x128xf16>, %arg3: memref<128x128xf32>, %arg4: index, %arg5: index) -> index {
    %true = arith.constant true
    %c128 = arith.constant 128 : index
    %0 = tensor.empty() : tensor<128x128xf32>
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    %1:2 = scf.if %arg0 -> (tensor<128x128xf32>, index) {
      %2 = hivm.hir.mmadL1 {hivm.remain_in_l0c = [0 : i32]} ins(%arg1, %arg2, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%0 : tensor<128x128xf32>) -> tensor<128x128xf32>
      hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%2 : tensor<128x128xf32>) outs(%arg3 : memref<128x128xf32>)
      scf.yield %2, %arg4 : tensor<128x128xf32>, index
    } else {
      %2 = hivm.hir.mmadL1 {b_transpose, hivm.remain_in_l0c = [0 : i32]} ins(%arg1, %arg2, %true, %c128, %c128, %c128 : tensor<128x128xf16>, tensor<128x128xf16>, i1, index, index, index) outs(%0 : tensor<128x128xf32>) -> tensor<128x128xf32>
      hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%2 : tensor<128x128xf32>) outs(%arg3 : memref<128x128xf32>)
      scf.yield %2, %arg5 : tensor<128x128xf32>, index
    } {hivm.remain_in_l0c}
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.pipe_barrier[<PIPE_MTE3>]
    hivm.hir.store ins(%1#0 : tensor<128x128xf32>) outs(%arg3 : memref<128x128xf32>)
    return %1#1 : index
  }
  func.func @bound_if_with_c_only_users(%arg0: i1, %arg1: tensor<?x?xf16>, %arg2: tensor<?x?xf16>, %arg3: index) -> (tensor<?x?xf32>, tensor<?x?xf32>, index) {
    %c0 = arith.constant 0 : index
    %true = arith.constant true
    %false = arith.constant false
    %alloc = memref.alloc(%arg3, %arg3) : memref<?x?xf32, #hivm.address_space<cc>>
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    %0 = scf.if %arg0 -> (tensor<?x?xf32>) {
      %3 = tensor.empty(%arg3, %arg3) : tensor<?x?xf32>
      %4 = hivm.hir.mmadL1 ins(%arg1, %arg2, %true, %arg3, %arg3, %arg3 : tensor<?x?xf16>, tensor<?x?xf16>, i1, index, index, index) outs(%3 : tensor<?x?xf32>) -> tensor<?x?xf32>
      scf.yield %4 : tensor<?x?xf32>
    } else {
      %3 = tensor.empty(%arg3, %arg3) : tensor<?x?xf32>
      %4 = hivm.hir.mmadL1 {b_transpose} ins(%arg1, %arg2, %true, %arg3, %arg3, %arg3 : tensor<?x?xf16>, tensor<?x?xf16>, i1, index, index, index) outs(%3 : tensor<?x?xf32>) -> tensor<?x?xf32>
      scf.yield %4 : tensor<?x?xf32>
    }
    annotation.mark %0 keys = ["bind_buffer"] values = [%alloc : memref<?x?xf32, #hivm.address_space<cc>>] : tensor<?x?xf32>
    %dim = tensor.dim %0, %c0 : tensor<?x?xf32>
    %1 = hivm.hir.mmadL1 ins(%arg1, %arg2, %false, %arg3, %arg3, %arg3 : tensor<?x?xf16>, tensor<?x?xf16>, i1, index, index, index) outs(%0 : tensor<?x?xf32>) -> tensor<?x?xf32>
    %2 = hivm.hir.mmadL1 {a_transpose} ins(%arg1, %arg2, %false, %arg3, %arg3, %arg3 : tensor<?x?xf16>, tensor<?x?xf16>, i1, index, index, index) outs(%0 : tensor<?x?xf32>) -> tensor<?x?xf32>
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    return %1, %2, %dim : tensor<?x?xf32>, tensor<?x?xf32>, index
  }
}


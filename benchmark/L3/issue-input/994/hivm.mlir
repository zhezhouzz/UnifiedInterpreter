module attributes {hacc.target = #hacc.target<"Ascend910B1">} {
  func.func @test_mmad_accumulation_while_no_outer_fixpipe(%arg0: tensor<64x64xf16>, %arg1: tensor<64x64xf16>, %arg2: tensor<64x64xf32>) -> tensor<64x64xf32> {
    %c64 = arith.constant 64 : index
    %true = arith.constant true
    %c0_i32 = arith.constant 0 : i32
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    %0:2 = scf.while (%arg3 = %c0_i32, %arg4 = %arg2) : (i32, tensor<64x64xf32>) -> (i32, tensor<64x64xf32>) {
      scf.condition(%true) %arg3, %arg4 : i32, tensor<64x64xf32>
    } do {
    ^bb0(%arg3: i32, %arg4: tensor<64x64xf32>):
      %2 = scf.if %true -> (tensor<64x64xf32>) {
        %3 = hivm.hir.mmadL1 {hivm.remain_in_l0c = [0 : i32], normalized_in_L0C} ins(%arg0, %arg1, %true, %c64, %c64, %c64 : tensor<64x64xf16>, tensor<64x64xf16>, i1, index, index, index) outs(%arg4 : tensor<64x64xf32>) -> tensor<64x64xf32>
        scf.yield %3 : tensor<64x64xf32>
      } else {
        scf.yield %arg4 : tensor<64x64xf32>
      } {hivm.matmul_limited_in_cube, hivm.remain_in_l0c = [0 : i32]}
      scf.yield %arg3, %2 : i32, tensor<64x64xf32>
    } attributes {hivm.remain_in_l0c = [1 : i32], normalized_in_L0C = [1 : i32]}
    %1:2 = scf.while (%arg3 = %c0_i32, %arg4 = %0#1) : (i32, tensor<64x64xf32>) -> (i32, tensor<64x64xf32>) {
      scf.condition(%true) %arg3, %arg4 : i32, tensor<64x64xf32>
    } do {
    ^bb0(%arg3: i32, %arg4: tensor<64x64xf32>):
      %2 = hivm.hir.mmadL1 ins(%arg0, %arg1, %true, %c64, %c64, %c64 : tensor<64x64xf16>, tensor<64x64xf16>, i1, index, index, index) outs(%arg4 : tensor<64x64xf32>) -> tensor<64x64xf32>
      scf.yield %arg3, %2 : i32, tensor<64x64xf32>
    }
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    return %1#1 : tensor<64x64xf32>
  }
}


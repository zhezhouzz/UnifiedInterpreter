module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @shared_accumulator(%arg0: i1, %arg1: tensor<1x1x16x16xf32>, %arg2: memref<16x16xf32>) {
    %c16 = arith.constant 16 : index
    %false = arith.constant false
    %0 = hivm.hir.convert_layout %arg1 output_shape [16, 16] {dstLayout = #hivm.data_layout<ND>, srcLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>} : (tensor<1x1x16x16xf32>) -> tensor<16x16xf32>
    %1 = tensor.empty() : tensor<2x1x16x8xf32>
    %2 = hivm.hir.fixpipe {channel_split = true} ins(%0 : tensor<16x16xf32>) outs(%1 : tensor<2x1x16x8xf32>) -> tensor<2x1x16x8xf32>
    hivm.hir.set_flag[<PIPE_FIX>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_FIX>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    %3 = scf.if %arg0 -> (tensor<16x16xf32>) {
      %4 = hivm.hir.mmadL1 ins(%2, %2, %false, %c16, %c16, %c16 : tensor<2x1x16x8xf32>, tensor<2x1x16x8xf32>, i1, index, index, index) outs(%arg1 : tensor<1x1x16x16xf32>) -> tensor<1x1x16x16xf32>
      %5 = hivm.hir.convert_layout %4 output_shape [16, 16] {dstLayout = #hivm.data_layout<ND>, srcLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>} : (tensor<1x1x16x16xf32>) -> tensor<16x16xf32>
      scf.yield %5 : tensor<16x16xf32>
    } else {
      scf.yield %0 : tensor<16x16xf32>
    } {hivm.remain_in_l0c = [0 : i32], normalized_in_L0C = [0 : i32]}
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_M>, <PIPE_MTE1>, <EVENT_ID1>]
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%3 : tensor<16x16xf32>) outs(%arg2 : memref<16x16xf32>)
    return
  }
  func.func @different_output_extents(%arg0: i1, %arg1: tensor<1x?x16x16xf32>, %arg2: index, %arg3: index) -> (tensor<?x16xf32>, tensor<?x16xf32>) {
    %0 = hivm.hir.convert_layout %arg1 output_shape [%arg2, 16] {dstLayout = #hivm.data_layout<ND>, srcLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>} : (tensor<1x?x16x16xf32>) -> tensor<?x16xf32>
    %1 = scf.if %arg0 -> (tensor<?x16xf32>) {
      %2 = hivm.hir.convert_layout %arg1 output_shape [%arg3, 16] {dstLayout = #hivm.data_layout<ND>, srcLayout = #hivm.data_layout<Fractal, fractalSizes = [16, 16]>} : (tensor<1x?x16x16xf32>) -> tensor<?x16xf32>
      scf.yield %2 : tensor<?x16xf32>
    } else {
      scf.yield %0 : tensor<?x16xf32>
    }
    return %1, %0 : tensor<?x16xf32>, tensor<?x16xf32>
  }
}


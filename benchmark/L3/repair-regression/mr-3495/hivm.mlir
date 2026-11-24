module attributes {hacc.target = #hacc.target<"Ascend950PR_9589">} {
  func.func @cv11(%arg0: tensor<16x16xf32>, %arg1: memref<16x16xf32>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.core_ratio = #hivm.core_ratio<1, 1>, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %alloc = memref.alloc() : memref<16x16xf32>
    hivm.hir.load ins(%arg1 : memref<16x16xf32>) outs(%alloc : memref<16x16xf32>) {"hivm.inserted-load"} core_type = <VECTOR>
    %0 = tensor.empty() : tensor<16x16xf32>
    %1 = hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%arg0 : tensor<16x16xf32>) outs(%0 : tensor<16x16xf32>) -> tensor<16x16xf32>
    %2 = tensor.empty() : tensor<16x16xf32>
    %3 = hivm.hir.load ins(%1 : tensor<16x16xf32>) outs(%2 : tensor<16x16xf32>) {"hivm.inserted-load"} core_type = <VECTOR> -> tensor<16x16xf32>
    %4 = tensor.empty() : tensor<16x16xf32>
    %5 = hivm.hir.vrelu ins(%3 : tensor<16x16xf32>) outs(%4 : tensor<16x16xf32>) -> tensor<16x16xf32>
    bufferization.materialize_in_destination %5 in writable %alloc : (tensor<16x16xf32>, memref<16x16xf32>) -> ()
    return
  }
  func.func @cv12(%arg0: tensor<16x16xf32>, %arg1: memref<16x16xf32>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.core_ratio = #hivm.core_ratio<1, 2>, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %alloc = memref.alloc() : memref<16x16xf32>
    hivm.hir.load ins(%arg1 : memref<16x16xf32>) outs(%alloc : memref<16x16xf32>) {"hivm.inserted-load"} core_type = <VECTOR>
    %alloc_0 = memref.alloc() : memref<16x16xf32, #hivm.address_space<ub>>
    %memspacecast = memref.memory_space_cast %alloc_0 : memref<16x16xf32, #hivm.address_space<ub>> to memref<16x16xf32>
    %0 = bufferization.to_tensor %memspacecast restrict writable : memref<16x16xf32>
    hivm.hir.fixpipe {dma_mode = #hivm.dma_mode<nz2nd>} ins(%arg0 : tensor<16x16xf32>) outs(%alloc_0 : memref<16x16xf32, #hivm.address_space<ub>>)
    %1 = tensor.empty() : tensor<16x16xf32>
    %2 = hivm.hir.vrelu ins(%0 : tensor<16x16xf32>) outs(%1 : tensor<16x16xf32>) -> tensor<16x16xf32>
    bufferization.materialize_in_destination %2 in writable %alloc : (tensor<16x16xf32>, memref<16x16xf32>) -> ()
    return
  }
}


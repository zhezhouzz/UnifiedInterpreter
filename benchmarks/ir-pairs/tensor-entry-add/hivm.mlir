module {
  func.func @tensor_entry_add(%arg0: tensor<8xf32>, %arg1: tensor<8xf32>, %arg2: memref<8xf32>) {
    %0 = tensor.empty() : tensor<8xf32>
    %1 = hivm.hir.vadd ins(%arg0, %arg1 : tensor<8xf32>, tensor<8xf32>) outs(%0 : tensor<8xf32>) -> tensor<8xf32>
    bufferization.materialize_in_destination %1 in writable %arg2 : (tensor<8xf32>, memref<8xf32>) -> ()
    return
  }
}


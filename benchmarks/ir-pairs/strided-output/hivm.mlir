module {
  func.func @strided_output(%arg0: memref<1xf32>, %arg1: memref<7xf16>, %arg2: index, %arg3: index, %arg4: index) {
    %c1 = arith.constant 1 : index
    %c4 = arith.constant 4 : index
    %0 = bufferization.to_tensor %arg0 restrict : memref<1xf32>
    %1 = tensor.empty() : tensor<1xf16>
    %2 = hivm.hir.vcast ins(%0 : tensor<1xf32>) outs(%1 : tensor<1xf16>) -> tensor<1xf16>
    scf.for %arg5 = %arg3 to %arg4 step %c1 {
      %3 = arith.remsi %arg5, %c4 : index
      %4 = arith.addi %arg2, %3 : index
      %reinterpret_cast = memref.reinterpret_cast %arg1 to offset: [%4], sizes: [1], strides: [1] : memref<7xf16> to memref<1xf16, strided<[1], offset: ?>>
      bufferization.materialize_in_destination %2 in writable %reinterpret_cast : (tensor<1xf16>, memref<1xf16, strided<[1], offset: ?>>) -> ()
    }
    return
  }
}


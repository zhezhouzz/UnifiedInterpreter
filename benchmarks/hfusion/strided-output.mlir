func.func @strided_output(%input: memref<1xf32>, %out: memref<7xf16>, %lane: index, %start: index, %n: index) {
  %one = arith.constant 1 : index
  %four = arith.constant 4 : index
  %src = bufferization.to_tensor %input restrict : memref<1xf32>
  %empty = tensor.empty() : tensor<1xf16>
  %value = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, round_mode = #hfusion.round_mode<rint>} ins(%src : tensor<1xf32>) outs(%empty : tensor<1xf16>) -> tensor<1xf16>
  scf.for %iv = %start to %n step %one {
    %slot = arith.remsi %iv, %four : index
    %offset = arith.addi %lane, %slot : index
    %dst = memref.reinterpret_cast %out to offset: [%offset], sizes: [1], strides: [1] : memref<7xf16> to memref<1xf16, strided<[1], offset: ?>>
    bufferization.materialize_in_destination %value in writable %dst : (tensor<1xf16>, memref<1xf16, strided<[1], offset: ?>>) -> ()
  }
  return
}

builtin.module {
  func.func @row_sum(%input: memref<3x4xf32>, %out: memref<3xf32>) {
    %cst = arith.constant 0.000000e+00 : f32
    %reinterpret_cast = memref.reinterpret_cast %input to offset: [0], sizes: [1, 4], strides: [4, 1] : memref<3x4xf32> to memref<1x4xf32, strided<[4, 1]>>
    %alloc = memref.alloc() : memref<1x4xf32>
    memref.copy %reinterpret_cast, %alloc : memref<1x4xf32, strided<[4, 1]>> to memref<1x4xf32>
    %0 = bufferization.to_tensor %alloc restrict writable : memref<1x4xf32>
    %1 = tensor.empty() : tensor<1xf32>
    %2 = linalg.fill ins(%cst : f32) outs(%1 : tensor<1xf32>) -> tensor<1xf32>
    %reduced = linalg.reduce ins(%0:tensor<1x4xf32>) outs(%2:tensor<1xf32>) dimensions = [1]
    (%in: f32, %init: f32) {
      %3 = arith.addf %in, %init : f32
      linalg.yield %3 : f32
    }
    %reinterpret_cast_1 = memref.reinterpret_cast %out to offset: [0], sizes: [1], strides: [1] : memref<3xf32> to memref<1xf32, strided<[1]>>
    bufferization.materialize_in_destination %reduced in writable %reinterpret_cast_1 : (tensor<1xf32>, memref<1xf32, strided<[1]>>) -> ()
    %reinterpret_cast_2 = memref.reinterpret_cast %input to offset: [4], sizes: [1, 4], strides: [4, 1] : memref<3x4xf32> to memref<1x4xf32, strided<[4, 1], offset: 4>>
    %alloc_1 = memref.alloc() : memref<1x4xf32>
    memref.copy %reinterpret_cast_2, %alloc_1 : memref<1x4xf32, strided<[4, 1], offset: 4>> to memref<1x4xf32>
    %4 = bufferization.to_tensor %alloc_1 restrict writable : memref<1x4xf32>
    %reduced_1 = linalg.reduce ins(%4:tensor<1x4xf32>) outs(%2:tensor<1xf32>) dimensions = [1]
    (%in_1: f32, %init_1: f32) {
      %5 = arith.addf %in_1, %init_1 : f32
      linalg.yield %5 : f32
    }
    %reinterpret_cast_3 = memref.reinterpret_cast %out to offset: [1], sizes: [1], strides: [1] : memref<3xf32> to memref<1xf32, strided<[1], offset: 1>>
    bufferization.materialize_in_destination %reduced_1 in writable %reinterpret_cast_3 : (tensor<1xf32>, memref<1xf32, strided<[1], offset: 1>>) -> ()
    %reinterpret_cast_4 = memref.reinterpret_cast %input to offset: [8], sizes: [1, 4], strides: [4, 1] : memref<3x4xf32> to memref<1x4xf32, strided<[4, 1], offset: 8>>
    %alloc_2 = memref.alloc() : memref<1x4xf32>
    memref.copy %reinterpret_cast_4, %alloc_2 : memref<1x4xf32, strided<[4, 1], offset: 8>> to memref<1x4xf32>
    %6 = bufferization.to_tensor %alloc_2 restrict writable : memref<1x4xf32>
    %reduced_2 = linalg.reduce ins(%6:tensor<1x4xf32>) outs(%2:tensor<1xf32>) dimensions = [1]
    (%in_2: f32, %init_2: f32) {
      %7 = arith.addf %in_2, %init_2 : f32
      linalg.yield %7 : f32
    }
    %reinterpret_cast_5 = memref.reinterpret_cast %out to offset: [2], sizes: [1], strides: [1] : memref<3xf32> to memref<1xf32, strided<[1], offset: 2>>
    bufferization.materialize_in_destination %reduced_2 in writable %reinterpret_cast_5 : (tensor<1xf32>, memref<1xf32, strided<[1], offset: 2>>) -> ()
    func.return
  }
}

builtin.module {
  func.func @vector_add(%a: memref<8xf32>, %b: memref<8xf32>, %out: memref<8xf32>) {
    %reinterpret_cast = memref.reinterpret_cast %a to offset: [0], sizes: [4], strides: [1] : memref<8xf32> to memref<4xf32, strided<[1]>>
    %alloc = memref.alloc() : memref<4xf32>
    memref.copy %reinterpret_cast, %alloc : memref<4xf32, strided<[1]>> to memref<4xf32>
    %0 = bufferization.to_tensor %alloc restrict writable : memref<4xf32>
    %reinterpret_cast_1 = memref.reinterpret_cast %b to offset: [0], sizes: [4], strides: [1] : memref<8xf32> to memref<4xf32, strided<[1]>>
    %alloc_1 = memref.alloc() : memref<4xf32>
    memref.copy %reinterpret_cast_1, %alloc_1 : memref<4xf32, strided<[1]>> to memref<4xf32>
    %1 = bufferization.to_tensor %alloc_1 restrict writable : memref<4xf32>
    %reinterpret_cast_2 = memref.reinterpret_cast %out to offset: [0], sizes: [4], strides: [1] : memref<8xf32> to memref<4xf32, strided<[1]>>
    %2 = tensor.empty() : tensor<4xf32>
    %3 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%0, %1 : tensor<4xf32>, tensor<4xf32>) outs(%2 : tensor<4xf32>) -> tensor<4xf32>
    bufferization.materialize_in_destination %3 in writable %reinterpret_cast_2 : (tensor<4xf32>, memref<4xf32, strided<[1]>>) -> ()
    %reinterpret_cast_3 = memref.reinterpret_cast %a to offset: [4], sizes: [4], strides: [1] : memref<8xf32> to memref<4xf32, strided<[1], offset: 4>>
    %alloc_2 = memref.alloc() : memref<4xf32>
    memref.copy %reinterpret_cast_3, %alloc_2 : memref<4xf32, strided<[1], offset: 4>> to memref<4xf32>
    %4 = bufferization.to_tensor %alloc_2 restrict writable : memref<4xf32>
    %reinterpret_cast_4 = memref.reinterpret_cast %b to offset: [4], sizes: [4], strides: [1] : memref<8xf32> to memref<4xf32, strided<[1], offset: 4>>
    %alloc_3 = memref.alloc() : memref<4xf32>
    memref.copy %reinterpret_cast_4, %alloc_3 : memref<4xf32, strided<[1], offset: 4>> to memref<4xf32>
    %5 = bufferization.to_tensor %alloc_3 restrict writable : memref<4xf32>
    %reinterpret_cast_5 = memref.reinterpret_cast %out to offset: [4], sizes: [4], strides: [1] : memref<8xf32> to memref<4xf32, strided<[1], offset: 4>>
    %6 = tensor.empty() : tensor<4xf32>
    %7 = hivm.hir.vadd ins(%4, %5 : tensor<4xf32>, tensor<4xf32>) outs(%6 : tensor<4xf32>) -> tensor<4xf32>
    bufferization.materialize_in_destination %7 in writable %reinterpret_cast_5 : (tensor<4xf32>, memref<4xf32, strided<[1], offset: 4>>) -> ()
    func.return
  }
}

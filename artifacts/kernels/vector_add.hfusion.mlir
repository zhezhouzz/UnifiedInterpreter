module {
  func.func @vector_add(%arg0: memref<?xi8>, %arg1: memref<?xi8>, %arg2: memref<?xf32> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf32> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg5: i32, %arg6: i32, %arg7: i32, %arg8: i32, %arg9: i32, %arg10: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, global_kernel = "local", mix_mode = "aiv", parallel_mode = "simd"} {
    %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [0], sizes: [4], strides: [1] : memref<?xf32> to memref<4xf32, strided<[1]>>
    %alloc = memref.alloc() : memref<4xf32>
    memref.copy %reinterpret_cast, %alloc : memref<4xf32, strided<[1]>> to memref<4xf32>
    %0 = bufferization.to_tensor %alloc restrict writable : memref<4xf32>
    %reinterpret_cast_0 = memref.reinterpret_cast %arg3 to offset: [0], sizes: [4], strides: [1] : memref<?xf32> to memref<4xf32, strided<[1]>>
    %alloc_1 = memref.alloc() : memref<4xf32>
    memref.copy %reinterpret_cast_0, %alloc_1 : memref<4xf32, strided<[1]>> to memref<4xf32>
    %1 = bufferization.to_tensor %alloc_1 restrict writable : memref<4xf32>
    %reinterpret_cast_2 = memref.reinterpret_cast %arg4 to offset: [0], sizes: [4], strides: [1] : memref<?xf32> to memref<4xf32, strided<[1]>>
    %2 = tensor.empty() : tensor<4xf32>
    %3 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%0, %1 : tensor<4xf32>, tensor<4xf32>) outs(%2 : tensor<4xf32>) -> tensor<4xf32>
    bufferization.materialize_in_destination %3 in writable %reinterpret_cast_2 : (tensor<4xf32>, memref<4xf32, strided<[1]>>) -> ()
    %reinterpret_cast_3 = memref.reinterpret_cast %arg2 to offset: [4], sizes: [4], strides: [1] : memref<?xf32> to memref<4xf32, strided<[1], offset: 4>>
    %alloc_4 = memref.alloc() : memref<4xf32>
    memref.copy %reinterpret_cast_3, %alloc_4 : memref<4xf32, strided<[1], offset: 4>> to memref<4xf32>
    %4 = bufferization.to_tensor %alloc_4 restrict writable : memref<4xf32>
    %reinterpret_cast_5 = memref.reinterpret_cast %arg3 to offset: [4], sizes: [4], strides: [1] : memref<?xf32> to memref<4xf32, strided<[1], offset: 4>>
    %alloc_6 = memref.alloc() : memref<4xf32>
    memref.copy %reinterpret_cast_5, %alloc_6 : memref<4xf32, strided<[1], offset: 4>> to memref<4xf32>
    %5 = bufferization.to_tensor %alloc_6 restrict writable : memref<4xf32>
    %reinterpret_cast_7 = memref.reinterpret_cast %arg4 to offset: [4], sizes: [4], strides: [1] : memref<?xf32> to memref<4xf32, strided<[1], offset: 4>>
    %6 = tensor.empty() : tensor<4xf32>
    %7 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%4, %5 : tensor<4xf32>, tensor<4xf32>) outs(%6 : tensor<4xf32>) -> tensor<4xf32>
    bufferization.materialize_in_destination %7 in writable %reinterpret_cast_7 : (tensor<4xf32>, memref<4xf32, strided<[1], offset: 4>>) -> ()
    return
  }
}


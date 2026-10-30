module {
  func.func @row_sum(%arg0: memref<?xi8>, %arg1: memref<?xi8>, %arg2: memref<?xf32> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg4: i32, %arg5: i32, %arg6: i32, %arg7: i32, %arg8: i32, %arg9: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, global_kernel = "local", mix_mode = "aiv", parallel_mode = "simd"} {
    %cst = arith.constant 0.000000e+00 : f32
    %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [0], sizes: [1, 4], strides: [4, 1] : memref<?xf32> to memref<1x4xf32, strided<[4, 1]>>
    %alloc = memref.alloc() : memref<1x4xf32>
    memref.copy %reinterpret_cast, %alloc : memref<1x4xf32, strided<[4, 1]>> to memref<1x4xf32>
    %0 = bufferization.to_tensor %alloc restrict writable : memref<1x4xf32>
    %1 = tensor.empty() : tensor<1xf32>
    %2 = linalg.fill ins(%cst : f32) outs(%1 : tensor<1xf32>) -> tensor<1xf32>
    %reduced = linalg.reduce ins(%0 : tensor<1x4xf32>) outs(%2 : tensor<1xf32>) dimensions = [1] 
      (%in: f32, %init: f32) {
        %5 = arith.addf %in, %init : f32
        linalg.yield %5 : f32
      }
    %reinterpret_cast_0 = memref.reinterpret_cast %arg3 to offset: [0], sizes: [1], strides: [1] : memref<?xf32> to memref<1xf32, strided<[1]>>
    bufferization.materialize_in_destination %reduced in writable %reinterpret_cast_0 : (tensor<1xf32>, memref<1xf32, strided<[1]>>) -> ()
    %reinterpret_cast_1 = memref.reinterpret_cast %arg2 to offset: [4], sizes: [1, 4], strides: [4, 1] : memref<?xf32> to memref<1x4xf32, strided<[4, 1], offset: 4>>
    %alloc_2 = memref.alloc() : memref<1x4xf32>
    memref.copy %reinterpret_cast_1, %alloc_2 : memref<1x4xf32, strided<[4, 1], offset: 4>> to memref<1x4xf32>
    %3 = bufferization.to_tensor %alloc_2 restrict writable : memref<1x4xf32>
    %reduced_3 = linalg.reduce ins(%3 : tensor<1x4xf32>) outs(%2 : tensor<1xf32>) dimensions = [1] 
      (%in: f32, %init: f32) {
        %5 = arith.addf %in, %init : f32
        linalg.yield %5 : f32
      }
    %reinterpret_cast_4 = memref.reinterpret_cast %arg3 to offset: [1], sizes: [1], strides: [1] : memref<?xf32> to memref<1xf32, strided<[1], offset: 1>>
    bufferization.materialize_in_destination %reduced_3 in writable %reinterpret_cast_4 : (tensor<1xf32>, memref<1xf32, strided<[1], offset: 1>>) -> ()
    %reinterpret_cast_5 = memref.reinterpret_cast %arg2 to offset: [8], sizes: [1, 4], strides: [4, 1] : memref<?xf32> to memref<1x4xf32, strided<[4, 1], offset: 8>>
    %alloc_6 = memref.alloc() : memref<1x4xf32>
    memref.copy %reinterpret_cast_5, %alloc_6 : memref<1x4xf32, strided<[4, 1], offset: 8>> to memref<1x4xf32>
    %4 = bufferization.to_tensor %alloc_6 restrict writable : memref<1x4xf32>
    %reduced_7 = linalg.reduce ins(%4 : tensor<1x4xf32>) outs(%2 : tensor<1xf32>) dimensions = [1] 
      (%in: f32, %init: f32) {
        %5 = arith.addf %in, %init : f32
        linalg.yield %5 : f32
      }
    %reinterpret_cast_8 = memref.reinterpret_cast %arg3 to offset: [2], sizes: [1], strides: [1] : memref<?xf32> to memref<1xf32, strided<[1], offset: 2>>
    bufferization.materialize_in_destination %reduced_7 in writable %reinterpret_cast_8 : (tensor<1xf32>, memref<1xf32, strided<[1], offset: 2>>) -> ()
    return
  }
}


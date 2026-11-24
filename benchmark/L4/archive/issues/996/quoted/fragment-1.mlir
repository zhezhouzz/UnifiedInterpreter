module {
  func.func private @triton_print(tensor<2x2x32x32xbf16>) attributes {hex = false, prefix = " x: "}
  func.func private @triton_print_0(tensor<2x2x32x32xbf16>) attributes {hex = false, prefix = " y: "}
  func.func private @triton_print_1(tensor<2x2x32x32xf32>) attributes {hex = false, prefix = " z: "}
  func.func @kernel(%arg0: memref<?xi8>, %arg1: memref<?xi8>, %arg2: memref<?xbf16> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xbf16> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg5: i32, %arg6: i32, %arg7: i32, %arg8: i32, %arg9: i32, %arg10: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, global_kernel = "local", mix_mode = "mix", parallel_mode = "simd"} {
    %cst = arith.constant dense<4096> : tensor<1xi64>
    %cst_0 = arith.constant dense<[4, 32, 32]> : tensor<3xi64>
    %cst_1 = arith.constant dense<[2, 2, 32, 32]> : tensor<4xi64>
    %cst_2 = arith.constant 0.000000e+00 : f32
    %0 = tensor.empty() : tensor<4x32x32xf32>
    %1 = linalg.fill ins(%cst_2 : f32) outs(%0 : tensor<4x32x32xf32>) -> tensor<4x32x32xf32>
    %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [0], sizes: [4096], strides: [1] : memref<?xbf16> to memref<4096xbf16, strided<[1]>>
    %alloc = memref.alloc() : memref<4096xbf16>
    memref.copy %reinterpret_cast, %alloc : memref<4096xbf16, strided<[1]>> to memref<4096xbf16>
    %2 = bufferization.to_tensor %alloc restrict writable : memref<4096xbf16>
    %reshape = tensor.reshape %2(%cst_1) : (tensor<4096xbf16>, tensor<4xi64>) -> tensor<2x2x32x32xbf16>
    %reinterpret_cast_3 = memref.reinterpret_cast %arg3 to offset: [0], sizes: [4096], strides: [1] : memref<?xbf16> to memref<4096xbf16, strided<[1]>>
    %alloc_4 = memref.alloc() : memref<4096xbf16>
    memref.copy %reinterpret_cast_3, %alloc_4 : memref<4096xbf16, strided<[1]>> to memref<4096xbf16>
    %3 = bufferization.to_tensor %alloc_4 restrict writable : memref<4096xbf16>
    %reshape_5 = tensor.reshape %3(%cst_1) : (tensor<4096xbf16>, tensor<4xi64>) -> tensor<2x2x32x32xbf16>
    %reshape_6 = tensor.reshape %2(%cst_0) : (tensor<4096xbf16>, tensor<3xi64>) -> tensor<4x32x32xbf16>
    %reshape_7 = tensor.reshape %3(%cst_0) : (tensor<4096xbf16>, tensor<3xi64>) -> tensor<4x32x32xbf16>
    %4 = linalg.batch_matmul {input_precision = "ieee"} ins(%reshape_6, %reshape_7 : tensor<4x32x32xbf16>, tensor<4x32x32xbf16>) outs(%1 : tensor<4x32x32xf32>) -> tensor<4x32x32xf32>
    %reshape_8 = tensor.reshape %4(%cst_1) : (tensor<4x32x32xf32>, tensor<4xi64>) -> tensor<2x2x32x32xf32>
    call @triton_print(%reshape) : (tensor<2x2x32x32xbf16>) -> ()
    call @triton_print_0(%reshape_5) : (tensor<2x2x32x32xbf16>) -> ()
    call @triton_print_1(%reshape_8) : (tensor<2x2x32x32xf32>) -> ()
    %reinterpret_cast_9 = memref.reinterpret_cast %arg4 to offset: [0], sizes: [4096], strides: [1] : memref<?xf32> to memref<4096xf32, strided<[1]>>
    %reshape_10 = tensor.reshape %4(%cst) : (tensor<4x32x32xf32>, tensor<1xi64>) -> tensor<4096xf32>
    bufferization.materialize_in_destination %reshape_10 in writable %reinterpret_cast_9 : (tensor<4096xf32>, memref<4096xf32, strided<[1]>>) -> ()
    return
  }
}

func.func @_attn_fwd(%arg0: i64, %arg1: memref<?xi8>, %arg2: memref<?xi8>, %arg3: memref<?xf16>, %arg4: memref<?xf16>, %arg5: memref<?xf16>, %arg6: memref<?xf32>, %arg7: memref<?xf16>, %arg8: memref<?xf32>, %arg9: f32, %arg10: i32, %arg11: i32, %arg12: i32, %arg13: i32, %arg14: i32, %arg15: i32) {
  %zero = arith.constant 0.0 : f32
  %two = arith.constant 2.0 : f32
  %three = arith.constant 3.0 : f32
  %lo = arith.constant 0 : i32
  %hi = arith.constant 1 : i32
  %step = arith.constant 1 : i32
  %matrix = tensor.empty() : tensor<2x2xf32>
  %row = tensor.empty() : tensor<2xf32>
  %buffer = memref.alloc() : memref<2xf32>
  scf.for %i = %lo to %hi step %step : i32 {
    %filled = linalg.fill ins(%two : f32) outs(%matrix : tensor<2x2xf32>) -> tensor<2x2xf32>
    %added = hivm.hir.vadd ins(%filled, %three : tensor<2x2xf32>, f32) outs(%matrix : tensor<2x2xf32>) -> tensor<2x2xf32>
    %init = linalg.fill ins(%zero : f32) outs(%row : tensor<2xf32>) -> tensor<2xf32>
    %reduced = linalg.reduce ins(%added : tensor<2x2xf32>) outs(%init : tensor<2xf32>) dimensions = [1]
      (%element: f32, %acc: f32) {
        %sum = arith.addf %element, %acc : f32
        linalg.yield %sum : f32
      }
    %shifted = hivm.hir.vadd ins(%reduced, %three : tensor<2xf32>, f32) outs(%row : tensor<2xf32>) -> tensor<2xf32>
    bufferization.materialize_in_destination %shifted in writable %buffer : (tensor<2xf32>, memref<2xf32>) -> ()
  }
  %view = bufferization.to_tensor %buffer restrict writable : memref<2xf32>
  %result = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%view, %two : tensor<2xf32>, f32) outs(%row : tensor<2xf32>) -> tensor<2xf32>
  return
}

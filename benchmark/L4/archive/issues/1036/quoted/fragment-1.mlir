func.func @select_before_to_tensor(%cond: i1, %value: f32) -> tensor<16xf32> {
  %a = memref.alloc() : memref<16xf32>
  %b = memref.alloc() : memref<16xf32>
  hivm.hir.vbrc ins(%value : f32) outs(%a : memref<16xf32>)
  %selected = arith.select %cond, %a, %b : memref<16xf32>
  %t = bufferization.to_tensor %selected restrict writable : memref<16xf32>
  return %t : tensor<16xf32>
}

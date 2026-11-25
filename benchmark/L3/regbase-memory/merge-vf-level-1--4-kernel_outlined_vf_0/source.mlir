module {
func.func @kernel_outlined_vf_0(%arg0: memref<8x248xf32>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
  %cst = arith.constant dense<0.000000e+00> : vector<1x64xf32>
  %c1 = arith.constant 1 : index
  %c8 = arith.constant 8 : index
  %c64 = arith.constant 64 : index
  %c248 = arith.constant 248 : index
  %c0 = arith.constant 0 : index
  scf.for %arg1 = %c0 to %c8 step %c1 {
    scf.for %arg2 = %c0 to %c248 step %c64 {
      %0 = affine.min affine_map<(d0) -> (-d0 + 248, 64)>(%arg2)
      %subview = memref.subview %arg0[%arg1, %arg2] [1, %0] [1, 1] : memref<8x248xf32> to memref<1x?xf32, strided<[248, 1], offset: ?>>
      %1 = vector.create_mask %c1, %0 : vector<1x64xi1>
      vector.transfer_write %cst, %subview[%c0, %c0], %1 {in_bounds = [true, true]} : vector<1x64xf32>, memref<1x?xf32, strided<[248, 1], offset: ?>>
    }
  }
  return
}
func.func @kernel_outlined_vf_1(%arg0: memref<8x248xf32>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
  %cst = arith.constant dense<0.000000e+00> : vector<1x64xf32>
  %c1 = arith.constant 1 : index
  %c8 = arith.constant 8 : index
  %c64 = arith.constant 64 : index
  %c248 = arith.constant 248 : index
  %c0 = arith.constant 0 : index
  scf.for %arg1 = %c0 to %c8 step %c1 {
    scf.for %arg2 = %c0 to %c248 step %c64 {
      %0 = affine.min affine_map<(d0) -> (-d0 + 248, 64)>(%arg2)
      %subview = memref.subview %arg0[%arg1, %arg2] [1, %0] [1, 1] : memref<8x248xf32> to memref<1x?xf32, strided<[248, 1], offset: ?>>
      %1 = vector.create_mask %c1, %0 : vector<1x64xi1>
      vector.transfer_write %cst, %subview[%c0, %c0], %1 {in_bounds = [true, true]} : vector<1x64xf32>, memref<1x?xf32, strided<[248, 1], offset: ?>>
    }
  }
  return
}
func.func @not_merge_when_load_write_to_same_buffer(%arg2: memref<?xf32>, %arg0: index, %arg3: memref<?xf32>) {
  %cst = arith.constant 0.000000e+00 : f32
  %c0 = arith.constant 0 : index
  %alloc = memref.alloc() : memref<8x248xf32>
  %reinterpret_cast = memref.reinterpret_cast %arg2 to offset: [%arg0], sizes: [8, 248], strides: [128, 1] : memref<?xf32> to memref<8x248xf32, strided<[128, 1], offset: ?>>
  call @kernel_outlined_vf_0(%alloc) {hivm.vector_function, no_inline} : (memref<8x248xf32>) -> ()
  %subview = memref.subview %reinterpret_cast[0, 0] [%arg0, 128] [1, 1] : memref<8x248xf32, strided<[128, 1], offset: ?>> to memref<?x128xf32, strided<[128, 1], offset: ?>>
  %subview_0 = memref.subview %alloc[0, 0] [%arg0, 128] [1, 1] : memref<8x248xf32> to memref<?x128xf32, strided<[248, 1]>>
  hivm.hir.load ins(%subview : memref<?x128xf32, strided<[128, 1], offset: ?>>) outs(%subview_0 : memref<?x128xf32, strided<[248, 1]>>) pad_mode = <PadValue> pad_value = %cst : f32 left_padding_num = %c0 : index
  %alloc_2 = memref.alloc() : memref<8x248xf32>
  call @kernel_outlined_vf_1(%alloc_2) {hivm.vector_function, no_inline} : (memref<8x248xf32>) -> ()
  return
}
}

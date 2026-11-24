module attributes {dlti.target_system_spec = #dlti.target_system_spec<"NPU" : #hacc.target_device_spec<#dlti.dl_entry<"L0C_SIZE", 1048576 : i32>, #dlti.dl_entry<"UB_ALIGN_SIZE", 256 : i32>>>} {
  func.func @test_cube(%arg0: index, %arg1: index, %arg2: memref<?xf16>, %arg3: index, %arg4: tensor<4x128x498xf32>, %arg5: memref<4x128x498xf16>) -> tensor<128xf32> {
    %c1 = arith.constant 1 : index
    %0 = tensor.empty() : tensor<128xf32>
    %1 = scf.for %arg6 = %arg0 to %arg1 step %c1 iter_args(%arg7 = %0) -> (tensor<128xf32>) {
      %2 = tensor.empty() : tensor<128x498xf32>
      %extracted_slice = tensor.extract_slice %arg4[%arg3, 0, 0] [1, 128, 498] [1, 1, 1] : tensor<4x128x498xf32> to tensor<128x498xf32>
      %3 = hivm.hir.load ins(%extracted_slice : tensor<128x498xf32>) outs(%2 : tensor<128x498xf32>) -> tensor<128x498xf32>
      %4 = tensor.empty() : tensor<128x1xf32>
      %5 = hivm.hir.vreduce <max> ins(%3 : tensor<128x498xf32>) outs(%4 : tensor<128x1xf32>) reduce_dims = [1] -> tensor<128x1xf32>
      %collapsed = tensor.collapse_shape %5 [[0, 1]] : tensor<128x1xf32> into tensor<128xf32>
      %6 = tensor.empty() : tensor<128x498xf16>
      %7 = hivm.hir.vcast ins(%3 : tensor<128x498xf32>) outs(%6 : tensor<128x498xf16>) -> tensor<128x498xf16>
      %subview = memref.subview %arg5[%arg3, 0, 0] [1, 128, 498] [1, 1, 1] : memref<4x128x498xf16> to memref<1x128x498xf16, strided<[63744, 498, 1], offset: ?>>
      %collapse_shape = memref.collapse_shape %subview [[0, 1], [2]] : memref<1x128x498xf16, strided<[63744, 498, 1], offset: ?>> into memref<128x498xf16, strided<[498, 1], offset: ?>>
      hivm.hir.store ins(%7 : tensor<128x498xf16>) outs(%collapse_shape : memref<128x498xf16, strided<[498, 1], offset: ?>>)
      scf.yield %collapsed : tensor<128xf32>
    } {hivm.loop_core_type = #hivm.tcore_type<VECTOR>}
    return %1 : tensor<128xf32>
  }
}


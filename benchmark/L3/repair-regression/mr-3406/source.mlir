module attributes {dlti.target_system_spec = #dlti.target_system_spec<"NPU" : #hacc.target_device_spec<#dlti.dl_entry<"L0C_SIZE", 1048576 : i32>, #dlti.dl_entry<"UB_ALIGN_SIZE", 256 : i32>>>} {
  func.func @test_cube(%lb: index, %ub: index, %gm_b: memref<?xf16>, %gm_offset: index, %gm_src: tensor<4x128x498xf32>, %gm_dst: memref<4x128x498xf16>) -> (tensor<128xf32>) {
    %c1 = arith.constant 1 : index
    %accum = tensor.empty() : tensor<128xf32>
    %res = scf.for %arg0 = %lb to %ub step %c1 iter_args(%arg1 = %accum) -> (tensor<128xf32>) {
      %empty = tensor.empty() : tensor<128x498xf32>
      %extracted_slice = tensor.extract_slice %gm_src[%gm_offset, 0, 0] [1, 128, 498] [1, 1, 1] : tensor<4x128x498xf32> to tensor<128x498xf32>
      %load = hivm.hir.load ins(%extracted_slice : tensor<128x498xf32>) outs(%empty : tensor<128x498xf32>) init_out_buffer = false -> tensor<128x498xf32>
      %empty1 = tensor.empty() : tensor<128x1xf32>
      %reduced = hivm.hir.vreduce <max> ins(%load : tensor<128x498xf32>) outs(%empty1 : tensor<128x1xf32>) reduce_dims = [1] -> tensor<128x1xf32>
      %collapsed = tensor.collapse_shape %reduced [[0, 1]] : tensor<128x1xf32> into tensor<128xf32>
      %empty2 = tensor.empty() : tensor<128x498xf16>
      %cast = hivm.hir.vcast ins(%load : tensor<128x498xf32>) outs(%empty2 : tensor<128x498xf16>) -> tensor<128x498xf16>
      %subview = memref.subview %gm_dst[%gm_offset, 0, 0] [1, 128, 498] [1, 1, 1] : memref<4x128x498xf16> to memref<1x128x498xf16, strided<[63744, 498, 1], offset: ?>>
      %collapse_shape = memref.collapse_shape %subview [[0, 1], [2]] : memref<1x128x498xf16, strided<[63744, 498, 1], offset: ?>> into memref<128x498xf16, strided<[498, 1], offset: ?>>
      hivm.hir.store ins(%cast : tensor<128x498xf16>) outs(%collapse_shape : memref<128x498xf16, strided<[498, 1], offset: ?>>)
      scf.yield %collapsed : tensor<128xf32>
    } {hivm.loop_core_type = #hivm.tcore_type<VECTOR>}
    return %res : tensor<128xf32>
  }
}

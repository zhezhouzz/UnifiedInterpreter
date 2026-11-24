module {
  func.func @test_vbrc_temp_buffer_first_axis_align() {
    %alloc = memref.alloc() : memref<1x32xf16>
    %alloc_0 = memref.alloc() : memref<10x32xf16>
    hivm.hir.vbrc ins(%alloc : memref<1x32xf16>) outs(%alloc_0 : memref<10x32xf16>) broadcast_dims = [0]
    return
  }
}


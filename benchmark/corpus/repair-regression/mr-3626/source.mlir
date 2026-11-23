func.func @test_vbrc_temp_buffer_first_axis_align() {
  %src = memref.alloc() : memref<1x32xf16>
  %dst = memref.alloc() : memref<10x32xf16>

  hivm.hir.vbrc ins(%src : memref<1x32xf16>)
                outs(%dst : memref<10x32xf16>)
                broadcast_dims = [0]

  return
}

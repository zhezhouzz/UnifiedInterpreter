module {
  func.func @test_block_sync_loop(%arg0: memref<16xf32>, %arg1: memref<16xf32>, %arg2: memref<256xf32>, %arg3: memref<256xf32>, %arg4: i1, %arg5: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}) attributes {hacc.always_inline, hfusion.fusion_kind = #hfusion.fusion_kind<MIX_CV>, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    hivm.hir.set_ffts_base_addr %arg5
    %true = arith.constant true
    %c16 = arith.constant 16 : index
    %c256 = arith.constant 256 : index
    %alloc = memref.alloc() : memref<16xf32>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32>) outs(%alloc : memref<16xf32>)
    %alloc_0 = memref.alloc() : memref<16xf32>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32>) outs(%alloc_0 : memref<16xf32>)
    %alloc_1 = memref.alloc() : memref<256xf32>
    hivm.hir.mmadL1 ins(%alloc, %alloc_0, %true, %c16, %c256, %c16 : memref<16xf32>, memref<16xf32>, i1, index, index, index) outs(%alloc_1 : memref<256xf32>)
    hivm.hir.fixpipe {enable_nz2nd} ins(%alloc_1 : memref<256xf32>) outs(%arg2 : memref<256xf32>)
    %0 = bufferization.to_tensor %arg2 restrict writable : memref<256xf32>
    %1 = tensor.empty() : tensor<256xf32>
    %2 = hivm.hir.load ins(%0 : tensor<256xf32>) outs(%1 : tensor<256xf32>) -> tensor<256xf32>
    %3 = tensor.empty() : tensor<256xf32>
    %4 = hivm.hir.vsub ins(%2, %2 : tensor<256xf32>, tensor<256xf32>) outs(%3 : tensor<256xf32>) -> tensor<256xf32>
    %5 = tensor.empty() : tensor<256xf32>
    %6 = hivm.hir.store ins(%4 : tensor<256xf32>) outs(%5 : tensor<256xf32>) -> tensor<256xf32>
    return
  }
}

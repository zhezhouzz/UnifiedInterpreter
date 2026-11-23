module {
  func.func @test_block_sync_mmadmx(%arg0: memref<32xf8E5M2, #hivm.address_space<gm>>, %arg1: memref<32xf8E5M2, #hivm.address_space<gm>>, %arg2: memref<2xui8, #hivm.address_space<gm>>, %arg3: memref<2xui8, #hivm.address_space<gm>>, %arg4: memref<1024xf32, #hivm.address_space<gm>>, %arg5: memref<1024xf32, #hivm.address_space<gm>>, %arg6: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>}) attributes {hacc.always_inline, hfusion.fusion_kind = #hfusion.fusion_kind<MIX_CV>, hivm.func_core_type = #hivm.func_core_type<MIX>} {
    hivm.hir.set_ffts_base_addr %arg6
    %c64_i64 = arith.constant 64 : i64
    %c128_i64 = arith.constant 128 : i64
    %c192_i64 = arith.constant 192 : i64
    %true = arith.constant true
    %c32 = arith.constant 32 : index
    %c32_0 = arith.constant 32 : index
    %c0_i64 = arith.constant 0 : i64
    %alloc = memref.alloc() : memref<32xf8E5M2, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<32xf8E5M2, #hivm.address_space<gm>>) outs(%alloc : memref<32xf8E5M2, #hivm.address_space<cbuf>>)
    %0 = hivm.hir.pointer_cast(%c64_i64) : memref<32xf8E5M2, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg1 : memref<32xf8E5M2, #hivm.address_space<gm>>) outs(%0 : memref<32xf8E5M2, #hivm.address_space<cbuf>>)
    %scaleA = hivm.hir.pointer_cast(%c128_i64) : memref<2xui8, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg2 : memref<2xui8, #hivm.address_space<gm>>) outs(%scaleA : memref<2xui8, #hivm.address_space<cbuf>>)
    %scaleB = hivm.hir.pointer_cast(%c192_i64) : memref<2xui8, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg3 : memref<2xui8, #hivm.address_space<gm>>) outs(%scaleB : memref<2xui8, #hivm.address_space<cbuf>>)
    %1 = hivm.hir.pointer_cast(%c0_i64) : memref<1024xf32, #hivm.address_space<cc>>
    hivm.hir.mmadmxL1 ins(%alloc, %0, %scaleA, %scaleB, %true, %c32, %c32_0, %c32 : memref<32xf8E5M2, #hivm.address_space<cbuf>>, memref<32xf8E5M2, #hivm.address_space<cbuf>>, memref<2xui8, #hivm.address_space<cbuf>>, memref<2xui8, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%1 : memref<1024xf32, #hivm.address_space<cc>>)
    hivm.hir.fixpipe {enable_nz2nd} ins(%1 : memref<1024xf32, #hivm.address_space<cc>>) outs(%arg4 : memref<1024xf32, #hivm.address_space<gm>>)
    %alloc_0 = memref.alloc() : memref<1024xf32, #hivm.address_space<ub>>
    %alloc_1 = memref.alloc() : memref<1024xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg4 : memref<1024xf32, #hivm.address_space<gm>>) outs(%alloc_0 : memref<1024xf32, #hivm.address_space<ub>>)
    hivm.hir.vadd ins(%alloc_0, %alloc_1 : memref<1024xf32, #hivm.address_space<ub>>, memref<1024xf32, #hivm.address_space<ub>>) outs(%alloc_0 : memref<1024xf32, #hivm.address_space<ub>>)
    hivm.hir.store ins(%alloc_0 : memref<1024xf32, #hivm.address_space<ub>>) outs(%arg5 : memref<1024xf32, #hivm.address_space<gm>>)
    return
  }
}

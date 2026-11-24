
module {
  func.func @test_tensor_insert_no_crash(
      %arg0: memref<16xf32, #hivm.address_space<gm>>,
      %arg1: memref<256xf32, #hivm.address_space<gm>>,
      %arg2: memref<256xf32, #hivm.address_space<gm>>,
      %arg3: f32,
      %arg4: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>})
      attributes {hacc.always_inline,
                  hfusion.fusion_kind = #hfusion.fusion_kind<MIX_CV>,
                  hivm.func_core_type = #hivm.func_core_type<MIX>} {
    hivm.hir.set_ffts_base_addr %arg4
    %c0 = arith.constant 0 : index
    %c16 = arith.constant 16 : index
    %c256 = arith.constant 256 : index
    %c64_i64 = arith.constant 64 : i64
    %c0_i64 = arith.constant 0 : i64
    %true = arith.constant true

    %alloc_cbuf = memref.alloc() : memref<16xf32, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%alloc_cbuf : memref<16xf32, #hivm.address_space<cbuf>>)
    %cbuf1 = hivm.hir.pointer_cast(%c64_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%cbuf1 : memref<16xf32, #hivm.address_space<cbuf>>)
    %cc = hivm.hir.pointer_cast(%c0_i64) : memref<256xf32, #hivm.address_space<cc>>
    hivm.hir.mmadL1 ins(%alloc_cbuf, %cbuf1, %true, %c16, %c256, %c16 : memref<16xf32, #hivm.address_space<cbuf>>, memref<16xf32, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%cc : memref<256xf32, #hivm.address_space<cc>>)
    hivm.hir.fixpipe {enable_nz2nd} ins(%cc : memref<256xf32, #hivm.address_space<cc>>) outs(%arg1 : memref<256xf32, #hivm.address_space<gm>>)

    %alloc_ub = memref.alloc() : memref<256xf32, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg1 : memref<256xf32, #hivm.address_space<gm>>) outs(%alloc_ub : memref<256xf32, #hivm.address_space<ub>>)

    %empty = tensor.empty() : tensor<1xf32>
    %inserted = tensor.insert %arg3 into %empty[%c0] {hivm.tcore_type = #hivm.tcore_type<VECTOR>} : tensor<1xf32>
    %extracted = tensor.extract %inserted[%c0] {hivm.tcore_type = #hivm.tcore_type<VECTOR>} : tensor<1xf32>

    hivm.hir.store ins(%alloc_ub : memref<256xf32, #hivm.address_space<ub>>) outs(%arg2 : memref<256xf32, #hivm.address_space<gm>>)
    return
  }
}

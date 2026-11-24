#gm = #hivm.address_space<gm>
#ub = #hivm.address_space<ub>
!gm_buffer = memref<?xf16, #gm>
!gm_tile = memref<1024xf16, strided<[1], offset: ?>, #gm>
!ub_tile = memref<1024xf16, #ub>

// 单个 Vector 核处理 tile_count 个连续块，每块包含 1024 个 f16 元素。
func.func @issue316_vexp(%input: !gm_buffer, %output: !gm_buffer, %tile_count: index)
    attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>,
                hivm.func_core_type = #hivm.func_core_type<AIV>} {
  %zero = arith.constant 0 : index
  %one = arith.constant 1 : index
  %width = arith.constant 1024 : index
  scf.for %i = %zero to %tile_count step %one {
    %offset = arith.muli %i, %width : index
    %src = memref.subview %input[%offset] [1024] [1] : !gm_buffer to !gm_tile
    %dst = memref.subview %output[%offset] [1024] [1] : !gm_buffer to !gm_tile
    %local = memref.alloc() : !ub_tile
    annotation.mark %local {hivm.multi_buffer = 2 : i32} : !ub_tile
    %result = memref.alloc() : !ub_tile
    hivm.hir.load ins(%src : !gm_tile) outs(%local : !ub_tile)
    hivm.hir.vexp ins(%local : !ub_tile) outs(%result : !ub_tile)
    hivm.hir.store ins(%result : !ub_tile) outs(%dst : !gm_tile)
  }
  return
}

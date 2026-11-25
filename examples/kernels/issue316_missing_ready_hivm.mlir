#gm = #hivm.address_space<gm>
#ub = #hivm.address_space<ub>
!gm_buffer = memref<?xf16, #gm>
!gm_tile = memref<1024xf16, strided<[1], offset: ?>, #gm>
!ub_tile = memref<1024xf16, #ub>

func.func @issue316_vexp(%input: !gm_buffer, %output: !ub_tile, %tile_count: index)
    attributes {hacc.function_kind = #hacc.function_kind<DEVICE>,
                hivm.func_core_type = #hivm.func_core_type<AIV>} {
  %zero = arith.constant 0 : index
  %one = arith.constant 1 : index
  %two = arith.constant 2 : index
  %width = arith.constant 1024 : index
  %bufA = memref.alloc() : !ub_tile
  %bufB = memref.alloc() : !ub_tile
  hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
  hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
  scf.for %i = %zero to %tile_count step %one {
    %slot = arith.remui %i, %two : index
    %event = arith.index_cast %slot : index to i64
    %useA = arith.cmpi eq, %slot, %zero : index
    %local = arith.select %useA, %bufA, %bufB : !ub_tile
    %offset = arith.muli %i, %width : index
    %src = memref.subview %input[%offset] [1024] [1] : !gm_buffer to !gm_tile
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, %event]
    hivm.hir.load ins(%src : !gm_tile) outs(%local : !ub_tile)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, %event]
    hivm.hir.vexp ins(%local : !ub_tile) outs(%output : !ub_tile)
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, %event]
    hivm.hir.pipe_barrier[<PIPE_V>]
  }
  hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
  hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
  hivm.hir.pipe_barrier[<PIPE_ALL>]
  return
}

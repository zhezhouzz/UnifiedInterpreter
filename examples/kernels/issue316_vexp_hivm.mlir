#gm = #hivm.address_space<gm>
#ub = #hivm.address_space<ub>
!gm_buffer = memref<?xf16, #gm>
!gm_tile = memref<1024xf16, strided<[1], offset: ?>, #gm>
!ub_tile = memref<1024xf16, #ub>

// 单个 Vector 核处理 tile_count 个连续块，每块包含 1024 个 f16 元素。
// 手动管理缓冲区和事件，编译时使用 --enable-auto-multi-buffer=false --disable-hivm-auto-inject-sync。
func.func @issue316_vexp(%input: !gm_buffer, %output: !gm_buffer, %tile_count: index)
    attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>,
                hivm.func_core_type = #hivm.func_core_type<AIV>} {
  %zero = arith.constant 0 : index
  %one = arith.constant 1 : index
  %two = arith.constant 2 : index
  %width = arith.constant 1024 : index
  // 每块占用 2048 字节。两个输入缓冲区和一个结果缓冲区贯穿整个循环。
  %bufA = memref.alloc() : !ub_tile
  %bufB = memref.alloc() : !ub_tile
  %result = memref.alloc() : !ub_tile

  // 初始时，两个输入缓冲区均可搬入，结果缓冲区也可写入。
  hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
  hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
  hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
  scf.for %i = %zero to %tile_count step %one {
    %slot = arith.remui %i, %two : index
    %event = arith.index_cast %slot : index to i64
    %useA = arith.cmpi eq, %slot, %zero : index
    %local = arith.select %useA, %bufA, %bufB : !ub_tile
    %offset = arith.muli %i, %width : index
    %src = memref.subview %input[%offset] [1024] [1] : !gm_buffer to !gm_tile
    %dst = memref.subview %output[%offset] [1024] [1] : !gm_buffer to !gm_tile
    // MTE2 等待所选输入缓冲区可用，搬入完成后通知 Vector。
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, %event]
    hivm.hir.load ins(%src : !gm_tile) outs(%local : !ub_tile)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, %event]

    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, %event]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
    hivm.hir.vexp ins(%local : !ub_tile) outs(%result : !ub_tile)
    // Vector 用完本轮输入后，允许第 i+2 轮覆盖同一缓冲区。
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, %event]
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]

    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%result : !ub_tile) outs(%dst : !gm_tile)
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
  }
  hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>]
  hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID1>]
  hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_V>, <EVENT_ID0>]
  hivm.hir.pipe_barrier[<PIPE_ALL>]
  return
}

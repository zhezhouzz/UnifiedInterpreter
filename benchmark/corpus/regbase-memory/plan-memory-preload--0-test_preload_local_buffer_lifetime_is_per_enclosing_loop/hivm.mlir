module {
  func.func @test_preload_local_buffer_lifetime_is_per_enclosing_loop(%arg0: memref<81920xi8, #hivm.address_space<gm>>, %arg1: memref<81920xi8, #hivm.address_space<gm>>, %arg2: memref<40960xi8, #hivm.address_space<gm>>, %arg3: memref<40960xi8, #hivm.address_space<gm>>) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c4 = arith.constant 4 : index
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    scf.for %arg4 = %c0 to %c4 step %c1 {
      scope.scope : () -> () {
        %alloc = memref.alloc() : memref<81920xi8, #hivm.address_space<ub>>
        annotation.mark %alloc {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<81920xi8, #hivm.address_space<ub>>
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        hivm.hir.load ins(%arg0 : memref<81920xi8, #hivm.address_space<gm>>) outs(%alloc : memref<81920xi8, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.store ins(%alloc : memref<81920xi8, #hivm.address_space<ub>>) outs(%arg1 : memref<81920xi8, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        scope.return
      }
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    scf.for %arg4 = %c0 to %c4 step %c1 {
      scope.scope : () -> () {
        %alloc = memref.alloc() : memref<40960xi8, #hivm.address_space<ub>>
        annotation.mark %alloc {hivm.multi_buffer = 4 : i32, hivm.preload_local_buffer = 1 : i32} : memref<40960xi8, #hivm.address_space<ub>>
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        hivm.hir.load ins(%arg2 : memref<40960xi8, #hivm.address_space<gm>>) outs(%alloc : memref<40960xi8, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.store ins(%alloc : memref<40960xi8, #hivm.address_space<ub>>) outs(%arg3 : memref<40960xi8, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        scope.return
      }
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    return
  }
}


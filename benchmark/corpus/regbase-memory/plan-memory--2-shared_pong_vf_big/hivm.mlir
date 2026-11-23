module {
  func.func private @shared_pong_vf_big(%arg0: memref<12288xi64, strided<[1]>, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }
  func.func private @shared_pong_vf_a1(%arg0: memref<64x64xf16, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }
  func.func private @shared_pong_vf_cov(%arg0: memref<64x64xi1, strided<[256, 1]>, #hivm.address_space<ub>>, %arg1: memref<12264xi64, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }
  func.func private @shared_pong_vf_m1(%arg0: memref<64x64xi1, strided<[256, 1]>, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }
  func.func private @shared_pong_vf_m3(%arg0: memref<64x256x1xi1, #hivm.address_space<ub>>, %arg1: memref<64x256x1xi1, #hivm.address_space<ub>>, %arg2: memref<64x256x1xi1, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }
  func.func @shared_pong_l1_outline(%arg0: memref<6144xi64, #hivm.address_space<gm>>, %arg1: memref<64x64xf16, #hivm.address_space<gm>>, %arg2: memref<64x64xf16, #hivm.address_space<gm>>) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c4 = arith.constant 4 : index
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    scf.for %arg3 = %c0 to %c4 step %c1 {
      %alloc = memref.alloc() : memref<12288xi64, #hivm.address_space<ub>>
      annotation.mark %alloc {hivm.multi_buffer = 2 : i32} : memref<12288xi64, #hivm.address_space<ub>>
      %subview = memref.subview %alloc[0] [6144] [1] : memref<12288xi64, #hivm.address_space<ub>> to memref<6144xi64, strided<[1]>, #hivm.address_space<ub>>
      hivm.hir.pipe_barrier[<PIPE_MTE2>]
      hivm.hir.load ins(%arg0 : memref<6144xi64, #hivm.address_space<gm>>) outs(%subview : memref<6144xi64, strided<[1]>, #hivm.address_space<ub>>)
      %subview_0 = memref.subview %alloc[0] [12288] [1] : memref<12288xi64, #hivm.address_space<ub>> to memref<12288xi64, strided<[1]>, #hivm.address_space<ub>>
      func.call @shared_pong_vf_big(%subview_0) {hivm.vector_function, no_inline} : (memref<12288xi64, strided<[1]>, #hivm.address_space<ub>>) -> ()
      %alloc_1 = memref.alloc() : memref<64x64xf16, #hivm.address_space<ub>>
      annotation.mark %alloc_1 {hivm.multi_buffer = 2 : i32} : memref<64x64xf16, #hivm.address_space<ub>>
      hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      hivm.hir.load ins(%arg1 : memref<64x64xf16, #hivm.address_space<gm>>) outs(%alloc_1 : memref<64x64xf16, #hivm.address_space<ub>>)
      hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      func.call @shared_pong_vf_a1(%alloc_1) {hivm.vector_function, no_inline} : (memref<64x64xf16, #hivm.address_space<ub>>) -> ()
      hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
      hivm.hir.store ins(%alloc_1 : memref<64x64xf16, #hivm.address_space<ub>>) outs(%arg2 : memref<64x64xf16, #hivm.address_space<gm>>)
      hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
      %alloc_2 = memref.alloc() : memref<64x256x1xi1, #hivm.address_space<ub>>
      %subview_3 = memref.subview %alloc_2[0, 0, 0] [64, 64, 1] [1, 1, 1] : memref<64x256x1xi1, #hivm.address_space<ub>> to memref<64x64xi1, strided<[256, 1]>, #hivm.address_space<ub>>
      func.call @shared_pong_vf_m1(%subview_3) {hivm.vector_function, no_inline} : (memref<64x64xi1, strided<[256, 1]>, #hivm.address_space<ub>>) -> ()
      %alloc_4 = memref.alloc() : memref<12264xi64, #hivm.address_space<ub>>
      func.call @shared_pong_vf_cov(%subview_3, %alloc_4) {hivm.vector_function, no_inline} : (memref<64x64xi1, strided<[256, 1]>, #hivm.address_space<ub>>, memref<12264xi64, #hivm.address_space<ub>>) -> ()
      %alloc_5 = memref.alloc() : memref<64x256x1xi1, #hivm.address_space<ub>>
      %alloc_6 = memref.alloc() : memref<64x256x1xi1, #hivm.address_space<ub>>
      func.call @shared_pong_vf_m3(%alloc_2, %alloc_5, %alloc_6) {hivm.vector_function, no_inline} : (memref<64x256x1xi1, #hivm.address_space<ub>>, memref<64x256x1xi1, #hivm.address_space<ub>>, memref<64x256x1xi1, #hivm.address_space<ub>>) -> ()
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
    return
  }
}


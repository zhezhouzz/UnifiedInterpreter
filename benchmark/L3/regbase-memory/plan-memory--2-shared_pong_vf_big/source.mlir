module {
  func.func private @shared_pong_vf_big(%a: memref<12288xi64, strided<[1]>, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }
  func.func private @shared_pong_vf_a1(%a: memref<64x64xf16, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }
  func.func private @shared_pong_vf_cov(%m: memref<64x64xi1, strided<[256, 1]>, #hivm.address_space<ub>>, %c: memref<12264xi64, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }
  func.func private @shared_pong_vf_m1(%m: memref<64x64xi1, strided<[256, 1]>, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }
  func.func private @shared_pong_vf_m3(%a: memref<64x256x1xi1, #hivm.address_space<ub>>, %b: memref<64x256x1xi1, #hivm.address_space<ub>>, %c: memref<64x256x1xi1, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }

  func.func @shared_pong_l1_outline(%src_big: memref<6144xi64, #hivm.address_space<gm>>, %src: memref<64x64xf16, #hivm.address_space<gm>>, %dst: memref<64x64xf16, #hivm.address_space<gm>>) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c4 = arith.constant 4 : index
    scf.for %i = %c0 to %c4 step %c1 {
      %A0 = memref.alloc() : memref<12288xi64, #hivm.address_space<ub>>
      annotation.mark %A0 {hivm.multi_buffer = 2 : i32} : memref<12288xi64, #hivm.address_space<ub>>
      %A0v = memref.subview %A0[0] [6144] [1] : memref<12288xi64, #hivm.address_space<ub>> to memref<6144xi64, strided<[1]>, #hivm.address_space<ub>>
      hivm.hir.load ins(%src_big : memref<6144xi64, #hivm.address_space<gm>>) outs(%A0v : memref<6144xi64, strided<[1]>, #hivm.address_space<ub>>)
      %A0s = memref.subview %A0[0] [12288] [1] : memref<12288xi64, #hivm.address_space<ub>> to memref<12288xi64, strided<[1]>, #hivm.address_space<ub>>
      func.call @shared_pong_vf_big(%A0s) {hivm.vector_function, no_inline} : (memref<12288xi64, strided<[1]>, #hivm.address_space<ub>>) -> ()

      %A1 = memref.alloc() : memref<64x64xf16, #hivm.address_space<ub>>
      annotation.mark %A1 {hivm.multi_buffer = 2 : i32} : memref<64x64xf16, #hivm.address_space<ub>>
      hivm.hir.load ins(%src : memref<64x64xf16, #hivm.address_space<gm>>) outs(%A1 : memref<64x64xf16, #hivm.address_space<ub>>)
      func.call @shared_pong_vf_a1(%A1) {hivm.vector_function, no_inline} : (memref<64x64xf16, #hivm.address_space<ub>>) -> ()
      hivm.hir.store ins(%A1 : memref<64x64xf16, #hivm.address_space<ub>>) outs(%dst : memref<64x64xf16, #hivm.address_space<gm>>)

      %A3 = memref.alloc() : memref<64x256x1xi1, #hivm.address_space<ub>>
      %A3s = memref.subview %A3[0, 0, 0] [64, 64, 1] [1, 1, 1] : memref<64x256x1xi1, #hivm.address_space<ub>> to memref<64x64xi1, strided<[256, 1]>, #hivm.address_space<ub>>
      func.call @shared_pong_vf_m1(%A3s) {hivm.vector_function, no_inline} : (memref<64x64xi1, strided<[256, 1]>, #hivm.address_space<ub>>) -> ()

      %A2 = memref.alloc() : memref<12264xi64, #hivm.address_space<ub>>
      func.call @shared_pong_vf_cov(%A3s, %A2) {hivm.vector_function, no_inline} : (memref<64x64xi1, strided<[256, 1]>, #hivm.address_space<ub>>, memref<12264xi64, #hivm.address_space<ub>>) -> ()

      %A4 = memref.alloc() : memref<64x256x1xi1, #hivm.address_space<ub>>
      %A5 = memref.alloc() : memref<64x256x1xi1, #hivm.address_space<ub>>
      func.call @shared_pong_vf_m3(%A3, %A4, %A5) {hivm.vector_function, no_inline} : (memref<64x256x1xi1, #hivm.address_space<ub>>, memref<64x256x1xi1, #hivm.address_space<ub>>, memref<64x256x1xi1, #hivm.address_space<ub>>) -> ()
    }
    return
  }
}

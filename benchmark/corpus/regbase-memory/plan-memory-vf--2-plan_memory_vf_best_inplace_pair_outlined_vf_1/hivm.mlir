module {
  func.func @plan_memory_vf_best_inplace_pair_outlined_vf_1(%arg0: memref<31744xf32, #hivm.address_space<ub>>, %arg1: memref<31744xf8E4M3FN, #hivm.address_space<ub>>, %arg2: memref<31744xf32, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %cst = arith.constant 0.000000e+00 : f32
    %c64 = arith.constant 64 : index
    %c31744 = arith.constant 31744 : index
    %c0 = arith.constant 0 : index
    scf.for %arg3 = %c0 to %c31744 step %c64 {
      %subview = memref.subview %arg0[%arg3] [64] [1] : memref<31744xf32, #hivm.address_space<ub>> to memref<64xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %subview_0 = memref.subview %arg2[%arg3] [64] [1] : memref<31744xf32, #hivm.address_space<ub>> to memref<64xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %0 = vector.transfer_read %subview[%c0], %cst {in_bounds = [true]} : memref<64xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<64xf32>
      %1 = math.log %0 : vector<64xf32>
      vector.transfer_write %1, %subview_0[%c0] {in_bounds = [true]} : vector<64xf32>, memref<64xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %subview_1 = memref.subview %arg1[%arg3] [64] [1] : memref<31744xf8E4M3FN, #hivm.address_space<ub>> to memref<64xf8E4M3FN, strided<[1], offset: ?>, #hivm.address_space<ub>>
      %2 = arith.truncf %1 {enable_saturate = false, round_mode = #hfusion.round_mode<rint>, unsigned_mode = #hfusion.unsigned_mode<si2si>} : vector<64xf32> to vector<64xf8E4M3FN>
      vector.transfer_write %2, %subview_1[%c0] {in_bounds = [true]} : vector<64xf8E4M3FN>, memref<64xf8E4M3FN, strided<[1], offset: ?>, #hivm.address_space<ub>>
    }
    return
  }
  func.func @plan_memory_vf_best_inplace_pair(%arg0: memref<?xf8E4M3FN, #hivm.address_space<gm>>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vf_mode = #hivm.vf_mode<SIMD>} {
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<31744xf32, #hivm.address_space<ub>>
    hivm.hir.debug {debugtype = "print", hex = false, prefix = " x0: ", tcoretype = #hivm.tcore_type<CUBE_OR_VECTOR>} %alloc : memref<31744xf32, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() {alignment = 64 : i64} : memref<31744xf8E4M3FN, #hivm.address_space<ub>>
    %alloc_1 = memref.alloc() {alignment = 64 : i64} : memref<31744xf32, #hivm.address_space<ub>>
    call @plan_memory_vf_best_inplace_pair_outlined_vf_1(%alloc, %alloc_0, %alloc_1) {hivm.vector_function, no_inline} : (memref<31744xf32, #hivm.address_space<ub>>, memref<31744xf8E4M3FN, #hivm.address_space<ub>>, memref<31744xf32, #hivm.address_space<ub>>) -> ()
    hivm.hir.set_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_S>, <EVENT_ID0>]
    hivm.hir.debug {debugtype = "print", hex = false, prefix = " ret: ", tcoretype = #hivm.tcore_type<CUBE_OR_VECTOR>} %alloc_1 : memref<31744xf32, #hivm.address_space<ub>>
    %reinterpret_cast = memref.reinterpret_cast %arg0 to offset: [0], sizes: [31744], strides: [1] : memref<?xf8E4M3FN, #hivm.address_space<gm>> to memref<31744xf8E4M3FN, strided<[1]>, #hivm.address_space<gm>>
    hivm.hir.store ins(%alloc_0 : memref<31744xf8E4M3FN, #hivm.address_space<ub>>) outs(%reinterpret_cast : memref<31744xf8E4M3FN, strided<[1]>, #hivm.address_space<gm>>)
    hivm.hir.pipe_barrier[<PIPE_ALL>]
    return
  }
}


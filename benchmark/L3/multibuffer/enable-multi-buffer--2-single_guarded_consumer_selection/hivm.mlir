module {
  func.func @single_guarded_consumer_selection(%arg0: memref<16xf16, #hivm.address_space<gm>>, %arg1: i1) {
    %c0_i64 = arith.constant 0 : i64
    %c32_i64 = arith.constant 32 : i64
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c4 = arith.constant 4 : index
    scf.for %arg2 = %c0 to %c4 step %c1 {
      %0 = hivm.hir.pointer_cast(%c0_i64, %c32_i64) : memref<16xf16, #hivm.address_space<ub>>
      annotation.mark %0 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
      "test.before_guard"() : () -> ()
      scf.if %arg1 {
        hivm.hir.pipe_barrier[<PIPE_MTE2>]
        hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%0 : memref<16xf16, #hivm.address_space<ub>>)
      }
    }
    return
  }
}


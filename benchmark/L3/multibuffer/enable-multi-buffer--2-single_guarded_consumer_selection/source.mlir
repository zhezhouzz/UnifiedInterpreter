module {
  func.func @single_guarded_consumer_selection(
      %src: memref<16xf16, #hivm.address_space<gm>>, %cond: i1) {
    %a0 = arith.constant 0 : i64
    %a1 = arith.constant 32 : i64
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c4 = arith.constant 4 : index

    scf.for %iv = %c0 to %c4 step %c1 {
      %buffer = hivm.hir.pointer_cast(%a0, %a1)
        : memref<16xf16, #hivm.address_space<ub>>
      annotation.mark %buffer {hivm.multi_buffer = 2 : i32}
        : memref<16xf16, #hivm.address_space<ub>>
      "test.before_guard"() : () -> ()
      scf.if %cond {
        hivm.hir.load
          ins(%src : memref<16xf16, #hivm.address_space<gm>>)
          outs(%buffer : memref<16xf16, #hivm.address_space<ub>>)
      }
    }
    return
  }
}

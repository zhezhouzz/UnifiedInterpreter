
module {

  func.func @test_preload_local_buffer_lifetime_is_per_enclosing_loop(
      %src0: memref<81920xi8, #hivm.address_space<gm>>,
      %dst0: memref<81920xi8, #hivm.address_space<gm>>,
      %src1: memref<40960xi8, #hivm.address_space<gm>>,
      %dst1: memref<40960xi8, #hivm.address_space<gm>>) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c4 = arith.constant 4 : index

    scf.for %i = %c0 to %c4 step %c1 {
      scope.scope : () -> () {
        %buf0 = memref.alloc() : memref<81920xi8, #hivm.address_space<ub>>
        annotation.mark %buf0 {
          hivm.multi_buffer = 2 : i32,
          hivm.preload_local_buffer = 1 : i32
        } : memref<81920xi8, #hivm.address_space<ub>>

        hivm.hir.load ins(%src0 : memref<81920xi8, #hivm.address_space<gm>>)
                      outs(%buf0 : memref<81920xi8, #hivm.address_space<ub>>)
        hivm.hir.store ins(%buf0 : memref<81920xi8, #hivm.address_space<ub>>)
                       outs(%dst0 : memref<81920xi8, #hivm.address_space<gm>>)

        scope.return
      }
    }

    scf.for %j = %c0 to %c4 step %c1 {
      scope.scope : () -> () {
        %buf1 = memref.alloc() : memref<40960xi8, #hivm.address_space<ub>>
        annotation.mark %buf1 {
          hivm.multi_buffer = 4 : i32,
          hivm.preload_local_buffer = 1 : i32
        } : memref<40960xi8, #hivm.address_space<ub>>

        hivm.hir.load ins(%src1 : memref<40960xi8, #hivm.address_space<gm>>)
                      outs(%buf1 : memref<40960xi8, #hivm.address_space<ub>>)
        hivm.hir.store ins(%buf1 : memref<40960xi8, #hivm.address_space<ub>>)
                       outs(%dst1 : memref<40960xi8, #hivm.address_space<gm>>)

        scope.return
      }
    }

    return
  }
}

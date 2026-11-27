module {
  func.func @test_db_two_address_two_buffer(%arg0: memref<16xf16, #hivm.address_space<gm>>,
                                            %arg1: memref<16xf16, #hivm.address_space<gm>>,
                                            %arg2: memref<16xf16, #hivm.address_space<gm>>,
                                            %arg3: memref<16xf16, #hivm.address_space<gm>>) {
    %c32_i64 = arith.constant 32 : i64
    %c0_i64 = arith.constant 0 : i64
    %c64_i64 = arith.constant 64 : i64
    %c96_i64 = arith.constant 96 : i64
    %c0 = arith.constant 0 : index
    %c4 = arith.constant 4 : index
    %c16 = arith.constant 16 : index
    scf.for %arg4 = %c0 to %c16 step %c4 {

      %0 = hivm.hir.pointer_cast(%c0_i64, %c32_i64) : memref<16xf16, #hivm.address_space<ub>>
      annotation.mark %0 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%0 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.store ins(%0 : memref<16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16xf16, #hivm.address_space<gm>>)

      %1 = hivm.hir.pointer_cast(%c64_i64, %c96_i64) : memref<16xf16, #hivm.address_space<ub>>
      annotation.mark %1 {hivm.multi_buffer = 2 : i32} : memref<16xf16, #hivm.address_space<ub>>
      hivm.hir.load ins(%arg2 : memref<16xf16, #hivm.address_space<gm>>) outs(%1 : memref<16xf16, #hivm.address_space<ub>>)
      hivm.hir.store ins(%1 : memref<16xf16, #hivm.address_space<ub>>) outs(%arg3 : memref<16xf16, #hivm.address_space<gm>>)
    }
    return
  }
}

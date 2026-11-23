module {
  func.func @multi_buffer_alloc_manual_3for(%arg0: memref<16xf16, #hivm.address_space<gm>>, %arg1: memref<16xf16, #hivm.address_space<gm>>) {
    %c0_i64 = arith.constant 0 : i64
    %c16_i64 = arith.constant 16 : i64
    %c128_i64 = arith.constant 128 : i64
    %c144_i64 = arith.constant 144 : i64
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %c3 = arith.constant 3 : index
    %c4 = arith.constant 4 : index
    %c8 = arith.constant 8 : index
    %c15 = arith.constant 15 : index
    %c16 = arith.constant 16 : index

    scf.for %arg2 = %c1 to %c15 step %c2 {
      scf.for %arg3 = %c0 to %c15 step %c1 {
          scf.for %arg4 = %c0 to %c15 step %c1 {
            hivm.hir.pipe_barrier[<PIPE_ALL>]
            %0 = hivm.hir.pointer_cast(%c0_i64, %c16_i64) [] : memref<16xf16, #hivm.address_space<ub>>
            hivm.hir.pipe_barrier[<PIPE_ALL>]
            %1 = hivm.hir.pointer_cast(%c128_i64, %c144_i64) [] : memref<16xf16, #hivm.address_space<ub>>

            hivm.hir.pipe_barrier[<PIPE_ALL>]
            hivm.hir.load ins(%arg0 : memref<16xf16, #hivm.address_space<gm>>) outs(%0 : memref<16xf16, #hivm.address_space<ub>>)
            hivm.hir.pipe_barrier[<PIPE_ALL>]
            hivm.hir.vadd ins(%0, %0 : memref<16xf16, #hivm.address_space<ub>>, memref<16xf16, #hivm.address_space<ub>>) outs(%1 : memref<16xf16, #hivm.address_space<ub>>)
            hivm.hir.pipe_barrier[<PIPE_ALL>]
            hivm.hir.store ins(%1 : memref<16xf16, #hivm.address_space<ub>>) outs(%arg1 : memref<16xf16, #hivm.address_space<gm>>)
          }
      }
    }
    return
  }
}

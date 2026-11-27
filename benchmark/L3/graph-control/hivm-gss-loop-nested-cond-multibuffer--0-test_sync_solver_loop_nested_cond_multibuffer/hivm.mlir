module {
  func.func @test_sync_solver_loop_nested_cond_multibuffer(%arg0: index) {
    %alloca = memref.alloca() : memref<1xi64>
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    memref.store %c0_i64, %alloca[%c0] : memref<1xi64>
    %c0_0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %c0_i64_1 = arith.constant 0 : i64
    %c1_i64 = arith.constant 1 : i64
    %c2_i64 = arith.constant 2 : i64
    %c3_i64 = arith.constant 3 : i64
    %c4_i64 = arith.constant 4 : i64
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID2>]
    hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID3>]
    scf.for %arg1 = %c0_0 to %arg0 step %c1 {
      %c0_2 = arith.constant 0 : index
      %0 = memref.load %alloca[%c0_2] : memref<1xi64>
      %c2_i64_3 = arith.constant 2 : i64
      %1 = arith.remui %0, %c2_i64_3 : i64
      %2 = arith.index_cast %1 : i64 to index
      %3 = arith.index_cast %2 : index to i1
      %c1_i64_4 = arith.constant 1 : i64
      %c2_i64_5 = arith.constant 2 : i64
      %4 = arith.select %3, %c1_i64_4, %c2_i64_5 : i64
      scf.if %true {
        %6 = hivm.hir.pointer_cast(%c0_i64_1, %c3_i64, %c1_i64) : memref<1xi1, #hivm.address_space<gm>>
        %7 = hivm.hir.pointer_cast(%c1_i64, %c0_i64_1) : memref<1xi1, #hivm.address_space<ub>>
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID3>]
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, %4]
        hivm.hir.load ins(%6 : memref<1xi1, #hivm.address_space<gm>>) outs(%7 : memref<1xi1, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        %8 = hivm.hir.pointer_cast(%c2_i64, %c1_i64) : memref<1xi1, #hivm.address_space<ub>>
        %9 = hivm.hir.pointer_cast(%c1_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.store ins(%8 : memref<1xi1, #hivm.address_space<ub>>) outs(%9 : memref<1xi1, #hivm.address_space<gm>>)
        %10 = hivm.hir.pointer_cast(%c1_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        %11 = hivm.hir.pointer_cast(%c1_i64, %c3_i64, %c0_i64_1) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.pipe_barrier[<PIPE_MTE3>]
        hivm.hir.store ins(%10 : memref<1xi1, #hivm.address_space<ub>>) outs(%11 : memref<1xi1, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        %12 = hivm.hir.pointer_cast(%c1_i64, %c3_i64, %c2_i64) : memref<1xi1, #hivm.address_space<gm>>
        %13 = hivm.hir.pointer_cast(%c0_i64_1, %c1_i64) : memref<1xi1, #hivm.address_space<ub>>
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        hivm.hir.load ins(%12 : memref<1xi1, #hivm.address_space<gm>>) outs(%13 : memref<1xi1, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        %14 = hivm.hir.pointer_cast(%c1_i64) : memref<1xi1, #hivm.address_space<ub>>
        %15 = hivm.hir.pointer_cast(%c0_i64_1, %c4_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.store ins(%14 : memref<1xi1, #hivm.address_space<ub>>) outs(%15 : memref<1xi1, #hivm.address_space<gm>>)
        %16 = hivm.hir.pointer_cast(%c2_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        %17 = hivm.hir.pointer_cast(%c2_i64, %c3_i64, %c0_i64_1) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.pipe_barrier[<PIPE_MTE3>]
        hivm.hir.store ins(%16 : memref<1xi1, #hivm.address_space<ub>>) outs(%17 : memref<1xi1, #hivm.address_space<gm>>)
        %18 = hivm.hir.pointer_cast(%c2_i64, %c0_i64_1, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        %19 = hivm.hir.pointer_cast(%c1_i64, %c3_i64, %c0_i64_1) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.pipe_barrier[<PIPE_MTE3>]
        hivm.hir.store ins(%18 : memref<1xi1, #hivm.address_space<ub>>) outs(%19 : memref<1xi1, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        %20 = hivm.hir.pointer_cast(%c1_i64, %c0_i64_1, %c4_i64) : memref<1xi1, #hivm.address_space<gm>>
        %21 = hivm.hir.pointer_cast(%c0_i64_1, %c3_i64) : memref<1xi1, #hivm.address_space<ub>>
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        hivm.hir.load ins(%20 : memref<1xi1, #hivm.address_space<gm>>) outs(%21 : memref<1xi1, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        %22 = hivm.hir.pointer_cast(%c2_i64, %c3_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        %23 = hivm.hir.pointer_cast(%c3_i64, %c4_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.store ins(%22 : memref<1xi1, #hivm.address_space<ub>>) outs(%23 : memref<1xi1, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        %24 = hivm.hir.pointer_cast(%c3_i64) : memref<1xi1, #hivm.address_space<gm>>
        %25 = hivm.hir.pointer_cast(%c2_i64, %c1_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID0>]
        hivm.hir.load ins(%24 : memref<1xi1, #hivm.address_space<gm>>) outs(%25 : memref<1xi1, #hivm.address_space<ub>>)
        hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        %26 = hivm.hir.pointer_cast(%c2_i64, %c3_i64, %c4_i64) : memref<1xi1, #hivm.address_space<ub>>
        %27 = hivm.hir.pointer_cast(%c2_i64, %c3_i64, %c4_i64) : memref<1xi1, #hivm.address_space<gm>>
        hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
        hivm.hir.store ins(%26 : memref<1xi1, #hivm.address_space<ub>>) outs(%27 : memref<1xi1, #hivm.address_space<gm>>)
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID3>]
        scf.if %true {
          %28 = hivm.hir.pointer_cast(%c1_i64, %c2_i64) : memref<1xi1, #hivm.address_space<ub>>
          %29 = hivm.hir.pointer_cast(%c2_i64) : memref<1xi1, #hivm.address_space<gm>>
          hivm.hir.pipe_barrier[<PIPE_MTE3>]
          hivm.hir.store ins(%28 : memref<1xi1, #hivm.address_space<ub>>) outs(%29 : memref<1xi1, #hivm.address_space<gm>>)
        }
        hivm.hir.set_flag[<PIPE_MTE3>, <PIPE_MTE2>, %4]
      }
      %c1_i64_6 = arith.constant 1 : i64
      %5 = arith.addi %0, %c1_i64_6 : i64
      %c0_7 = arith.constant 0 : index
      memref.store %5, %alloca[%c0_7] : memref<1xi64>
    }
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID1>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID2>]
    hivm.hir.wait_flag[<PIPE_MTE3>, <PIPE_MTE2>, <EVENT_ID3>]
    return
  }
}


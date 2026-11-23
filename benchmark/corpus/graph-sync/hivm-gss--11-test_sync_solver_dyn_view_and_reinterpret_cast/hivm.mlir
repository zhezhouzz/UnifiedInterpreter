module {
  func.func @test_sync_solver_dyn_view_and_reinterpret_cast(%arg0: memref<1x?xi16, #hivm.address_space<gm>>, %arg1: memref<?x1xi16, #hivm.address_space<gm>>) {
    %c0_i64 = arith.constant 0 : i64
    %c1 = arith.constant 1 : index
    %c0 = arith.constant 0 : index
    %dim = memref.dim %arg0, %c1 : memref<1x?xi16, #hivm.address_space<gm>>
    %0 = hivm.hir.pointer_cast(%c0_i64) : memref<2048xi8, #hivm.address_space<ub>>
    %view = memref.view %0[%c0][%dim] : memref<2048xi8, #hivm.address_space<ub>> to memref<1x?xi16, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<1x?xi16, #hivm.address_space<gm>>) outs(%view : memref<1x?xi16, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    %reinterpret_cast = memref.reinterpret_cast %view to offset: [0], sizes: [%dim, 1], strides: [1, 1] : memref<1x?xi16, #hivm.address_space<ub>> to memref<?x1xi16, #hivm.address_space<ub>>
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%reinterpret_cast : memref<?x1xi16, #hivm.address_space<ub>>) outs(%arg1 : memref<?x1xi16, #hivm.address_space<gm>>)
    return
  }
}


module attributes {hacc.target = #hacc.target<"Ascend910B1">} {
  func.func private @mb_other_rollback_vf0(%arg0: memref<5985xi64, strided<[1]>, #hivm.address_space<ub>>, %arg1: memref<5985xi64, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %c0_i64 = arith.constant 0 : i64
    %0 = vector.constant_mask [1] : vector<64xi1>
    %subview = memref.subview %arg0[0] [1] [1] : memref<5985xi64, strided<[1]>, #hivm.address_space<ub>> to memref<1xi64, strided<[1]>, #hivm.address_space<ub>>
    %subview_0 = memref.subview %arg1[0] [1] [1] : memref<5985xi64, #hivm.address_space<ub>> to memref<1xi64, #hivm.address_space<ub>>
    %1 = vector.transfer_read %subview[%c0], %c0_i64, %0 {in_bounds = [true]} : memref<1xi64, strided<[1]>, #hivm.address_space<ub>>, vector<64xi64>
    vector.transfer_write %1, %subview_0[%c0], %0 {in_bounds = [true]} : vector<64xi64>, memref<1xi64, #hivm.address_space<ub>>
    return
  }
  func.func private @mb_other_rollback_vf1(%arg0: memref<5985xi64, #hivm.address_space<ub>>, %arg1: memref<6500xi64, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    return
  }
  func.func private @mb_other_rollback_vf2(%arg0: memref<6500xi64, #hivm.address_space<ub>>, %arg1: memref<6500xi64, strided<[1]>, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, no_inline} {
    %c0 = arith.constant 0 : index
    %c0_i64 = arith.constant 0 : i64
    %0 = vector.constant_mask [1] : vector<64xi1>
    %subview = memref.subview %arg0[0] [1] [1] : memref<6500xi64, #hivm.address_space<ub>> to memref<1xi64, #hivm.address_space<ub>>
    %subview_0 = memref.subview %arg1[0] [1] [1] : memref<6500xi64, strided<[1]>, #hivm.address_space<ub>> to memref<1xi64, strided<[1]>, #hivm.address_space<ub>>
    %1 = vector.transfer_read %subview[%c0], %c0_i64, %0 {in_bounds = [true]} : memref<1xi64, #hivm.address_space<ub>>, vector<64xi64>
    vector.transfer_write %1, %subview_0[%c0], %0 {in_bounds = [true]} : vector<64xi64>, memref<1xi64, strided<[1]>, #hivm.address_space<ub>>
    return
  }
  func.func @mb_other_rollback_level0_retry(%arg0: memref<5985xi64, #hivm.address_space<gm>>, %arg1: memref<6500xi64, #hivm.address_space<gm>>) {
    %alloc = memref.alloc() : memref<6932xi64, #hivm.address_space<ub>>
    annotation.mark %alloc {hivm.multi_buffer = 2 : i32} : memref<6932xi64, #hivm.address_space<ub>>
    %subview = memref.subview %alloc[0] [5985] [1] : memref<6932xi64, #hivm.address_space<ub>> to memref<5985xi64, strided<[1]>, #hivm.address_space<ub>>
    hivm.hir.load ins(%arg0 : memref<5985xi64, #hivm.address_space<gm>>) outs(%subview : memref<5985xi64, strided<[1]>, #hivm.address_space<ub>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    %alloc_0 = memref.alloc() : memref<5985xi64, #hivm.address_space<ub>>
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_V>, <EVENT_ID0>]
    call @mb_other_rollback_vf0(%subview, %alloc_0) {hivm.vector_function, no_inline} : (memref<5985xi64, strided<[1]>, #hivm.address_space<ub>>, memref<5985xi64, #hivm.address_space<ub>>) -> ()
    %alloc_1 = memref.alloc() : memref<6500xi64, #hivm.address_space<ub>>
    call @mb_other_rollback_vf1(%alloc_0, %alloc_1) {hivm.vector_function, no_inline} : (memref<5985xi64, #hivm.address_space<ub>>, memref<6500xi64, #hivm.address_space<ub>>) -> ()
    %alloc_2 = memref.alloc() : memref<7200xi64, #hivm.address_space<ub>>
    annotation.mark %alloc_2 {hivm.multi_buffer = 2 : i32} : memref<7200xi64, #hivm.address_space<ub>>
    %subview_3 = memref.subview %alloc_2[0] [6500] [1] : memref<7200xi64, #hivm.address_space<ub>> to memref<6500xi64, strided<[1]>, #hivm.address_space<ub>>
    call @mb_other_rollback_vf2(%alloc_1, %subview_3) {hivm.vector_function, no_inline} : (memref<6500xi64, #hivm.address_space<ub>>, memref<6500xi64, strided<[1]>, #hivm.address_space<ub>>) -> ()
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_V>, <PIPE_MTE3>, <EVENT_ID0>]
    hivm.hir.store ins(%subview_3 : memref<6500xi64, strided<[1]>, #hivm.address_space<ub>>) outs(%arg1 : memref<6500xi64, #hivm.address_space<gm>>)
    return
  }
}


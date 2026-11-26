module {
  func.func @stream_0(%arg0: memref<?xi32>, %arg1: i128) {
    %c1 = arith.constant 1 : index
    %c1_i128 = arith.constant 1 : i128
    %true = arith.constant true
    %c0_i128 = arith.constant 0 : i128
    %c-1_i128 = arith.constant -1 : i128
    %0:2 = scf.while (%arg2 = %arg1, %arg3 = %true) : (i128, i1) -> (i128, i1) {
      %1 = arith.cmpi sgt, %arg2, %c0_i128 : i128
      %2 = arith.andi %1, %arg3 : i1
      scf.condition(%2) %arg2, %arg3 : i128, i1
    } do {
    ^bb0(%arg2: i128, %arg3: i1):
      %1:2 = scf.while (%arg4 = %c0_i128, %arg5 = %true) : (i128, i1) -> (i128, i1) {
        %3 = arith.cmpi slt, %arg4, %arg2 : i128
        %4 = arith.andi %3, %arg5 : i1
        scf.condition(%4) %arg4, %arg5 : i128, i1
      } do {
      ^bb0(%arg4: i128, %arg5: i1):
        func.call @write(%arg0, %c1, %c1) : (memref<?xi32>, index, index) -> ()
        %3 = arith.addi %arg4, %c1_i128 : i128
        scf.yield %3, %true : i128, i1
      }
      %2 = arith.addi %arg2, %c-1_i128 : i128
      scf.yield %2, %1#1 : i128, i1
    }
    return
  }
  func.func private @write(%arg0: memref<?xi32>, %arg1: index, %arg2: index) {
    %c1_i32 = arith.constant 1 : i32
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    scf.for %arg3 = %c0 to %arg2 step %c1 {
      %0 = arith.addi %arg1, %arg3 : index
      memref.store %c1_i32, %arg0[%0] : memref<?xi32>
    }
    return
  }
}


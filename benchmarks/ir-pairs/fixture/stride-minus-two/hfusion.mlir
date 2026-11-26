module {
  func.func @stream_0(%arg0: memref<?xi32>) {
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %c3_i128 = arith.constant 3 : i128
    %c-1_i128 = arith.constant -1 : i128
    %c-2_i128 = arith.constant -2 : i128
    %0:2 = scf.while (%arg1 = %c3_i128, %arg2 = %true) : (i128, i1) -> (i128, i1) {
      %1 = arith.cmpi sgt, %arg1, %c-1_i128 : i128
      %2 = arith.andi %1, %arg2 : i1
      scf.condition(%2) %arg1, %arg2 : i128, i1
    } do {
    ^bb0(%arg1: i128, %arg2: i1):
      func.call @write(%arg0, %c1, %c1) : (memref<?xi32>, index, index) -> ()
      %1 = arith.addi %arg1, %c-2_i128 : i128
      scf.yield %1, %true : i128, i1
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


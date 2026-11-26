module {
  func.func @stream_0(%arg0: memref<?xi32>, %arg1: i128) {
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %false = arith.constant false
    %c0_i128 = arith.constant 0 : i128
    %c1_i128 = arith.constant 1 : i128
    %0:2 = scf.while (%arg2 = %c0_i128, %arg3 = %true) : (i128, i1) -> (i128, i1) {
      %2 = arith.cmpi slt, %arg2, %arg1 : i128
      %3 = arith.andi %2, %arg3 : i1
      scf.condition(%3) %arg2, %arg3 : i128, i1
    } do {
    ^bb0(%arg2: i128, %arg3: i1):
      %2 = arith.addi %arg2, %c1_i128 : i128
      scf.yield %2, %false : i128, i1
    }
    %1 = scf.if %0#1 -> (i1) {
      func.call @read(%arg0, %c1, %c1) : (memref<?xi32>, index, index) -> ()
      func.call @write(%arg0, %c1, %c1) : (memref<?xi32>, index, index) -> ()
      scf.yield %true : i1
    } else {
      scf.yield %false : i1
    }
    return
  }
  func.func private @read(%arg0: memref<?xi32>, %arg1: index, %arg2: index) {
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


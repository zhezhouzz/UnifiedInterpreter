module {
  func.func @stream_0(%arg0: memref<?xi32>) {
    %c2 = arith.constant 2 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %false = arith.constant false
    %c1_i128 = arith.constant 1 : i128
    %c2_i128 = arith.constant 2 : i128
    %0:2 = scf.while (%arg1 = %c1_i128, %arg2 = %false) : (i128, i1) -> (i128, i1) {
      %2 = arith.cmpi slt, %arg1, %c2_i128 : i128
      %3 = arith.andi %2, %arg2 : i1
      scf.condition(%3) %arg1, %arg2 : i128, i1
    } do {
    ^bb0(%arg1: i128, %arg2: i1):
      scf.yield %arg1, %true : i128, i1
    }
    %1 = scf.if %0#1 -> (i1) {
      func.call @copy(%arg0, %c0, %c1, %arg0, %c1, %c1) : (memref<?xi32>, index, index, memref<?xi32>, index, index) -> ()
      func.call @copy(%arg0, %c1, %c1, %arg0, %c2, %c1) : (memref<?xi32>, index, index, memref<?xi32>, index, index) -> ()
      scf.yield %true : i1
    } else {
      scf.yield %false : i1
    }
    return
  }
  func.func private @copy(%arg0: memref<?xi32>, %arg1: index, %arg2: index, %arg3: memref<?xi32>, %arg4: index, %arg5: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    scf.for %arg6 = %c0 to %arg2 step %c1 {
      %0 = arith.addi %arg1, %arg6 : index
      %1 = memref.load %arg0[%0] : memref<?xi32>
      %2 = arith.addi %arg4, %arg6 : index
      memref.store %1, %arg3[%2] : memref<?xi32>
    }
    return
  }
}


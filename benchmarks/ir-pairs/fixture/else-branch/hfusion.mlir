module {
  func.func @stream_0(%arg0: memref<?xi32>) {
    %c2 = arith.constant 2 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %false = arith.constant false
    %0 = scf.if %false -> (i1) {
      scf.yield %true : i1
    } else {
      func.call @copy(%arg0, %c0, %c1, %arg0, %c1, %c1) : (memref<?xi32>, index, index, memref<?xi32>, index, index) -> ()
      func.call @copy(%arg0, %c1, %c1, %arg0, %c2, %c1) : (memref<?xi32>, index, index, memref<?xi32>, index, index) -> ()
      scf.yield %true : i1
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


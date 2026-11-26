module {
  func.func @stream_0(%arg0: memref<?xi32>, %arg1: i128) {
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %false = arith.constant false
    %c0_i128 = arith.constant 0 : i128
    %0 = arith.cmpi eq, %arg1, %c0_i128 : i128
    %1 = scf.if %0 -> (i1) {
      scf.yield %true : i1
    } else {
      scf.yield %true : i1
    }
    %2 = scf.if %1 -> (i1) {
      func.call @write(%arg0, %c1, %c1) : (memref<?xi32>, index, index) -> ()
      %3 = scf.if %0 -> (i1) {
        scf.yield %true : i1
      } else {
        scf.yield %true : i1
      }
      scf.yield %3 : i1
    } else {
      scf.yield %false : i1
    }
    return
  }
  func.func @stream_1(%arg0: memref<?xi32>, %arg1: i128) {
    %c1 = arith.constant 1 : index
    %true = arith.constant true
    %false = arith.constant false
    %c0_i128 = arith.constant 0 : i128
    %0 = arith.cmpi eq, %arg1, %c0_i128 : i128
    %1 = scf.if %0 -> (i1) {
      scf.yield %true : i1
    } else {
      scf.yield %true : i1
    }
    %2 = scf.if %1 -> (i1) {
      func.call @read(%arg0, %c1, %c1) : (memref<?xi32>, index, index) -> ()
      %3 = scf.if %0 -> (i1) {
        scf.yield %true : i1
      } else {
        scf.yield %true : i1
      }
      scf.yield %3 : i1
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


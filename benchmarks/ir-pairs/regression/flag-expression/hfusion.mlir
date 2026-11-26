module {
  func.func @stream_0(%arg0: memref<?xi32>, %arg1: i128) {
    return
  }
  func.func @stream_1(%arg0: memref<?xi32>) {
    %c1 = arith.constant 1 : index
    call @read(%arg0, %c1, %c1) : (memref<?xi32>, index, index) -> ()
    call @write(%arg0, %c1, %c1) : (memref<?xi32>, index, index) -> ()
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


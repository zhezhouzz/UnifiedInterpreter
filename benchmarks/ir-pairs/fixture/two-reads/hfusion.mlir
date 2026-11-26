module {
  func.func @stream_0(%arg0: memref<?xi32>) {
    %c1 = arith.constant 1 : index
    call @read(%arg0, %c1, %c1) : (memref<?xi32>, index, index) -> ()
    call @read(%arg0, %c1, %c1) : (memref<?xi32>, index, index) -> ()
    return
  }
  func.func private @read(%arg0: memref<?xi32>, %arg1: index, %arg2: index) {
    return
  }
}


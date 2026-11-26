module {
  func.func @stream_0(%arg0: memref<?xi32>, %arg1: memref<1xmemref<?xi32>>) {
    %c1 = arith.constant 1 : index
    %0 = call @reserve(%arg1, %c1) : (memref<1xmemref<?xi32>>, index) -> memref<?xi32>
    return
  }
  func.func @stream_1(%arg0: memref<?xi32>, %arg1: memref<1xmemref<?xi32>>) {
    %c1 = arith.constant 1 : index
    call @write_shared(%arg1, %c1, %c1) : (memref<1xmemref<?xi32>>, index, index) -> ()
    call @read_shared(%arg1, %c1, %c1) : (memref<1xmemref<?xi32>>, index, index) -> ()
    return
  }
  func.func private @read_shared(%arg0: memref<1xmemref<?xi32>>, %arg1: index, %arg2: index) {
    return
  }
  func.func private @reserve(%arg0: memref<1xmemref<?xi32>>, %arg1: index) -> memref<?xi32> {
    %c0 = arith.constant 0 : index
    %alloc = memref.alloc(%arg1) : memref<?xi32>
    memref.store %alloc, %arg0[%c0] : memref<1xmemref<?xi32>>
    return %alloc : memref<?xi32>
  }
  func.func private @write_shared(%arg0: memref<1xmemref<?xi32>>, %arg1: index, %arg2: index) {
    %c1_i32 = arith.constant 1 : i32
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %0 = memref.load %arg0[%c0] : memref<1xmemref<?xi32>>
    scf.for %arg3 = %c0 to %arg2 step %c1 {
      %1 = arith.addi %arg1, %arg3 : index
      memref.store %c1_i32, %0[%1] : memref<?xi32>
    }
    return
  }
}


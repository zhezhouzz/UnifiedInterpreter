module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>, %slot: memref<1xmemref<?xi32, #hivm.address_space<gm>>>) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 1 : i128
    %v4 = arith.index_cast %v3 : i128 to index
    %v5 = func.call @reserve(%slot, %v4) : (memref<1xmemref<?xi32, #hivm.address_space<gm>>>, index) -> memref<?xi32, #hivm.address_space<gm>> loc("site")
    %v6 = arith.constant 0 : i128
    return
  }
  func.func @stream_1(%mem: memref<?xi32, #hivm.address_space<gm>>, %slot: memref<1xmemref<?xi32, #hivm.address_space<gm>>>) {
    %v7 = arith.constant true
    %v8 = arith.constant false
    %v9 = arith.constant 1 : i128
    %v10 = arith.constant 0 : i128
    %v11 = arith.index_cast %v9 : i128 to index
    %v12 = arith.index_cast %v10 : i128 to index
    func.call @write_shared(%slot, %v12, %v11) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<1xmemref<?xi32, #hivm.address_space<gm>>>, index, index) -> () loc("site")
    %v13 = arith.constant 1 : i128
    %v14 = arith.constant 0 : i128
    %v15 = arith.index_cast %v13 : i128 to index
    %v16 = arith.index_cast %v14 : i128 to index
    func.call @read_shared(%slot, %v16, %v15) {hivm.pipe = #hivm.pipe<PIPE_MTE2>} : (memref<1xmemref<?xi32, #hivm.address_space<gm>>>, index, index) -> () loc("site.0")
    return
  }
  func.func private @read_shared(%src: memref<1xmemref<?xi32, #hivm.address_space<gm>>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    %v17 = memref.load %src[%z] : memref<1xmemref<?xi32, #hivm.address_space<gm>>>
    scf.for %j = %z to %n step %one {
      %v18 = arith.addi %s, %j : index
      %v19 = memref.load %v17[%v18] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
  func.func private @reserve(%slot: memref<1xmemref<?xi32, #hivm.address_space<gm>>>, %n: index) -> memref<?xi32, #hivm.address_space<gm>> {
    %mem = memref.alloc(%n) : memref<?xi32, #hivm.address_space<gm>>
    %z = arith.constant 0 : index
    memref.store %mem, %slot[%z] : memref<1xmemref<?xi32, #hivm.address_space<gm>>>
    return %mem : memref<?xi32, #hivm.address_space<gm>>
  }
  func.func private @write_shared(%src: memref<1xmemref<?xi32, #hivm.address_space<gm>>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    %v20 = memref.load %src[%z] : memref<1xmemref<?xi32, #hivm.address_space<gm>>>
    scf.for %j = %z to %n step %one {
      %v21 = arith.addi %s, %j : index
      %v22 = arith.constant 1 : i32
      memref.store %v22, %v20[%v21] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

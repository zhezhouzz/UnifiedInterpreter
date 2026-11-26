module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 2 : i128
    %v4 = arith.index_cast %v3 : i128 to index
    %v5 = memref.alloc(%v4) : memref<?xi32, #hivm.address_space<gm>> loc("site")
    %v6 = arith.constant 0 : i128
    %v7 = arith.index_cast %v3 : i128 to index
    %v8 = arith.index_cast %v6 : i128 to index
    func.call @write(%v5, %v8, %v7) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0")
    %v9 = arith.index_cast %v3 : i128 to index
    %v10 = arith.index_cast %v6 : i128 to index
    func.call @read(%v5, %v10, %v9) {hivm.pipe = #hivm.pipe<PIPE_MTE2>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0")
    return
  }
  func.func private @read(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v11 = arith.addi %s, %j : index
      %v12 = memref.load %src[%v11] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v13 = arith.addi %s, %j : index
      %v14 = arith.constant 1 : i32
      memref.store %v14, %src[%v13] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

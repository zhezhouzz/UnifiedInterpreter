module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>, %n99: i128) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 0 : i128
    %v4 = arith.constant 1 : i128
    %v5:2 = scf.while (%v6 = %v3, %v7 = %v1) : (i128, i1) -> (i128, i1) {
      %v10 = arith.cmpi slt, %v6, %n99 : i128
      %v11 = arith.andi %v10, %v7 : i1
      scf.condition(%v11) %v6, %v7 : i128, i1
    } do {
    ^bb0(%v8: i128, %v9: i1):
      %v12 = arith.constant 1 : i128
      %v13 = arith.constant 1 : i128
      %v14 = arith.index_cast %v12 : i128 to index
      %v15 = arith.index_cast %v13 : i128 to index
      func.call @write(%mem, %v15, %v14) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0")
      %v16 = arith.addi %v8, %v4 : i128
      scf.yield %v16, %v1 : i128, i1
    }
    return
  }
  func.func @stream_1(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v17 = arith.constant true
    %v18 = arith.constant false
    %v19 = arith.constant 1 : i128
    %v20 = arith.constant 1 : i128
    %v21 = arith.index_cast %v19 : i128 to index
    %v22 = arith.index_cast %v20 : i128 to index
    func.call @read(%mem, %v22, %v21) {hivm.pipe = #hivm.pipe<PIPE_MTE2>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site")
    return
  }
  func.func private @read(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v23 = arith.addi %s, %j : index
      %v24 = memref.load %src[%v23] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v25 = arith.addi %s, %j : index
      %v26 = arith.constant 1 : i32
      memref.store %v26, %src[%v25] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

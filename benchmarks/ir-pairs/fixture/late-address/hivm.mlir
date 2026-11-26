module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>, %n99: i128) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 1 : i128
    %v4 = arith.constant 11 : i128
    %v5 = arith.index_cast %v3 : i128 to index
    %v6 = arith.index_cast %v4 : i128 to index
    func.call @read(%mem, %v6, %v5) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site")
    %v7 = arith.constant 0 : i128
    %v8 = arith.constant 1 : i128
    %v9:2 = scf.while (%v10 = %v7, %v11 = %v1) : (i128, i1) -> (i128, i1) {
      %v14 = arith.cmpi slt, %v10, %n99 : i128
      %v15 = arith.andi %v14, %v11 : i1
      scf.condition(%v15) %v10, %v11 : i128, i1
    } do {
    ^bb0(%v12: i128, %v13: i1):
      %v16 = arith.constant 1 : i128
      %v17 = arith.constant 3 : i128
      %v18 = arith.addi %v17, %v12 : i128
      %v19 = arith.index_cast %v16 : i128 to index
      %v20 = arith.index_cast %v18 : i128 to index
      func.call @write(%mem, %v20, %v19) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0.0")
      %v21 = arith.addi %v12, %v8 : i128
      scf.yield %v21, %v1 : i128, i1
    }
    return
  }
  func.func private @read(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v22 = arith.addi %s, %j : index
      %v23 = memref.load %src[%v22] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v24 = arith.addi %s, %j : index
      %v25 = arith.constant 1 : i32
      memref.store %v25, %src[%v24] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>, %n0: i128) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 0 : i128
    %v4 = arith.constant 1 : i128
    %v5:2 = scf.while (%v6 = %v3, %v7 = %v1) : (i128, i1) -> (i128, i1) {
      %v10 = arith.cmpi slt, %v6, %n0 : i128
      %v11 = arith.andi %v10, %v7 : i1
      scf.condition(%v11) %v6, %v7 : i128, i1
    } do {
    ^bb0(%v8: i128, %v9: i1):
      %v12 = arith.constant 1 : i128
      %v13 = arith.index_cast %v12 : i128 to index
      %v14 = memref.alloc(%v13) : memref<?xi32, #hivm.address_space<gm>> loc("site.0")
      %v15 = arith.constant 0 : i128
      %v16 = arith.index_cast %v12 : i128 to index
      %v17 = arith.index_cast %v15 : i128 to index
      func.call @write(%v14, %v17, %v16) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0")
      %v18 = arith.addi %v8, %v4 : i128
      scf.yield %v18, %v1 : i128, i1
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v19 = arith.addi %s, %j : index
      %v20 = arith.constant 1 : i32
      memref.store %v20, %src[%v19] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

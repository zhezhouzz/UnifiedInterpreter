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
      %v12 = arith.constant 4 : i128
      %v13 = arith.constant 5 : i128
      %v14 = arith.constant 1 : i128
      %v15:2 = scf.while (%v16 = %v12, %v17 = %v1) : (i128, i1) -> (i128, i1) {
        %v20 = arith.cmpi slt, %v16, %v13 : i128
        %v21 = arith.andi %v20, %v17 : i1
        scf.condition(%v21) %v16, %v17 : i128, i1
      } do {
      ^bb0(%v18: i128, %v19: i1):
        %v22 = arith.constant 1 : i128
        %v23 = arith.constant 1 : i128
        %v24 = arith.index_cast %v22 : i128 to index
        %v25 = arith.index_cast %v23 : i128 to index
        func.call @write(%mem, %v25, %v24) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0")
        %v26 = arith.addi %v18, %v14 : i128
        scf.yield %v26, %v1 : i128, i1
      }
      %v27 = arith.addi %v8, %v4 : i128
      scf.yield %v27, %v15#1 : i128, i1
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v28 = arith.addi %s, %j : index
      %v29 = arith.constant 1 : i32
      memref.store %v29, %src[%v28] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

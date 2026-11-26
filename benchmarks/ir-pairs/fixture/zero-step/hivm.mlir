module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 1 : i128
    %v4 = arith.constant 2 : i128
    %v5 = arith.constant 0 : i128
    %v6:2 = scf.while (%v7 = %v3, %v8 = %v2) : (i128, i1) -> (i128, i1) {
      %v11 = arith.cmpi slt, %v7, %v4 : i128
      %v12 = arith.andi %v11, %v8 : i1
      scf.condition(%v12) %v7, %v8 : i128, i1
    } do {
    ^bb0(%v9: i128, %v10: i1):
      %v13 = arith.addi %v9, %v5 : i128
      scf.yield %v13, %v1 : i128, i1
    }
    %v14 = scf.if %v6#1 -> (i1) {
      %v15 = arith.constant 1 : i128
      %v16 = arith.constant 0 : i128
      %v17 = arith.constant 1 : i128
      %v18 = arith.constant 1 : i128
      %v19 = arith.index_cast %v15 : i128 to index
      %v20 = arith.index_cast %v16 : i128 to index
      %v21 = arith.index_cast %v17 : i128 to index
      %v22 = arith.index_cast %v18 : i128 to index
      func.call @copy(%mem, %v20, %v19, %mem, %v22, %v21) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index, memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.1")
      %v23 = arith.constant 1 : i128
      %v24 = arith.constant 1 : i128
      %v25 = arith.constant 1 : i128
      %v26 = arith.constant 2 : i128
      %v27 = arith.index_cast %v23 : i128 to index
      %v28 = arith.index_cast %v24 : i128 to index
      %v29 = arith.index_cast %v25 : i128 to index
      %v30 = arith.index_cast %v26 : i128 to index
      func.call @copy(%mem, %v28, %v27, %mem, %v30, %v29) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index, memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.1.0")
      scf.yield %v1 : i1
    } else {
      scf.yield %v2 : i1
    }
    return
  }
  func.func private @copy(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index, %dst: memref<?xi32, #hivm.address_space<gm>>, %d: index, %dn: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v31 = arith.addi %s, %j : index
      %v32 = memref.load %src[%v31] : memref<?xi32, #hivm.address_space<gm>>
      %v33 = arith.addi %d, %j : index
      memref.store %v32, %dst[%v33] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

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
      %v12 = arith.addi %v8, %v4 : i128
      scf.yield %v12, %v1 : i128, i1
    }
    %v13 = scf.if %v5#1 -> (i1) {
      %v14 = arith.constant 1 : i128
      %v15 = arith.constant 0 : i128
      %v16 = arith.constant 1 : i128
      %v17 = arith.constant 1 : i128
      %v18 = arith.index_cast %v14 : i128 to index
      %v19 = arith.index_cast %v15 : i128 to index
      %v20 = arith.index_cast %v16 : i128 to index
      %v21 = arith.index_cast %v17 : i128 to index
      func.call @copy(%mem, %v19, %v18, %mem, %v21, %v20) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index, memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.1")
      %v22 = arith.constant 1 : i128
      %v23 = arith.constant 1 : i128
      %v24 = arith.constant 1 : i128
      %v25 = arith.constant 2 : i128
      %v26 = arith.index_cast %v22 : i128 to index
      %v27 = arith.index_cast %v23 : i128 to index
      %v28 = arith.index_cast %v24 : i128 to index
      %v29 = arith.index_cast %v25 : i128 to index
      func.call @copy(%mem, %v27, %v26, %mem, %v29, %v28) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index, memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.1.0")
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
      %v30 = arith.addi %s, %j : index
      %v31 = memref.load %src[%v30] : memref<?xi32, #hivm.address_space<gm>>
      %v32 = arith.addi %d, %j : index
      memref.store %v31, %dst[%v32] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

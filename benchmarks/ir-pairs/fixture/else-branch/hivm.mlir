module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = scf.if %v2 -> (i1) {
      scf.yield %v1 : i1
    } else {
      %v4 = arith.constant 1 : i128
      %v5 = arith.constant 0 : i128
      %v6 = arith.constant 1 : i128
      %v7 = arith.constant 1 : i128
      %v8 = arith.index_cast %v4 : i128 to index
      %v9 = arith.index_cast %v5 : i128 to index
      %v10 = arith.index_cast %v6 : i128 to index
      %v11 = arith.index_cast %v7 : i128 to index
      func.call @copy(%mem, %v9, %v8, %mem, %v11, %v10) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index, memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.1")
      %v12 = arith.constant 1 : i128
      %v13 = arith.constant 1 : i128
      %v14 = arith.constant 1 : i128
      %v15 = arith.constant 2 : i128
      %v16 = arith.index_cast %v12 : i128 to index
      %v17 = arith.index_cast %v13 : i128 to index
      %v18 = arith.index_cast %v14 : i128 to index
      %v19 = arith.index_cast %v15 : i128 to index
      func.call @copy(%mem, %v17, %v16, %mem, %v19, %v18) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index, memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.1.0")
      scf.yield %v1 : i1
    }
    return
  }
  func.func private @copy(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index, %dst: memref<?xi32, #hivm.address_space<gm>>, %d: index, %dn: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v20 = arith.addi %s, %j : index
      %v21 = memref.load %src[%v20] : memref<?xi32, #hivm.address_space<gm>>
      %v22 = arith.addi %d, %j : index
      memref.store %v21, %dst[%v22] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

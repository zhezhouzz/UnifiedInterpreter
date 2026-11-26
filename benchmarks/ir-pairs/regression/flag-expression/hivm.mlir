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
      %v12 = arith.addi %v8, %v4 : i128
      scf.yield %v12, %v1 : i128, i1
    }
    %v13 = scf.if %v5#1 -> (i1) {
      %v14 = arith.constant 1 : i128
      %v15 = arith.constant 0 : i128
      %v16 = arith.constant 19 : i128
      %v17 = arith.cmpi eq, %n0, %v16 : i128
      %v18 = arith.select %v17, %v15, %v14 : i128
      %v19 = arith.trunci %v18 : i128 to i64
      hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_S>] flag = %v19 loc("site.1.0")
      scf.yield %v1 : i1
    } else {
      scf.yield %v2 : i1
    }
    return
  }
  func.func @stream_1(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v20 = arith.constant true
    %v21 = arith.constant false
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_V>, <PIPE_S>] flag = 0 loc("site")
    %v22 = arith.constant 1 : i128
    %v23 = arith.constant 1 : i128
    %v24 = arith.index_cast %v22 : i128 to index
    %v25 = arith.index_cast %v23 : i128 to index
    func.call @read(%mem, %v25, %v24) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0")
    %v26 = arith.constant 1 : i128
    %v27 = arith.constant 1 : i128
    %v28 = arith.index_cast %v26 : i128 to index
    %v29 = arith.index_cast %v27 : i128 to index
    func.call @write(%mem, %v29, %v28) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0")
    return
  }
  func.func private @read(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v30 = arith.addi %s, %j : index
      %v31 = memref.load %src[%v30] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v32 = arith.addi %s, %j : index
      %v33 = arith.constant 1 : i32
      memref.store %v33, %src[%v32] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

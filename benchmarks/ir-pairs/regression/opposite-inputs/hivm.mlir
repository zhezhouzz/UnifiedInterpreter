module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>, %n0: i128) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 0 : i128
    %v4 = arith.cmpi eq, %n0, %v3 : i128
    %v5 = scf.if %v4 -> (i1) {
      scf.yield %v1 : i1
    } else {
      hivm.hir.sync_block_wait[<VECTOR>, <PIPE_V>, <PIPE_S>] flag = 0 loc("site.0.1")
      scf.yield %v1 : i1
    }
    %v6 = scf.if %v5 -> (i1) {
      %v7 = arith.constant 1 : i128
      %v8 = arith.constant 1 : i128
      %v9 = arith.index_cast %v7 : i128 to index
      %v10 = arith.index_cast %v8 : i128 to index
      func.call @write(%mem, %v10, %v9) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.2")
      %v11 = scf.if %v4 -> (i1) {
        hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_S>] flag = 0 loc("site.0.2.0.0")
        scf.yield %v1 : i1
      } else {
        scf.yield %v1 : i1
      }
      scf.yield %v11 : i1
    } else {
      scf.yield %v2 : i1
    }
    return
  }
  func.func @stream_1(%mem: memref<?xi32, #hivm.address_space<gm>>, %n0: i128) {
    %v12 = arith.constant true
    %v13 = arith.constant false
    %v14 = arith.constant 0 : i128
    %v15 = arith.cmpi eq, %n0, %v14 : i128
    %v16 = scf.if %v15 -> (i1) {
      hivm.hir.sync_block_wait[<VECTOR>, <PIPE_V>, <PIPE_S>] flag = 0 loc("site.0.0")
      scf.yield %v12 : i1
    } else {
      scf.yield %v12 : i1
    }
    %v17 = scf.if %v16 -> (i1) {
      %v18 = arith.constant 1 : i128
      %v19 = arith.constant 1 : i128
      %v20 = arith.index_cast %v18 : i128 to index
      %v21 = arith.index_cast %v19 : i128 to index
      func.call @read(%mem, %v21, %v20) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.2")
      %v22 = scf.if %v15 -> (i1) {
        scf.yield %v12 : i1
      } else {
        hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_S>] flag = 0 loc("site.0.2.0.1")
        scf.yield %v12 : i1
      }
      scf.yield %v22 : i1
    } else {
      scf.yield %v13 : i1
    }
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

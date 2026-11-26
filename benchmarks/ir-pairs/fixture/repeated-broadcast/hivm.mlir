module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_S>] flag = 0 loc("site")
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_S>] flag = 0 loc("site.0")
    return
  }
  func.func @stream_1(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v3 = arith.constant true
    %v4 = arith.constant false
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_V>, <PIPE_S>] flag = 0 loc("site")
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_V>, <PIPE_S>] flag = 0 loc("site.0")
    %v5 = arith.constant 1 : i128
    %v6 = arith.constant 1 : i128
    %v7 = arith.index_cast %v5 : i128 to index
    %v8 = arith.index_cast %v6 : i128 to index
    func.call @write(%mem, %v8, %v7) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0")
    return
  }
  func.func @stream_2(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v9 = arith.constant true
    %v10 = arith.constant false
    %v11 = arith.constant 1 : i128
    %v12 = arith.constant 1 : i128
    %v13 = arith.index_cast %v11 : i128 to index
    %v14 = arith.index_cast %v12 : i128 to index
    func.call @read(%mem, %v14, %v13) {hivm.pipe = #hivm.pipe<PIPE_MTE2>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site")
    return
  }
  func.func private @read(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v15 = arith.addi %s, %j : index
      %v16 = memref.load %src[%v15] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v17 = arith.addi %s, %j : index
      %v18 = arith.constant 1 : i32
      memref.store %v18, %src[%v17] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

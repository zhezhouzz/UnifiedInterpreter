module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 1 : i128
    %v4 = arith.constant 1 : i128
    %v5 = arith.index_cast %v3 : i128 to index
    %v6 = arith.index_cast %v4 : i128 to index
    func.call @write(%mem, %v6, %v5) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site")
    hivm.hir.sync_block_set[<VECTOR>, <PIPE_V>, <PIPE_MTE2>] flag = 0 loc("site.0")
    return
  }
  func.func @stream_1(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v7 = arith.constant true
    %v8 = arith.constant false
    hivm.hir.sync_block_wait[<VECTOR>, <PIPE_V>, <PIPE_MTE2>] flag = 0 loc("site")
    %v9 = arith.constant 1 : i128
    %v10 = arith.constant 1 : i128
    %v11 = arith.index_cast %v9 : i128 to index
    %v12 = arith.index_cast %v10 : i128 to index
    func.call @read(%mem, %v12, %v11) {hivm.pipe = #hivm.pipe<PIPE_MTE2>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0")
    return
  }
  func.func private @read(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v13 = arith.addi %s, %j : index
      %v14 = memref.load %src[%v13] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v15 = arith.addi %s, %j : index
      %v16 = arith.constant 1 : i32
      memref.store %v16, %src[%v15] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

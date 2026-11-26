module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>] loc("site")
    hivm.hir.set_flag[<PIPE_V>, <PIPE_MTE2>, <EVENT_ID0>] loc("site.0")
    %v3 = arith.constant 1 : i128
    %v4 = arith.constant 0 : i128
    %v5 = arith.constant 1 : i128
    %v6 = arith.constant 1 : i128
    %v7 = arith.index_cast %v3 : i128 to index
    %v8 = arith.index_cast %v4 : i128 to index
    %v9 = arith.index_cast %v5 : i128 to index
    %v10 = arith.index_cast %v6 : i128 to index
    func.call @copy(%mem, %v8, %v7, %mem, %v10, %v9) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index, memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0")
    %v11 = arith.constant 1 : i128
    %v12 = arith.constant 1 : i128
    %v13 = arith.constant 1 : i128
    %v14 = arith.constant 2 : i128
    %v15 = arith.index_cast %v11 : i128 to index
    %v16 = arith.index_cast %v12 : i128 to index
    %v17 = arith.index_cast %v13 : i128 to index
    %v18 = arith.index_cast %v14 : i128 to index
    func.call @copy(%mem, %v16, %v15, %mem, %v18, %v17) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index, memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0.0")
    return
  }
  func.func private @copy(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index, %dst: memref<?xi32, #hivm.address_space<gm>>, %d: index, %dn: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v19 = arith.addi %s, %j : index
      %v20 = memref.load %src[%v19] : memref<?xi32, #hivm.address_space<gm>>
      %v21 = arith.addi %d, %j : index
      memref.store %v20, %dst[%v21] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

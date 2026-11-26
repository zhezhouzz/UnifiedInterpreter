module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>, %n0: i128) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 3 : i128
    %v4 = arith.cmpi eq, %n0, %v3 : i128
    %v5 = scf.if %v4 -> (i1) {
      %v6 = arith.constant 1 : i128
      %v7 = arith.constant 1 : i128
      %v8 = arith.index_cast %v6 : i128 to index
      %v9 = arith.index_cast %v7 : i128 to index
      func.call @write(%mem, %v9, %v8) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0")
      scf.yield %v1 : i1
    } else {
      scf.yield %v1 : i1
    }
    return
  }
  func.func @stream_1(%mem: memref<?xi32, #hivm.address_space<gm>>, %n5: i128) {
    %v10 = arith.constant true
    %v11 = arith.constant false
    %v12 = arith.constant 4 : i128
    %v13 = arith.cmpi eq, %n5, %v12 : i128
    %v14 = scf.if %v13 -> (i1) {
      %v15 = arith.constant 1 : i128
      %v16 = arith.constant 1 : i128
      %v17 = arith.index_cast %v15 : i128 to index
      %v18 = arith.index_cast %v16 : i128 to index
      func.call @read(%mem, %v18, %v17) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0")
      scf.yield %v10 : i1
    } else {
      scf.yield %v10 : i1
    }
    return
  }
  func.func private @read(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v19 = arith.addi %s, %j : index
      %v20 = memref.load %src[%v19] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v21 = arith.addi %s, %j : index
      %v22 = arith.constant 1 : i32
      memref.store %v22, %src[%v21] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

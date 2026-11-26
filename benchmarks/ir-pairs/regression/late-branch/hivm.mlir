module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>, %n0: i128) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 1 : i128
    %v4 = arith.constant 1 : i128
    %v5 = arith.index_cast %v3 : i128 to index
    %v6 = arith.index_cast %v4 : i128 to index
    func.call @read(%mem, %v6, %v5) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site")
    %v7 = arith.constant 0 : i128
    %v8 = arith.constant 1 : i128
    %v9:2 = scf.while (%v10 = %v7, %v11 = %v1) : (i128, i1) -> (i128, i1) {
      %v14 = arith.cmpi slt, %v10, %n0 : i128
      %v15 = arith.andi %v14, %v11 : i1
      scf.condition(%v15) %v10, %v11 : i128, i1
    } do {
    ^bb0(%v12: i128, %v13: i1):
      %v16 = arith.constant 16 : i128
      %v17 = arith.cmpi eq, %v12, %v16 : i128
      %v18 = scf.if %v17 -> (i1) {
        %v19 = arith.constant 17 : i128
        %v20 = arith.cmpi eq, %n0, %v19 : i128
        %v21 = scf.if %v20 -> (i1) {
          %v22 = arith.constant 1 : i128
          %v23 = arith.constant 1 : i128
          %v24 = arith.index_cast %v22 : i128 to index
          %v25 = arith.index_cast %v23 : i128 to index
          func.call @write(%mem, %v25, %v24) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0.0.0.0.0.0")
          scf.yield %v1 : i1
        } else {
          scf.yield %v1 : i1
        }
        scf.yield %v21 : i1
      } else {
        scf.yield %v1 : i1
      }
      %v26 = arith.addi %v12, %v8 : i128
      scf.yield %v26, %v18 : i128, i1
    }
    return
  }
  func.func private @read(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v27 = arith.addi %s, %j : index
      %v28 = memref.load %src[%v27] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v29 = arith.addi %s, %j : index
      %v30 = arith.constant 1 : i32
      memref.store %v30, %src[%v29] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

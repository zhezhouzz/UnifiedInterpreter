module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 0 : i128
    %v4 = arith.constant 1267650600228229401496703205376 : i128
    %v5 = arith.constant 1 : i128
    %v6:2 = scf.while (%v7 = %v3, %v8 = %v1) : (i128, i1) -> (i128, i1) {
      %v11 = arith.cmpi slt, %v7, %v4 : i128
      %v12 = arith.andi %v11, %v8 : i1
      scf.condition(%v12) %v7, %v8 : i128, i1
    } do {
    ^bb0(%v9: i128, %v10: i1):
      %v13 = arith.addi %v9, %v5 : i128
      scf.yield %v13, %v2 : i128, i1
    }
    %v14 = scf.if %v6#1 -> (i1) {
      %v15 = arith.constant 1 : i128
      %v16 = arith.constant 1 : i128
      %v17 = arith.index_cast %v15 : i128 to index
      %v18 = arith.index_cast %v16 : i128 to index
      func.call @write(%mem, %v18, %v17) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.1")
      scf.yield %v1 : i1
    } else {
      scf.yield %v2 : i1
    }
    return
  }
  func.func private @write(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v19 = arith.addi %s, %j : index
      %v20 = arith.constant 1 : i32
      memref.store %v20, %src[%v19] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

module {
  func.func @stream_0(%mem: memref<?xi32, #hivm.address_space<gm>>) {
    %v1 = arith.constant true
    %v2 = arith.constant false
    %v3 = arith.constant 1 : i128
    %v4 = arith.constant 1 : i128
    %v5 = arith.index_cast %v3 : i128 to index
    %v6 = arith.index_cast %v4 : i128 to index
    func.call @read(%mem, %v6, %v5) {hivm.pipe = #hivm.pipe<PIPE_V>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site")
    %v7 = arith.constant 1 : i128
    %v8 = arith.constant 1 : i128
    %v9 = arith.index_cast %v7 : i128 to index
    %v10 = arith.index_cast %v8 : i128 to index
    func.call @read(%mem, %v10, %v9) {hivm.pipe = #hivm.pipe<PIPE_MTE2>} : (memref<?xi32, #hivm.address_space<gm>>, index, index) -> () loc("site.0")
    return
  }
  func.func private @read(%src: memref<?xi32, #hivm.address_space<gm>>, %s: index, %n: index) {
    %z = arith.constant 0 : index
    %one = arith.constant 1 : index
    scf.for %j = %z to %n step %one {
      %v11 = arith.addi %s, %j : index
      %v12 = memref.load %src[%v11] : memref<?xi32, #hivm.address_space<gm>>
    }
    return
  }
}

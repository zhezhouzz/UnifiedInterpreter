module {
  func.func @rank_zero() -> f32 {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %cst = arith.constant 2.000000e+00 : f32
    %cst_0 = arith.constant 5.000000e+00 : f32
    %alloc = memref.alloc() : memref<f32, #hivm.address_space<ub>>
    memref.store %cst_0, %alloc[] : memref<f32, #hivm.address_space<ub>>
    %0 = scf.for %arg0 = %c0 to %c2 step %c1 iter_args(%arg1 = %alloc) -> (memref<f32, #hivm.address_space<ub>>) {
      %alloc_1 = memref.alloc() : memref<f32, #hivm.address_space<ub>>
      memref.store %cst, %alloc_1[] : memref<f32, #hivm.address_space<ub>>
      %2 = memref.load %arg1[] : memref<f32, #hivm.address_space<ub>>
      %3 = memref.load %alloc_1[] : memref<f32, #hivm.address_space<ub>>
      %4 = arith.addf %2, %3 : f32
      memref.store %4, %alloc_1[] : memref<f32, #hivm.address_space<ub>>
      scf.yield %alloc_1 : memref<f32, #hivm.address_space<ub>>
    }
    %1 = memref.load %0[] : memref<f32, #hivm.address_space<ub>>
    return %1 : f32
  }
}


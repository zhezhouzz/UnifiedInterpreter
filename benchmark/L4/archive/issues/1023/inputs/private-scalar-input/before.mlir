module attributes {hivm.module_core_type = #hivm.module_core_type<MIX>} {
  func.func private @consume(memref<1xf32, #hivm.address_space<ub>>, f32) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function}
  func.func @gate(%arg0: memref<1xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %c0 = arith.constant 0 : index
    %alloc = memref.alloc() : memref<1xf32, #hivm.address_space<ub>>
    %0 = memref.load %arg0[%c0] : memref<1xf32, #hivm.address_space<gm>>
    memref.store %0, %alloc[%c0] : memref<1xf32, #hivm.address_space<ub>>
    call @consume(%alloc, %0) {hivm.vector_function} : (memref<1xf32, #hivm.address_space<ub>>, f32) -> ()
    return
  }
  func.func @after_call(%arg0: f32) attributes {hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %c0 = arith.constant 0 : index
    %alloc = memref.alloc() : memref<1xf32, #hivm.address_space<ub>>
    call @consume(%alloc, %arg0) {hivm.vector_function} : (memref<1xf32, #hivm.address_space<ub>>, f32) -> ()
    memref.store %arg0, %alloc[%c0] : memref<1xf32, #hivm.address_space<ub>>
    return
  }
  func.func @prior_iteration(%arg0: index, %arg1: f32) attributes {hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %alloc = memref.alloc() : memref<1xf32, #hivm.address_space<ub>>
    scf.for %arg2 = %c0 to %arg0 step %c1 {
      memref.store %arg1, %alloc[%c0] : memref<1xf32, #hivm.address_space<ub>>
      func.call @consume(%alloc, %arg1) {hivm.vector_function} : (memref<1xf32, #hivm.address_space<ub>>, f32) -> ()
    }
    return
  }
  func.func @shared(%arg0: memref<1xf32, #hivm.address_space<gm>>, %arg1: f32) attributes {hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %c0 = arith.constant 0 : index
    %alloc = memref.alloc() : memref<1xf32, #hivm.address_space<ub>>
    memref.store %arg1, %alloc[%c0] : memref<1xf32, #hivm.address_space<ub>>
    call @consume(%alloc, %arg1) {hivm.vector_function} : (memref<1xf32, #hivm.address_space<ub>>, f32) -> ()
    %0 = memref.load %alloc[%c0] {hivm.tcore_type = #hivm.tcore_type<CUBE>} : memref<1xf32, #hivm.address_space<ub>>
    memref.store %0, %arg0[%c0] {hivm.tcore_type = #hivm.tcore_type<CUBE>} : memref<1xf32, #hivm.address_space<gm>>
    return
  }
  func.func private @use_scalars(memref<1xindex, #hivm.address_space<ub>>, memref<1xui8, #hivm.address_space<ub>>, memref<1xi64, #hivm.address_space<ub>>, memref<1xi1, #hivm.address_space<ub>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function}
  func.func @unsupported_types(%arg0: index, %arg1: ui8, %arg2: i64, %arg3: i1) attributes {hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %c0 = arith.constant 0 : index
    %alloc = memref.alloc() : memref<1xindex, #hivm.address_space<ub>>
    %alloc_0 = memref.alloc() : memref<1xui8, #hivm.address_space<ub>>
    %alloc_1 = memref.alloc() : memref<1xi64, #hivm.address_space<ub>>
    %alloc_2 = memref.alloc() : memref<1xi1, #hivm.address_space<ub>>
    memref.store %arg0, %alloc[%c0] : memref<1xindex, #hivm.address_space<ub>>
    memref.store %arg1, %alloc_0[%c0] : memref<1xui8, #hivm.address_space<ub>>
    memref.store %arg2, %alloc_1[%c0] : memref<1xi64, #hivm.address_space<ub>>
    memref.store %arg3, %alloc_2[%c0] : memref<1xi1, #hivm.address_space<ub>>
    call @use_scalars(%alloc, %alloc_0, %alloc_1, %alloc_2) {hivm.vector_function} : (memref<1xindex, #hivm.address_space<ub>>, memref<1xui8, #hivm.address_space<ub>>, memref<1xi64, #hivm.address_space<ub>>, memref<1xi1, #hivm.address_space<ub>>) -> ()
    return
  }
  func.func @cube_owned(%arg0: f32) attributes {hivm.func_core_type = #hivm.func_core_type<MIX>} {
    %c0 = arith.constant 0 : index
    %alloc = memref.alloc() : memref<1xf32, #hivm.address_space<ub>>
    scope.scope : () -> () {
      memref.store %arg0, %alloc[%c0] : memref<1xf32, #hivm.address_space<ub>>
      func.call @consume(%alloc, %arg0) {hivm.vector_function} : (memref<1xf32, #hivm.address_space<ub>>, f32) -> ()
      scope.return
    } {hivm.tcore_type = #hivm.tcore_type<CUBE>}
    return
  }
}


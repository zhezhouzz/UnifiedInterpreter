module attributes {hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @indirect_atomic_add_read_modify_write(%arg0: memref<16xf32>, %arg1: memref<16xf32>, %arg2: memref<16xi64>, %arg3: memref<16xi8>, %arg4: memref<16xf32>, %arg5: memref<16xf32>) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
    linalg.copy ins(%arg0 : memref<16xf32>) outs(%arg5 : memref<16xf32>)
    call @indirect_atomic_add(%arg1, %arg2, %arg5, %arg3, %arg5) : (memref<16xf32>, memref<16xi64>, memref<16xf32>, memref<16xi8>, memref<16xf32>) -> ()
    linalg.copy ins(%arg1 : memref<16xf32>) outs(%arg5 : memref<16xf32>)
    linalg.copy ins(%arg5 : memref<16xf32>) outs(%arg4 : memref<16xf32>)
    return
  }
  func.func private @indirect_atomic_add(%arg0: memref<16xf32>, %arg1: memref<16xi64>, %arg2: memref<16xf32>, %arg3: memref<16xi8>, %arg4: memref<16xf32>) {
    %c0 = arith.constant 0 : index
    %c16 = arith.constant 16 : index
    %c1 = arith.constant 1 : index
    %c0_i8 = arith.constant 0 : i8
    scf.for %arg5 = %c0 to %c16 step %c1 {
      %0 = memref.load %arg3[%arg5] : memref<16xi8>
      %1 = arith.cmpi ne, %0, %c0_i8 : i8
      scf.if %1 {
        %2 = memref.load %arg1[%arg5] : memref<16xi64>
        %3 = arith.index_cast %2 : i64 to index
        %4 = memref.load %arg2[%arg5] : memref<16xf32>
        %5 = memref.atomic_rmw addf %4, %arg0[%3] : (f32, memref<16xf32>) -> f32
        memref.store %5, %arg4[%arg5] : memref<16xf32>
      }
    }
    return
  }
}


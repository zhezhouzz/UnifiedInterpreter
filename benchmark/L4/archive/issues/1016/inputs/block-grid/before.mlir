module {
  func.func @clear_block(%arg0: memref<?xi8>, %arg1: memref<?xi8>, %arg2: memref<?xi32>, %arg3: i32, %arg4: i32, %arg5: i32, %arg6: i32, %arg7: i32, %arg8: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, global_kernel = "local", mix_mode = "aiv", parallel_mode = "simd"} {
    %0 = arith.index_cast %arg6 : i32 to index
    %1 = arith.index_cast %arg7 : i32 to index
    %c4096 = arith.constant 4096 : index
    %2 = arith.muli %1, %c4096 : index
    %3 = arith.addi %0, %2 : index
    %c0_i32 = arith.constant 0 : i32
    memref.store %c0_i32, %arg2[%3] : memref<?xi32>
    return
  }
}


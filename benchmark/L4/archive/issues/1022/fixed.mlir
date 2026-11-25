module attributes {dlti.target_system_spec = #dlti.target_system_spec<"NPU" : #hacc.target_device_spec<#dlti.dl_entry<"AI_CORE_COUNT", 36 : i32>, #dlti.dl_entry<"CUBE_CORE_COUNT", 36 : i32>, #dlti.dl_entry<"VECTOR_CORE_COUNT", 36 : i32>, #dlti.dl_entry<"UB_SIZE", 2555904 : i32>, #dlti.dl_entry<"L1_SIZE", 4194304 : i32>, #dlti.dl_entry<"L0A_SIZE", 524288 : i32>, #dlti.dl_entry<"L0B_SIZE", 524288 : i32>, #dlti.dl_entry<"L0C_SIZE", 2097152 : i32>, #dlti.dl_entry<"UB_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L1_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L0C_ALIGN_SIZE", 4096 : i32>, #dlti.dl_entry<"MINIMAL_D_CACHE_SIZE", 262144 : i32>, #dlti.dl_entry<"MAXIMUM_D_CACHE_SIZE", 983040 : i32>, #dlti.dl_entry<"ARCH", "dav-920r1">, #dlti.dl_entry<"UB_BANK_GROUP_COUNT", 32 : i32>>>, hacc.target = #hacc.target<"Ascend960DT_968B7">} {
  func.func @initialized(%arg0: memref<64xf32, #hivm.address_space<gm>>) {
    %c0_i64 = arith.constant 0 : i64
    %c256_i64 = arith.constant 256 : i64
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %cst = arith.constant 2.000000e+00 : f32
    %cst_0 = arith.constant 5.000000e+00 : f32
    %0 = hivm.hir.pointer_cast(%c256_i64) : memref<64xf32, #hivm.address_space<ub>>
    hivm.hir.vbrc ins(%cst_0 : f32) outs(%0 : memref<64xf32, #hivm.address_space<ub>>)
    %1 = scf.for %arg1 = %c0 to %c2 step %c1 iter_args(%arg2 = %0) -> (memref<64xf32, #hivm.address_space<ub>>) {
      %2 = hivm.hir.pointer_cast(%c0_i64) : memref<64xf32, #hivm.address_space<ub>>
      scope.scope : () -> () {
        hivm.hir.vbrc ins(%cst : f32) outs(%2 : memref<64xf32, #hivm.address_space<ub>>)
        scope.return
      } {no_inline}
      hivm.hir.vadd ins(%arg2, %2 : memref<64xf32, #hivm.address_space<ub>>, memref<64xf32, #hivm.address_space<ub>>) outs(%2 : memref<64xf32, #hivm.address_space<ub>>)
      %3 = hivm.hir.pointer_cast(%c256_i64) : memref<64xf32, #hivm.address_space<ub>>
      hivm.hir.copy ins(%2 : memref<64xf32, #hivm.address_space<ub>>) outs(%3 : memref<64xf32, #hivm.address_space<ub>>)
      scf.yield %3 : memref<64xf32, #hivm.address_space<ub>>
    }
    hivm.hir.store ins(%1 : memref<64xf32, #hivm.address_space<ub>>) outs(%arg0 : memref<64xf32, #hivm.address_space<gm>>)
    return
  }
  func.func @external_init(%arg0: memref<64xf32, #hivm.address_space<ub>>, %arg1: index, %arg2: f32) -> memref<64xf32, #hivm.address_space<ub>> {
    %c256_i64 = arith.constant 256 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %0 = scf.for %arg3 = %c0 to %arg1 step %c1 iter_args(%arg4 = %arg0) -> (memref<64xf32, #hivm.address_space<ub>>) {
      %1 = hivm.hir.pointer_cast(%c0_i64) : memref<64xf32, #hivm.address_space<ub>>
      hivm.hir.vbrc ins(%arg2 : f32) outs(%1 : memref<64xf32, #hivm.address_space<ub>>)
      hivm.hir.vadd ins(%arg4, %1 : memref<64xf32, #hivm.address_space<ub>>, memref<64xf32, #hivm.address_space<ub>>) outs(%1 : memref<64xf32, #hivm.address_space<ub>>)
      %2 = hivm.hir.pointer_cast(%c256_i64) : memref<64xf32, #hivm.address_space<ub>>
      annotation.mark %2 {mem_unique} : memref<64xf32, #hivm.address_space<ub>>
      hivm.hir.copy ins(%1 : memref<64xf32, #hivm.address_space<ub>>) outs(%2 : memref<64xf32, #hivm.address_space<ub>>)
      scf.yield %2 : memref<64xf32, #hivm.address_space<ub>>
    }
    return %0 : memref<64xf32, #hivm.address_space<ub>>
  }
  func.func @single_update(%arg0: memref<64xf32, #hivm.address_space<ub>>, %arg1: index) -> memref<64xf32, #hivm.address_space<ub>> {
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %0 = scf.for %arg2 = %c0 to %arg1 step %c1 iter_args(%arg3 = %arg0) -> (memref<64xf32, #hivm.address_space<ub>>) {
      %1 = hivm.hir.pointer_cast(%c0_i64) : memref<64xf32, #hivm.address_space<ub>>
      hivm.hir.vadd ins(%arg3, %arg3 : memref<64xf32, #hivm.address_space<ub>>, memref<64xf32, #hivm.address_space<ub>>) outs(%1 : memref<64xf32, #hivm.address_space<ub>>)
      scf.yield %1 : memref<64xf32, #hivm.address_space<ub>>
    }
    return %0 : memref<64xf32, #hivm.address_space<ub>>
  }
  func.func @scalar_writer(%arg0: index, %arg1: memref<64xf32, #hivm.address_space<ub>>, %arg2: index, %arg3: f32) -> memref<64xf32, #hivm.address_space<ub>> {
    %c256_i64 = arith.constant 256 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %0 = scf.for %arg4 = %c0 to %arg2 step %c1 iter_args(%arg5 = %arg1) -> (memref<64xf32, #hivm.address_space<ub>>) {
      %1 = hivm.hir.pointer_cast(%c0_i64) : memref<64xf32, #hivm.address_space<ub>>
      memref.store %arg3, %1[%arg0] : memref<64xf32, #hivm.address_space<ub>>
      %2 = memref.load %arg5[%arg0] : memref<64xf32, #hivm.address_space<ub>>
      %3 = memref.load %1[%arg0] : memref<64xf32, #hivm.address_space<ub>>
      %4 = arith.addf %2, %3 : f32
      memref.store %4, %1[%arg0] : memref<64xf32, #hivm.address_space<ub>>
      %5 = hivm.hir.pointer_cast(%c256_i64) : memref<64xf32, #hivm.address_space<ub>>
      annotation.mark %5 {mem_unique} : memref<64xf32, #hivm.address_space<ub>>
      hivm.hir.copy ins(%1 : memref<64xf32, #hivm.address_space<ub>>) outs(%5 : memref<64xf32, #hivm.address_space<ub>>)
      scf.yield %5 : memref<64xf32, #hivm.address_space<ub>>
    }
    return %0 : memref<64xf32, #hivm.address_space<ub>>
  }
}


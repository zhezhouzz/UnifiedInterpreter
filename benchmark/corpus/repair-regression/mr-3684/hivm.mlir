module {
  func.func @yield_preload_local_used_after(%arg0: memref<?xf32, #hivm.address_space<gm>>, %arg1: memref<?xf32, #hivm.address_space<gm>>, %arg2: i32) {
    %c2_i32 = arith.constant 2 : i32
    %c16384_i64 = arith.constant 16384 : i64
    %c65536_i64 = arith.constant 65536 : i64
    %c32768_i64 = arith.constant 32768 : i64
    %c81920_i64 = arith.constant 81920 : i64
    %c49152_i64 = arith.constant 49152 : i64
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %0 = hivm.hir.pointer_cast(%c49152_i64) : memref<64x64xf32, #hivm.address_space<ub>>
    %reinterpret_cast = memref.reinterpret_cast %arg0 to offset: [0], sizes: [64, 64], strides: [64, 1] : memref<?xf32, #hivm.address_space<gm>> to memref<64x64xf32, strided<[64, 1]>, #hivm.address_space<gm>>
    %reinterpret_cast_0 = memref.reinterpret_cast %arg1 to offset: [0], sizes: [64, 64], strides: [64, 1] : memref<?xf32, #hivm.address_space<gm>> to memref<64x64xf32, strided<[64, 1]>, #hivm.address_space<gm>>
    %1 = arith.addi %arg2, %c2_i32 : i32
    %2 = arith.cmpi sgt, %arg2, %c0_i32 : i32
    %3 = arith.select %2, %1, %c0_i32 : i32
    %4 = scf.for %arg3 = %c0_i32 to %3 step %c1_i32 iter_args(%arg4 = %0) -> (memref<64x64xf32, #hivm.address_space<ub>>)  : i32 {
      %6 = arith.subi %arg3, %c1_i32 : i32
      %7 = hivm.hir.pointer_cast(%c32768_i64, %c81920_i64) : memref<64x64xf32, #hivm.address_space<ub>>
      %8 = hivm.hir.pointer_cast(%c32768_i64, %c81920_i64) : memref<64x64xf32, #hivm.address_space<ub>>
      annotation.mark %7 {hivm.multi_buffer = 2 : i32} : memref<64x64xf32, #hivm.address_space<ub>>
      annotation.mark %8 {hivm.multi_buffer = 2 : i32} : memref<64x64xf32, #hivm.address_space<ub>>
      %9 = hivm.hir.pointer_cast(%c16384_i64, %c65536_i64) : memref<64x64xf32, #hivm.address_space<ub>>
      %10 = hivm.hir.pointer_cast(%c65536_i64, %c16384_i64) : memref<64x64xf32, #hivm.address_space<ub>>
      annotation.mark %10 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<64x64xf32, #hivm.address_space<ub>>
      annotation.mark %9 {hivm.multi_buffer = 2 : i32, hivm.preload_local_buffer = 1 : i32} : memref<64x64xf32, #hivm.address_space<ub>>
      %11 = arith.cmpi sge, %arg3, %c0_i32 : i32
      %12 = arith.cmpi slt, %arg3, %arg2 : i32
      %13 = arith.andi %11, %12 : i1
      scf.if %13 {
        annotation.mark %9 {effects = ["write", "read"], hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>} : memref<64x64xf32, #hivm.address_space<ub>>
      }
      %14 = arith.cmpi sge, %6, %c0_i32 : i32
      %15 = arith.cmpi slt, %6, %arg2 : i32
      %16 = arith.andi %14, %15 : i1
      %17 = scf.if %16 -> (memref<64x64xf32, #hivm.address_space<ub>>) {
        %collapse_shape_3 = memref.collapse_shape %reinterpret_cast [[0, 1]] : memref<64x64xf32, strided<[64, 1]>, #hivm.address_space<gm>> into memref<4096xf32, strided<[1]>, #hivm.address_space<gm>>
        %collapse_shape_4 = memref.collapse_shape %7 [[0, 1]] : memref<64x64xf32, #hivm.address_space<ub>> into memref<4096xf32, #hivm.address_space<ub>>
        hivm.hir.load ins(%collapse_shape_3 : memref<4096xf32, strided<[1]>, #hivm.address_space<gm>>) outs(%collapse_shape_4 : memref<4096xf32, #hivm.address_space<ub>>) eviction_policy = <EvictFirst> core_type = <VECTOR>
        %18 = hivm.hir.pointer_cast(%c49152_i64) : memref<64x64xf32, #hivm.address_space<ub>>
        scf.yield %18 : memref<64x64xf32, #hivm.address_space<ub>>
      } else {
        scf.yield %arg4 : memref<64x64xf32, #hivm.address_space<ub>>
      }
      scf.yield %17 : memref<64x64xf32, #hivm.address_space<ub>>
    }
    %5 = hivm.hir.pointer_cast(%c16384_i64, %c65536_i64) : memref<64x64xf32, #hivm.address_space<ub>>
    %collapse_shape = memref.collapse_shape %5 [[0, 1]] : memref<64x64xf32, #hivm.address_space<ub>> into memref<4096xf32, #hivm.address_space<ub>>
    %collapse_shape_1 = memref.collapse_shape %reinterpret_cast_0 [[0, 1]] : memref<64x64xf32, strided<[64, 1]>, #hivm.address_space<gm>> into memref<4096xf32, strided<[1]>, #hivm.address_space<gm>>
    hivm.hir.store ins(%collapse_shape : memref<4096xf32, #hivm.address_space<ub>>) outs(%collapse_shape_1 : memref<4096xf32, strided<[1]>, #hivm.address_space<gm>>)
    %collapse_shape_2 = memref.collapse_shape %4 [[0, 1]] : memref<64x64xf32, #hivm.address_space<ub>> into memref<4096xf32, #hivm.address_space<ub>>
    hivm.hir.store ins(%collapse_shape_2 : memref<4096xf32, #hivm.address_space<ub>>) outs(%collapse_shape_1 : memref<4096xf32, strided<[1]>, #hivm.address_space<gm>>)
    return
  }
}


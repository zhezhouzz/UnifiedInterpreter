
func.func @for_op_if_true_mf_setwait(%arg0: memref<16xf32, #hivm.address_space<gm>>, %arg1: memref<16xf32, #hivm.address_space<gm>>, %arg2: memref<256xf32, #hivm.address_space<gm>>, %cond: i1) {
  %c0_i64 = arith.constant 0 : i64
  %c64_i64 = arith.constant 64 : i64
  %true = arith.constant true
  %c16 = arith.constant 16 : index
  %c256 = arith.constant 256 : index
  %c0_i32 = arith.constant 0 : i32
  %c4_i32 = arith.constant 4 : i32
  %c1_i32 = arith.constant 1 : i32
  scf.for %i = %c0_i32 to %c4_i32 step %c1_i32 : i32 {
    %buf_a = hivm.hir.pointer_cast(%c0_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<16xf32, #hivm.address_space<gm>>) outs(%buf_a : memref<16xf32, #hivm.address_space<cbuf>>)
    %buf_b = hivm.hir.pointer_cast(%c64_i64) : memref<16xf32, #hivm.address_space<cbuf>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg1 : memref<16xf32, #hivm.address_space<gm>>) outs(%buf_b : memref<16xf32, #hivm.address_space<cbuf>>)
    %buf_cc = hivm.hir.pointer_cast(%c0_i64) : memref<256xf32, #hivm.address_space<cc>>
    scf.if %cond {
      hivm.hir.mmadL1 ins(%buf_a, %buf_b, %true, %c16, %c256, %c16 : memref<16xf32, #hivm.address_space<cbuf>>, memref<16xf32, #hivm.address_space<cbuf>>, i1, index, index, index) outs(%buf_cc : memref<256xf32, #hivm.address_space<cc>>)
      hivm.hir.fixpipe {enable_nz2nd} ins(%buf_cc : memref<256xf32, #hivm.address_space<cc>>) outs(%arg2 : memref<256xf32, #hivm.address_space<gm>>)
    }
  }
  return
}

"builtin.module"() ({
  "func.func"() <{function_type = (memref<1x1x16x16xf16, #hivm.address_space<cbuf>>, memref<1x1x16x16xf16, #hivm.address_space<cbuf>>, memref<1x1x16x16xf32, #hivm.address_space<cc>>) -> (), sym_name = "mmad_parts"}> ({
  ^bb0(%arg0: memref<1x1x16x16xf16, #hivm.address_space<cbuf>>, %arg1: memref<1x1x16x16xf16, #hivm.address_space<cbuf>>, %arg2: memref<1x1x16x16xf32, #hivm.address_space<cc>>):
    %0 = "arith.constant"() <{value = true}> : () -> i1
    %1 = "arith.constant"() <{value = 16 : index}> : () -> index
    "hivm.hir.mmadL1"(%arg0, %arg1, %0, %1, %1, %1, %arg2) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1, 0, 0, 0>}> : (memref<1x1x16x16xf16, #hivm.address_space<cbuf>>, memref<1x1x16x16xf16, #hivm.address_space<cbuf>>, i1, index, index, index, memref<1x1x16x16xf32, #hivm.address_space<cc>>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()

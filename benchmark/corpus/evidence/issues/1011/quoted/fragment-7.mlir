// AIC（Cube 侧）：A 按 16×8 分形视图解释
46094  %3 = hivm.hir.pointer_cast(%c18432_i64) : memref<18x1x1x16x8xf32, #hivm.address_space<cbuf>>

// AIV（Vector 侧）：A 按稠密 18×7×5 写入
46192  %6 = hivm.hir.pointer_cast(%c18432_i64) : memref<18x7x5xf32, #hivm.address_space<cbuf>>
46199      %collapse_shape_7 = memref.collapse_shape %subview
                  : memref<18x7x5xf32, strided<[56, 8, 1]>, ub> -> memref<126x5xf32, strided<[8, 1]>, ub>
46200      %collapse_shape_8 = memref.collapse_shape %6
                  : memref<18x7x5xf32, cbuf> -> memref<126x5xf32, cbuf>
46201      hivm.hir.copy ins(%collapse_shape_7) outs(%collapse_shape_8) {"hivm.inserted-copy"}

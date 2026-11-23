40340  %alloc = memref.alloc(%c18_0, %3, %2, %c16, %c8) : memref<?x?x?x?x?xf32, #hivm.address_space<cbuf>>
...
40353    hivm.hir.nd2nz {dst_continuous} ins(%collapse_shape : memref<?x?xf32, strided<[10, 1]>, gm>)
                outs(%collapse_shape_17 : memref<?x?x?x?xf32, strided<[?, ?, ?, 1]>, cbuf>)
...
40366  %alloc_11 = memref.alloc(%c18_6, %5, %4, %c16_9, %c8_10) : memref<?x?x?x?x?xf32, #hivm.address_space<cbuf>>
40367  annotation.mark %alloc_11 {effects = ["write", "read"],
              hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>}
...
40387    %subview = memref.subview %alloc_11[%arg11, %10, %8, %9, %11] [1, %7, %6, %c16_16, %c8_17]
                : memref<?x?x?x?x?xf32, cbuf> to memref<?x?x?x?xf32, strided<[?, ?, ?, 1]>>
40411    hivm.hir.mmadL1 {already_set_real_mkn, batch_matmul, …}
                ins(%subview, %subview_27, … : memref<?x?x?x?xf32, strided<[?, ?, ?, 1]>>, …)
                outs(%alloc_32 : memref<?x?x?x?xf32, #hivm.address_space<cc>>)

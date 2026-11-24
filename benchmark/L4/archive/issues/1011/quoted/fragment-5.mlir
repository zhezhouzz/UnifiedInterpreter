39886    %alloc_0 = memref.alloc() : memref<18x7x5xf32, #hivm.address_space<cbuf>>
39887    annotation.mark %alloc_0 {effects = ["write", "read"],
                hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>}
...
39894      %subview = memref.subview %alloc_0[%arg11, 0, 0] [1, 7, 5] [1, 1, 1]
                  : memref<18x7x5xf32, cbuf> to memref<7x5xf32, strided<[5, 1], offset: ?>>
39896      %subview_2 = memref.subview %alloc[%arg11, 0, 0] [1, 5, 10] [1, 1, 1]   // B 操作数
39899      hivm.hir.mmadL1 {already_set_real_mkn, batch_matmul, …}
                  ins(%subview, %subview_2, %true, %c7, %c5, %c10
                      : memref<7x5xf32, strided<[5, 1]>>, memref<5x10xf32, strided<[10, 1]>>, …)
                  outs(%alloc_3 : memref<7x10xf32, #hivm.address_space<cc>>)

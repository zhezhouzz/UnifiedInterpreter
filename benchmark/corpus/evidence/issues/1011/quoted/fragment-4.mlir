2752    %alloc_6 = memref.alloc() : memref<18x7x5xf32, #hivm.address_space<cbuf>>
2754    hivm.hir.copy ins(%8 : tensor<18x7x5xf32>)
                outs(%alloc_6 : memref<18x7x5xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
2756    scf.for %arg11 = %c0 to %c18 step %c1 {
2757      %extracted_slice = tensor.extract_slice %9[%arg11, 0, 0] [1, 7, 5] [1, 1, 1]
                  : tensor<18x7x5xf32> to tensor<7x5xf32>
2760      %11 = hivm.hir.mmadL1 {batch_matmul, fixpipe_for_result_already_inserted = true}
                  ins(%extracted_slice, %extracted_slice_8, … : tensor<7x5xf32>, tensor<5x10xf32>, …)
                  outs(%10 : tensor<7x10xf32>) -> tensor<7x10xf32>

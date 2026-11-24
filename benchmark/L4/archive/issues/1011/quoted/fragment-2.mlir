2629    %10 = hivm.hir.copy ins(%8 : tensor<18x7x5xf32>) outs(%9 : tensor<18x7x5xf32>)
                {"hivm.inserted-copy"} -> tensor<18x7x5xf32>
2631    %12 = hivm.hir.batchMmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C}
                ins(%10, %5, %true, %c7, %c5, %c10
                    : tensor<18x7x5xf32>, tensor<18x5x10xf32>, i1, index, index, index)
                outs(%11 : tensor<18x7x10xf32>) -> tensor<18x7x10xf32>

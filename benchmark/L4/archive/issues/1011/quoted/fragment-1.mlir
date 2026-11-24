 22      %6 = arith.mulf %2, %3 : tensor<18x7x5xf32>
 23      %7 = arith.addf %4, %6 : tensor<18x7x5xf32>
 24      %8 = linalg.batch_matmul {input_precision = "ieee"}
               ins(%7, %5 : tensor<18x7x5xf32>, tensor<18x5x10xf32>)
               outs(%1 : tensor<18x7x10xf32>) -> tensor<18x7x10xf32>

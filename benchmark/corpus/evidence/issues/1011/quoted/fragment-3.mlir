2739    %11 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>}
                ins(%cst : f32) outs(%10 : tensor<32x16xf32>) -> tensor<32x16xf32>
2740    %inserted_slice = tensor.insert_slice %8 into %11[0, 0] [21, 12] [1, 1]
                : tensor<21x12xf32> into tensor<32x16xf32>
2741    %expanded = tensor.expand_shape %inserted_slice [[0], [1, 2]] output_shape [32, 2, 8]
                : tensor<32x16xf32> into tensor<32x2x8xf32>
2743    %13 = hivm.hir.vtranspose ins(%expanded : tensor<32x2x8xf32>)
                outs(%12 : tensor<2x32x8xf32>) permutation = [1, 0, 2] -> tensor<2x32x8xf32>
2744    %expanded_6 = tensor.expand_shape %13 [[0], [1, 2], [3]] output_shape [2, 2, 16, 8]
                : tensor<2x32x8xf32> into tensor<2x2x16x8xf32>
2746    %15 = hivm.hir.copy ins(%expanded_6 : tensor<2x2x16x8xf32>)
                outs(%14 : tensor<2x2x16x8xf32>) {"hivm.inserted-copy"} -> tensor<2x2x16x8xf32>
2747    %16 = hivm.hir.mmadL1 {already_set_real_mkn, …}
                ins(%15, %5, … : tensor<2x2x16x8xf32>, tensor<12x227xf32>, …)
                outs(%9 : tensor<21x227xf32>) -> tensor<21x227xf32>

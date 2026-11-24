%x = hivm.hir.atomic_cas
    ins(%cmp, %new : memref<160xi32>, memref<160xi32>)
    outs(%gm : memref<160xi32, strided<[1], offset: ?>>) -> tensor<160xi32>

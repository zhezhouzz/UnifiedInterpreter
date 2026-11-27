module {
    func.func @vadd_inplace(%lhs_gm : memref<16x16xf16, #hivm.address_space<gm>>,
                             %rhs_gm :  memref<16x16xf16, #hivm.address_space<gm>>,
                             %vadd_gm :memref<16x16xf16, #hivm.address_space<gm>>) {
      %lhs_ub = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
      hivm.hir.load ins(%lhs_gm : memref<16x16xf16, #hivm.address_space<gm>>)
                    outs(%lhs_ub : memref<16x16xf16, #hivm.address_space<ub>>)
      %rhs_ub = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
      hivm.hir.load ins(%rhs_gm : memref<16x16xf16, #hivm.address_space<gm>>)
                    outs(%rhs_ub : memref<16x16xf16, #hivm.address_space<ub>>)
      %vadd_res_ub = memref.alloc() : memref<16x16xf16, #hivm.address_space<ub>>
      hivm.hir.vadd ins(%lhs_ub, %rhs_ub : memref<16x16xf16, #hivm.address_space<ub>>,
                        memref<16x16xf16, #hivm.address_space<ub>>)
                    outs(%vadd_res_ub : memref<16x16xf16, #hivm.address_space<ub>>)
      hivm.hir.store ins(%vadd_res_ub : memref<16x16xf16, #hivm.address_space<ub>>)
                     outs(%vadd_gm : memref<16x16xf16, #hivm.address_space<gm>>)
      return
    }
}

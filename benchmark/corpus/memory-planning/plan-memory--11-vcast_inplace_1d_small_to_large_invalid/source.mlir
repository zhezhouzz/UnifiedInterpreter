module {
    func.func @vcast_inplace_1d_small_to_large_invalid(%arg0_gm : memref<1024xf16, #hivm.address_space<gm>>,
                                                       %vcast_gm :memref<1024xf32, #hivm.address_space<gm>>) {
      %arg0_ub = memref.alloc() : memref<1024xf16, #hivm.address_space<ub>>
      hivm.hir.load ins(%arg0_gm : memref<1024xf16, #hivm.address_space<gm>>)
                    outs(%arg0_ub : memref<1024xf16, #hivm.address_space<ub>>)
      %vcast_res_ub = memref.alloc() : memref<1024xf32, #hivm.address_space<ub>>
      hivm.hir.vcast ins(%arg0_ub : memref<1024xf16, #hivm.address_space<ub>>)
      outs(%vcast_res_ub : memref<1024xf32, #hivm.address_space<ub>>) round_mode = #hivm.round_mode<rint>
      hivm.hir.store ins(%vcast_res_ub : memref<1024xf32, #hivm.address_space<ub>>)
                     outs(%vcast_gm : memref<1024xf32, #hivm.address_space<gm>>)
      return
    }
}

%v = ave.hir.vload <NORM> %m[%c0, %c0]
    {ave.unaligned_ub_access = #ave.unaligned_ub_access}
    : memref<1x64xf32, #hivm.address_space<ub>>, vector<64xf32>

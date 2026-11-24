%pge = ave.hir.pge <VL4> ...
ave.hir.masked_store <NORM_B32> %val, %arg0[...], %pge
    : ..., memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
//              ^^^^^^^^^^^^^^^^ 类型里还带着 stride，但 NORM_B32 按连续地址落地，stride 被忽略

Before VectorToHIVMAVE, `%base` is an aligned UB memref, `%c0` is a zero index, and `%zero` is an `f32` zero.

```mlir
%m = memref.expand_shape %base [[0, 1]] output_shape [1, 64]
    : memref<64xf32, #hivm.address_space<ub>>
    into memref<1x64xf32, #hivm.address_space<ub>>
%v = vector.transfer_read %m[%c0, %c0], %zero {in_bounds = [true, true]}
    : memref<1x64xf32, #hivm.address_space<ub>>, vector<1x64xf32>
```

After VectorToHIVMAVE, the load is marked unaligned.

```mlir
%v = ave.hir.vload <NORM> %m[%c0, %c0]
    {ave.unaligned_ub_access = #ave.unaligned_ub_access}
    : memref<1x64xf32, #hivm.address_space<ub>>, vector<64xf32>
```

`memref.expand_shape` preserves the base address. The load at `%m[0, 0]` starts at the same aligned address as `%base[0]`, so it should lower to an aligned load.
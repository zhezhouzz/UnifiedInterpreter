%m = memref.expand_shape %base [[0, 1]] output_shape [1, 64]
    : memref<64xf32, #hivm.address_space<ub>>
    into memref<1x64xf32, #hivm.address_space<ub>>
%v = vector.transfer_read %m[%c0, %c0], %zero {in_bounds = [true, true]}
    : memref<1x64xf32, #hivm.address_space<ub>>, vector<1x64xf32>

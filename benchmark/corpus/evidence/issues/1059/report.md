## Background
During performance analysis of DynamicMxQuant on Ascend950, an opportunity was found to improve how quantization multipliers are computed. Each group of 32 input elements has a scale parameter. A short sequence of elementwise operations converts that parameter into a multiplier shared by all elements in the group.
For a row of 8192 elements, there are 256 groups and 256 multipliers to compute.

## Current behavior
The generated code splits this work into two loops:
- The first loop prepares scale parameters for 64 different groups per iteration and stores them in UB.
- The second loop loads one scale parameter per iteration, broadcasts it across vector lanes, and then computes the multiplier.
After broadcast, all active lanes perform the same calculation on the same scale parameter. The multiplier computation consists of subtraction, shift, two comparisons, predicate AND, and select. This sequence executes 256 times per row, although the first loop already has 64 different scale parameters available together in a vector.

## Expected behavior
Compute the multipliers in the first loop, using the vector of 64 different scale parameters, and store the prepared multipliers in UB. The second loop should load and broadcast a prepared multiplier, then use it directly. This would reduce execution of the multiplier computation sequence from 256 to 4 times per row.

## Possible approach
Preserve per-group computations before broadcast during fusion/vectorization, or recover this placement in a later optimization. In the captured pipeline, `hfusion-pre-vectorization-fusion` moves the multiplier expression into the larger broadcast domain. The desired placement should survive subsequent lowering.

A manual IR transformation reduced kernel time from approximately 42.07 µs to 27.04 µs.

## IR comparison

<details>
<summary>Current IR</summary>

```mlir
scf.for %arg5 = %c0 to %c256 step %c64 {

  %base_buffer, %offset, %sizes, %strides = memref.extract_strided_metadata %arg2 : memref<256xi32, #hivm.address_space<ub>> -> memref<i32, #hivm.address_space<ub>>, index, index, index
  %reinterpret_cast = memref.reinterpret_cast %base_buffer to offset: [%arg5], sizes: [64], strides: [1] : memref<i32, #hivm.address_space<ub>> to memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>

  %base_buffer_0, %offset_1, %sizes_2, %strides_3 = memref.extract_strided_metadata %arg1 : memref<256xi32, #hivm.address_space<ub>> -> memref<i32, #hivm.address_space<ub>>, index, index, index
  %reinterpret_cast_4 = memref.reinterpret_cast %base_buffer_0 to offset: [%arg5], sizes: [64], strides: [1] : memref<i32, #hivm.address_space<ub>> to memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>

  %res = ave.hir.vload <NORM> %reinterpret_cast[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xi32>

  %13 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %14 = ave.hir.vshrs %res, %c7_i32, %13, %true : vector<64xi32>, i32, vector<64xi1>
  %15 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %16 = ave.hir.vsub %14, %7, %15 : vector<64xi32>, vector<64xi1>
  %17 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %18 = ave.hir.vsmaxs %16, %c0_i32, %17 : vector<64xi32>, i32, vector<64xi1>
  %19 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %20 = ave.hir.vsmins %18, %c255_i32, %19 : vector<64xi32>, i32, vector<64xi1>
  %21 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %22 = ave.hir.vcmp <GE> %res, %1, %21 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
  %23 = ave.hir.vsel %22, %3, %20 : vector<64xi1>, vector<64xi32>
  %24 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>

  ave.hir.masked_store <NORM_B32> %reinterpret_cast_4[%c0], %24, %23 {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi32>

  %base_buffer_5, %offset_6, %sizes_7, %strides_8 = memref.extract_strided_metadata %arg0 : memref<256xi8, #hivm.address_space<ub>> -> memref<i8, #hivm.address_space<ub>>, index, index, index
  %reinterpret_cast_9 = memref.reinterpret_cast %base_buffer_5 to offset: [%arg5], sizes: [64], strides: [1] : memref<i8, #hivm.address_space<ub>> to memref<64xi8, strided<[1], offset: ?>, #hivm.address_space<ub>>
  %25 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %26 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %27 = ave.hir.broadcast %c255_i32, %26 : i32, vector<64xi1> -> vector<64xi32>
  %28 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %29 = ave.hir.vand %23, %27, %28 : vector<64xi32>, vector<64xi1>
  %30 = ave.hir.vtrunci %29, false, %25 {functionType = #ave.func_dist_type<even>, pp = #ave.vcvt_pp_type<pp0>, uni = #hivm.unsigned_mode<si2ui>} : vector<64xi32>, vector<64xi8>, vector<64xi1>
  %31 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %32 = builtin.unrealized_conversion_cast %30 : vector<64xi8> to vector<256xi8>
  %33 = llvm.bitcast %32 : vector<256xi8> to vector<64xi32>

  ave.hir.masked_store <PK4_B32> %reinterpret_cast_9[%c0], %31, %33 {functionType = #ave.func_dist_type<pk4>, hivm.is_continuous} : memref<64xi8, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi32>
}

scf.for %arg5 = %c0 to %c256 step %c1 {

  %base_buffer, %offset, %sizes, %strides = memref.extract_strided_metadata %arg1 : memref<256xi32, #hivm.address_space<ub>> -> memref<i32, #hivm.address_space<ub>>, index, index, index
  %reinterpret_cast = memref.reinterpret_cast %base_buffer to offset: [%arg5], sizes: [1], strides: [1] : memref<i32, #hivm.address_space<ub>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>

  %base_buffer_0, %offset_1, %sizes_2:2, %strides_3:2 = memref.extract_strided_metadata %arg4 : memref<256x32xbf16, #hivm.address_space<ub>> -> memref<bf16, #hivm.address_space<ub>>, index, index, index, index, index
  %13 = affine.apply #map()[%arg5]
  %reinterpret_cast_4 = memref.reinterpret_cast %base_buffer_0 to offset: [%13], sizes: [32], strides: [1] : memref<bf16, #hivm.address_space<ub>> to memref<32xbf16, #map1, #hivm.address_space<ub>>

  %res = ave.hir.vload <UNPK_B16> %reinterpret_cast_4[%c0] {functionType = #ave.func_dist_type<pk>} : memref<32xbf16, #map1, #hivm.address_space<ub>> into vector<64xbf16>

  %res_5 = ave.hir.vload <BRC_B32> %reinterpret_cast[%c0] {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xi32>

  %14 = ave.hir.vsub %9, %res_5, %12 : vector<64xi32>, vector<64xi1>
  %15 = ave.hir.vshls %14, %c23_i32, %12, %false : vector<64xi32>, i32, vector<64xi1>
  %16 = vector.bitcast %15 : vector<64xi32> to vector<64xf32>
  %17 = ave.hir.vcmp <LT> %res_5, %3, %12 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
  %18 = ave.hir.vcmp <GT> %res_5, %5, %12 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
  %19 = ave.hir.preg.and <b8> %18, %17, %12 : vector<64xi1>
  %20 = ave.hir.vsel %19, %16, %11 : vector<64xi1>, vector<64xf32>

  %21 = ave.hir.vextf %res, <part_even>, %12 {functionType = #ave.func_dist_type<even>} : vector<64xbf16>, vector<64xf32>, vector<64xi1>
  %22 = ave.hir.vmul %21, %20, %12 : vector<64xf32>, vector<64xi1>
  %23 = ave.hir.vtruncf %22, <rint>, true, <part_even>, %12 {functionType = #ave.func_dist_type<even>} : vector<64xf32>, vector<64xf8E4M3FN>, vector<64xi1>

  %base_buffer_6, %offset_7, %sizes_8:2, %strides_9:2 = memref.extract_strided_metadata %arg3 : memref<256x32xf8E4M3FN, #hivm.address_space<ub>> -> memref<f8E4M3FN, #hivm.address_space<ub>>, index, index, index, index, index
  %24 = affine.apply #map()[%arg5]
  %reinterpret_cast_10 = memref.reinterpret_cast %base_buffer_6 to offset: [%24], sizes: [32], strides: [1] : memref<f8E4M3FN, #hivm.address_space<ub>> to memref<32xf8E4M3FN, #map1, #hivm.address_space<ub>>
  %25 = builtin.unrealized_conversion_cast %23 : vector<64xf8E4M3FN> to vector<256xf8E4M3FN>
  %26 = llvm.bitcast %25 : vector<256xf8E4M3FN> to vector<64xf32>

  ave.hir.masked_store <PK4_B32> %reinterpret_cast_10[%c0], %12, %26 {functionType = #ave.func_dist_type<pk4>} : memref<32xf8E4M3FN, #map1, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
}
```

</details>

<details>
<summary>Expected IR</summary>

```mlir
scf.for %arg5 = %c0 to %c256 step %c64 {

  %base_buffer, %offset, %sizes, %strides = memref.extract_strided_metadata %arg2 : memref<256xi32, #hivm.address_space<ub>> -> memref<i32, #hivm.address_space<ub>>, index, index, index
  %reinterpret_cast = memref.reinterpret_cast %base_buffer to offset: [%arg5], sizes: [64], strides: [1] : memref<i32, #hivm.address_space<ub>> to memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>

  %base_buffer_0, %offset_1, %sizes_2, %strides_3 = memref.extract_strided_metadata %arg1 : memref<256xi32, #hivm.address_space<ub>> -> memref<i32, #hivm.address_space<ub>>, index, index, index
  %reinterpret_cast_4 = memref.reinterpret_cast %base_buffer_0 to offset: [%arg5], sizes: [64], strides: [1] : memref<i32, #hivm.address_space<ub>> to memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>

  %res = ave.hir.vload <NORM> %reinterpret_cast[%c0] {functionType = #ave.func_dist_type<norm>} : memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xi32>

  %13 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %14 = ave.hir.vshrs %res, %c7_i32, %13, %true : vector<64xi32>, i32, vector<64xi1>
  %15 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %16 = ave.hir.vsub %14, %7, %15 : vector<64xi32>, vector<64xi1>
  %17 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %18 = ave.hir.vsmaxs %16, %c0_i32, %17 : vector<64xi32>, i32, vector<64xi1>
  %19 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %20 = ave.hir.vsmins %18, %c255_i32, %19 : vector<64xi32>, i32, vector<64xi1>
  %21 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %22 = ave.hir.vcmp <GE> %res, %1, %21 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
  %23 = ave.hir.vsel %22, %3, %20 : vector<64xi1>, vector<64xi32>
  %24 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>

  %mult_sub = ave.hir.vsub %9, %23, %24 : vector<64xi32>, vector<64xi1>
  %mult_bits = ave.hir.vshls %mult_sub, %c23_i32, %24, %false : vector<64xi32>, i32, vector<64xi1>
  %mult_lt = ave.hir.vcmp <LT> %23, %3, %24 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
  %mult_gt = ave.hir.vcmp <GT> %23, %5, %24 : vector<64xi32>, vector<64xi1> -> vector<64xi1>
  %mult_valid = ave.hir.preg.and <b8> %mult_gt, %mult_lt, %24 : vector<64xi1>
  %mult_ready = ave.hir.vsel %mult_valid, %mult_bits, %5 : vector<64xi1>, vector<64xi32>

  ave.hir.masked_store <NORM_B32> %reinterpret_cast_4[%c0], %24, %mult_ready {functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<64xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi32>

  %base_buffer_5, %offset_6, %sizes_7, %strides_8 = memref.extract_strided_metadata %arg0 : memref<256xi8, #hivm.address_space<ub>> -> memref<i8, #hivm.address_space<ub>>, index, index, index
  %reinterpret_cast_9 = memref.reinterpret_cast %base_buffer_5 to offset: [%arg5], sizes: [64], strides: [1] : memref<i8, #hivm.address_space<ub>> to memref<64xi8, strided<[1], offset: ?>, #hivm.address_space<ub>>
  %25 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %26 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %27 = ave.hir.broadcast %c255_i32, %26 : i32, vector<64xi1> -> vector<64xi32>
  %28 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %29 = ave.hir.vand %23, %27, %28 : vector<64xi32>, vector<64xi1>
  %30 = ave.hir.vtrunci %29, false, %25 {functionType = #ave.func_dist_type<even>, pp = #ave.vcvt_pp_type<pp0>, uni = #hivm.unsigned_mode<si2ui>} : vector<64xi32>, vector<64xi8>, vector<64xi1>
  %31 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
  %32 = builtin.unrealized_conversion_cast %30 : vector<64xi8> to vector<256xi8>
  %33 = llvm.bitcast %32 : vector<256xi8> to vector<64xi32>

  ave.hir.masked_store <PK4_B32> %reinterpret_cast_9[%c0], %31, %33 {functionType = #ave.func_dist_type<pk4>, hivm.is_continuous} : memref<64xi8, strided<[1], offset: ?>, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi32>
}

scf.for %arg5 = %c0 to %c256 step %c1 {

  %base_buffer, %offset, %sizes, %strides = memref.extract_strided_metadata %arg1 : memref<256xi32, #hivm.address_space<ub>> -> memref<i32, #hivm.address_space<ub>>, index, index, index
  %reinterpret_cast = memref.reinterpret_cast %base_buffer to offset: [%arg5], sizes: [1], strides: [1] : memref<i32, #hivm.address_space<ub>> to memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<ub>>

  %base_buffer_0, %offset_1, %sizes_2:2, %strides_3:2 = memref.extract_strided_metadata %arg4 : memref<256x32xbf16, #hivm.address_space<ub>> -> memref<bf16, #hivm.address_space<ub>>, index, index, index, index, index
  %13 = affine.apply #map()[%arg5]
  %reinterpret_cast_4 = memref.reinterpret_cast %base_buffer_0 to offset: [%13], sizes: [32], strides: [1] : memref<bf16, #hivm.address_space<ub>> to memref<32xbf16, #map1, #hivm.address_space<ub>>

  %res = ave.hir.vload <UNPK_B16> %reinterpret_cast_4[%c0] {functionType = #ave.func_dist_type<pk>} : memref<32xbf16, #map1, #hivm.address_space<ub>> into vector<64xbf16>

  %res_5 = ave.hir.vload <BRC_B32> %reinterpret_cast[%c0] {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>} : memref<1xi32, strided<[1], offset: ?>, #hivm.address_space<ub>> into vector<64xi32>
  %20 = vector.bitcast %res_5 : vector<64xi32> to vector<64xf32>

  %21 = ave.hir.vextf %res, <part_even>, %12 {functionType = #ave.func_dist_type<even>} : vector<64xbf16>, vector<64xf32>, vector<64xi1>
  %22 = ave.hir.vmul %21, %20, %12 : vector<64xf32>, vector<64xi1>
  %23 = ave.hir.vtruncf %22, <rint>, true, <part_even>, %12 {functionType = #ave.func_dist_type<even>} : vector<64xf32>, vector<64xf8E4M3FN>, vector<64xi1>

  %base_buffer_6, %offset_7, %sizes_8:2, %strides_9:2 = memref.extract_strided_metadata %arg3 : memref<256x32xf8E4M3FN, #hivm.address_space<ub>> -> memref<f8E4M3FN, #hivm.address_space<ub>>, index, index, index, index, index
  %24 = affine.apply #map()[%arg5]
  %reinterpret_cast_10 = memref.reinterpret_cast %base_buffer_6 to offset: [%24], sizes: [32], strides: [1] : memref<f8E4M3FN, #hivm.address_space<ub>> to memref<32xf8E4M3FN, #map1, #hivm.address_space<ub>>
  %25 = builtin.unrealized_conversion_cast %23 : vector<64xf8E4M3FN> to vector<256xf8E4M3FN>
  %26 = llvm.bitcast %25 : vector<256xf8E4M3FN> to vector<64xf32>

  ave.hir.masked_store <PK4_B32> %reinterpret_cast_10[%c0], %12, %26 {functionType = #ave.func_dist_type<pk4>} : memref<32xf8E4M3FN, #map1, #hivm.address_space<ub>>, vector<64xi1>, vector<64xf32>
}
```

</details>

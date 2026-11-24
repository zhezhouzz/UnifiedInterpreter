## Background
DynamicMxQuant computes a maximum for each group of 32 BF16 input elements to determine its quantization scale. This computation operates on the integer representation of the BF16 values after clearing the sign bit.

For a row of 8192 elements, the generated loop processes 256 groups independently, one group per iteration. Each iteration extends the 32 input values from i16 to i32, performs a maximum reduction, and stores a single i32 result in UB.

Although adjacent groups are stored contiguously, the generated code does not process them together. This results in 256 separate reductions and single-element stores per row. The extension to i32 also occurs before the reduction, even though clearing the sign bit limits the values to the range 0–32767.

## Possible approach
Recognize independent reductions over contiguous groups during vectorization and lower them using grouped reduction instructions. In the manually transformed variant, an i16 grouped maximum first reduces each block of 16 elements. A pairwise maximum then combines adjacent results to obtain one maximum per original group of 32. Four resulting maximums are stored together.

This transformation reduced kernel time from approximately 55.98 µs to 42.07 µs.

## IR comparison

<details>
<summary>Current IR</summary>

```mlir
%res = ave.hir.vload <UNPK_B16> %reinterpret_cast[%c0] {functionType = #ave.func_dist_type<pk>} : memref<32xbf16, #map1, #hivm.address_space<ub>> into vector<64xbf16>
%6 = vector.bitcast %res : vector<64xbf16> to vector<64xi16>
%7 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
%8 = ave.hir.vand %6, %1, %7 : vector<64xi16>, vector<64xi1>

%9 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
%10 = ave.hir.vextui %8, %9 {functionType = #ave.func_dist_type<even>, part = #ave.vcvt_part_type<part_even>} : vector<64xi16>, vector<64xi32>, vector<64xi1>
%11 = ave.hir.vsel %4, %10, %3 : vector<64xi1>, vector<64xi32>

%12 = ave.hir.pge <ALL> {functionType = #ave.func_dist_type<pb32>} : vector<64xi1>
%13 = ave.hir.reduction <max>, %11, %12 : vector<64xi32>, vector<64xi1> -> vector<64xi32>
%14 = builtin.unrealized_conversion_cast %13 : vector<64xi32> to vector<1xi32>

%15 = ave.hir.pge <VL1> {functionType = #ave.func_dist_type<pb32>} : vector<1xi1>
ave.hir.masked_store <ONEPT_B32> %reinterpret_cast_4[], %15, %14 {ave.unaligned_ub_access = #ave.unaligned_ub_access, functionType = #ave.func_dist_type<norm>, hivm.is_continuous} : memref<i32, strided<[], offset: ?>, #hivm.address_space<ub>>, vector<1xi1>, vector<1xi32>
```
</details>

<details>
<summary>Example of expected IR</summary>

  ```mlir
  scf.for %g = %c0 to %c256 step %c4 {
  %offset = arith.muli %g, %c32 : index
  %x = ave.hir.vload <NORM> %flat[%offset] : memref<8192xbf16, #hivm.address_space<ub>> into vector<128xbf16>
  %bits = vector.bitcast %x : vector<128xbf16> to vector<128xi16>
  %abs = ave.hir.vand %bits, %abs_mask, %p16 : vector<128xi16>, vector<128xi1>

  %halves = ave.hir.group_reduction <max> %abs, %p16 {cast = #hivm.cast<cast_signed>} : vector<128xi16>, vector<128xi1> -> vector<128xi16>

  %pairs = llvm.bitcast %halves : vector<128xi16> to vector<64xi32>
  %lo = ave.hir.vand %pairs, %low_mask, %p4 : vector<64xi32>, vector<64xi1>
  %hi = ave.hir.vshrs %pairs, %c16_i32, %p4, %false : vector<64xi32>, i32, vector<64xi1>
  %maxima = ave.hir.vsmax %lo, %hi, %p4 : vector<64xi32>, vector<64xi1>

  ave.hir.masked_store <NORM_B32> %arg0[%g], %p4, %maxima {ave.unaligned_ub_access = #ave.unaligned_ub_access} : memref<256xi32, #hivm.address_space<ub>>, vector<64xi1>, vector<64xi32>
}
```

</details>

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

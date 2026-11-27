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

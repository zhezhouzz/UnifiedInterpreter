module attributes {hacc.target = #hacc.target<"Ascend960DT_968B7">, hivm.module_core_type = #hivm.module_core_type<AIV>} {
  llvm.func @llvm.hivm.vintlvv2.v256s8(vector<256xi8>, vector<256xi8>, i32) -> vector<256xi8>
  llvm.func @shuffle(%arg0: !llvm.ptr<6>, %arg1: !llvm.ptr<6>) attributes {hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<AIV>, hivm.vector_function, hivm_regbaseintrins.target = #hivm_regbaseintrins.target<"dav-920r1">} {
    %0 = llvm.mlir.constant(0 : i32) : i32
    %1 = llvm.mlir.constant(1 : i32) : i32
    %2 = llvm.mlir.constant(3 : i32) : i32
    %3 = "hivm_regbaseintrins.intr.hivm.vldsx1.v256s8"(%arg0, %0, %0, %0) : (!llvm.ptr<6>, i32, i32, i32) -> vector<256xi8>
    %4 = "hivm_regbaseintrins.intr.hivm.vintlvv2"(%3, %3, %0) : (vector<256xi8>, vector<256xi8>, i32) -> vector<256xi8>
    %5 = llvm.bitcast %4 : vector<256xi8> to vector<128xi16>
    %6 = "hivm_regbaseintrins.intr.hivm.vdintlvv2"(%5, %5, %1) : (vector<128xi16>, vector<128xi16>, i32) -> vector<128xi16>
    %7 = llvm.bitcast %6 : vector<128xi16> to vector<64xi32>
    %8 = "hivm_regbaseintrins.intr.hivm.vdintlv"(%7, %7) : (vector<64xi32>, vector<64xi32>) -> !llvm.struct<(vector<64xi32>, vector<64xi32>)>
    %9 = llvm.extractvalue %8[1] : !llvm.struct<(vector<64xi32>, vector<64xi32>)> 
    %10 = llvm.bitcast %9 : vector<64xi32> to vector<64xf32>
    %11 = "hivm_regbaseintrins.intr.hivm.vintlvv2"(%10, %10, %1) : (vector<64xf32>, vector<64xf32>, i32) -> vector<64xf32>
    %12 = llvm.bitcast %11 : vector<64xf32> to vector<256xi8>
    %13 = "hivm_regbaseintrins.intr.hivm.pge.b8"(%0, %0) {mask_bit_width = 8 : i32} : (i32, i32) -> vector<256xi1>
    "hivm_regbaseintrins.intr.hivm.vstsx1.v256s8"(%12, %arg1, %0, %2, %0, %13) : (vector<256xi8>, !llvm.ptr<6>, i32, i32, i32, vector<256xi1>) -> ()
    llvm.return
  }
  llvm.func @kernel(%arg0: i64, %arg1: i64) attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, hivm.func_core_type = #hivm.func_core_type<AIV>, hivm_regbaseintrins.target = #hivm_regbaseintrins.target<"dav-920r1">} {
    %0 = llvm.inttoptr %arg0 : i64 to !llvm.ptr<6>
    %1 = llvm.inttoptr %arg1 : i64 to !llvm.ptr<6>
    llvm.call @shuffle(%0, %1) {hivm.vector_function} : (!llvm.ptr<6>, !llvm.ptr<6>) -> ()
    llvm.return
  }
}


// REQUIRES: enable-lir-compile
// DEFINE: %{compile} = bishengir-compile --enable-triton-kernel-compile=true --mlir-disable-threading --mlir-print-ir-after=tile-cube-vector-loop,hivm-insert-convert-layout
// DEFINE: %{opt} = bishengir-opt %s --mlir-disable-threading --mlir-print-ir-after=tile-cube-vector-loop,hivm-insert-convert-layout -o %t.mlir
// RUN: %{compile} %s --target=Ascend910_9382 -o %t.default.o 2> %t.default.log
// RUN: FileCheck %s --check-prefixes=TILE,ND,PACKED < %t.default.log
// RUN: %{compile} %s --target=Ascend910_9382 --enable-layout-optimization=true -o %t.on.o 2> %t.on.log
// RUN: FileCheck %s --check-prefixes=TILE,ND,PACKED < %t.on.log
// RUN: %{compile} %s --target=Ascend910_9382 --enable-layout-optimization=false -o %t.off.o 2> %t.off.log
// RUN: FileCheck %s --check-prefixes=TILE,ND --implicit-check-not=InsertConvertLayout < %t.off.log
// RUN: %{compile} %s --target=Ascend910B2 -o %t.a2.o 2> %t.a2.log
// RUN: FileCheck %s --check-prefixes=TILE,ND,PACKED < %t.a2.log
// RUN: %{compile} %s --target=Ascend910B2 --enable-layout-optimization=false -o %t.a2-off.o 2> %t.a2-off.log
// RUN: FileCheck %s --check-prefixes=TILE,ND --implicit-check-not=InsertConvertLayout < %t.a2-off.log
// RUN: %{compile} %S/../../bishengir-compile/triton/device-debug/cube1.mlir --target=Ascend910_9382 --enable-hfusion-compile=true -o %t.print.o 2> %t.print.log
// RUN: FileCheck %s --check-prefix=TILE --implicit-check-not=InsertConvertLayout < %t.print.log
// RUN: bishengir-opt %S/../../bishengir-compile/triton/device-debug/cube1.mlir -adapt-triton-kernel -o %t.hfusion.mlir
// RUN: %{compile} %t.hfusion.mlir --target=Ascend910_9382 --enable-hfusion-compile=true -o %t.hfusion.o 2> %t.hfusion.log
// RUN: FileCheck %s --check-prefix=TILE --implicit-check-not=InsertConvertLayout < %t.hfusion.log
// RUN: %{opt} '-bishengir-compile=target=Ascend910_9382 o=%t.pass.o' 2> %t.pass.log
// RUN: FileCheck %s --check-prefixes=TILE,ND,PACKED < %t.pass.log
// RUN: %{opt} '-bishengir-compile=target=Ascend910_9382 enable-layout-optimization=false o=%t.pass-off.o' 2> %t.pass-off.log
// RUN: FileCheck %s --check-prefixes=TILE,ND --implicit-check-not=InsertConvertLayout < %t.pass-off.log
// RUN: echo 'module {}' | bishengir-opt --hacc-append-device-spec=target=Ascend950PR_9579 '--lower-hivm-pipeline=target=Ascend950PR_9579' --dump-pass-pipeline -o /dev/null 2>&1 | FileCheck %s --check-prefix=A5-ORDER
// A5-ORDER: hivm-insert-convert-layout{{.*}}hivm-tile-batchmm-into-loop

// TILE: IR Dump After TileCubeVectorLoop
// ND: hivm.hir.mmadL1
// ND-SAME: tensor<32x64xf16>, tensor<64x64xf16>
// PACKED: IR Dump After InsertConvertLayout
// PACKED: hivm.hir.mmadL1
// PACKED-SAME: tensor<4x2x16x16xf16>, tensor<4x4x16x16xf16>

// An ordinary function may share the Triton adapter's print prefix.
func.func private @triton_print_count(%count: index) -> index {
  return %count : index
}

func.func @matmul_loop(
    %ffts: i64 {hacc.arg_type = #hacc.arg_type<ffts_base_address>},
    %lhs: memref<?x64x64xf16, #hivm.address_space<gm>>,
    %rhs: memref<64x64xf16, #hivm.address_space<gm>>,
    %dst: memref<?x64x64xf32, #hivm.address_space<gm>>, %count: index,
    %workspace: memref<?xi8> {hacc.arg_type = #hacc.arg_type<workspace>},
    %num_x: i32, %num_y: i32, %num_z: i32, %id_x: i32, %id_y: i32, %id_z: i32)
    attributes {hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>} {
  %true = arith.constant true
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c64 = arith.constant 64 : index
  %bound = func.call @triton_print_count(%count) : (index) -> index
  scf.for %i = %c0 to %bound step %c1 {
    %src = memref.subview %lhs[%i, 0, 0] [1, 64, 64] [1, 1, 1]
      : memref<?x64x64xf16, #hivm.address_space<gm>>
        to memref<64x64xf16, strided<[64, 1], offset: ?>, #hivm.address_space<gm>>
    %a_buf = memref.alloc() : memref<64x64xf16>
    hivm.hir.load ins(%src : memref<64x64xf16, strided<[64, 1], offset: ?>, #hivm.address_space<gm>>)
                  outs(%a_buf : memref<64x64xf16>)
    %a = bufferization.to_tensor %a_buf restrict writable : memref<64x64xf16>
    %b_buf = memref.alloc() : memref<64x64xf16>
    hivm.hir.load ins(%rhs : memref<64x64xf16, #hivm.address_space<gm>>) outs(%b_buf : memref<64x64xf16>)
    %b = bufferization.to_tensor %b_buf restrict writable : memref<64x64xf16>
    %empty = tensor.empty() : tensor<64x64xf32>
    // Two M tiles exercise packing a slice of the empty accumulator.
    %c = hivm.hir.mmadL1 {hivm.tile_mix_cube_num = 2 : i32} ins(%a, %b, %true, %c64, %c64, %c64
        : tensor<64x64xf16>, tensor<64x64xf16>, i1, index, index, index)
        outs(%empty : tensor<64x64xf32>) -> tensor<64x64xf32>
    %out = memref.subview %dst[%i, 0, 0] [1, 64, 64] [1, 1, 1]
      : memref<?x64x64xf32, #hivm.address_space<gm>>
        to memref<64x64xf32, strided<[64, 1], offset: ?>, #hivm.address_space<gm>>
    hivm.hir.store ins(%c : tensor<64x64xf32>)
                   outs(%out : memref<64x64xf32, strided<[64, 1], offset: ?>, #hivm.address_space<gm>>)
  } {hivm.loop_core_type = #hivm.tcore_type<CUBE>}
  return
}

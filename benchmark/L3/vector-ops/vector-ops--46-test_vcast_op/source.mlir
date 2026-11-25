func.func @test_vcast_op() {
  %f16 = memref.alloc() : memref<2x16xf16>
  %f32 = memref.alloc() : memref<2x16xf32>
  %s4 = memref.alloc() : memref<2x16xi4>
  %s8 = memref.alloc() : memref<2x16xi8>
  %s16 = memref.alloc() : memref<2x16xi16>
  %s32 = memref.alloc() : memref<2x16xi32>
  %s64 = memref.alloc() : memref<2x16xi64>
  %bf16 = memref.alloc() : memref<2x16xbf16>
  %u8 = memref.alloc() : memref<2x16xui8>
  hivm.hir.vcast ins(%bf16 : memref<2x16xbf16>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%bf16 : memref<2x16xbf16>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%bf16 : memref<2x16xbf16>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%bf16 : memref<2x16xbf16>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%bf16 : memref<2x16xbf16>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%bf16 : memref<2x16xbf16>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s4 : memref<2x16xi4>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s4 : memref<2x16xi4>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s4 : memref<2x16xi4>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s4 : memref<2x16xi4>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s4 : memref<2x16xi4>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s4 : memref<2x16xi4>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s8 : memref<2x16xi8>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s8 : memref<2x16xi8>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s8 : memref<2x16xi8>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s8 : memref<2x16xi8>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s8 : memref<2x16xi8>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%s8 : memref<2x16xi8>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%u8 : memref<2x16xui8>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%u8 : memref<2x16xui8>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%u8 : memref<2x16xui8>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%u8 : memref<2x16xui8>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%u8 : memref<2x16xui8>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f16 : memref<2x16xf16>) outs(%u8 : memref<2x16xui8>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%bf16 : memref<2x16xbf16>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%bf16 : memref<2x16xbf16>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%bf16 : memref<2x16xbf16>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%bf16 : memref<2x16xbf16>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%bf16 : memref<2x16xbf16>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<odd>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s64 : memref<2x16xi64>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s64 : memref<2x16xi64>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s64 : memref<2x16xi64>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s64 : memref<2x16xi64>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%f32 : memref<2x16xf32>) outs(%s64 : memref<2x16xi64>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%s16 : memref<2x16xi16>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%s16 : memref<2x16xi16>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%s16 : memref<2x16xi16>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%s16 : memref<2x16xi16>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%s16 : memref<2x16xi16>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%s16 : memref<2x16xi16>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%s16 : memref<2x16xi16>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%s32 : memref<2x16xi32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%s32 : memref<2x16xi32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%s32 : memref<2x16xi32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%s32 : memref<2x16xi32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%s32 : memref<2x16xi32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%s32 : memref<2x16xi32>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%s32 : memref<2x16xi32>) outs(%s16 : memref<2x16xi16>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%s32 : memref<2x16xi32>) outs(%s64 : memref<2x16xi64>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%s4 : memref<2x16xi4>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%s64 : memref<2x16xi64>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<round>
  hivm.hir.vcast ins(%s64 : memref<2x16xi64>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<ceil>
  hivm.hir.vcast ins(%s64 : memref<2x16xi64>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<floor>
  hivm.hir.vcast ins(%s64 : memref<2x16xi64>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%s64 : memref<2x16xi64>) outs(%f32 : memref<2x16xf32>)
                 round_mode = #hivm.round_mode<trunc>
  hivm.hir.vcast ins(%s64 : memref<2x16xi64>) outs(%s32 : memref<2x16xi32>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%s8 : memref<2x16xi8>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<rint>
  hivm.hir.vcast ins(%u8 : memref<2x16xui8>) outs(%f16 : memref<2x16xf16>)
                 round_mode = #hivm.round_mode<rint>
  return
}

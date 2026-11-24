module {
  func.func @test_vcast_op() {
    %alloc = memref.alloc() : memref<2x16xf16>
    %alloc_0 = memref.alloc() : memref<2x16xf32>
    %alloc_1 = memref.alloc() : memref<2x16xi4>
    %alloc_2 = memref.alloc() : memref<2x16xi8>
    %alloc_3 = memref.alloc() : memref<2x16xi16>
    %alloc_4 = memref.alloc() : memref<2x16xi32>
    %alloc_5 = memref.alloc() : memref<2x16xi64>
    %alloc_6 = memref.alloc() : memref<2x16xbf16>
    %alloc_7 = memref.alloc() : memref<2x16xui8>
    hivm.hir.vcast ins(%alloc_6 : memref<2x16xbf16>) outs(%alloc_0 : memref<2x16xf32>)
    hivm.hir.vcast ins(%alloc_6 : memref<2x16xbf16>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_6 : memref<2x16xbf16>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_6 : memref<2x16xbf16>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_6 : memref<2x16xbf16>) outs(%alloc_4 : memref<2x16xi32>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_6 : memref<2x16xbf16>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_0 : memref<2x16xf32>)
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_3 : memref<2x16xi16>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_3 : memref<2x16xi16>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_3 : memref<2x16xi16>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_3 : memref<2x16xi16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_3 : memref<2x16xi16>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_4 : memref<2x16xi32>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_1 : memref<2x16xi4>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_1 : memref<2x16xi4>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_1 : memref<2x16xi4>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_1 : memref<2x16xi4>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_1 : memref<2x16xi4>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_1 : memref<2x16xi4>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_2 : memref<2x16xi8>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_2 : memref<2x16xi8>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_2 : memref<2x16xi8>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_2 : memref<2x16xi8>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_2 : memref<2x16xi8>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_2 : memref<2x16xi8>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_7 : memref<2x16xui8>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_7 : memref<2x16xui8>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_7 : memref<2x16xui8>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_7 : memref<2x16xui8>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_7 : memref<2x16xui8>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc : memref<2x16xf16>) outs(%alloc_7 : memref<2x16xui8>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_6 : memref<2x16xbf16>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_6 : memref<2x16xbf16>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_6 : memref<2x16xbf16>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_6 : memref<2x16xbf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_6 : memref<2x16xbf16>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc : memref<2x16xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc : memref<2x16xf16>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc : memref<2x16xf16>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc : memref<2x16xf16>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc : memref<2x16xf16>) round_mode = <odd>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc : memref<2x16xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc : memref<2x16xf16>) round_mode = <trunc>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_0 : memref<2x16xf32>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <trunc>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_3 : memref<2x16xi16>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_3 : memref<2x16xi16>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_3 : memref<2x16xi16>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_3 : memref<2x16xi16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_3 : memref<2x16xi16>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_4 : memref<2x16xi32>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_4 : memref<2x16xi32>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_5 : memref<2x16xi64>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_5 : memref<2x16xi64>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_5 : memref<2x16xi64>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_5 : memref<2x16xi64>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_0 : memref<2x16xf32>) outs(%alloc_5 : memref<2x16xi64>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc_3 : memref<2x16xi16>) outs(%alloc : memref<2x16xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_3 : memref<2x16xi16>) outs(%alloc : memref<2x16xf16>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_3 : memref<2x16xi16>) outs(%alloc : memref<2x16xf16>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_3 : memref<2x16xi16>) outs(%alloc : memref<2x16xf16>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_3 : memref<2x16xi16>) outs(%alloc : memref<2x16xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_3 : memref<2x16xi16>) outs(%alloc : memref<2x16xf16>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc_3 : memref<2x16xi16>) outs(%alloc_0 : memref<2x16xf32>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_4 : memref<2x16xi32>) outs(%alloc_0 : memref<2x16xf32>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_4 : memref<2x16xi32>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_4 : memref<2x16xi32>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_4 : memref<2x16xi32>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_4 : memref<2x16xi32>) outs(%alloc_0 : memref<2x16xf32>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_4 : memref<2x16xi32>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc_4 : memref<2x16xi32>) outs(%alloc_3 : memref<2x16xi16>)
    hivm.hir.vcast ins(%alloc_4 : memref<2x16xi32>) outs(%alloc_5 : memref<2x16xi64>)
    hivm.hir.vcast ins(%alloc_1 : memref<2x16xi4>) outs(%alloc : memref<2x16xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_5 : memref<2x16xi64>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <round>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_5 : memref<2x16xi64>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <ceil>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_5 : memref<2x16xi64>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <floor>
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_5 : memref<2x16xi64>) outs(%alloc_0 : memref<2x16xf32>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_5 : memref<2x16xi64>) outs(%alloc_0 : memref<2x16xf32>) round_mode = <trunc>
    hivm.hir.vcast ins(%alloc_5 : memref<2x16xi64>) outs(%alloc_4 : memref<2x16xi32>)
    hivm.hir.vcast ins(%alloc_2 : memref<2x16xi8>) outs(%alloc : memref<2x16xf16>)
    hivm.hir.pipe_barrier[<PIPE_V>]
    hivm.hir.vcast ins(%alloc_7 : memref<2x16xui8>) outs(%alloc : memref<2x16xf16>)
    return
  }
}


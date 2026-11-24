module {
  func.func @test_vcast_tensor_op() {
    %0 = tensor.empty() : tensor<2x16xf16>
    %1 = tensor.empty() : tensor<2x16xf32>
    %2 = tensor.empty() : tensor<2x16xi4>
    %3 = tensor.empty() : tensor<2x16xi8>
    %4 = tensor.empty() : tensor<2x16xi16>
    %5 = tensor.empty() : tensor<2x16xi32>
    %6 = tensor.empty() : tensor<2x16xi64>
    %7 = tensor.empty() : tensor<2x16xbf16>
    %8 = tensor.empty() : tensor<2x16xui8>
    %9 = hivm.hir.vcast ins(%7 : tensor<2x16xbf16>) outs(%1 : tensor<2x16xf32>) -> tensor<2x16xf32>
    %10 = hivm.hir.vcast ins(%7 : tensor<2x16xbf16>) outs(%5 : tensor<2x16xi32>) round_mode = <round> -> tensor<2x16xi32>
    %11 = hivm.hir.vcast ins(%7 : tensor<2x16xbf16>) outs(%5 : tensor<2x16xi32>) round_mode = <ceil> -> tensor<2x16xi32>
    %12 = hivm.hir.vcast ins(%7 : tensor<2x16xbf16>) outs(%5 : tensor<2x16xi32>) round_mode = <floor> -> tensor<2x16xi32>
    %13 = hivm.hir.vcast ins(%7 : tensor<2x16xbf16>) outs(%5 : tensor<2x16xi32>) -> tensor<2x16xi32>
    %14 = hivm.hir.vcast ins(%7 : tensor<2x16xbf16>) outs(%5 : tensor<2x16xi32>) round_mode = <trunc> -> tensor<2x16xi32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %15 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%1 : tensor<2x16xf32>) -> tensor<2x16xf32>
    %16 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%4 : tensor<2x16xi16>) round_mode = <round> -> tensor<2x16xi16>
    %17 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%4 : tensor<2x16xi16>) round_mode = <ceil> -> tensor<2x16xi16>
    %18 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%4 : tensor<2x16xi16>) round_mode = <floor> -> tensor<2x16xi16>
    %19 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%4 : tensor<2x16xi16>) -> tensor<2x16xi16>
    %20 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%4 : tensor<2x16xi16>) round_mode = <trunc> -> tensor<2x16xi16>
    %21 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%5 : tensor<2x16xi32>) round_mode = <round> -> tensor<2x16xi32>
    %22 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%5 : tensor<2x16xi32>) round_mode = <ceil> -> tensor<2x16xi32>
    %23 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%5 : tensor<2x16xi32>) round_mode = <floor> -> tensor<2x16xi32>
    %24 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%5 : tensor<2x16xi32>) -> tensor<2x16xi32>
    %25 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%5 : tensor<2x16xi32>) round_mode = <trunc> -> tensor<2x16xi32>
    %26 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%2 : tensor<2x16xi4>) -> tensor<2x16xi4>
    %27 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%2 : tensor<2x16xi4>) round_mode = <round> -> tensor<2x16xi4>
    %28 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%2 : tensor<2x16xi4>) round_mode = <ceil> -> tensor<2x16xi4>
    %29 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%2 : tensor<2x16xi4>) round_mode = <floor> -> tensor<2x16xi4>
    %30 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%2 : tensor<2x16xi4>) -> tensor<2x16xi4>
    %31 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%2 : tensor<2x16xi4>) round_mode = <trunc> -> tensor<2x16xi4>
    %32 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%3 : tensor<2x16xi8>) -> tensor<2x16xi8>
    %33 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%3 : tensor<2x16xi8>) round_mode = <round> -> tensor<2x16xi8>
    %34 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%3 : tensor<2x16xi8>) round_mode = <ceil> -> tensor<2x16xi8>
    %35 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%3 : tensor<2x16xi8>) round_mode = <floor> -> tensor<2x16xi8>
    %36 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%3 : tensor<2x16xi8>) -> tensor<2x16xi8>
    %37 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%3 : tensor<2x16xi8>) round_mode = <trunc> -> tensor<2x16xi8>
    %38 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%8 : tensor<2x16xui8>) -> tensor<2x16xui8>
    %39 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%8 : tensor<2x16xui8>) round_mode = <round> -> tensor<2x16xui8>
    %40 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%8 : tensor<2x16xui8>) round_mode = <ceil> -> tensor<2x16xui8>
    %41 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%8 : tensor<2x16xui8>) round_mode = <floor> -> tensor<2x16xui8>
    %42 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%8 : tensor<2x16xui8>) -> tensor<2x16xui8>
    %43 = hivm.hir.vcast ins(%0 : tensor<2x16xf16>) outs(%8 : tensor<2x16xui8>) round_mode = <trunc> -> tensor<2x16xui8>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %44 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%7 : tensor<2x16xbf16>) round_mode = <round> -> tensor<2x16xbf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %45 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%7 : tensor<2x16xbf16>) round_mode = <ceil> -> tensor<2x16xbf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %46 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%7 : tensor<2x16xbf16>) round_mode = <floor> -> tensor<2x16xbf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %47 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%7 : tensor<2x16xbf16>) -> tensor<2x16xbf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %48 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%7 : tensor<2x16xbf16>) round_mode = <trunc> -> tensor<2x16xbf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %49 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%0 : tensor<2x16xf16>) -> tensor<2x16xf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %50 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%0 : tensor<2x16xf16>) round_mode = <round> -> tensor<2x16xf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %51 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%0 : tensor<2x16xf16>) round_mode = <ceil> -> tensor<2x16xf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %52 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%0 : tensor<2x16xf16>) round_mode = <floor> -> tensor<2x16xf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %53 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%0 : tensor<2x16xf16>) round_mode = <odd> -> tensor<2x16xf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %54 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%0 : tensor<2x16xf16>) -> tensor<2x16xf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %55 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%0 : tensor<2x16xf16>) round_mode = <trunc> -> tensor<2x16xf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %56 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%1 : tensor<2x16xf32>) round_mode = <round> -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %57 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%1 : tensor<2x16xf32>) round_mode = <ceil> -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %58 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%1 : tensor<2x16xf32>) round_mode = <floor> -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %59 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%1 : tensor<2x16xf32>) -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %60 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%1 : tensor<2x16xf32>) round_mode = <trunc> -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %61 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%4 : tensor<2x16xi16>) round_mode = <round> -> tensor<2x16xi16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %62 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%4 : tensor<2x16xi16>) round_mode = <ceil> -> tensor<2x16xi16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %63 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%4 : tensor<2x16xi16>) round_mode = <floor> -> tensor<2x16xi16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %64 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%4 : tensor<2x16xi16>) -> tensor<2x16xi16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %65 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%4 : tensor<2x16xi16>) round_mode = <trunc> -> tensor<2x16xi16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %66 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%5 : tensor<2x16xi32>) round_mode = <round> -> tensor<2x16xi32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %67 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%5 : tensor<2x16xi32>) round_mode = <ceil> -> tensor<2x16xi32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %68 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%5 : tensor<2x16xi32>) round_mode = <floor> -> tensor<2x16xi32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %69 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%5 : tensor<2x16xi32>) -> tensor<2x16xi32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %70 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%5 : tensor<2x16xi32>) round_mode = <trunc> -> tensor<2x16xi32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %71 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%6 : tensor<2x16xi64>) round_mode = <round> -> tensor<2x16xi64>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %72 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%6 : tensor<2x16xi64>) round_mode = <ceil> -> tensor<2x16xi64>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %73 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%6 : tensor<2x16xi64>) round_mode = <floor> -> tensor<2x16xi64>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %74 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%6 : tensor<2x16xi64>) -> tensor<2x16xi64>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %75 = hivm.hir.vcast ins(%1 : tensor<2x16xf32>) outs(%6 : tensor<2x16xi64>) round_mode = <trunc> -> tensor<2x16xi64>
    %76 = hivm.hir.vcast ins(%4 : tensor<2x16xi16>) outs(%0 : tensor<2x16xf16>) -> tensor<2x16xf16>
    %77 = hivm.hir.vcast ins(%4 : tensor<2x16xi16>) outs(%0 : tensor<2x16xf16>) round_mode = <round> -> tensor<2x16xf16>
    %78 = hivm.hir.vcast ins(%4 : tensor<2x16xi16>) outs(%0 : tensor<2x16xf16>) round_mode = <ceil> -> tensor<2x16xf16>
    %79 = hivm.hir.vcast ins(%4 : tensor<2x16xi16>) outs(%0 : tensor<2x16xf16>) round_mode = <floor> -> tensor<2x16xf16>
    %80 = hivm.hir.vcast ins(%4 : tensor<2x16xi16>) outs(%0 : tensor<2x16xf16>) -> tensor<2x16xf16>
    %81 = hivm.hir.vcast ins(%4 : tensor<2x16xi16>) outs(%0 : tensor<2x16xf16>) round_mode = <trunc> -> tensor<2x16xf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %82 = hivm.hir.vcast ins(%4 : tensor<2x16xi16>) outs(%1 : tensor<2x16xf32>) -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %83 = hivm.hir.vcast ins(%5 : tensor<2x16xi32>) outs(%1 : tensor<2x16xf32>) -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %84 = hivm.hir.vcast ins(%5 : tensor<2x16xi32>) outs(%1 : tensor<2x16xf32>) round_mode = <round> -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %85 = hivm.hir.vcast ins(%5 : tensor<2x16xi32>) outs(%1 : tensor<2x16xf32>) round_mode = <ceil> -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %86 = hivm.hir.vcast ins(%5 : tensor<2x16xi32>) outs(%1 : tensor<2x16xf32>) round_mode = <floor> -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %87 = hivm.hir.vcast ins(%5 : tensor<2x16xi32>) outs(%1 : tensor<2x16xf32>) -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %88 = hivm.hir.vcast ins(%5 : tensor<2x16xi32>) outs(%1 : tensor<2x16xf32>) round_mode = <trunc> -> tensor<2x16xf32>
    %89 = hivm.hir.vcast ins(%5 : tensor<2x16xi32>) outs(%4 : tensor<2x16xi16>) -> tensor<2x16xi16>
    %90 = hivm.hir.vcast ins(%5 : tensor<2x16xi32>) outs(%6 : tensor<2x16xi64>) -> tensor<2x16xi64>
    %91 = hivm.hir.vcast ins(%2 : tensor<2x16xi4>) outs(%0 : tensor<2x16xf16>) -> tensor<2x16xf16>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %92 = hivm.hir.vcast ins(%6 : tensor<2x16xi64>) outs(%1 : tensor<2x16xf32>) round_mode = <round> -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %93 = hivm.hir.vcast ins(%6 : tensor<2x16xi64>) outs(%1 : tensor<2x16xf32>) round_mode = <ceil> -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %94 = hivm.hir.vcast ins(%6 : tensor<2x16xi64>) outs(%1 : tensor<2x16xf32>) round_mode = <floor> -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %95 = hivm.hir.vcast ins(%6 : tensor<2x16xi64>) outs(%1 : tensor<2x16xf32>) -> tensor<2x16xf32>
    hivm.hir.pipe_barrier[<PIPE_V>]
    %96 = hivm.hir.vcast ins(%6 : tensor<2x16xi64>) outs(%1 : tensor<2x16xf32>) round_mode = <trunc> -> tensor<2x16xf32>
    %97 = hivm.hir.vcast ins(%6 : tensor<2x16xi64>) outs(%5 : tensor<2x16xi32>) -> tensor<2x16xi32>
    %98 = hivm.hir.vcast ins(%3 : tensor<2x16xi8>) outs(%0 : tensor<2x16xf16>) -> tensor<2x16xf16>
    %99 = hivm.hir.vcast ins(%8 : tensor<2x16xui8>) outs(%0 : tensor<2x16xf16>) -> tensor<2x16xf16>
    return
  }
}


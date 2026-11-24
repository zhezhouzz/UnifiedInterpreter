module attributes {hacc.target = #hacc.target<"Ascend950PR_9589">} {
  func.func @ca_f16_plain(%arg0: memref<48x32xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<48x32xf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<48x32xf16, #hivm.address_space<ca>>
    memref.copy %arg0, %alloc : memref<48x32xf16, #hivm.address_space<gm>> to memref<48x32xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<48x32xf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<48x32xf16, #hivm.address_space<ca>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }
  func.func @ca_f16_transpose(%arg0: memref<32x48xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<32x48xf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<48x32xf16, #hivm.address_space<ca>>
    memref.copy %arg0, %alloc : memref<32x48xf16, #hivm.address_space<gm>> to memref<32x48xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<32x48xf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<48x32xf16, #hivm.address_space<ca>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }
  func.func @cb_f16_plain(%arg0: memref<32x48xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<32x48xf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<32x48xf16, #hivm.address_space<cb>>
    memref.copy %arg0, %alloc : memref<32x48xf16, #hivm.address_space<gm>> to memref<32x48xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<32x48xf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<32x48xf16, #hivm.address_space<cb>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }
  func.func @cb_f16_transpose(%arg0: memref<48x32xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<48x32xf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<32x48xf16, #hivm.address_space<cb>>
    memref.copy %arg0, %alloc : memref<48x32xf16, #hivm.address_space<gm>> to memref<48x32xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<48x32xf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<32x48xf16, #hivm.address_space<cb>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }
  func.func @ca_bf16_plain(%arg0: memref<48x32xbf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<48x32xbf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<48x32xbf16, #hivm.address_space<ca>>
    memref.copy %arg0, %alloc : memref<48x32xbf16, #hivm.address_space<gm>> to memref<48x32xbf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<48x32xbf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<48x32xbf16, #hivm.address_space<ca>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }
  func.func @ca_bf16_transpose(%arg0: memref<32x48xbf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<32x48xbf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<48x32xbf16, #hivm.address_space<ca>>
    memref.copy %arg0, %alloc : memref<32x48xbf16, #hivm.address_space<gm>> to memref<32x48xbf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<32x48xbf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<48x32xbf16, #hivm.address_space<ca>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }
  func.func @cb_bf16_plain(%arg0: memref<32x48xbf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<32x48xbf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<32x48xbf16, #hivm.address_space<cb>>
    memref.copy %arg0, %alloc : memref<32x48xbf16, #hivm.address_space<gm>> to memref<32x48xbf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<32x48xbf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<32x48xbf16, #hivm.address_space<cb>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }
  func.func @cb_bf16_transpose(%arg0: memref<48x32xbf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<48x32xbf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<32x48xbf16, #hivm.address_space<cb>>
    memref.copy %arg0, %alloc : memref<48x32xbf16, #hivm.address_space<gm>> to memref<48x32xbf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<48x32xbf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<32x48xbf16, #hivm.address_space<cb>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }
  func.func @ca_f32_plain(%arg0: memref<48x32xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<48x32xf32, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<48x32xf32, #hivm.address_space<ca>>
    memref.copy %arg0, %alloc : memref<48x32xf32, #hivm.address_space<gm>> to memref<48x32xf32, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<48x32xf32, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<48x32xf32, #hivm.address_space<ca>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }
  func.func @ca_f32_transpose(%arg0: memref<32x48xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<32x48xf32, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<48x32xf32, #hivm.address_space<ca>>
    memref.copy %arg0, %alloc : memref<32x48xf32, #hivm.address_space<gm>> to memref<32x48xf32, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<32x48xf32, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<48x32xf32, #hivm.address_space<ca>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }
  func.func @cb_f32_plain(%arg0: memref<32x48xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<32x48xf32, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<32x48xf32, #hivm.address_space<cb>>
    memref.copy %arg0, %alloc : memref<32x48xf32, #hivm.address_space<gm>> to memref<32x48xf32, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<32x48xf32, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<32x48xf32, #hivm.address_space<cb>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }
  func.func @cb_f32_transpose(%arg0: memref<48x32xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<48x32xf32, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<32x48xf32, #hivm.address_space<cb>>
    memref.copy %arg0, %alloc : memref<48x32xf32, #hivm.address_space<gm>> to memref<48x32xf32, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<48x32xf32, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<32x48xf32, #hivm.address_space<cb>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }
  func.func @transpose_hint(%arg0: memref<32x48xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() {hivm.fractal_layout = "nZ"} : memref<48x32xf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<48x32xf16, #hivm.address_space<ca>>
    hivm.hir.nd2nz {dst_continuous} ins(%arg0 : memref<32x48xf16, #hivm.address_space<gm>>) outs(%alloc : memref<48x32xf16, #hivm.address_space<cbuf>>)
    hivm.hir.set_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.wait_flag[<PIPE_MTE2>, <PIPE_MTE1>, <EVENT_ID0>]
    hivm.hir.l12l0 ins(%alloc : memref<48x32xf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<48x32xf16, #hivm.address_space<ca>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }
  func.func @a_parent_views(%arg0: memref<64x96xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<64x96xf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<96x64xf16, #hivm.address_space<ca>>
    memref.copy %arg0, %alloc : memref<64x96xf16, #hivm.address_space<gm>> to memref<64x96xf16, #hivm.address_space<cbuf>>
    %subview = memref.subview %alloc[16, 32] [48, 32] [1, 1] : memref<64x96xf16, #hivm.address_space<cbuf>> to memref<48x32xf16, strided<[96, 1], offset: 1568>, #hivm.address_space<cbuf>>
    %subview_1 = memref.subview %alloc_0[32, 16] [48, 32] [1, 1] : memref<96x64xf16, #hivm.address_space<ca>> to memref<48x32xf16, strided<[64, 1], offset: 2064>, #hivm.address_space<ca>>
    hivm.hir.l12l0 ins(%subview : memref<48x32xf16, strided<[96, 1], offset: 1568>, #hivm.address_space<cbuf>>) outs(%subview_1 : memref<48x32xf16, strided<[64, 1], offset: 2064>, #hivm.address_space<ca>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }
  func.func @b_parent_views(%arg0: memref<96x96xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<96x96xf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<64x128xf16, #hivm.address_space<cb>>
    memref.copy %arg0, %alloc : memref<96x96xf16, #hivm.address_space<gm>> to memref<96x96xf16, #hivm.address_space<cbuf>>
    %subview = memref.subview %alloc[32, 16] [32, 48] [1, 1] : memref<96x96xf16, #hivm.address_space<cbuf>> to memref<32x48xf16, strided<[96, 1], offset: 3088>, #hivm.address_space<cbuf>>
    %subview_1 = memref.subview %alloc_0[16, 32] [32, 48] [1, 1] : memref<64x128xf16, #hivm.address_space<cb>> to memref<32x48xf16, strided<[128, 1], offset: 2080>, #hivm.address_space<cb>>
    hivm.hir.l12l0 ins(%subview : memref<32x48xf16, strided<[96, 1], offset: 3088>, #hivm.address_space<cbuf>>) outs(%subview_1 : memref<32x48xf16, strided<[128, 1], offset: 2080>, #hivm.address_space<cb>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }
  func.func @legacy_partition(%arg0: memref<48x96xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<48x96xf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<48x32xf16, #hivm.address_space<ca>>
    memref.copy %arg0, %alloc : memref<48x96xf16, #hivm.address_space<gm>> to memref<48x96xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<48x96xf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<48x32xf16, #hivm.address_space<ca>>) {k_part_idx = 1, k_part = 32, k_part_ceil = 32, k_part_loop = 3, k_part_actual = 32, m = 48}
    return
  }
  func.func @gm_to_l1_to_l0(%arg0: memref<48x32xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %alloc = memref.alloc() : memref<48x32xf16, #hivm.address_space<cbuf>>
    %alloc_0 = memref.alloc() : memref<48x32xf16, #hivm.address_space<ca>>
    memref.copy %arg0, %alloc : memref<48x32xf16, #hivm.address_space<gm>> to memref<48x32xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%alloc : memref<48x32xf16, #hivm.address_space<cbuf>>) outs(%alloc_0 : memref<48x32xf16, #hivm.address_space<ca>>) {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }
}


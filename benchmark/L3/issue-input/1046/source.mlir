module attributes {hacc.target = #hacc.target<"Ascend950PR_9589">} {
  func.func @ca_f16_plain(%gm: memref<48x32xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<48x32xf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<48x32xf16, #hivm.address_space<ca>>
    memref.copy %gm, %s : memref<48x32xf16, #hivm.address_space<gm>> to memref<48x32xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<48x32xf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<48x32xf16, #hivm.address_space<ca>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }

  func.func @ca_f16_transpose(%gm: memref<32x48xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<32x48xf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<48x32xf16, #hivm.address_space<ca>>
    memref.copy %gm, %s : memref<32x48xf16, #hivm.address_space<gm>> to memref<32x48xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<32x48xf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<48x32xf16, #hivm.address_space<ca>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }

  func.func @cb_f16_plain(%gm: memref<32x48xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<32x48xf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<32x48xf16, #hivm.address_space<cb>>
    memref.copy %gm, %s : memref<32x48xf16, #hivm.address_space<gm>> to memref<32x48xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<32x48xf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<32x48xf16, #hivm.address_space<cb>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }

  func.func @cb_f16_transpose(%gm: memref<48x32xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<48x32xf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<32x48xf16, #hivm.address_space<cb>>
    memref.copy %gm, %s : memref<48x32xf16, #hivm.address_space<gm>> to memref<48x32xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<48x32xf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<32x48xf16, #hivm.address_space<cb>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }

  func.func @ca_bf16_plain(%gm: memref<48x32xbf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<48x32xbf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<48x32xbf16, #hivm.address_space<ca>>
    memref.copy %gm, %s : memref<48x32xbf16, #hivm.address_space<gm>> to memref<48x32xbf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<48x32xbf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<48x32xbf16, #hivm.address_space<ca>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }

  func.func @ca_bf16_transpose(%gm: memref<32x48xbf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<32x48xbf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<48x32xbf16, #hivm.address_space<ca>>
    memref.copy %gm, %s : memref<32x48xbf16, #hivm.address_space<gm>> to memref<32x48xbf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<32x48xbf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<48x32xbf16, #hivm.address_space<ca>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }

  func.func @cb_bf16_plain(%gm: memref<32x48xbf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<32x48xbf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<32x48xbf16, #hivm.address_space<cb>>
    memref.copy %gm, %s : memref<32x48xbf16, #hivm.address_space<gm>> to memref<32x48xbf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<32x48xbf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<32x48xbf16, #hivm.address_space<cb>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }

  func.func @cb_bf16_transpose(%gm: memref<48x32xbf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<48x32xbf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<32x48xbf16, #hivm.address_space<cb>>
    memref.copy %gm, %s : memref<48x32xbf16, #hivm.address_space<gm>> to memref<48x32xbf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<48x32xbf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<32x48xbf16, #hivm.address_space<cb>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }

  func.func @ca_f32_plain(%gm: memref<48x32xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<48x32xf32, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<48x32xf32, #hivm.address_space<ca>>
    memref.copy %gm, %s : memref<48x32xf32, #hivm.address_space<gm>> to memref<48x32xf32, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<48x32xf32, #hivm.address_space<cbuf>>)
      outs(%d : memref<48x32xf32, #hivm.address_space<ca>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }

  func.func @ca_f32_transpose(%gm: memref<32x48xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<32x48xf32, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<48x32xf32, #hivm.address_space<ca>>
    memref.copy %gm, %s : memref<32x48xf32, #hivm.address_space<gm>> to memref<32x48xf32, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<32x48xf32, #hivm.address_space<cbuf>>)
      outs(%d : memref<48x32xf32, #hivm.address_space<ca>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }

  func.func @cb_f32_plain(%gm: memref<32x48xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<32x48xf32, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<32x48xf32, #hivm.address_space<cb>>
    memref.copy %gm, %s : memref<32x48xf32, #hivm.address_space<gm>> to memref<32x48xf32, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<32x48xf32, #hivm.address_space<cbuf>>)
      outs(%d : memref<32x48xf32, #hivm.address_space<cb>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }

  func.func @cb_f32_transpose(%gm: memref<48x32xf32, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<48x32xf32, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<32x48xf32, #hivm.address_space<cb>>
    memref.copy %gm, %s : memref<48x32xf32, #hivm.address_space<gm>> to memref<48x32xf32, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<48x32xf32, #hivm.address_space<cbuf>>)
      outs(%d : memref<32x48xf32, #hivm.address_space<cb>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }


  func.func @transpose_hint(%gm: memref<32x48xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() {hivm.fractal_layout = "nZ"} : memref<48x32xf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<48x32xf16, #hivm.address_space<ca>>
    hivm.hir.nd2nz {dst_continuous}
      ins(%gm : memref<32x48xf16, #hivm.address_space<gm>>)
      outs(%s : memref<48x32xf16, #hivm.address_space<cbuf>>)
    hivm.hir.l12l0 ins(%s : memref<48x32xf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<48x32xf16, #hivm.address_space<ca>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48, is_transposed = true}
    return
  }

  func.func @a_parent_views(%gm: memref<64x96xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<64x96xf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<96x64xf16, #hivm.address_space<ca>>
    memref.copy %gm, %s : memref<64x96xf16, #hivm.address_space<gm>> to memref<64x96xf16, #hivm.address_space<cbuf>>
    %sv = memref.subview %s[16, 32] [48, 32] [1, 1] : memref<64x96xf16, #hivm.address_space<cbuf>> to memref<48x32xf16, strided<[96, 1], offset: 1568>, #hivm.address_space<cbuf>>
    %dv = memref.subview %d[32, 16] [48, 32] [1, 1] : memref<96x64xf16, #hivm.address_space<ca>> to memref<48x32xf16, strided<[64, 1], offset: 2064>, #hivm.address_space<ca>>
    hivm.hir.l12l0 ins(%sv : memref<48x32xf16, strided<[96, 1], offset: 1568>, #hivm.address_space<cbuf>>)
      outs(%dv : memref<48x32xf16, strided<[64, 1], offset: 2064>, #hivm.address_space<ca>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }

  func.func @b_parent_views(%gm: memref<96x96xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<96x96xf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<64x128xf16, #hivm.address_space<cb>>
    memref.copy %gm, %s : memref<96x96xf16, #hivm.address_space<gm>> to memref<96x96xf16, #hivm.address_space<cbuf>>
    %sv = memref.subview %s[32, 16] [32, 48] [1, 1] : memref<96x96xf16, #hivm.address_space<cbuf>> to memref<32x48xf16, strided<[96, 1], offset: 3088>, #hivm.address_space<cbuf>>
    %dv = memref.subview %d[16, 32] [32, 48] [1, 1] : memref<64x128xf16, #hivm.address_space<cb>> to memref<32x48xf16, strided<[128, 1], offset: 2080>, #hivm.address_space<cb>>
    hivm.hir.l12l0 ins(%sv : memref<32x48xf16, strided<[96, 1], offset: 3088>, #hivm.address_space<cbuf>>)
      outs(%dv : memref<32x48xf16, strided<[128, 1], offset: 2080>, #hivm.address_space<cb>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }

  func.func @legacy_partition(%gm: memref<48x96xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<48x96xf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<48x32xf16, #hivm.address_space<ca>>
    memref.copy %gm, %s : memref<48x96xf16, #hivm.address_space<gm>> to memref<48x96xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<48x96xf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<48x32xf16, #hivm.address_space<ca>>)
      {k_part_idx = 1, k_part = 32, k_part_ceil = 32, k_part_loop = 3, k_part_actual = 32, m = 48}
    return
  }

  func.func @gm_to_l1_to_l0(%gm: memref<48x32xf16, #hivm.address_space<gm>>) attributes {hivm.func_core_type = #hivm.func_core_type<AIC>} {
    %s = memref.alloc() : memref<48x32xf16, #hivm.address_space<cbuf>>
    %d = memref.alloc() : memref<48x32xf16, #hivm.address_space<ca>>
    memref.copy %gm, %s : memref<48x32xf16, #hivm.address_space<gm>> to memref<48x32xf16, #hivm.address_space<cbuf>>
    hivm.hir.l12l0 ins(%s : memref<48x32xf16, #hivm.address_space<cbuf>>)
      outs(%d : memref<48x32xf16, #hivm.address_space<ca>>)
      {k_part_idx = 0, k_part = 32, k_part_ceil = 32, k_part_loop = 1, k_part_actual = 32, m = 48}
    return
  }
}

module attributes {dlti.target_system_spec = #dlti.target_system_spec<"NPU" : #hacc.target_device_spec<#dlti.dl_entry<"AI_CORE_COUNT", 28 : i32>, #dlti.dl_entry<"CUBE_CORE_COUNT", 28 : i32>, #dlti.dl_entry<"VECTOR_CORE_COUNT", 56 : i32>, #dlti.dl_entry<"UB_SIZE", 2031616 : i32>, #dlti.dl_entry<"L1_SIZE", 4194304 : i32>, #dlti.dl_entry<"L0A_SIZE", 524288 : i32>, #dlti.dl_entry<"L0B_SIZE", 524288 : i32>, #dlti.dl_entry<"L0C_SIZE", 2097152 : i32>, #dlti.dl_entry<"UB_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L1_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L0C_ALIGN_SIZE", 4096 : i32>, #dlti.dl_entry<"MINIMAL_D_CACHE_SIZE", 262144 : i32>, #dlti.dl_entry<"MAXIMUM_D_CACHE_SIZE", 983040 : i32>, #dlti.dl_entry<"ARCH", "dav-c310">>>, hacc.target = #hacc.target<"Ascend950PR_9579">, ssbuffer.insertionOptimization} {
  func.func @_prefill_bnsd_score_kernel(%arg0: memref<?xi8> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg1: memref<?xi8> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xf16> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg5: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg6: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg7: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg8: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg9: memref<?xf32> {tt.tensor_kind = 1 : i32}, %arg10: i32, %arg11: i32, %arg12: i32, %arg13: i32, %arg14: i32, %arg15: i32, %arg16: f32, %arg17: i32, %arg18: i32, %arg19: i32, %arg20: i32, %arg21: i32, %arg22: i32, %arg23: i32, %arg24: i32, %arg25: i32, %arg26: i32, %arg27: i32, %arg28: i32, %arg29: i32, %arg30: i32) attributes {DirectlyUsedGMArgIdxList = [9, 2], SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, mix_mode = "mix", parallel_mode = "mix_simd_simt"} {
    %cst = arith.constant -1.000000e+00 : f16
    %c-2139095040_i32 = arith.constant -2139095040 : i32
    %c2147483647_i32 = arith.constant 2147483647 : i32
    %c31_i32 = arith.constant 31 : i32
    %c1 = arith.constant 1 : index
    %c128 = arith.constant 128 : index
    %c127_i32 = arith.constant 127 : i32
    %c0_i32 = arith.constant 0 : i32
    %cst_0 = arith.constant 0.000000e+00 : f16
    %cst_1 = arith.constant 0xFF800000 : f32
    %c128_i32 = arith.constant 128 : i32
    %cst_2 = arith.constant 0.000000e+00 : f32
    %c32_i32 = arith.constant 32 : i32
    %c1_i32 = arith.constant 1 : i32
    %c0 = arith.constant 0 : index
    %cst_3 = arith.constant 1.44269502 : f32
    %0 = tensor.empty() : tensor<1xf32>
    %1 = tensor.empty() : tensor<64xi32>
    %2 = tensor.empty() : tensor<64x128xf32>
    %3 = linalg.fill ins(%cst_2 : f32) outs(%2 : tensor<64x128xf32>) -> tensor<64x128xf32>
    %4 = tensor.empty() : tensor<64x128xf16>
    %5 = linalg.fill ins(%cst_0 : f16) outs(%4 : tensor<64x128xf16>) -> tensor<64x128xf16>
    %6 = arith.remsi %arg28, %arg14 : i32
    %7 = arith.divsi %arg28, %arg14 : i32
    %8 = arith.index_cast %6 : i32 to index
    %reinterpret_cast = memref.reinterpret_cast %arg7 to offset: [%8], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
    %9 = memref.load %reinterpret_cast[%c0] : memref<1xi32, strided<[1], offset: ?>>
    %10 = arith.addi %9, %c127_i32 : i32
    %11 = arith.divsi %10, %c128_i32 : i32
    %12 = arith.subi %arg15, %c1_i32 : i32
    %13 = arith.addi %11, %12 : i32
    %14 = arith.divsi %13, %arg15 : i32
    %15 = arith.maxsi %14, %c1_i32 : i32
    %16 = arith.muli %7, %15 : i32
    %17 = arith.addi %16, %15 : i32
    %18 = arith.minsi %17, %11 : i32
    %19 = arith.cmpi sge, %16, %18 : i32
    scf.if %19 {
    } else {
      %reinterpret_cast_4 = memref.reinterpret_cast %arg5 to offset: [%8], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
      %20 = memref.load %reinterpret_cast_4[%c0] : memref<1xi32, strided<[1], offset: ?>>
      %reinterpret_cast_5 = memref.reinterpret_cast %arg6 to offset: [%8], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
      %21 = memref.load %reinterpret_cast_5[%c0] : memref<1xi32, strided<[1], offset: ?>>
      %reinterpret_cast_6 = memref.reinterpret_cast %arg8 to offset: [%8], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
      %22 = memref.load %reinterpret_cast_6[%c0] : memref<1xi32, strided<[1], offset: ?>>
      %23 = tensor.empty() : tensor<128xi32>
      %24 = hfusion.arange offset[%c0] strides[%c1] outs(%23 : tensor<128xi32>) -> tensor<128xi32>
      %25 = hfusion.arange offset[%c0] strides[%c1] outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %26 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<shrsi>} ins(%25, %c31_i32 : tensor<64xi32>, i32) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %27 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<vand>} ins(%26, %c1_i32 : tensor<64xi32>, i32) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %28 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%25, %27 : tensor<64xi32>, tensor<64xi32>) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %29 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<shrsi>} ins(%28, %c1_i32 : tensor<64xi32>, i32) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %30 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<vand>} ins(%28, %c1_i32 : tensor<64xi32>, i32) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %31 = linalg.elemwise_binary {fun = #linalg.binary_fn<sub>} ins(%30, %27 : tensor<64xi32>, tensor<64xi32>) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %32 = arith.muli %arg29, %arg12 : i32
      %33 = arith.muli %21, %c32_i32 : i32
      %34 = arith.addi %20, %33 : i32
      %35 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%34, %29 : i32, tensor<64xi32>) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %36 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%32, %31 : i32, tensor<64xi32>) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %37 = tensor.empty() : tensor<64xi1>
      %38 = hfusion.compare {compare_fn = #hfusion.compare_fn<vlt>} ins(%35, %22 : tensor<64xi32>, i32) outs(%37 : tensor<64xi1>) -> tensor<64xi1>
      %39 = hfusion.compare {compare_fn = #hfusion.compare_fn<vlt>} ins(%31, %arg12 : tensor<64xi32>, i32) outs(%37 : tensor<64xi1>) -> tensor<64xi1>
      %40 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<vand>} ins(%38, %39 : tensor<64xi1>, tensor<64xi1>) outs(%37 : tensor<64xi1>) -> tensor<64xi1>
      %41 = arith.subi %22, %c1_i32 : i32
      %42 = linalg.elemwise_binary {fun = #linalg.binary_fn<min_signed>} ins(%35, %41 : tensor<64xi32>, i32) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %43 = linalg.elemwise_binary {fun = #linalg.binary_fn<max_signed>} ins(%20, %42 : i32, tensor<64xi32>) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %expanded = tensor.expand_shape %43 [[0, 1]] output_shape [64, 1] : tensor<64xi32> into tensor<64x1xi32>
      %44 = tensor.empty() : tensor<64x1xi32>
      %45 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%expanded, %arg17 : tensor<64x1xi32>, i32) outs(%44 : tensor<64x1xi32>) -> tensor<64x1xi32>
      %expanded_7 = tensor.expand_shape %36 [[0, 1]] output_shape [64, 1] : tensor<64xi32> into tensor<64x1xi32>
      %46 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%expanded_7, %arg18 : tensor<64x1xi32>, i32) outs(%44 : tensor<64x1xi32>) -> tensor<64x1xi32>
      %47 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%45, %46 : tensor<64x1xi32>, tensor<64x1xi32>) outs(%44 : tensor<64x1xi32>) -> tensor<64x1xi32>
      %expanded_8 = tensor.expand_shape %24 [[0, 1]] output_shape [1, 128] : tensor<128xi32> into tensor<1x128xi32>
      %48 = tensor.empty() : tensor<64x128xi32>
      %collapsed = tensor.collapse_shape %47 [[0, 1]] : tensor<64x1xi32> into tensor<64xi32>
      %broadcasted = linalg.broadcast ins(%collapsed : tensor<64xi32>) outs(%48 : tensor<64x128xi32>) dimensions = [1] 
      %broadcasted_9 = linalg.broadcast ins(%24 : tensor<128xi32>) outs(%48 : tensor<64x128xi32>) dimensions = [0] 
      %49 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%broadcasted, %broadcasted_9 : tensor<64x128xi32>, tensor<64x128xi32>) outs(%48 : tensor<64x128xi32>) -> tensor<64x128xi32>
      hfusion.print " q_offsets: " {hex = false} %49 : tensor<64x128xi32>
      %50 = tensor.empty() : tensor<1x128xi1>
      %51 = hfusion.compare {compare_fn = #hfusion.compare_fn<vlt>} ins(%expanded_8, %arg13 : tensor<1x128xi32>, i32) outs(%50 : tensor<1x128xi1>) -> tensor<1x128xi1>
      %52 = tensor.empty() : tensor<64x128xi1>
      %53 = tensor.empty() : tensor<64xf16>
      %54 = hfusion.select ins(%40, %cst, %cst_0 : tensor<64xi1>, f16, f16) outs(%53 : tensor<64xf16>) -> tensor<64xf16>
      %broadcasted_10 = linalg.broadcast ins(%54 : tensor<64xf16>) outs(%4 : tensor<64x128xf16>) dimensions = [1] 
      %55 = hfusion.compare {compare_fn = #hfusion.compare_fn<vne>} ins(%broadcasted_10, %cst_0 : tensor<64x128xf16>, f16) outs(%52 : tensor<64x128xi1>) -> tensor<64x128xi1>
      %collapsed_11 = tensor.collapse_shape %51 [[0, 1]] : tensor<1x128xi1> into tensor<128xi1>
      %56 = tensor.empty() : tensor<128xf16>
      %57 = hfusion.select ins(%collapsed_11, %cst, %cst_0 : tensor<128xi1>, f16, f16) outs(%56 : tensor<128xf16>) -> tensor<128xf16>
      %broadcasted_12 = linalg.broadcast ins(%57 : tensor<128xf16>) outs(%4 : tensor<64x128xf16>) dimensions = [0] 
      %58 = hfusion.compare {compare_fn = #hfusion.compare_fn<vne>} ins(%broadcasted_12, %cst_0 : tensor<64x128xf16>, f16) outs(%52 : tensor<64x128xi1>) -> tensor<64x128xi1>
      %59 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<vand>} ins(%55, %58 : tensor<64x128xi1>, tensor<64x128xi1>) outs(%52 : tensor<64x128xi1>) -> tensor<64x128xi1>
      %60 = tensor.empty() : tensor<64x128xi64>
      %61 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, round_mode = #hfusion.round_mode<rint>} ins(%49 : tensor<64x128xi32>) outs(%60 : tensor<64x128xi64>) -> tensor<64x128xi64>
      %62 = tensor.empty() : tensor<64x128xi8>
      %63 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, round_mode = #hfusion.round_mode<rint>} ins(%59 : tensor<64x128xi1>) outs(%62 : tensor<64x128xi8>) -> tensor<64x128xi8>
      %64 = hfusion.indirect_load ins(%arg2 : memref<?xf16>, %61 : tensor<64x128xi64>, %63 : tensor<64x128xi8>, %5 : tensor<64x128xf16>) outs(%4 : tensor<64x128xf16>) {isVolatile = false} -> tensor<64x128xf16>
      %inserted = tensor.insert %arg16 into %0[%c0] : tensor<1xf32>
      %65 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%inserted, %cst_3 : tensor<1xf32>, f32) outs(%0 : tensor<1xf32>) -> tensor<1xf32>
      %extracted = tensor.extract %65[%c0] : tensor<1xf32>
      %66 = arith.subi %18, %16 : i32
      %67 = arith.muli %6, %arg22 : i32
      %68 = arith.extsi %arg19 : i32 to i64
      %69 = arith.muli %arg29, %arg21 : i32
      %70 = arith.index_cast %69 : i32 to index
      %broadcasted_13 = linalg.broadcast ins(%35 : tensor<64xi32>) outs(%48 : tensor<64x128xi32>) dimensions = [1] 
      %71 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%36, %arg23 : tensor<64xi32>, i32) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %72 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%35, %arg24 : tensor<64xi32>, i32) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      %73 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%71, %72 : tensor<64xi32>, tensor<64xi32>) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
      scf.for %arg31 = %c0_i32 to %66 step %c1_i32  : i32 {
        %74 = arith.addi %16, %arg31 : i32
        %75 = arith.index_cast %67 : i32 to index
        %76 = arith.index_cast %74 : i32 to index
        %77 = arith.addi %75, %76 : index
        %reinterpret_cast_14 = memref.reinterpret_cast %arg4 to offset: [%77], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
        %78 = memref.load %reinterpret_cast_14[%c0] : memref<1xi32, strided<[1], offset: ?>>
        %79 = arith.extsi %78 : i32 to i64
        %80 = arith.muli %74, %c128_i32 : i32
        %81 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%80, %24 : i32, tensor<128xi32>) outs(%23 : tensor<128xi32>) -> tensor<128xi32>
        %82 = tensor.empty() : tensor<128xi1>
        %83 = hfusion.compare {compare_fn = #hfusion.compare_fn<vlt>} ins(%81, %9 : tensor<128xi32>, i32) outs(%82 : tensor<128xi1>) -> tensor<128xi1>
        %84 = arith.muli %79, %68 : i64
        %85 = arith.index_cast %84 : i64 to index
        %86 = arith.addi %85, %70 : index
        %87 = arith.index_cast %arg20 : i32 to index
        %reinterpret_cast_15 = memref.reinterpret_cast %arg3 to offset: [%86], sizes: [128, 128], strides: [%87, 1] : memref<?xf16> to memref<128x128xf16, strided<[?, 1], offset: ?>>
        %alloc = memref.alloc() : memref<128x128xf16>
        %88 = arith.index_cast %80 : i32 to index
        %89 = arith.addi %88, %c128 : index
        %90 = arith.index_cast %9 : i32 to index
        %91 = arith.maxsi %88, %90 : index
        %92 = arith.minsi %89, %91 : index
        %93 = arith.subi %92, %88 : index
        %94 = arith.index_cast %arg13 : i32 to index
        %95 = arith.maxsi %94, %c0 : index
        %96 = arith.minsi %95, %c128 : index
        %97 = arith.minsi %93, %c128 : index
        %98 = arith.maxsi %97, %c0 : index
        %99 = arith.minsi %96, %c128 : index
        %100 = arith.maxsi %99, %c0 : index
        %101 = arith.cmpi slt, %98, %c128 : index
        %102 = arith.cmpi slt, %100, %c128 : index
        %103 = arith.ori %101, %102 : i1
        scf.if %103 {
          linalg.fill ins(%cst_0 : f16) outs(%alloc : memref<128x128xf16>)
        } {hivm.unlikely_condition}
        %subview = memref.subview %reinterpret_cast_15[0, 0] [%98, %100] [1, 1] : memref<128x128xf16, strided<[?, 1], offset: ?>> to memref<?x?xf16, strided<[?, 1], offset: ?>>
        %subview_16 = memref.subview %alloc[0, 0] [%98, %100] [1, 1] : memref<128x128xf16> to memref<?x?xf16, strided<[128, 1]>>
        memref.copy %subview, %subview_16 : memref<?x?xf16, strided<[?, 1], offset: ?>> to memref<?x?xf16, strided<[128, 1]>>
        %104 = bufferization.to_tensor %alloc restrict writable : memref<128x128xf16>
        %105 = tensor.empty() : tensor<128x128xf16>
        %transposed = linalg.transpose ins(%104 : tensor<128x128xf16>) outs(%105 : tensor<128x128xf16>) permutation = [1, 0] 
        %106 = linalg.matmul {input_precision = "ieee"} ins(%64, %transposed : tensor<64x128xf16>, tensor<128x128xf16>) outs(%3 : tensor<64x128xf32>) -> tensor<64x128xf32>
        %107 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%106, %extracted : tensor<64x128xf32>, f32) outs(%2 : tensor<64x128xf32>) -> tensor<64x128xf32>
        %broadcasted_17 = linalg.broadcast ins(%81 : tensor<128xi32>) outs(%48 : tensor<64x128xi32>) dimensions = [0] 
        %108 = hfusion.compare {compare_fn = #hfusion.compare_fn<vge>} ins(%broadcasted_13, %broadcasted_17 : tensor<64x128xi32>, tensor<64x128xi32>) outs(%52 : tensor<64x128xi1>) -> tensor<64x128xi1>
        %109 = hfusion.select ins(%83, %cst, %cst_0 : tensor<128xi1>, f16, f16) outs(%56 : tensor<128xf16>) -> tensor<128xf16>
        %broadcasted_18 = linalg.broadcast ins(%109 : tensor<128xf16>) outs(%4 : tensor<64x128xf16>) dimensions = [0] 
        %110 = hfusion.compare {compare_fn = #hfusion.compare_fn<vne>} ins(%broadcasted_18, %cst_0 : tensor<64x128xf16>, f16) outs(%52 : tensor<64x128xi1>) -> tensor<64x128xi1>
        %111 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<vand>} ins(%108, %110 : tensor<64x128xi1>, tensor<64x128xi1>) outs(%52 : tensor<64x128xi1>) -> tensor<64x128xi1>
        %112 = hfusion.select ins(%111, %107, %cst_1 : tensor<64x128xi1>, tensor<64x128xf32>, f32) outs(%2 : tensor<64x128xf32>) -> tensor<64x128xf32>
        %113 = tensor.empty() : tensor<64xf32>
        %114 = linalg.fill ins(%cst_1 : f32) outs(%113 : tensor<64xf32>) -> tensor<64xf32>
        %115 = hfusion.bitcast ins(%112 : tensor<64x128xf32>) outs(%48 : tensor<64x128xi32>) -> tensor<64x128xi32>
        %116 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<vand>} ins(%115, %c2147483647_i32 : tensor<64x128xi32>, i32) outs(%48 : tensor<64x128xi32>) -> tensor<64x128xi32>
        %117 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%116, %c-2139095040_i32 : tensor<64x128xi32>, i32) outs(%48 : tensor<64x128xi32>) -> tensor<64x128xi32>
        %118 = linalg.elemwise_binary {fun = #linalg.binary_fn<min_signed>} ins(%117, %c1_i32 : tensor<64x128xi32>, i32) outs(%117 : tensor<64x128xi32>) -> tensor<64x128xi32>
        %119 = linalg.elemwise_binary {fun = #linalg.binary_fn<max_signed>} ins(%118, %c0_i32 : tensor<64x128xi32>, i32) outs(%118 : tensor<64x128xi32>) -> tensor<64x128xi32>
        %120 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, enable_overflow = false, round_mode = #hfusion.round_mode<rint>} ins(%119 : tensor<64x128xi32>) outs(%2 : tensor<64x128xf32>) -> tensor<64x128xf32>
        %121 = hfusion.compare {compare_fn = #hfusion.compare_fn<vne>} ins(%120, %cst_2 : tensor<64x128xf32>, f32) outs(%52 : tensor<64x128xi1>) -> tensor<64x128xi1>
        %122 = hfusion.select ins(%121, %cst_1, %112 : tensor<64x128xi1>, f32, tensor<64x128xf32>) outs(%2 : tensor<64x128xf32>) -> tensor<64x128xf32>
        %reduced = linalg.reduce ins(%122 : tensor<64x128xf32>) outs(%114 : tensor<64xf32>) dimensions = [1] 
          (%in: f32, %init: f32) {
            %128 = arith.maximumf %in, %init : f32
            linalg.yield %128 : f32
          }
        %123 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%73, %74 : tensor<64xi32>, i32) outs(%1 : tensor<64xi32>) -> tensor<64xi32>
        %124 = tensor.empty() : tensor<64xi64>
        %125 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, round_mode = #hfusion.round_mode<rint>} ins(%123 : tensor<64xi32>) outs(%124 : tensor<64xi64>) -> tensor<64xi64>
        %126 = tensor.empty() : tensor<64xi8>
        %127 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, round_mode = #hfusion.round_mode<rint>} ins(%40 : tensor<64xi1>) outs(%126 : tensor<64xi8>) -> tensor<64xi8>
        hfusion.indirect_store ins(%reduced : tensor<64xf32>, %125 : tensor<64xi64>, %127 : tensor<64xi8>) outs(%arg9 : memref<?xf32>)
      }
    }
    return
  }
}


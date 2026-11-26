module attributes {dlti.target_system_spec = #dlti.target_system_spec<"NPU" : #hacc.target_device_spec<#dlti.dl_entry<"AI_CORE_COUNT", 28 : i32>, #dlti.dl_entry<"CUBE_CORE_COUNT", 28 : i32>, #dlti.dl_entry<"VECTOR_CORE_COUNT", 56 : i32>, #dlti.dl_entry<"UB_SIZE", 2031616 : i32>, #dlti.dl_entry<"L1_SIZE", 4194304 : i32>, #dlti.dl_entry<"L0A_SIZE", 524288 : i32>, #dlti.dl_entry<"L0B_SIZE", 524288 : i32>, #dlti.dl_entry<"L0C_SIZE", 2097152 : i32>, #dlti.dl_entry<"UB_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L1_ALIGN_SIZE", 256 : i32>, #dlti.dl_entry<"L0C_ALIGN_SIZE", 4096 : i32>, #dlti.dl_entry<"MINIMAL_D_CACHE_SIZE", 262144 : i32>, #dlti.dl_entry<"MAXIMUM_D_CACHE_SIZE", 983040 : i32>, #dlti.dl_entry<"ARCH", "dav-c310">>>, hacc.target = #hacc.target<"Ascend950PR_9579">} {
  func.func @_gqa_sparse_fwd_kernel(%arg0: memref<?xi8> {hacc.arg_type = #hacc.arg_type<sync_block_lock>}, %arg1: memref<?xi8> {hacc.arg_type = #hacc.arg_type<workspace>}, %arg2: memref<?xbf16> {tt.tensor_kind = 0 : i32}, %arg3: memref<?xbf16> {tt.tensor_kind = 0 : i32}, %arg4: memref<?xbf16>, %arg5: memref<?xbf16>, %arg6: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg7: memref<?xbf16> {tt.tensor_kind = 1 : i32}, %arg8: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg9: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg10: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg11: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg12: memref<?xi32> {tt.tensor_kind = 0 : i32}, %arg13: i32, %arg14: i32, %arg15: i32, %arg16: i32, %arg17: f32, %arg18: i32, %arg19: i32, %arg20: i32, %arg21: i32, %arg22: i32, %arg23: i32, %arg24: i32, %arg25: i32, %arg26: i32, %arg27: i32, %arg28: i32, %arg29: i32, %arg30: i32, %arg31: i32, %arg32: i32, %arg33: i32, %arg34: i32, %arg35: i32, %arg36: i32, %arg37: i32) attributes {SyncBlockLockArgIdx = 0 : i64, WorkspaceArgIdx = 1 : i64, hacc.entry, hacc.function_kind = #hacc.function_kind<DEVICE>, mix_mode = "mix", parallel_mode = "simd"} {
    %c-1_i32 = arith.constant -1 : i32
    %cst = arith.constant 2.000000e+00 : f32
    %cst_0 = arith.constant 0.693147182 : f32
    %c-2139095040_i32 = arith.constant -2139095040 : i32
    %c2147483647_i32 = arith.constant 2147483647 : i32
    %cst_1 = arith.constant 0.000000e+00 : f32
    %cst_2 = arith.constant 0xFF800000 : f32
    %c1_i64 = arith.constant 1 : i64
    %c128_i32 = arith.constant 128 : i32
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %cst_3 = arith.constant 0.000000e+00 : bf16
    %c16 = arith.constant 16 : index
    %c1 = arith.constant 1 : index
    %c128 = arith.constant 128 : index
    %c0 = arith.constant 0 : index
    %cst_4 = arith.constant 1.44269502 : f32
    %0 = tensor.empty() : tensor<1xf32>
    %1 = tensor.empty() : tensor<16xf32>
    %2 = linalg.fill ins(%cst_2 : f32) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
    %3 = tensor.empty() : tensor<1x1x128xf32>
    %4 = tensor.empty() : tensor<16x128xf32>
    %5 = linalg.fill ins(%cst_1 : f32) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
    %6 = tensor.empty() : tensor<1x128xf32>
    %7 = linalg.fill ins(%cst_1 : f32) outs(%6 : tensor<1x128xf32>) -> tensor<1x128xf32>
    %8 = linalg.fill ins(%cst_2 : f32) outs(%6 : tensor<1x128xf32>) -> tensor<1x128xf32>
    %inserted = tensor.insert %arg17 into %0[%c0] : tensor<1xf32>
    %9 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%inserted, %cst_4 : tensor<1xf32>, f32) outs(%0 : tensor<1xf32>) -> tensor<1xf32>
    %extracted = tensor.extract %9[%c0] : tensor<1xf32>
    %10 = arith.muli %arg36, %arg14 : i32
    %11 = arith.index_cast %arg37 : i32 to index
    %reinterpret_cast = memref.reinterpret_cast %arg9 to offset: [%11], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
    %12 = memref.load %reinterpret_cast[%c0] : memref<1xi32, strided<[1], offset: ?>>
    %13 = arith.addi %11, %c1 : index
    %reinterpret_cast_5 = memref.reinterpret_cast %arg9 to offset: [%13], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
    %14 = memref.load %reinterpret_cast_5[%c0] : memref<1xi32, strided<[1], offset: ?>>
    %15 = arith.subi %14, %12 : i32
    %reinterpret_cast_6 = memref.reinterpret_cast %arg10 to offset: [%11], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
    %16 = memref.load %reinterpret_cast_6[%c0] : memref<1xi32, strided<[1], offset: ?>>
    %reinterpret_cast_7 = memref.reinterpret_cast %arg10 to offset: [%13], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
    %17 = memref.load %reinterpret_cast_7[%c0] : memref<1xi32, strided<[1], offset: ?>>
    %18 = arith.subi %17, %16 : i32
    %reinterpret_cast_8 = memref.reinterpret_cast %arg11 to offset: [%11], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
    %19 = memref.load %reinterpret_cast_8[%c0] : memref<1xi32, strided<[1], offset: ?>>
    %reinterpret_cast_9 = memref.reinterpret_cast %arg12 to offset: [%11], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
    %20 = memref.load %reinterpret_cast_9[%c0] : memref<1xi32, strided<[1], offset: ?>>
    %21 = arith.cmpi sge, %arg35, %18 : i32
    scf.if %21 {
    } else {
      %22 = arith.subi %18, %arg35 : i32
      %23 = arith.minsi %22, %c1_i32 : i32
      %24 = arith.muli %arg37, %arg31 : i32
      %25 = arith.index_cast %24 : i32 to index
      %26 = tensor.empty() : tensor<128xi32>
      %27 = hfusion.arange offset[%c0] strides[%c1] outs(%26 : tensor<128xi32>) -> tensor<128xi32>
      %28 = arith.muli %arg36, %arg27 : i32
      %29 = arith.muli %12, %arg18 : i32
      %30 = arith.index_cast %29 : i32 to index
      %31 = arith.muli %10, %arg19 : i32
      %32 = arith.index_cast %31 : i32 to index
      %33 = arith.addi %30, %32 : index
      %expanded = tensor.expand_shape %27 [[0, 1]] output_shape [1, 128] : tensor<128xi32> into tensor<1x128xi32>
      %34 = arith.extsi %arg20 : i32 to i64
      %35 = arith.muli %arg36, %arg21 : i32
      %36 = arith.index_cast %35 : i32 to index
      %37 = arith.muli %12, %arg29 : i32
      %38 = arith.index_cast %37 : i32 to index
      %39 = arith.muli %10, %arg30 : i32
      %40 = arith.index_cast %39 : i32 to index
      %41 = arith.addi %38, %40 : index
      scf.for %arg38 = %c0_i32 to %23 step %c1_i32  : i32 {
        %42 = arith.addi %arg35, %arg38 : i32
        %43 = arith.addi %16, %42 : i32
        %44 = arith.muli %43, %arg28 : i32
        %45 = arith.extsi %44 : i32 to i64
        %46 = arith.extsi %28 : i32 to i64
        %47 = arith.addi %45, %46 : i64
        %48 = arith.addi %20, %42 : i32
        %49 = arith.addi %48, %c128_i32 : i32
        %50 = arith.divsi %49, %c128_i32 : i32
        %51 = arith.minsi %arg16, %50 : i32
        %52 = arith.maxsi %42, %c0_i32 : i32
        %53 = arith.index_cast %52 : i32 to index
        %54 = arith.index_cast %arg18 : i32 to index
        %55 = arith.index_cast %arg19 : i32 to index
        %56 = arith.muli %53, %54 : index
        %57 = arith.addi %56, %33 : index
        %58 = arith.index_cast %15 : i32 to index
        %59 = arith.index_cast %arg14 : i32 to index
        %60 = arith.index_cast %arg15 : i32 to index
        %61 = arith.maxsi %54, %c1 : index
        %reinterpret_cast_10 = memref.reinterpret_cast %arg2 to offset: [%57], sizes: [1, 16, 128], strides: [%61, %55, 1] : memref<?xbf16> to memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>>
        %alloc = memref.alloc() : memref<1x16x128xbf16>
        %62 = arith.divsi %56, %54 : index
        %63 = arith.subi %58, %62 : index
        %64 = arith.maxsi %63, %c0 : index
        %65 = arith.minsi %64, %c1 : index
        %66 = arith.remsi %56, %54 : index
        %67 = arith.divsi %66, %55 : index
        %68 = arith.subi %59, %67 : index
        %69 = arith.maxsi %68, %c0 : index
        %70 = arith.minsi %69, %c16 : index
        %71 = arith.remsi %66, %55 : index
        %72 = arith.subi %60, %71 : index
        %73 = arith.maxsi %72, %c0 : index
        %74 = arith.minsi %73, %c128 : index
        %75 = arith.subi %c0_i32, %42 : i32
        %76 = arith.maxsi %75, %c0_i32 : i32
        %77 = arith.index_cast %76 : i32 to index
        %78 = arith.minsi %77, %65 : index
        %79 = arith.subi %65, %78 : index
        %80 = arith.minsi %70, %c0 : index
        %81 = arith.subi %70, %80 : index
        %82 = arith.minsi %74, %c0 : index
        %83 = arith.subi %74, %82 : index
        %84 = arith.cmpi slt, %79, %c1 : index
        %85 = arith.cmpi slt, %81, %c16 : index
        %86 = arith.ori %84, %85 : i1
        %87 = arith.cmpi slt, %83, %c128 : index
        %88 = arith.ori %86, %87 : i1
        scf.if %88 {
          linalg.fill ins(%cst_3 : bf16) outs(%alloc : memref<1x16x128xbf16>)
        } {hivm.unlikely_condition}
        %subview = memref.subview %reinterpret_cast_10[0, 0, 0] [%79, %81, %83] [1, 1, 1] : memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>> to memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>>
        %subview_11 = memref.subview %alloc[%78, %80, %82] [%79, %81, %83] [1, 1, 1] : memref<1x16x128xbf16> to memref<?x?x?xbf16, strided<[2048, 128, 1], offset: ?>>
        memref.copy %subview, %subview_11 : memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>> to memref<?x?x?xbf16, strided<[2048, 128, 1], offset: ?>>
        %89 = bufferization.to_tensor %alloc restrict writable : memref<1x16x128xbf16>
        %90 = tensor.empty() : tensor<1x128xi32>
        %91 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%expanded, %c-1_i32 : tensor<1x128xi32>, i32) outs(%90 : tensor<1x128xi32>) -> tensor<1x128xi32>
        %92 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%48, %91 : i32, tensor<1x128xi32>) outs(%90 : tensor<1x128xi32>) -> tensor<1x128xi32>
        %collapsed = tensor.collapse_shape %89 [[0, 1], [2]] : tensor<1x16x128xbf16> into tensor<16x128xbf16>
        %expanded_12 = tensor.expand_shape %92 [[0], [1, 2]] output_shape [1, 1, 128] : tensor<1x128xi32> into tensor<1x1x128xi32>
        %93:4 = scf.for %arg39 = %c0_i32 to %51 step %c1_i32 iter_args(%arg40 = %47, %arg41 = %2, %arg42 = %2, %arg43 = %5) -> (i64, tensor<16xf32>, tensor<16xf32>, tensor<16x128xf32>)  : i32 {
          %124 = arith.index_cast %arg40 : i64 to index
          %reinterpret_cast_16 = memref.reinterpret_cast %arg6 to offset: [%124], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
          %125 = memref.load %reinterpret_cast_16[%c0] : memref<1xi32, strided<[1], offset: ?>>
          %126 = arith.addi %arg40, %c1_i64 : i64
          %127 = arith.muli %125, %c128_i32 : i32
          %128 = arith.index_cast %125 : i32 to index
          %129 = arith.addi %25, %128 : index
          %reinterpret_cast_17 = memref.reinterpret_cast %arg8 to offset: [%129], sizes: [1], strides: [1] : memref<?xi32> to memref<1xi32, strided<[1], offset: ?>>
          %130 = memref.load %reinterpret_cast_17[%c0] : memref<1xi32, strided<[1], offset: ?>>
          %131 = arith.extsi %130 : i32 to i64
          %132 = arith.muli %131, %34 : i64
          %133 = arith.index_cast %132 : i64 to index
          %134 = arith.addi %133, %36 : index
          %135 = arith.index_cast %arg22 : i32 to index
          %reinterpret_cast_18 = memref.reinterpret_cast %arg3 to offset: [%134], sizes: [128, 128], strides: [%135, 1] : memref<?xbf16> to memref<128x128xbf16, strided<[?, 1], offset: ?>>
          %alloc_19 = memref.alloc() : memref<128x128xbf16>
          %136 = arith.index_cast %127 : i32 to index
          %137 = arith.addi %136, %c128 : index
          %138 = arith.index_cast %19 : i32 to index
          %139 = arith.maxsi %136, %138 : index
          %140 = arith.minsi %137, %139 : index
          %141 = arith.subi %140, %136 : index
          %142 = arith.maxsi %60, %c0 : index
          %143 = arith.minsi %142, %c128 : index
          %144 = arith.minsi %141, %c128 : index
          %145 = arith.maxsi %144, %c0 : index
          %146 = arith.minsi %143, %c128 : index
          %147 = arith.maxsi %146, %c0 : index
          %148 = arith.cmpi slt, %145, %c128 : index
          %149 = arith.cmpi slt, %147, %c128 : index
          %150 = arith.ori %148, %149 : i1
          scf.if %150 {
            linalg.fill ins(%cst_3 : bf16) outs(%alloc_19 : memref<128x128xbf16>)
          } {hivm.unlikely_condition}
          %subview_20 = memref.subview %reinterpret_cast_18[0, 0] [%145, %147] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>> to memref<?x?xbf16, strided<[?, 1], offset: ?>>
          %subview_21 = memref.subview %alloc_19[0, 0] [%145, %147] [1, 1] : memref<128x128xbf16> to memref<?x?xbf16, strided<[128, 1]>>
          memref.copy %subview_20, %subview_21 : memref<?x?xbf16, strided<[?, 1], offset: ?>> to memref<?x?xbf16, strided<[128, 1]>>
          %151 = bufferization.to_tensor %alloc_19 restrict writable : memref<128x128xbf16>
          %152 = tensor.empty() : tensor<128x128xbf16>
          %transposed = linalg.transpose ins(%151 : tensor<128x128xbf16>) outs(%152 : tensor<128x128xbf16>) permutation = [1, 0] 
          %153 = tensor.empty() : tensor<1x1x128xi1>
          %154 = hfusion.compare {compare_fn = #hfusion.compare_fn<vge>} ins(%expanded_12, %127 : tensor<1x1x128xi32>, i32) outs(%153 : tensor<1x1x128xi1>) -> tensor<1x1x128xi1>
          %155 = hfusion.select ins(%154, %cst_1, %cst_2 : tensor<1x1x128xi1>, f32, f32) outs(%3 : tensor<1x1x128xf32>) -> tensor<1x1x128xf32>
          %156 = tensor.empty() : tensor<1x16x128xf32>
          %collapsed_22 = tensor.collapse_shape %155 [[0], [1, 2]] : tensor<1x1x128xf32> into tensor<1x128xf32>
          %broadcasted_23 = linalg.broadcast ins(%collapsed_22 : tensor<1x128xf32>) outs(%156 : tensor<1x16x128xf32>) dimensions = [1] 
          %collapsed_24 = tensor.collapse_shape %broadcasted_23 [[0, 1], [2]] : tensor<1x16x128xf32> into tensor<16x128xf32>
          %157 = linalg.matmul {input_precision = "ieee"} ins(%collapsed, %transposed : tensor<16x128xbf16>, tensor<128x128xbf16>) outs(%5 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %158 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%157, %extracted : tensor<16x128xf32>, f32) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %159 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%collapsed_24, %158 : tensor<16x128xf32>, tensor<16x128xf32>) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %extracted_slice_25 = tensor.extract_slice %7[0, 0] [1, %141] [1, 1] : tensor<1x128xf32> to tensor<1x?xf32>
          %inserted_slice = tensor.insert_slice %extracted_slice_25 into %8[0, 0] [1, %141] [1, 1] : tensor<1x?xf32> into tensor<1x128xf32>
          %collapsed_26 = tensor.collapse_shape %inserted_slice [[0, 1]] : tensor<1x128xf32> into tensor<128xf32>
          %broadcasted_27 = linalg.broadcast ins(%collapsed_26 : tensor<128xf32>) outs(%4 : tensor<16x128xf32>) dimensions = [0] 
          %160 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%159, %broadcasted_27 : tensor<16x128xf32>, tensor<16x128xf32>) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %161 = tensor.empty() : tensor<16x128xi32>
          %162 = hfusion.bitcast ins(%160 : tensor<16x128xf32>) outs(%161 : tensor<16x128xi32>) -> tensor<16x128xi32>
          %163 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<vand>} ins(%162, %c2147483647_i32 : tensor<16x128xi32>, i32) outs(%161 : tensor<16x128xi32>) -> tensor<16x128xi32>
          %164 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%163, %c-2139095040_i32 : tensor<16x128xi32>, i32) outs(%161 : tensor<16x128xi32>) -> tensor<16x128xi32>
          %165 = linalg.elemwise_binary {fun = #linalg.binary_fn<min_signed>} ins(%164, %c1_i32 : tensor<16x128xi32>, i32) outs(%164 : tensor<16x128xi32>) -> tensor<16x128xi32>
          %166 = linalg.elemwise_binary {fun = #linalg.binary_fn<max_signed>} ins(%165, %c0_i32 : tensor<16x128xi32>, i32) outs(%165 : tensor<16x128xi32>) -> tensor<16x128xi32>
          %167 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, enable_overflow = false, round_mode = #hfusion.round_mode<rint>} ins(%166 : tensor<16x128xi32>) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %168 = tensor.empty() : tensor<16x128xi1>
          %169 = hfusion.compare {compare_fn = #hfusion.compare_fn<vne>} ins(%167, %cst_1 : tensor<16x128xf32>, f32) outs(%168 : tensor<16x128xi1>) -> tensor<16x128xi1>
          %170 = hfusion.select ins(%169, %cst_2, %160 : tensor<16x128xi1>, f32, tensor<16x128xf32>) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %reduced = linalg.reduce ins(%170 : tensor<16x128xf32>) outs(%2 : tensor<16xf32>) dimensions = [1] 
            (%in: f32, %init: f32) {
              %211 = arith.maximumf %in, %init : f32
              linalg.yield %211 : f32
            }
          %171 = tensor.empty() : tensor<16xi32>
          %172 = hfusion.bitcast ins(%arg41 : tensor<16xf32>) outs(%171 : tensor<16xi32>) -> tensor<16xi32>
          %173 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<vand>} ins(%172, %c2147483647_i32 : tensor<16xi32>, i32) outs(%171 : tensor<16xi32>) -> tensor<16xi32>
          %174 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%173, %c-2139095040_i32 : tensor<16xi32>, i32) outs(%171 : tensor<16xi32>) -> tensor<16xi32>
          %175 = linalg.elemwise_binary {fun = #linalg.binary_fn<min_signed>} ins(%174, %c1_i32 : tensor<16xi32>, i32) outs(%174 : tensor<16xi32>) -> tensor<16xi32>
          %176 = linalg.elemwise_binary {fun = #linalg.binary_fn<max_signed>} ins(%175, %c0_i32 : tensor<16xi32>, i32) outs(%175 : tensor<16xi32>) -> tensor<16xi32>
          %177 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, enable_overflow = false, round_mode = #hfusion.round_mode<rint>} ins(%176 : tensor<16xi32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %178 = tensor.empty() : tensor<16xi1>
          %179 = hfusion.compare {compare_fn = #hfusion.compare_fn<vne>} ins(%177, %cst_1 : tensor<16xf32>, f32) outs(%178 : tensor<16xi1>) -> tensor<16xi1>
          %180 = hfusion.select ins(%179, %cst_2, %arg41 : tensor<16xi1>, f32, tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %181 = hfusion.bitcast ins(%reduced : tensor<16xf32>) outs(%171 : tensor<16xi32>) -> tensor<16xi32>
          %182 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<vand>} ins(%181, %c2147483647_i32 : tensor<16xi32>, i32) outs(%171 : tensor<16xi32>) -> tensor<16xi32>
          %183 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%182, %c-2139095040_i32 : tensor<16xi32>, i32) outs(%171 : tensor<16xi32>) -> tensor<16xi32>
          %184 = linalg.elemwise_binary {fun = #linalg.binary_fn<min_signed>} ins(%183, %c1_i32 : tensor<16xi32>, i32) outs(%183 : tensor<16xi32>) -> tensor<16xi32>
          %185 = linalg.elemwise_binary {fun = #linalg.binary_fn<max_signed>} ins(%184, %c0_i32 : tensor<16xi32>, i32) outs(%184 : tensor<16xi32>) -> tensor<16xi32>
          %186 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, enable_overflow = false, round_mode = #hfusion.round_mode<rint>} ins(%185 : tensor<16xi32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %187 = hfusion.compare {compare_fn = #hfusion.compare_fn<vne>} ins(%186, %cst_1 : tensor<16xf32>, f32) outs(%178 : tensor<16xi1>) -> tensor<16xi1>
          %188 = hfusion.select ins(%187, %cst_2, %reduced : tensor<16xi1>, f32, tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %189 = hfusion.elemwise_binary {fun = #hfusion.binary_fn<maxf>} ins(%180, %188 : tensor<16xf32>, tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %broadcasted_28 = linalg.broadcast ins(%189 : tensor<16xf32>) outs(%4 : tensor<16x128xf32>) dimensions = [1] 
          %190 = linalg.elemwise_binary {fun = #linalg.binary_fn<sub>} ins(%160, %broadcasted_28 : tensor<16x128xf32>, tensor<16x128xf32>) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %191 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%190, %cst_0 : tensor<16x128xf32>, f32) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %192 = linalg.elemwise_unary {fun = #linalg.unary_fn<exp>} ins(%191 : tensor<16x128xf32>) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %193 = linalg.fill ins(%cst_1 : f32) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %reduced_29 = linalg.reduce ins(%192 : tensor<16x128xf32>) outs(%193 : tensor<16xf32>) dimensions = [1] 
            (%in: f32, %init: f32) {
              %211 = arith.addf %in, %init : f32
              linalg.yield %211 : f32
            }
          %194 = linalg.elemwise_binary {fun = #linalg.binary_fn<sub>} ins(%arg41, %189 : tensor<16xf32>, tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %195 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%194, %cst_0 : tensor<16xf32>, f32) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %196 = linalg.elemwise_unary {fun = #linalg.unary_fn<exp>} ins(%195 : tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %broadcasted_30 = linalg.broadcast ins(%196 : tensor<16xf32>) outs(%4 : tensor<16x128xf32>) dimensions = [1] 
          %197 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%arg43, %broadcasted_30 : tensor<16x128xf32>, tensor<16x128xf32>) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %198 = arith.addi %134, %60 : index
          %reinterpret_cast_31 = memref.reinterpret_cast %arg3 to offset: [%198], sizes: [128, 128], strides: [%135, 1] : memref<?xbf16> to memref<128x128xbf16, strided<[?, 1], offset: ?>>
          %alloc_32 = memref.alloc() : memref<128x128xbf16>
          scf.if %150 {
            linalg.fill ins(%cst_3 : bf16) outs(%alloc_32 : memref<128x128xbf16>)
          } {hivm.unlikely_condition}
          %subview_33 = memref.subview %reinterpret_cast_31[0, 0] [%145, %147] [1, 1] : memref<128x128xbf16, strided<[?, 1], offset: ?>> to memref<?x?xbf16, strided<[?, 1], offset: ?>>
          %subview_34 = memref.subview %alloc_32[0, 0] [%145, %147] [1, 1] : memref<128x128xbf16> to memref<?x?xbf16, strided<[128, 1]>>
          memref.copy %subview_33, %subview_34 : memref<?x?xbf16, strided<[?, 1], offset: ?>> to memref<?x?xbf16, strided<[128, 1]>>
          %199 = bufferization.to_tensor %alloc_32 restrict writable : memref<128x128xbf16>
          %200 = tensor.empty() : tensor<16x128xbf16>
          %201 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, round_mode = #hfusion.round_mode<rint>} ins(%192 : tensor<16x128xf32>) outs(%200 : tensor<16x128xbf16>) -> tensor<16x128xbf16>
          %202 = linalg.matmul {input_precision = "ieee"} ins(%201, %199 : tensor<16x128xbf16>, tensor<128x128xbf16>) outs(%197 : tensor<16x128xf32>) -> tensor<16x128xf32>
          %203 = linalg.elemwise_binary {fun = #linalg.binary_fn<sub>} ins(%arg42, %189 : tensor<16xf32>, tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %204 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%203, %cst_0 : tensor<16xf32>, f32) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %205 = linalg.elemwise_unary {fun = #linalg.unary_fn<exp>} ins(%204 : tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %206 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%205, %reduced_29 : tensor<16xf32>, tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %207 = linalg.elemwise_unary {fun = #linalg.unary_fn<log>} ins(%206 : tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %208 = linalg.elemwise_unary {fun = #linalg.unary_fn<log>} ins(%cst : f32) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %209 = linalg.elemwise_binary {fun = #linalg.binary_fn<div>} ins(%207, %208 : tensor<16xf32>, tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          %210 = linalg.elemwise_binary {fun = #linalg.binary_fn<add>} ins(%189, %209 : tensor<16xf32>, tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
          scf.yield %126, %189, %210, %202 : i64, tensor<16xf32>, tensor<16xf32>, tensor<16x128xf32>
        }
        %94 = linalg.elemwise_binary {fun = #linalg.binary_fn<sub>} ins(%93#1, %93#2 : tensor<16xf32>, tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
        %95 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%94, %cst_0 : tensor<16xf32>, f32) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
        %96 = linalg.elemwise_unary {fun = #linalg.unary_fn<exp>} ins(%95 : tensor<16xf32>) outs(%1 : tensor<16xf32>) -> tensor<16xf32>
        %broadcasted = linalg.broadcast ins(%96 : tensor<16xf32>) outs(%4 : tensor<16x128xf32>) dimensions = [1] 
        %97 = linalg.elemwise_binary {fun = #linalg.binary_fn<mul>} ins(%93#3, %broadcasted : tensor<16x128xf32>, tensor<16x128xf32>) outs(%4 : tensor<16x128xf32>) -> tensor<16x128xf32>
        %expanded_13 = tensor.expand_shape %97 [[0, 1], [2]] output_shape [1, 16, 128] : tensor<16x128xf32> into tensor<1x16x128xf32>
        %98 = arith.index_cast %arg29 : i32 to index
        %99 = arith.index_cast %arg30 : i32 to index
        %100 = arith.muli %53, %98 : index
        %101 = arith.addi %100, %41 : index
        %102 = arith.maxsi %98, %c1 : index
        %reinterpret_cast_14 = memref.reinterpret_cast %arg7 to offset: [%101], sizes: [1, 16, 128], strides: [%102, %99, 1] : memref<?xbf16> to memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>>
        %103 = tensor.empty() : tensor<1x16x128xbf16>
        %104 = hfusion.cast {cast = #hfusion.type_fn<cast_signed>, round_mode = #hfusion.round_mode<rint>} ins(%expanded_13 : tensor<1x16x128xf32>) outs(%103 : tensor<1x16x128xbf16>) -> tensor<1x16x128xbf16>
        %105 = arith.divsi %100, %98 : index
        %106 = arith.subi %58, %105 : index
        %107 = arith.maxsi %106, %c0 : index
        %108 = arith.minsi %107, %c1 : index
        %109 = arith.remsi %100, %98 : index
        %110 = arith.divsi %109, %99 : index
        %111 = arith.subi %59, %110 : index
        %112 = arith.maxsi %111, %c0 : index
        %113 = arith.minsi %112, %c16 : index
        %114 = arith.remsi %109, %99 : index
        %115 = arith.subi %60, %114 : index
        %116 = arith.maxsi %115, %c0 : index
        %117 = arith.minsi %116, %c128 : index
        %118 = arith.minsi %77, %108 : index
        %119 = arith.subi %108, %118 : index
        %120 = arith.minsi %113, %c0 : index
        %121 = arith.subi %113, %120 : index
        %122 = arith.minsi %117, %c0 : index
        %123 = arith.subi %117, %122 : index
        %extracted_slice = tensor.extract_slice %104[%118, %120, %122] [%119, %121, %123] [1, 1, 1] : tensor<1x16x128xbf16> to tensor<?x?x?xbf16>
        %subview_15 = memref.subview %reinterpret_cast_14[0, 0, 0] [%119, %121, %123] [1, 1, 1] : memref<1x16x128xbf16, strided<[?, ?, 1], offset: ?>> to memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>>
        bufferization.materialize_in_destination %extracted_slice in writable %subview_15 : (tensor<?x?x?xbf16>, memref<?x?x?xbf16, strided<[?, ?, 1], offset: ?>>) -> ()
      }
    }
    return
  }
}


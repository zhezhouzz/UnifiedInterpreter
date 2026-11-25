%subview_17 = memref.subview %alloc_16[0] [128] [1] : memref<256xf32> to memref<128xf32, strided<[1]>>
%alloc_18 = memref.alloc() {alignment = 64 : i64} : memref<256xf32>
hivm.hir.copy ins(%alloc_10 : memref<256xf32>) outs(%alloc_18 : memref<256xf32>)      // 零模板
%subview_19 = memref.subview %alloc_18[0] [128] [1] : memref<256xf32> to memref<128xf32, strided<[1]>>
memref.copy %subview_17, %subview_19 : memref<128xf32, strided<[1]>> to memref<128xf32, strided<[1]>>  // ← 真实数据
%subview_20 = memref.subview %alloc_18[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
%alloc_21 = memref.alloc() {alignment = 64 : i64} : memref<256xf32>
hivm.hir.copy ins(%alloc_10 : memref<256xf32>) outs(%alloc_21 : memref<256xf32>)
%subview_22 = memref.subview %alloc_21[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
memref.copy %subview_20, %subview_22 : memref<64xf32, strided<[1]>> to memref<64xf32, strided<[1]>>

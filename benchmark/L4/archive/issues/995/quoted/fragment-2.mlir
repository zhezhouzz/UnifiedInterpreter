%subview_17 = memref.subview %alloc_16[0] [128] [1] : memref<256xf32> to memref<128xf32, strided<[1]>>
%alloc_18 = memref.alloc() {alignment = 64 : i64} : memref<256xf32>
hivm.hir.copy ins(%alloc_10 : memref<256xf32>) outs(%alloc_18 : memref<256xf32>)      // 只剩零模板
%subview_19 = memref.subview %alloc_18[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>   // 128 被裁成 64
%alloc_20 = memref.alloc() {alignment = 64 : i64} : memref<256xf32>
hivm.hir.copy ins(%alloc_10 : memref<256xf32>) outs(%alloc_20 : memref<256xf32>)
%subview_21 = memref.subview %alloc_20[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
memref.copy %subview_19, %subview_21 : memref<64xf32, strided<[1]>> to memref<64xf32, strided<[1]>>          // 拷的是 0

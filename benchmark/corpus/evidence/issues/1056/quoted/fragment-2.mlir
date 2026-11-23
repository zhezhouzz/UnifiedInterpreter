%alloc_16 = memref.alloc() : memref<8x256xbf16>
%subview = memref.subview %alloc_16[%arg15, 0] [1, 256] [1, 1]
    : memref<8x256xbf16>
      to memref<1x256xbf16, strided<[256, 1], offset: ?>>
%collapse_shape = memref.collapse_shape %subview [[0, 1]]
    : memref<1x256xbf16, strided<[256, 1], offset: ?>>
      into memref<256xbf16, strided<[1], offset: ?>>

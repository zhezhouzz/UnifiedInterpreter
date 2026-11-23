%93 = memref.alloc() : memref<1x8x256xbf16>
%269 = memref.subview %93[0, %arg181, 0] [1, 1, 256] [1, 1, 1]
    : memref<1x8x256xbf16>
      to memref<1x1x256xbf16, strided<[2048, 256, 1], offset: ?>>
%270 = memref.collapse_shape %269 [[0, 1], [2]]
    : memref<1x1x256xbf16, strided<[2048, 256, 1], offset: ?>>
      into memref<1x256xbf16, strided<[256, 1], offset: ?>>

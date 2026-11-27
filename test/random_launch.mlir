module {
  func.func @sample(%buffer: memref<?xi32, strided<[?], offset: ?>>, %value: i32) -> i32 {
    %zero = arith.constant 0 : index
    memref.store %value, %buffer[%zero] : memref<?xi32, strided<[?], offset: ?>>
    %result = memref.load %buffer[%zero] : memref<?xi32, strided<[?], offset: ?>>
    return %result : i32
  }
}

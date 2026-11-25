func.func @test_scf_if_0(%arg0: memref<19xf32>, %arg1: memref<17xf32>, %arg2: index, %arg3: index) {
  %c0 = arith.constant 0 : index
  %cst = arith.constant 5.000000e+00 : f32
  %0 = arith.cmpi ne, %arg3, %c0 : index
  %subview = memref.subview %arg0[%arg2] [%arg3] [1] : memref<19xf32> to memref<?xf32, strided<[1], offset: ?>>
  %1 = scf.if %0 -> (memref<?xf32, strided<[?], offset: ?>>) {
    %alloc = memref.alloc(%arg3) {alignment = 64 : i64} : memref<?xf32>
    hivm.hir.vbrc ins(%cst : f32) outs(%alloc : memref<?xf32>)
    %cast = memref.cast %alloc : memref<?xf32> to memref<?xf32, strided<[?], offset: ?>>
    scf.yield %cast : memref<?xf32, strided<[?], offset: ?>>
  } else {
    %subview_0 = memref.subview %arg1[%arg2] [%arg3] [1] : memref<17xf32> to memref<?xf32, strided<[1], offset: ?>>
    %alloc = memref.alloc(%arg3) {alignment = 64 : i64} : memref<?xf32>
    hivm.hir.load ins(%subview_0 : memref<?xf32, strided<[1], offset: ?>>) outs(%alloc : memref<?xf32>) pad_mode = <PadValue> pad_value = %cst : f32
    %cast = memref.cast %alloc : memref<?xf32> to memref<?xf32, strided<[?], offset: ?>>
    scf.yield %cast : memref<?xf32, strided<[?], offset: ?>>
  }
  hivm.hir.store ins(%1 : memref<?xf32, strided<[?], offset: ?>>) outs(%subview : memref<?xf32, strided<[1], offset: ?>>) atomic = <none>
  return
}

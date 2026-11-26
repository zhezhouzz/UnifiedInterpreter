module {
  func.func @issue316_vexp(%arg0: memref<?xf16>, %arg1: memref<1024xf16>, %arg2: index) attributes {hacc.function_kind = #hacc.function_kind<DEVICE>} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %c1024 = arith.constant 1024 : index
    %alloc = memref.alloc() : memref<1024xf16>
    %alloc_0 = memref.alloc() : memref<1024xf16>
    scf.for %arg3 = %c0 to %arg2 step %c1 {
      %0 = arith.remui %arg3, %c2 : index
      %1 = arith.cmpi eq, %0, %c0 : index
      %2 = arith.select %1, %alloc, %alloc_0 : memref<1024xf16>
      %3 = arith.muli %arg3, %c1024 : index
      %subview = memref.subview %arg0[%3] [1024] [1] : memref<?xf16> to memref<1024xf16, strided<[1], offset: ?>>
      linalg.copy ins(%subview : memref<1024xf16, strided<[1], offset: ?>>) outs(%2 : memref<1024xf16>)
      hfusion.barrier
      linalg.elemwise_unary {fun = #linalg.unary_fn<exp>} ins(%2 : memref<1024xf16>) outs(%arg1 : memref<1024xf16>)
    }
    return
  }
}


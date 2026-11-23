#map = affine_map<()[s0, s1] -> (s0 - s1)>
module {
  func.func private @write(memref<?xf32>)
  func.func private @read(memref<?xf32>)
  func.func @return_partial_tile(%arg0: memref<?xf32>, %arg1: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    scf.for %arg2 = %c0 to %arg1 step %c1 {
      %0 = scope.scope : () -> memref<?xf32> {
        %1 = affine.apply #map()[%arg1, %arg2]
        %subview = memref.subview %arg0[0] [%1] [1] : memref<?xf32> to memref<?xf32>
        func.call @write(%subview) : (memref<?xf32>) -> ()
        scope.return %subview : memref<?xf32>
      } {hivm.max_preload_num = 2 : i32, hivm.preload_num = 1 : i32, no_inline}
      scope.scope : () -> () {
        func.call @read(%0) : (memref<?xf32>) -> ()
        scope.return
      } {hivm.max_preload_num = 2 : i32, hivm.preload_num = 0 : i32, no_inline}
    }
    return
  }
}


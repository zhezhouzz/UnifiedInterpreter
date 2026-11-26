func.func private @indirect_atomic_add(%gm: memref<16xf32>, %indices: memref<16xi64>,
    %increments: memref<16xf32>, %mask: memref<16xi8>, %previous: memref<16xf32>) {
  %zero = arith.constant 0 : index
  %end = arith.constant 16 : index
  %one = arith.constant 1 : index
  %off = arith.constant 0 : i8
  scf.for %lane = %zero to %end step %one {
    %predicate = memref.load %mask[%lane] : memref<16xi8>
    %enabled = arith.cmpi ne, %predicate, %off : i8
    scf.if %enabled {
      %offset = memref.load %indices[%lane] : memref<16xi64>
      %idx = arith.index_cast %offset : i64 to index
      %increment = memref.load %increments[%lane] : memref<16xf32>
      %old = memref.atomic_rmw addf %increment, %gm[%idx] : (f32, memref<16xf32>) -> f32
      memref.store %old, %previous[%lane] : memref<16xf32>
    }
  }
  return
}

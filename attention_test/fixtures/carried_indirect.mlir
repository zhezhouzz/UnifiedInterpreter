func.func @carried_indirect(%src: memref<?xi64>, %out: memref<?xi64>, %stride: index, %count: index) {
  %before = arith.constant -1 : index
  %zero = arith.constant 0 : index
  %one = arith.constant 1 : index
  %zero_i64 = arith.constant 0 : i64
  %view = memref.reinterpret_cast %src to offset: [%zero], sizes: [2], strides: [%stride]
    : memref<?xi64> to memref<2xi64, strided<[?], offset: ?>>
  %delta = memref.load %view[%one] : memref<2xi64, strided<[?], offset: ?>>
  %empty = tensor.empty() : tensor<2xi64>
  %mask_buf = tensor.empty() : tensor<2xi1>
  %offsets = hfusion.arange offset[%before] strides[%one] outs(%empty : tensor<2xi64>) -> tensor<2xi64>
  %mask = hfusion.compare {compare_fn = #hfusion.compare_fn<vge>}
    ins(%offsets, %zero_i64 : tensor<2xi64>, i64) outs(%mask_buf : tensor<2xi1>) -> tensor<2xi1>
  %fallback = linalg.fill ins(%zero_i64 : i64) outs(%empty : tensor<2xi64>) -> tensor<2xi64>
  %gathered = hfusion.indirect_load
    ins(%view : memref<2xi64, strided<[?], offset: ?>>, %offsets : tensor<2xi64>,
        %mask : tensor<2xi1>, %fallback : tensor<2xi64>)
    outs(%empty : tensor<2xi64>) -> tensor<2xi64>
  %start = tensor.extract %gathered[%one] : tensor<2xi64>
  %carry:2 = scf.for %iv = %zero to %count step %one iter_args(%previous = %start, %current = %start) -> (i64, i64) {
    %next = arith.addi %current, %delta : i64
    scf.yield %current, %next : i64, i64
  }
  %partial = tensor.insert %carry#0 into %empty[%zero] : tensor<2xi64>
  %ready = tensor.insert %carry#1 into %partial[%one] : tensor<2xi64>
  hfusion.indirect_store ins(%ready : tensor<2xi64>, %offsets : tensor<2xi64>, %mask : tensor<2xi1>)
    outs(%out : memref<?xi64>)
  return
}

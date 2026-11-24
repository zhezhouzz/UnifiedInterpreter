// 函数 A：带步长 stride=8192（本 bug 场景）
func.func @store_strided(%arg0: memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>) {
  %cst  = arith.constant dense<0xFF800000> : vector<64xf32>   // 4 个 -inf 在前 4 lane
  %mask = vector.constant_mask [4] : vector<64xi1>            // 仅前 4 lane 有效
  vector.transfer_write %cst, %arg0[...], %mask { in_bounds = [true] }
      : vector<64xf32>, memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
  return
}

// 函数 B：单位步长 stride=1（对照）—— 其余与 A 完全相同
func.func @store_unit(%arg0: memref<4xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>) { ... }

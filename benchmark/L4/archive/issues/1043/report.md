标题
[Bug]: pairing 失败时仍执行 mask 下沉和 vbrc 前移，存在未知性能回退风险

环境信息
- 操作系统：<请填写>
- 昇腾硬件信息：Ascend910_95（Ascend950PR_9579）
- CANN 软件版本：<请填写>
- 安装的对应软件版本：<请填写 bishengir / AscendNPU-IR 版本或 commit>
- 相关 Pass：bishengir-opt -hivm-optimize-row-loads（OptimizeRowLoads）

问题描述

现象
OptimizeRowLoads 中的两项优化——vbrc 前移（fill hoisting）和按行 mask 下沉
（mask sinking）——原先与相邻行 pairing 是相互独立的。即使 pairing 条件不满足
（例如 tripCount < 2，或 verifyRowTransfer 因 source 不是固定 GM 的
memref.reinterpret_cast、目的地不是 dense tile 等原因失败），pass 仍会消除
arith.select、把 fallback 的 hivm.hir.vbrc 提到循环外，并给单行 load 加上
predicate。

这个行为本身在语义上正确，但这部分循环并没有获得 pairing 带来的收益，其实际
收益与代价缺乏验证，可能引入未知的性能劣化（例如额外的 predicate 计算、未被批量
化的 GM 访问、以及尚未评估的发射形态），目前也尚未定位到具体原因。

最小可复现示例
取一个 masked 行加载循环，source 使用 memref.subview（不可配对），配合行 mask 和
arith.select：

    %src = memref.subview %base[%offset, 0] [1, 16] [1, 1]
      : memref<?x16xf16> to memref<1x16xf16, strided<[16, 1], offset: ?>>
    // ... hivm.hir.load 写入 %dst 的一行
    %selected = arith.select %full_mask, %loaded, %fallback
      : tensor<4x16xi1>, tensor<4x16xf16>

运行：

    bishengir-opt repro.mlir -hivm-optimize-row-loads

实际结果：循环外出现 hivm.hir.vbrc，循环内出现 scf.if 且 arith.select 被消除
（即单独执行了 mask 下沉 + vbrc 前移）。
期望结果：pairing 不成立时循环保持原样，仅保留原有的 load 和 select。

影响范围
bishengir/lib/Dialect/HIVM/Transforms/OptimizeRowLoads.cpp 的 optimizeRowGather；
单行 mask 下沉与 fill hoisting 路径。

当前处理
为避免不可控的性能回退，先收紧实现：将 pairing 判定提前到 mask 匹配之前，pairing
失败（tripCount < 2 或 verifyRowTransfer 失败）时直接不做任何剩余优化，mask 下沉
和 vbrc 前移只随配对发射路径执行；同时移除了不再可达的
RowEmitter::sinkMask。相关 lit 测试已同步调整（OptimizeRowLoads/mask.mlir、
mask-casts.mlir、recognition.mlir）。

后续计划
这是临时规避方案，会损失一部分本可合法下沉 mask 的场景。待分析清楚这部分独立优化
引入性能劣化的具体原因后，会重构该实现，让 mask 下沉和 fill 前移在 pairing 之外
也能安全、可验证地生效。

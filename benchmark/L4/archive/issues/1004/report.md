## 背景

fail20 family 的根因是 TreeReduceV2 对 RA 形态（约简在第一轴）的 addf-reduce 存在掩码丢失问题，且 reduce-only kernel 被强推 TreeReduceV2。RA 形态需要 AV2 内的专用物化路线，不再依赖 TreeReduceV2 路由与强制开关。

## 变更范围

- 新增 TreeReduce.h/.cpp：emitTreeReduceRA（已 tile 的 RA reduce 原地改写 masked 向量树）、emitTreeReduceRAPlan（外层 batch tile → 最内维 VL 列切分 → structured.tree_reduce_ra）、isTreeReduceRACandidate、radix-16 fold schedule（结合序与 legacy computeReductionFoldPlan 等价）
- 新 transform op structured.tree_reduce_ra
- AutoVectorizeV2 路由梯子：叶子/producer 双路径接入物化路线；兄弟融合参与条件放宽为节点全 RA 候选（1-trip 经 apply_cse 满足解释器 SSA 等值要求，融合后 eliminate-single-iteration 干净内联）
- 形状契约校验：非约简/非最内维 slice extent 必须 1（违约 definite failure，防静默错值）
- compile-main：移除 reduce-only 强推 TreeReduceV2 的死代码

## 验证口径

- lit 345 例仅剩 2 个既有失败（基线对照）；AutoVectorizeVerifier 零失败
- 形状契约负路径：强造多行 tile → definite failure（静默错值通路堵死）
- single-trip 兄弟融合形态翻转 + downstream 消除无损（addf 32→32）
- E2E 数值窗口与 RA70 路由表重采随合入后排期

## 闭环范围

PR5069 检视意见（P1/P2/P3 全部项 + license 头惯例）已逐条闭环，见 PR 描述"检视意见闭环"节。
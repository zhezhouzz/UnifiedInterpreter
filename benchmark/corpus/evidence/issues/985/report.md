[Feature]: A6 NDDMA transpose 扩展

## 背景
当前 A6（Ascend960 / dav-920r1）上，`hivm-fuse-transpose-into-load` 只融合最后两轴交换；
内轴交换（尾轴不动）和尾轴拆分（尾轴搬到更外层）仍保留独立的 linalg.transpose。

## 目标
A6 上把这两类转置也融合进 `hivm.hir.load`，由 DMA 一步搬出转置结果。

## 范围
- host：置换分类（尾轴交换 / 内轴交换 / 尾轴拆分）、A6 代际门控、尾轴拆分前置检查；
- 模板：A6 下行连续且 UB 行/平面 stride 32B 对齐 → block DMA，否则 NDDMA；
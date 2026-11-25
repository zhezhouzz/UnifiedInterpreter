# #1047 的双向通知

报告描述 3D arange 的 scalar fallback。在一块 UB 上，先让 V 的前序访问完成，标量循环写入，然后再允许 V 消费。修复涉及的模板 C++ 和 MR head 保存在本库。[报告](report.md) · [修复改动](../../repairs/issue-1047-mr-5282/change.patch)

可执行的单 lane 对照见 [L2 标量回退用例](../../../../L2/scalar-fallback)。

# #1047 的双向通知

报告描述 3D arange 的 scalar fallback。在一块 UB 上，先让 V 的前序访问完成，标量循环写入，然后再允许 V 消费。修复涉及的模板 C++ 和 MR head 保存在本库。[报告](report.md) · [修复改动](../../repairs/issue-1047-mr-5282/change.patch)

`fixed.expected.core` 是 LLM 编写的单地址协议预期。为聚焦方向，各取一次向量读、标量写和向量消费，两个方向复用逻辑编号 0。固定补丁在两个方向都使用 LIB_EVENT_ID0；这里把它重命名为逻辑事件 0。该 MR 的已保存改动只有模板文件，没有把报告中提到的 host 测试算作同提交单测。[core](fixed.expected.core)

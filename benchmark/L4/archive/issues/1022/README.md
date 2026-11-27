# #1022 的地址见证

报告者的原网络案例给出 UB 偏移 34816 和修复后的 51200。此处使用报告附件中更小的 `loop-carried/initialized` 单测。旧输出第一轮把 incoming 和 newly filled tile 都放在 byte 0，修复输出分别放在 256 和 0。两份完整输出从同一份 ZIP 提取，属于报告者的证据。[报告](report.md) · [原证据包](evidence.zip) · [修复提交和测试](reported-fix/source.json)

完整函数见 [L2 附件回归](../../../../L2/issue-1022-attachment)。

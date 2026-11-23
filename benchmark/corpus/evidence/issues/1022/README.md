# #1022 的地址见证

报告者的原网络案例给出 UB 偏移 34816 和修复后的 51200。此处使用报告附件中更小的 `loop-carried/initialized` 单测。旧输出第一轮把 incoming 和 newly filled tile 都放在 byte 0，修复输出分别放在 256 和 0。两份完整输出从同一份 ZIP 提取，属于报告者的证据。[报告](report.md) · [原证据包](evidence.zip) · [修复提交和测试](reported-fix/source.json)

两个 `*.expected.core` 是手写的第一轮、单元素观察。选一条每次操作完成后再发起下一条的执行，先以 5 标记 incoming，再以 2 标记新 tile，最后观察 vadd 的第一个操作数。旧版读到被替换的值 2，修复版保有 5。这里使用标签代表浮点值，省略加法结果、复制回环和第二轮；Rocq 检查的是 AST。附件的 legacy/fixed compiler 及训练 kernel 本轮没有在本机执行。[旧 MLIR](legacy.mlir) · [旧 core](legacy.expected.core) · [修复 MLIR](fixed.mlir) · [修复 core](fixed.expected.core)

## 背景

A6（Ascend960）具备 NDDMA 广播搬运能力，需要完善编译器支持，减少 GM 搬运后的独立广播操作。

## 目标

在 A6 上将符合条件的广播融合到 `hivm.hir.load`，由搬运指令直接生成广播结果，保持 A3/A5 行为不变。

## 范围

- IR 与模板：扩展 LoadOp 广播属性及 A6 NDDMA 广播搬运支持。
- 优化：支持同函数内、静态输出 tile 的纯广播融合，并适配 Flatten、InlineLoadCopy；不满足条件时保留原路径。

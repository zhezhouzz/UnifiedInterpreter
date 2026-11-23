---
name: hivm-core-benchmark
description: 使用 UnifiedInterpreter 的 AscendNPU-IR benchmark 重放编译、检验 HIVM 到 core 的翻译、为 trace checker 选择正负对照，或把真实 issue 与修复测试加入语料。
---

# 使用 HIVM → core benchmark

先确定要检验什么。同一个例子可以回答“编译器发出了哪些同步指令”“elaborator 保留了哪些事件”“该程序允许消费者提前读吗”。这三个问题各有自己的输入和判据。

| 开发任务 | 从哪里开始 | 看什么结果 |
|---|---|---|
| 接入新的 interpreter 或 trace checker | 直接使用手写例子的 Rocq `shared_program`。[正常例 Fixture.v](corpus/handwritten/ready-and-drain/Fixture.v) | 选择 `observe_ub_zero` 检查“消费者发起读之前，生产者的写是否已经完成”。再对[缺 wait 的同一例子](corpus/handwritten/ready-without-wait/Fixture.v)寻找最短 witness。 |
| 扩充 parser / elaborator | 在[逐例索引](corpus/CATALOG.md)选有诊断的函数，读取其 `hivm.mlir`、`case.json` 和 `diagnostics.json` | 核对不支持的 op、函数和位置。新规则通过后，比较实际 AST 和预期，并保留相邻的不支持情形作回归。 |
| 验证编译器 pass 或修复 | 从 [GitCode issue 与修复索引](corpus/evidence/README.md)追到提交、原测试和 RUN 参数 | 对固定输入、目标芯片和观察点比较优化前后。可从 [#981 原始 MLIR](corpus/evidence/issues/981/quoted/fragment-1.mlir) 入手，观察重叠 subview 内外各一个 lane。 |
| 测核内 flag 匹配 | 取[同键连续两次 set](corpus/handwritten/overlapping-sets/case.json)和[反方向同号事件](corpus/handwritten/independent-directions/case.json) | 按执行流和有向 `(src_pipe, dst_pipe, event_id)` 投影**完成事件**。同键的 S S W W 在第二个 S 违反 A4；另一方向有独立的键。 |

## 跑一个例子

以下命令从 UnifiedInterpreter worktree 根目录执行。本机默认使用同级 AscendNPU-IR 的 Ninja build；其他位置可提前设置 `ASCEND_BUILD`。reader 复用该 build 的 dialect 注册和链接参数。仅消费已存的 core 或 Rocq fixture 时，可以直接打开相应文件。

```sh
cd benchmark/corpus
build="${ASCEND_BUILD:-$HOME/GIT/Distributed/AscendNPU-IR/build}"
scratch=$(mktemp -d)
python3 tools/build_reader.py "$build" "$scratch/reader"
python3 tools/elaborate.py handwritten/ready-and-drain/hivm.mlir \
  --reader "$scratch/reader" --function ready_and_drain --watch-ub-byte 0
python3 tools/demo.py --bin "$build/bin" --reader "$scratch/reader"
```

在生成的 core 中找到对 `UB_BYTE_0` 的写、MTE2 → V 的 set/wait 和 V 上的读。正常例中同步把写完成排在读发起之前。缺 wait 时，demo 会给出三个事件的见证：load 发起、set 发起、V 发起。比较一次运行是否与已存结果一致，可查[验证输出](corpus/verification.txt)。

全量回归使用 `tools/check.py`。它重编译源 MLIR、逐字节比较 HIVM、重跑整函数与切片翻译及诊断，并用固定上游语法类型检查 Rocq fixture。所需 Rocq 版本、upstream checkout 和完整命令见[运行与接入](corpus/README.md#运行与接入)。

## 选择下游输入并解释结果

- **检查编译器实际输出**时，先读 `case.json` 的 `argv`、阶段和目标函数。文件名为 `hivm.mlir` 的回归产物可能仍在 tensor/CV 中间层；验证分核后同步时，要确认 AIC/AIV 入口和同步插入点。
- **检查自动翻译**时，按范围选 `actual.core` 或 `slice.actual.core`。`expected.core` 的来源与范围在 `case.json` 的 `expectation` 中。某些 expected 是 LLM 辅助生成的投影；教程的 `expected.kernel.core` 还可能引入逻辑围栏。报告对拍结果时写明比较了哪个范围。
- **检查轨迹**时，区分“合法执行到达坏状态”和“候选轨迹违反公理”。前者给出观察地址与最短 witness，后者给出首个被禁止的完成事件。从基本块中间开始的切片，还需说明入口处的内存、未消费通知及在途操作。Rocq 类型检查只确认程序能接入上游 AST。
- **检查跨核例子**时，从同一次编译的两端函数和 subblock guard 确定参与者。1:2 的一轮通知要分别记录两个 Vector 的 wait，同一收件人等待两次不能代替另一方。硬件配置与 kernel 活动流的区别见[分代参数](profiles/README.md)。

## 加入新例子

从[已有 case.json](corpus/handwritten/ready-and-drain/case.json)沿用字段。在对应来源组保存可重放的 `source.mlir`、固定编译器实际生成的 `hivm.mlir` 和带明确观察范围的 `expected.core`。记下来源提交或 issue、pass 参数、选择的函数、预期性质及其依据。运行 elaborator 后保存实际输出或诊断，并同步 `Fixture.v` 和[逐例索引](corpus/CATALOG.md)。

只有报告正文或附件时，先放入[证据索引](corpus/evidence/README.md)，分别注明报告者的运行结果与本地复现进度。做修复对照时保留相同输入，记录旧版和修复版的 SHA，以及第一个改变的 IR 或观察值。新增主表输入后运行全量回归。

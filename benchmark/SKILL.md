---
name: hivm-core-benchmark
description: 使用 UnifiedInterpreter 的 AscendNPU-IR benchmark 重放编译、检验 HIVM 到 core 的翻译、为 trace checker 或操作语义引擎选择正负对照，或把真实同步 issue 与修复测试加入语料。
---

# 使用 HIVM → core benchmark

总览与分层规范（L1–L4）见 [README.md](README.md)，精选同步/并发靶场见 [SYNC_ISSUES.md](SYNC_ISSUES.md)，语料库运行细节见 [corpus/README.md](corpus/README.md)。

先确定要检验什么。同一个例子可以回答“编译器发出了哪些同步指令”“elaborator 保留了哪些事件”“该程序允许消费者提前读吗”。这三个问题各有自己的输入和判据。

| 开发任务 | 从哪里开始 | 看什么结果 |
|---|---|---|
| 接入新的 interpreter 或 trace checker | 直接使用 L1 手写例子的 `.core` 或 Rocq `shared_program`：[正常例](corpus/handwritten/ready-and-drain/Fixture.v) vs [缺 wait 例](corpus/handwritten/ready-without-wait/Fixture.v) | 选择 `observe_ub_zero` 检查“消费者发起读之前，生产者的写是否已经完成”；对缺 wait 例寻找 3 步最短 witness |
| 扩充 parser / elaborator | 查看 [README.md §3](README.md#3-目标语义对齐与实测覆盖缺口) 的阻塞 Top 项，或在 [逐例索引](corpus/CATALOG.md) 选有诊断的函数读取 `hivm.mlir` 与 `diagnostics.json` | 优先补齐 `memref.alloc`、`pipe_barrier`、`scf.for` 与 DPS 算子；新规则通过后比较整函数 AST 与预期，保留回归 |
| 验证真实同步 issue 与编译器修复 | 从 [精选同步靶场](SYNC_ISSUES.md) 按优先级（P0/P1）选例，追到提交、原测试与 RUN 参数 | 优先构造同一输入的 `buggy` vs `fixed`（或 sync-on vs sync-off）成对对照，记录首个差异点与观察值 |
| 测核内 flag 匹配协议 | 取 [同键连续两次 set](corpus/handwritten/overlapping-sets/case.json) 和 [反方向同号事件](corpus/handwritten/independent-directions/case.json) | 按执行流和有向 `(src_pipe, dst_pipe, event_id)` 投影完成事件：同键 `S S W W` 在第 2 个 `S` 违反 A4；反方向键独立 |

## 跑一个例子

以下命令从 UnifiedInterpreter 根目录执行。本机默认使用同级 AscendNPU-IR 的 Ninja build；其他位置可提前设置 `ASCEND_BUILD`。

```sh
cd benchmark/corpus
build="${ASCEND_BUILD:-$HOME/GIT/Distributed/AscendNPU-IR/build}"
scratch=$(mktemp -d)
python3 tools/build_reader.py "$build" "$scratch/reader"
python3 tools/elaborate.py handwritten/ready-and-drain/hivm.mlir \
  --reader "$scratch/reader" --function ready_and_drain --watch-ub-byte 0
python3 tools/demo.py --bin "$build/bin" --reader "$scratch/reader"
```

在生成的 core 中找到对 `UB_BYTE_0` 的写、MTE2 → V 的 set/wait 和 V 上的读。正常例中同步把写完成排在读发起之前；缺 wait 时，demo 给出 3 步最短见证：`load.start → set.start → V.start`。全量回归运行 `tools/check.py`，基线见 [verification.txt](corpus/verification.txt)。

## 报告结果时的硬性口径

- **严格区分四类结果**：可重编译、可整函数翻译、通过 AST/类型检查、真正证明安全或检出反例，四者不可混用。
- **禁止把切片冒充整函数**：报告翻译率时必须分开写明整函数（`actual.core`）与基本块切片（`slice.actual.core`），切片结果须注明入口状态前提。
- **区分同步主线与延展项**：同步/并发统计仅计入 [SYNC_ISSUES.md](SYNC_ISSUES.md) §1–§4 中的案例；`#981`、`#995` 等内存别名误编译须标注为“内存模型延展展示”。
- **检查跨核例子时保留参与者身份**：从同一次编译的 AIC/AIV 函数和 sub-block guard 确定活动流（`core_ratio`），1:2 的一轮广播须分别记录两个 AIV 的 wait；硬件参数见 [profiles/README.md](profiles/README.md)。

## 加入新例子

遵循 [README.md §4](README.md#4-新一轮-benchmark-重建与入库规范验收标准) 的目录契约：保存可重放 `source.mlir`、固定编译器产出的 `hivm.mlir`（优先成对保存 `buggy`/`fixed`）、整函数 `program.core` 或诊断 `diagnostics.json`，在 `case.json` 记录 `tier`、缺陷类别、芯片配置、`core_ratio` 与预期判据，并同步更新 [SYNC_ISSUES.md](SYNC_ISSUES.md) 与 [CATALOG.md](corpus/CATALOG.md)。

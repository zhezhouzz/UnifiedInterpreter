# AscendNPU-IR HIVM 同步与并发语义 Benchmark

本目录是 **UnifiedInterpreter** 面向华为 AscendNPU-IR 的 **HIVM 同步与并发语义验证 Benchmark 总入口**。核心目标有两个：

1. **向华为展示工具的实际价值**：对真实的 post-sync HIVM MLIR，自动检测同步缺失、非法同步协议、多缓冲槽位覆盖、跨核交接缺陷与死锁，并给出最短可执行反例（witness）或数值差异。
2. **反推核心语言（CoreLang）与前端翻译演进**：用真实编译器产物的实测诊断数据，明确核心语言必须覆盖的同步原语、内存模型与控制流优先级。

> **快速导航**：[精选同步 Issue 与修复靶场](SYNC_ISSUES.md) · [芯片配置与分核参数](profiles/README.md) · [语料库运行与工具手册](corpus/README.md) · [212 例全量逐例索引](corpus/CATALOG.md) · [开发者 Skill](SKILL.md)

---

## 1. Benchmark 分层体系（L1 – L4）

为避免“批量抓来的原始素材”掩盖“给华为看的核心能力”，所有用例按 **四层金字塔** 组织：

| 层级 | 名称与定位 | 规模与内容 | 给谁看 / 用来干什么 |
|---|---|---|---|
| **L1** | **核心演示集（Showcase）** | 精选 6 组正负对照与真实回归（见 §2） | **对外演示与组会 3 分钟 Demo**：展示工具从真实 HIVM 到最短反例 witness 的完整闭环 |
| **L2** | **同步与并发真实靶场（Target Bug Suite）** | 从 72 个原始 issue 与 39 个 MR 中精选出的 **18 个纯同步/并发 Issue + 6 个独立修复 MR**（见 [SYNC_ISSUES.md](SYNC_ISSUES.md)） | **华为痛点对齐与能力路线图**：覆盖核内 flag、pipe_barrier、多缓冲、CV 流水与 MIX 1:2 跨核死锁 |
| **L3** | **自动化回归底座（Regression Corpus）** | 16 个来源组、**212 个去重可重放 MLIR 输入** + 原生 BiShengIR Dialect Parser + 诊断基线（见 [corpus/CATALOG.md](corpus/CATALOG.md)） | **持续回归与覆盖率度量**：统计真实 HIVM 中哪些结构已可整函数翻译、哪些仍是语义/前端缺口 |
| **L4** | **原始证据归档（Raw Archive）** | 72 份 GitCode issue 原文、39 个修复 patch、8 份报告者 ZIP、Triton/分布式教程源码（见 [corpus/evidence/README.md](corpus/evidence/README.md)） | **溯源与后续取材池**：含约 50 个非同步类 issue，不计入同步验证通过率 |

---

## 2. L1 核心演示集（面向华为的 3 分钟闭环）

| 演示主题 | 入口材料 | 检验性质与当前结果 |
|---|---|---|
| **1. 核内缺 `wait` 提前读** | [正常版 HIVM](corpus/handwritten/ready-and-drain/hivm.mlir) · [正常 core](corpus/handwritten/ready-and-drain/watch-ub0.core) vs [缺 wait core](corpus/handwritten/ready-without-wait/watch-ub0.core) | 正常版穷尽 21 个状态无提前读；删去 `wait` 后给出 **3 步最短反例**：`load.start → set.start → V.start`（load 尚未完成即读取 UB） |
| **2. 同步协议合法性（A4）** | [重复 set](corpus/handwritten/overlapping-sets/expected.core) vs [反方向同号事件](corpus/handwritten/independent-directions/expected.core) · [错误消费 pipe](corpus/handwritten/wrong-consumer-pipe/case.json) | 同键 `S₁ S₂ W₁ W₂` 在第 2 个完成事件违反 A4；反方向 `(V, MTE2, 0)` 与 `(MTE2, V, 0)` 键独立通过 |
| **3. 真实 Triton 算子开关同步差分** | [masked add 源码](triton/kernels.py) · [910B1 开 sync](triton/910B1-on.mlir) vs [关 sync](triton/910B1-off.mlir) · [950PR 跨芯片](triton/950-on.mlir) | 同一 HFusion 输入只切换 `disable-hivm-auto-inject-sync`，静态 set/wait/barrier 为 `4/4/1` vs `0/0/0`；910B1 与 950PR 同捕点结构对照可重放 |
| **4. 混合核（MIX）AIC ↔ AIV 交接** | [kern3 三函数](official/mix.mlir) → [跨核+核内 sync](official/mix-both.mlir) · [opsem `_attn_fwd` 建模](../docs/core-language-opsem.tex) | 覆盖 `fixpipe` 写 workspace → `sync_block_set[FIX, S]` → `sync_block_wait[FIX, S]` → `load` 的 1:1 / 1:2 跨核交接 |
| **5. 真实同步回归：#920 & #316** | [#920 反馈环回归](issue920/920.mlir)（[!5025](corpus/evidence/repairs/issue-920-mr-5025/repair.json)）· [#316 双缓冲正文](corpus/evidence/issues/316/report.md) | #920 在本机固定编译器上复现上游禁止的 2 处 feedback loop skew；#316 为多缓冲 `bufA/bufB` 轮换标杆 |
| **6. 延展展示（非同步类）：#981 内存别名误编译** | [#981 原始 MLIR](corpus/evidence/issues/981/quoted/fragment-1.mlir) → [本机 `canonicalize-ext` 输出](corpus/evidence/issues/981/local-canonicalize.mlir) | **非同步类加分项**：展示引入内存/subview 模型后，可直接定位真实编译器 bug——输入 `7` 时，被覆盖 subview 内的 lane `0, 63` 由 `0` 错变为 `7`，边界外 lane `64, 127` 保持 `7` |

一键复现 L1 演示（本机固定工具链 `bishengir-opt 1.2.0`，源提交 `fbdf863a8c8c268e5cfea0d5f1d921e227267fd5`）：

```sh
# 1) 重放第一批 Triton 差分 / MIX / #920 实验
export BISHENG_BIN=~/GIT/Distributed/AscendNPU-IR/build/bin
python3 replay.py --bin "$BISHENG_BIN" --output "$(mktemp -d)"

# 2) 构建原生 MLIR reader 并运行三分钟同步与 #981 演示
cd corpus
scratch=$(mktemp -d)
python3 tools/build_reader.py ~/GIT/Distributed/AscendNPU-IR/build "$scratch/reader"
python3 tools/demo.py --bin "$BISHENG_BIN" --reader "$scratch/reader"
```

---

## 3. 目标语义对齐与实测覆盖缺口

本仓库当前有两条并行推进的核心语言规范，benchmark 实测数据直接决定了二者如何整合：

- **操作语义规范**（[docs/core-language-opsem.tex](../docs/core-language-opsem.tex)）：直接对齐真实 Ascend AI Core / HIVM——单 AI Core 多流（$\kappa_{0:1}, \kappa_{1:0}, \kappa_{1:1}, \kappa_{1:2}$）、单流多异步队列 $Q_s(p)$、Destination-Passing Style（`issue[p](f, views)` + `foot` + 真实共享内存 $\mu$）、全部 5 种 HIVM 同步原语（`setflag`/`waitflag`/`pipebarrier`/`syncblockset`/`syncblockwait` 含 `S` 标量阻塞与 1:2 正向广播）、动态步长 `for`。**当前待补**：显式 `mem alloc` 原语。
- **公理化 Trace 规范**（上游 `core_language` 分支 `d331719`）：`run { C1 || ... || Cn }` 并发分支、静态展开有限循环、显式 `alloc()`、异步 SSA 绑定与 A1–A5 + `Aval` 公理，已有 Rocq 形式化与 #316 地址轮换定理证明。**当前缺口**：无 `pipebarrier`、无 `syncblock` 与 1:2 广播、A2 中 `waitflag` 阻塞整条分支（与单流多队列硬件不同）、`read_end` 尚无共享内存 read-from 约束。

### 当前语料库实测基线（诚实口径，[verification.txt](corpus/verification.txt)）

> **注意**：当前 `corpus/` 下的自动翻译器 `tools/elaborate.py` 与 `Fixture.v` 是**过渡版本**——它面向的是上游 `Axiomatic.Syntax` 的直线单流子集，尚未接入 `opsem.tex` 的 `pipebarrier`、跨核 `syncblock`、`for` 与 DPS 内存模型。

| 验证项 | 当前实测结果 | 准确含义 |
|---|---:|---|
| `source.mlir` 重编译比对 `hivm.mlir` | **212 / 212** 逐字节一致 | 编译产物完全可重放 |
| **整函数**自动翻译（`actual.core`） | **17 / 212** 成功（14 手写 + 3 真实 MLIR） | 真实 MLIR 整函数覆盖率低，受下方 Top 缺失特性阻塞 |
| **显式基本块切片**翻译（`slice.actual.core`） | **197 / 212** 成功（与 expected AST 197/197 一致） | 仅验证基本块内直线片段，**不能等同于整函数验证** |
| Rocq `Fixture.v` 检查 | **215** 个模块通过 `d331719` 类型检查 | 仅验证能构造上游 AST，**不表示已证明程序安全** |

### 导致真实 HIVM 整函数翻译失败的 Top 阻塞项（212 例统计）

| 阻塞 MLIR 操作 / 结构 | 出现频次 | 根因归属 | 解决路径 |
|---|---:|---|---|
| `memref.alloc` / `memref.alloca` | **205 + 18** | `opsem.tex` 尚缺显式 `alloc`；过渡版 elaborator 未接入 | 在 `opsem.tex` 新增 `alloc` 原语并接入前端 |
| `hivm.hir.pipe_barrier` | **194** | 过渡版上游语法不含 `pipe_barrier`（**`opsem.tex` 已有**） | 前端直接下放到 `opsem.tex` 的 `pipebarrier[p]` |
| `hivm.hir.vcast` / `nd2nz` / `mmadL1` / `fixpipe` | **95 / 30 / 22 / 21** | 前端算子映射白名单未补全（**`opsem.tex` DPS 原生支持**） | 按 `Operator_d` 补齐抽象算子与读写足迹 `foot` |
| `scf.for` / `scf.if` | **65 / 14** | 过渡版 elaborator 仅支持直线片段（**`opsem.tex` 已有**） | 对齐统一 CoreLang 后接入控制流翻译 |
| 跨核 `sync_block_set/wait` 与 MIX 分核 | 覆盖 15 个 MIX 用例 | 过渡版上游语法仅支持核内 `(SW)*`（**`opsem.tex` 已有**） | 保留 AIC/AIV 双流、活动 `core_ratio` 与 1:2 广播配置 |

---

## 4. 新一轮 Benchmark 重建与入库规范（验收标准）

后续对本目录进行推倒重建或扩充时，**统一遵循以下硬性规范**：

1. **主题聚焦**：同步/并发主榜单只收录与 **管道同步、屏障、多缓冲生命周期、跨核同步、死锁/竞争** 相关的用例；与同步无关的 issue（精度、布局、FP8、debug info 等）统一放归档区，不计入主统计。
2. **优先成对对照（Buggy vs Fixed / Sync-On vs Sync-Off）**：
   - 每个 L1/L2 核心用例优先提供成对可重放 IR：要么是同一源输入的 `buggy` vs `fixed`（或关 sync vs 开 sync），要么是明确标注的合法/非法变异对。
3. **统一的单例目录契约（每个用例目录）**：
   - `case.json`：必含 `id`、`tier`（`L1`/`L2`/`L3`）、`category`（同步缺陷类别）、`source_ref`（仓库/commit/issue/MR）、`chip_profile`（如 `Ascend910B1`/`Ascend950PR_9579`）、`core_ratio`（`0:1`/`1:0`/`1:1`/`1:2`）、`compile_argv`、`entry_functions`（AIC/AIV 列表）、`expected_verdict`（`safe` / `race` / `deadlock` / `protocol_violation` / `wrong_value`）与 `oracle_note`。
   - `source.mlir`（以及前端源码如 `.py`，若有）与固定编译器实际生成的 `hivm.mlir`（若为成对对照，保存 `buggy.hivm.mlir` 与 `fixed.hivm.mlir`）。
   - `program.core`（由前端自动生成的整函数 CoreLang，若暂不可整函数翻译，明确记录 `diagnostics.json`，**禁止将手切几行的切片伪装成整函数成功**）。
4. **严格区分四类结论**：
   - **可重编译**（`bishengir-opt` 产物字节一致）
   - **可整函数翻译**（MLIR → CoreLang 无诊断报错）
   - **可类型/良构检查**（通过静态类型或 Rocq AST 检查）
   - **已验证安全性 / 检出反例**（真正给出最短 witness 或穷尽无错证明）

---

## 5. 目录结构一览

```text
benchmark/
├── README.md                  # 本文件：唯一总入口、分层体系、语义缺口与重建规范
├── SYNC_ISSUES.md             # L2 精选表：纯同步/并发 GitCode Issue 与修复 MR 靶场
├── SKILL.md                   # 面向开发者与 Agent 的操作 Skill
├── profiles/                  # Ascend910B1 / Ascend950PR_9579 芯片参数与核配置
├── triton/                    # L1：手写 Triton masked add 的开关同步与跨芯片差分
├── official/                  # L1：官方 MIX kern3 的跨核 + 核内同步产物
├── issue920/                  # L1：#920 CV-pipelining 反馈环回归复现
├── replay.py                  # L1 第一批实验一键重放脚本（对照 actual.txt / toolchain.txt）
├── licenses/                  # AscendNPU-IR 许可证与 NOTICE
└── corpus/                    # L3/L4 自动化语料库、原生 MLIR reader 与过渡版工具链
    ├── README.md              # 语料库技术运行手册（build_reader / elaborate / demo / check）
    ├── CATALOG.md             # 16 组 212 例全量逐例索引
    ├── verification.txt       # 全量自动化校验基线输出
    ├── tools/                 # ir.cpp, build_reader.py, elaborate.py, core_to_rocq.py, demo.py, check.py
    ├── handwritten/           # 14 个手写核内同步正负对照（L1 核心来源）
    ├── <15 other groups>/     # 官方 pass 测试、教程特化、回归测试与 issue 输入
    └── evidence/              # L4 原始归档：72 份 issue、39 个修复 MR patch、8 个 ZIP 证据包
```

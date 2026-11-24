# Derived Core Language Interpreter：实现总结、推导方法与学术贡献分析

> 分支：`feat/derived-interpreter`  
> 设计依据：`docs/core-language-derivation.tex`  
> 核心约束：零侵入 `rocq/CoreLanguage/Axiomatic/`、零 `Admitted`、零额外公理（全部顶层定理均通过 `Print Assumptions` 与 `rocqchk` 独立核检查）。

---

## 1. 总体概览

本工作围绕 Ascend NPU 核心异步流水线语言（`CoreLanguage`），在**不修改公理化规范层 `rocq/CoreLanguage/Axiomatic/` 一行代码**的前提下，完整实现了从声明式公理化 Trace 语义推导可执行 Effect-Handler 解释器的全链路，涵盖：

1. **形式化派生与双向等价证明（Rocq）**：一阶在线前缀自动机、保路径循环重聚焦、高阶 Free Monad 语义效应与分层处理器，以及健全性（Soundness）、完备性（Completeness）与函数式对应（Functional Correspondence）的完整机械化证明。
2. **双目标可执行落地（OCaml）**：
   - **Target A（Rocq Extraction）**：从 Rocq 直接提取 `derived_core_interpreter.{ml,mli}`，纳入 `extracted_semantics` 库与独立检查驱动；
   - **Target B（OCaml 5 `Effect.Deep` 反去函数化）**：将 `core_effect` 一对一反去函数化为 OCaml 5 原生 `Effect.t` 与协作式纤程调度器，集成进现有 `lib/`（H1–H5）浅嵌入运行时。
3. **三阶验证阶梯**：Rocq 端到端场景定理（含 AscendNPU-IR Issue #316 与 Issue #920 风格早用异步结果）、`rocqchk` + `Print Assumptions` 零公理审计、以及 Target A 与 Target B 在全部 10 组场景上的 **bit-for-bit 交叉验证**。

---

## 2. Effect-Handler 解释器是如何从 Trace Semantics 推导出来的

该解释器不是凭直觉重写一套操作语义再事后对齐，而是沿一条 **4 步可逆的语义变换链**从 `rocq/CoreLanguage/Axiomatic/TraceSemantics.v` 机械推导得到：

```text
公理化 Trace Semantics (TraceSemantics.v)
  │
  ├─ 第 1 步：自动机操作化（Zero-Prophecy Online Prefix Automaton）
  ├─ 第 2 步：循环续体去函数化 + 行政重聚焦（Path-Preserving Refocusing）
  ▼
一阶在线状态自动机 (Refocusing.v + Automaton.v)
  │   ▲
  │   │  双向证明等价（Soundness.v + Completeness.v: automaton_iff_program_semantics）
  │
  ├─ 第 3 步：效应分解 + Free Monad（Functional Correspondence / 半去函数化）
  ▼
Rocq 高阶 Free Monad Effect-Handler 解释器 (CoreEffects.v + Handlers.v)
  │   ▲
  │   │  精确函数式对应（Handlers.v: free_and_derived_equivalent）
  │
  ├─ 第 4 步：再函数化（Refunctionalization：Trigger → Effect.perform）
  ▼
OCaml 5 原生 Effect.Deep 协作纤程解释器 (lib/core_effects.ml + lib/core_interpreter.ml)
```

### 第 1 步：自动机操作化（公理 A1–A5 与内存/值约束 → 增量状态与守卫）

Danvy 的经典抽象机推导（Functional / Syntactic Correspondence）要求起点已经是“方向化”的语义，而 `TraceSemantics.v` 是声明式全局过滤语义（先枚举候选事件全集的所有排列前缀，再用公理筛选）。

因此推导的第零座桥梁是验证**零预言因果前缀性（Zero-Prophecy Property）**：判定 $t \cdot e$ 是否合法仅依赖前缀 $t$ 的有限摘要状态，而无需偷看未来事件。关键在于 `Events.v` 对异步读/计算在 Start 处绑定的是抽象句柄 `Async o` 而非未来值，结果只需在 `ReadEnd` / `ComputeEnd` 时写入状态。由此每条公理一一编译为在线自动机状态分量与转移守卫（`Automaton.v`）：

| `TraceSemantics.v` 声明式公理 | 推导出的在线自动机状态分量与转移守卫 |
| --- | --- |
| **A1**（完成必晚于发起） | 在途操作表 `sync_inflight`：发起时入表 `PRead`/`PWrite`/`PCompute`/`PSetFlag`/`PWaitFlag`，完成时查表并移出 |
| **A2**（程序序 + `WaitFlag` 阻塞后续指令） | 每分支游标状态 `TRunning` / `TWaitingFlag w cur` / `TDone`：分支发起 `WaitFlagStart` 后立即挂起，直到 `WaitFlagEnd` 唤醒 |
| **A3**（`SetFlagEnd` 晚于同 pipe 更早操作的完成） | `SetFlagStart` 瞬间对 `sync_inflight` 中同 pipe 的在途操作做依赖快照 `deps`，`SetFlagEnd` 守卫要求 `deps_drained deps` |
| **A4**（每个 $(p,q,\varepsilon)$ 投影属于 $\mathsf{Pref}(\{\langle S,W\rangle\}^*)$） | 正则语言最小 2 状态 DFA `sync_flags`：`SetFlagEnd` 要求 `false → true`（禁止重复 set），`WaitFlagEnd` 要求 `true → false` |
| **A5**（同 pipe 后续发起不能越过未完成 `WaitFlag`） | 流水线阻塞表 `sync_active_wait`：`WaitFlagStart` 登记阻塞，同 pipe 所有后续 Start 均检查 `pipe_ready`，`WaitFlagEnd` 清除 |
| **$\mathcal{A}_{\rm mem}$**（读最新已完成写；`Alloc` 地址未写过） | 写历史表 `mem_writes`：`WriteEnd` 追加 `(a, v)`，`ReadEnd` 查最新值，`Alloc` 检查 `mem_lookup = None` |
| **$\mathcal{A}_{\rm val}$**（已完成异步结果约束） | 完成结果表 `mem_done_val`：`ReadEnd`/`ComputeEnd` 写入 `(o, res)`；早用异步结果与未初始化读抽离为外部 `choice_policy` |

### 第 2 步：循环续体去函数化与保路径 Refocusing

公理语义在标注前通过 `expand_loops c at_end` 静态展开全部循环，再用 `label_paths` 按二叉树路径分配 `op_id`，且 `EventsStop` 禁止停在 `CAlias`/`Select` 这类静音行政节点上。

应用 Syntactic Correspondence / Refocusing（`Refocusing.v`）：
- 将 `expand_loops` 的第二参数 `at_end`（循环体结束时的续体）去函数化为一阶栈帧 `KLoop x next_i hi body after`；
- 将 `CAlias`、`Select`、`For` 展开和 `LoopEnd` 弹栈融合为尾递归的 `refocus`，在推进过程中按 `xO`/`xI` 精确维护 `cursor_path`，使其与静态全展开 `annotate_program` 分配的 `op_id` **逐位一致**，空间复杂度仅 $O(\text{循环嵌套深度})$。

### 第 3 步：效应分解与 Free Monad（Functional Correspondence）

把一阶自动机的分支控制流与全局状态正交拆解（`CoreEffects.v` + `Handlers.v`）：
1. **效应签名 `core_effect`**：把每条头命令的环境交互抽象为 10 个一阶 GADT 构造子（`EAlloc`、`EAtomic`、`EAssignPipe`、`EIssueRead`、`EIssueWrite`、`EIssueCompute`、`EIssueSetFlag`、`EAwaitFlag`、`EBranch`、`EReturn`）；
2. **单分支 CPS 指称 `denote_branch`**：基于 `Base/Free.v`，每条分支 `refocus` 后发出 `Free.Trigger req k`，不直接触碰任何全局状态；
3. **分层 Handlers + 可插拔调度策略**：按内存/分配、标量与分支控制、同步与流水线、在途完成四层拆分处理器，顶层调度器把交错与完成时机抽离为 `schedule_policy`（`serialized_policy`、`overlapped_round_robin_policy`、`scripted_policy`）；
4. **函数式对应等价证明**：在 `Handlers.v` 中证明 `free_and_derived_equivalent`，表明高阶 Free 解释器将续体 `k` 去函数化后精确退化为第 2 步的一阶自动机，从而直接继承双向 Soundness 与 Completeness。

### 第 4 步：再函数化（Refunctionalization）到 OCaml 5 `Effect.Deep`

对 Rocq 的 `Free.Trigger req k` 做 Danvy–Millikin 意义下的再函数化（`lib/core_effects.ml` + `lib/core_interpreter.ml`）：
- 10 个 `core_effect` 构造子一对一映射为 OCaml 5 原生 `type _ Effect.t += ...`（通过 Functor 实现零 `Obj.magic` 的强类型 GADT 效应）；
- `denote_branch` 变为直接风格 `eval_branch`，`Trigger req k` 变为 `Effect.perform req`，续体从堆闭包变为 OCaml 5 原生分段纤程栈；
- 解决 OCaml 5 **one-shot 续体**与调度探测的冲突：每个暂停纤程保存为 `Fiber_running (Paused (req, k))`，调度器先通过纯 `probe_issue` 检查 `req` 而不消耗 `k`，确认提交 `Act_issue j` 时才调用子处理器并以 `Effect.Deep.continue k value` 恢复续体恰好一次；`EAwaitFlag` 挂起为 `Fiber_waiting (w, paused')`，待 `Act_finish w` 唤醒。

---

## 3. 已完成模块、核心定理与验证结果

### 3.1 代码清单

| 阶段 / 层级 | 文件路径 | 核心内容 |
| --- | --- | --- |
| Stage 1：重聚焦 | `rocq/CoreLanguage/Derived/Refocusing.v` | `annotate_program_valid`、`loop_frame`、`thread_cursor`、`plug_stack`、`refocus`、`refocus_preserves_ops_and_po` |
| Stage 1：自动机 | `rocq/CoreLanguage/Derived/Automaton.v` | `machine_state`、`choice_policy`（strict / permissive）、`auto_step` / `auto_steps`、`exec_issue_branch` / `exec_finish_op` |
| Stage 1：效应层 | `rocq/CoreLanguage/Derived/CoreEffects.v` | 10 构造子 `core_effect` GADT、单分支 Free 指称 `denote_branch` |
| Stage 1：处理器 | `rocq/CoreLanguage/Derived/Handlers.v` | 4 层模块化处理器、3 种 `schedule_policy`、`run_free_interpreter`、`run_derived_interpreter`、`free_and_derived_equivalent` |
| Stage 2：健全性 | `rocq/CoreLanguage/Derived/Soundness.v` | 22 项自动机不变式 `machine_inv_at`、`automaton_sound`、`derived_interpreter_sound`、`free_interpreter_sound` |
| Stage 2：完备性 | `rocq/CoreLanguage/Derived/Completeness.v` | 反向不变式 `extra_auto_inv`、前缀重放 `replay_inv`、`automaton_complete`、`automaton_iff_program_semantics`、`derived_interpreter_complete`、`free_interpreter_complete` |
| 验证 Step 1：示例 | `rocq/CoreLanguage/Derived/DerivedExamples.v` | Issue #316（串行 / 6-inflight 重叠 / Free 重叠）、`SharedResource`、`Overwrite`、`UninitRead`、`EarlyAsyncUse`（Issue #920 风格）、`LoopAlloc`、`open_bool_program_complete` |
| 验证 Step 2：审计 | `rocq/CoreLanguage/Derived/ProofAudit.v` | 对 20 个顶层定理执行 `Print Assumptions`，全部 `Closed under the global context` |
| Stage 3a：Target A | `rocq/CoreLanguage/Derived/ExtractDerived.v` | 提取 `derived_core_interpreter.{ml,mli}` 与全部 demo |
| Stage 3b：Target B | `lib/core_effects.ml`、`lib/core_interpreter.ml` | OCaml 5 原生 `Effect.t` + `Effect.Deep.match_with` 4 层处理器与协作式纤程调度器 + 内置全场景实例 |
| H1–H5 桥接 | `lib/effects.ml`、`lib/interpreter.ml`、`lib/unified_interpreter.ml` | 新增 `Core_async_events` 并在 `H5` 中记录核心语言异步事件轨迹，公开导出 `Core_effects` 与 `Core_interpreter` |
| 验证 Step 3：构建与测试 | `scripts/build_extraction.sh`、`extracted/dune`、`scripts/check_extracted_derived.ml`、`scripts/check_rocq.sh`、`test/dune`、`test/test_derived_interpreter.ml` | Extraction 接入 Dune、`rocqchk` + `ProofAudit` 自动化检查、独立提取驱动校验、Target A vs Target B 10 组场景 bit-for-bit 交叉验证与 H5 桥接测试 |

### 3.2 验证命令与结果

- **全量 Rocq 构建 + `rocqchk` + `ProofAudit` + 独立提取检查**：
  ```sh
  ROCQ_OPAM_SWITCH=unified-interpreter sh scripts/check_rocq.sh
  ```
  - `make -C rocq -f Makefile all` 通过；
  - `rocqchk` 独立内核验证全部 8 个 `CoreLanguage.Derived.*` 模块通过；
  - `ProofAudit.v` 20 个顶层定理全部输出 `Closed under the global context`；
  - `check_extracted_hivm.exe` 与 `check_extracted_derived.exe` 全部通过。
- **OCaml 单元测试与跨目标 bit-for-bit 交叉验证**：
  ```sh
  opam exec --switch=unified-interpreter -- dune runtest test/
  ```
  - 原有 `test_unified_interpreter`（H1–H5）保持全部通过；
  - `test_derived_interpreter` 在全部 10 组场景（含 Issue #316 串行与 6-inflight 双缓冲重叠的 125 条事件）上确认 Target A（Derived & Free）与 Target B（OCaml 5 `Effect.Deep`）事件轨迹、使用记录、输出、在途计数和错误码 **bit-for-bit 完全一致**，且 `H5` 桥接验证通过。

---

## 4. 学术创新点（Novelty）与论文贡献定位

从 PLDI / POPL / ICFP / OOPSLA / CPP 审稿视角看，Defunctionalization、Refocusing、Free Monad 和公理↔操作等价本身属于经典基础设施，不应包装为新理论本身；真正有辨识度、可作为论文核心 contribution 的是以下 5 点：

1. **为 Danvy 对应谱系补齐从声明式公理化 Trace 语义出发的“第零座桥梁”**
   - 相比 Danvy / Hillerström 等从方向化操作或指称语义出发的推导、弱内存模型的单体操作化、以及 ITrees/CTrees 的正向 refinement，本工作打通了“声明式公理化并发语义 → 零预言在线前缀自动机 → 模块化 Free Monad Effect Handlers → 原生 `Effect.Deep` 纤程运行时”的可逆推导链，并零公理证得完整双向等价。
2. **路径精确的循环续体去函数化与重聚焦（Path-Preserving Refocusing）**
   - 解决了硬件 IR 验证中的经典矛盾：公理化安全证明依赖静态全展开 `expand_loops` 提供的规范全局 `op_id`，而可执行解释器无法承受预展开大循环；保路径 `refocus` 在 $O(\text{嵌套深度})$ 空间内位级精确复现静态 `op_id` 并消除静音行政步骤。
3. **异构 NPU 解耦异步流水线公理的零预言操作化与非确定性正交因子化**
   - 针对 Ascend 等异构 NPU 的分离阶段操作（Start/End）、快照式 pipe 排空（A3）、严格交替正则同步协议（A4 最小 2 状态 DFA）、以及 `Async o` 句柄零预言消解 $\mathcal{A}_{\rm val}$，把非确定性正交分解为 `ChoicePolicy × SchedulePolicy`，使同一核心可零修改派生出严格检错器、串行模拟器、真实多在途重叠模拟器与完备脚本重放器。
4. **以通用派生解释器作为公理化语义的可执行见证生成器（Verified Witness Generation）**
   - 一次零公理证明通用 Soundness，即可把原先针对单个案例（如 Issue #316）需手工编写上千行的 trace 存在性证明（`SerializedTrace.v` / `Issue316Execution.v`），压缩为运行对应调度策略 + 几行 `vm_cast_no_check` 的机检合法见证，同时能直接复现真实双缓冲重叠（`max_inflight = 6`）与早用异步结果乱序（Issue #920 风格）。
5. **`Free` 半去函数化中间层的双目标同构与 OCaml 5 One-Shot 续体探测规约**
   - 清晰刻画了 `Free.Trigger` 作为一阶自动机与原生 `Effect.Deep` 之间的中点，并提出 `Paused (req, k)` 纯探测 + 单次 `continue` 协议以安全衔接 OCaml 5 的 one-shot 界定续体，与 Rocq 提取代码达成 bit-for-bit 交叉验证。

### 会议定位参考

- **CPP / ITP**：当前成果已非常完整且契合（零 `Admitted`/零公理双向证明、`rocqchk` 审计、保路径 Refocusing、真实 AscendNPU-IR 案例与双目标交叉验证）。
- **ICFP / OOPSLA / PLDI**：适合在现有基础上进一步强化“通用公理→Handler 合成理论”、更多真实 AscendNPU-IR 内核与 Fuzzing 检错评估、Target A vs Target B 性能对比，以及与上层 HFusion/HIVM 下降的语义 refinement 衔接。

---

## 5. 理论边界与通用化路线：为什么不能对“任意” Trace Semantics 直接构造？

### 5.1 理论上不能对任意 Trace Semantics 构造零预言在线自动机的三条硬边界

1. **破坏“零预言性（Zero-Prophecy）”的未来依赖语义**
   - 若语义允许当前读操作读到未来才发生的写（如弱内存 Load Buffering / 推测读），或假如 `ReadStart` 必须立刻绑定未来 `ReadEnd` 才能确定的具体值 `Known v`，在线自动机仅看历史前缀无法决定该值，必须引入 **Prophecy / Promising / 回溯剪枝**。
2. **非前缀封闭或含活性（Liveness）的语义**
   - 在线前缀自动机天然对应前缀封闭的安全性质（Safety）。诸如“每个 `ReadStart` 最终必有 `ReadEnd`”这类活性约束需要额外的终止接受条件（如 `inflight = []`）；而全局无环性约束（如弱内存 `acyclic(po ∪ rf ∪ co ∪ fr)`）则会产生无法补全的**死胡同前缀（dead-end prefixes）**，局部守卫不足以保证完备无回溯。
3. **退化的“全历史自动机” vs. 有限充分统计量与模块化 Handler**
   - 虽然对任意可判定且前缀封闭的 `Valid : list Event -> bool` 都可以构造一个把整条历史 $t$ 当作状态、守卫为 `Valid (t ++ [e])` 的平凡自动机，但：
     - 声明式 `Prop` 公理（含量词与 `Permutation`）本身不可直接计算；
     - 即使强行可判定化，也缺乏增量充分统计量（每步重扫整条历史），且所有公理耦合在一起，无法拆分为独立的 Memory / Sync / Scheduler Effect Handlers。

### 5.2 当前实现中特化于 A1–A5 的部分

- 方法论（4 步推导链）本身是通用的，但当前 Rocq 代码实例中的 `sync_state`（`sync_inflight` / `sync_flags` / `sync_active_wait`）、`mem_state`（`mem_writes` / `mem_done_val`）、`Soundness.v` 的 22 项不变式与 `Completeness.v` 的 `extra_auto_inv` 都是围绕 `TraceSemantics.v` 的固定公理 A1–A5 + $\mathcal{A}_{\rm mem}$ + $\mathcal{A}_{\rm val}$ 手工编写的。
- 若新增硬件同步公理 A6（例如深度为 $k$ 的计数信号量、跨核全局内存屏障、或 pipe 内乱序规则），当前需要手工扩展状态、处理器与对应证明。

### 5.3 下一步通用化方向：可组合因果公理代数（Compositional Causal Trace Axiom Combinators）

观察 A1–A5 与 $\mathcal{A}_{\rm mem}/\mathcal{A}_{\rm val}$，它们本质上是极少数可复用因果模式的实例化。将其抽象为通用框架，即可实现“公理组合 → 自动机与 Handler 自动合成”：

1. **公理合取 ↔ 自动机乘积 ↔ Effect Handler 叠层**：若公理 $P_1, P_2$ 分别拥有健全且完备的在线监视自动机 $(S_1, \delta_1, G_1)$ 与 $(S_2, \delta_2, G_2)$，则 $P_1 \land P_2$ 自动对应乘积自动机 $(S_1 \times S_2, \delta_1 \times \delta_2, G_1 \land G_2)$ 及其对应 Handler 的组合叠层，Soundness 与 Completeness 通过一次性的组合定理自动继承。
2. **五类通用“公理 → 在线监视器 / Handler”构造子**：
   - **正则投影模板**（$\pi_k(t) \in \mathsf{Pref}(L)$ + DFA）：覆盖 **A4**，并零改动推广到深度为 $k$ 的计数信号量、锁协议与多阶段握手；
   - **二阶段配对模板（Bracketed Lifecycle）**：`End` 必晚于 `Start`（覆盖 **A1**）；
   - **快照排空屏障模板（Snapshot-Drain Fence）**：某类 `End(o)` 晚于所有早于 `Start(o)` 发起且满足谓词 $P$ 的操作之 `End`（覆盖 **A3**，可直接实例化全局 memory fence / 跨核 barrier）；
   - **开区间阻塞模板（Active-Gate Blocking）**：只要存在尚未 `End` 的操作 $w$，禁止发起满足 $Q(w, u)$ 的操作 $u$（同时覆盖 **A2** 与 **A5**）；
   - **最新写入历史模板（Latest-Writer + `ChoicePolicy`）**：在事件 $e$ 处读取最近满足 $R$ 的历史写值，无历史记录则委托外部 `ChoicePolicy`（同时覆盖 **$\mathcal{A}_{\rm mem}$** 与 **$\mathcal{A}_{\rm val}$**）。

完成这一层抽象后，工作主张即可从“为特定 A1–A5 推导一个经验证解释器”进一步升格为“刻画可零预言操作化的可组合因果 trace 公理片段，并模块化自动合成带双向等价保证的分层 Effect-Handler 解释器”。

# 精选同步与并发 Issue / 修复 MR 靶场（L2）

本文从 [原始归档](corpus/evidence/README.md) 的 72 份 GitCode Issue 与 39 个修复 MR 中，**剔除与同步/并发无关的噪音**（如 FP8 转换、NDDMA 扩展、精度、debug metadata 等约 50 项），筛选出 **18 个纯同步/并发 Issue + 6 个高价值独立修复 MR**，并单列 **2 个内存别名误编译延展案例**。

所有路径均相对于 `benchmark/` 根目录。优先级定义：

- **P0（首选演示 / 必做靶标）**：华为典型同步/死锁/多缓冲痛点，且已有可重放 MLIR、patch 或明确最小模型。
- **P1（核心验证目标）**：高度贴合 HIVM 同步语义，需要补齐 `pipe_barrier`、跨核 1:2、计数器边界或 `alloc` 后即可成对验证。
- **P2（中长期扩展）**：涉及 SIMT/分布式/有序锁/性能型同步劣化，作为后续扩展方向。

---

## 1. 核内管道同步缺失与 Event ID 冲突

| 优先级 | 编号 | 缺陷摘要 | 涉及 HIVM 原语 / Pass | 所需 CoreLang 特性 | 本地材料与当前状态 |
|---|---|---|---|---|---|
| **P0** | [#1047](https://gitcode.com/Ascend/AscendNPU-IR/issues/1047) / [!5282](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5282) | 3D `arange` 标量回退路径中 `PIPE_V` 与 `PIPE_S` 缺少同步，标量写可能覆盖未完成的向量访问，或后续向量读到未写完的 UB 数据 | `set_flag`/`wait_flag`（`PIPE_V ↔ PIPE_S`） | `PIPE_S` 与 `PIPE_V` 交互、共享 UB 内存 $\mu$ | [正文](corpus/evidence/issues/1047/report.md) · [修复 patch](corpus/evidence/repairs/issue-1047-mr-5282/change.patch)（缺独立 MLIR，适合构造最小成对模型） |
| **P0** | [#579](https://gitcode.com/Ascend/AscendNPU-IR/issues/579) | 模板库 `LIB_EVENT_ID0`（`EVENT_ID6`）与 `GraphSyncSolver`/`InjectSync` 分配的 `event_id` 冲突，导致 `wait_flag` 被无关 `set_flag` 提前释放、load 读脏数据 | `set_flag`/`wait_flag`（同键 event ID 冲突） | 同流有向键 `(p, q, ε)` 冲突与 `A4` / 重叠 set 检测 | [正文](corpus/evidence/issues/579/report.md)（可直接对应 `handwritten/overlapping-sets` 模型） |
| **P0** | [!3472](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3472) | `GraphSyncSolver` 未追踪 zero-trip 循环中的 memref 别名，导致漏插同步 | `GraphSyncSolver`、`scf.for` + multibuffer | 动态 `for`（含 0 轮执行）+ `alloc`/view 别名 | [修复元数据](corpus/evidence/repairs/mr-3472/repair.json) · [patch](corpus/evidence/repairs/mr-3472/change.patch) · [回归用例](corpus/repair-regression/mr-3472/case.json) |
| **P0** | [!3512](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3512) | `GraphSyncSolver` 未把 `__builtin_indirect_atomic` 的 GM 地址参数当作读写参数，导致漏插同步 | `GraphSyncSolver`、间接原子访存 | `foot` 读写足迹覆盖自定义/原子算子 | [修复元数据](corpus/evidence/repairs/mr-3512/repair.json) · [patch](corpus/evidence/repairs/mr-3512/change.patch) · [回归用例](corpus/repair-regression/mr-3512/case.json) |
| **P1** | [#708](https://gitcode.com/Ascend/AscendNPU-IR/issues/708) | `GraphSyncSolver` / `InjectSync` 将 `func::CallOp` 视为可跳过，导致 SIMT VF 调用与其 VECTOR 消费者之间缺少同步边，引发设备端数据竞争 | `GraphSyncSolver`、SIMD-SIMT VF 调用 | 跨函数/VF 调用的管道足迹与同步边 | [正文](corpus/evidence/issues/708/report.md) |
| **P1** | [#1012](https://gitcode.com/Ascend/AscendNPU-IR/issues/1012) / [!5074](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5074) | HIVM v2 pipeline 忽略编译器 `auto-sync` 开关，始终按默认配置跑同步求解器 | HIVM v2 pipeline、intra/cross-core GSS | 开关差分对比框架（sync-on vs sync-off） | [正文](corpus/evidence/issues/1012/report.md) · [用例](corpus/issue-input/1012/case.json) · [patch](corpus/evidence/repairs/issue-1012-mr-5074/change.patch) |
| **P1** | [#1015](https://gitcode.com/Ascend/AscendNPU-IR/issues/1015) | RegBase 目标自动插入 `GET_BUF` / `RLS_BUF` 核内同步，需防止不安全的 buffer-ID 复用 | `GET_BUF` / `RLS_BUF`（RegBase 核内同步） | 抽象 `sync_id` 配置或 buffer-ID 锁/令牌语义 | [正文](corpus/evidence/issues/1015/report.md) |

---

## 2. 多缓冲（MultiBuffer）、Preload 槽位轮换与生命周期覆盖

| 优先级 | 编号 | 缺陷摘要 | 涉及 HIVM 原语 / Pass | 所需 CoreLang 特性 | 本地材料与当前状态 |
|---|---|---|---|---|---|
| **P0** | [#316](https://gitcode.com/Ascend/AscendNPU-IR/issues/316) | CV 场景 Vector 侧开启双缓冲（`bufA`/`bufB` 轮换）：第 2 轮复用 `bufA` 前必须等待第 0 轮消费释放 | `enable-multi-buffer`、`set_flag`/`wait_flag`、双缓冲槽位 | `alloc()` + `for` 循环 + 动态 `event` / `view` 选择 | [正文](corpus/evidence/issues/316/report.md) · [内嵌 MLIR](corpus/evidence/issues/316/quoted)（上游 `d331719` 已有 Rocq 版） |
| **P0** | [#1020](https://gitcode.com/Ascend/AscendNPU-IR/issues/1020) / [!5334](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5334) | `CreatePreload` 在 affine tile size 下中止，且可能**复用仍在活跃期的 preload buffer slot** | `hivm-create-preload`、多缓冲槽位轮换 | `alloc()` + 循环槽位轮换 + 活跃期覆写（WAR）检查 | [正文](corpus/evidence/issues/1020/report.md) · [证据包](corpus/evidence/issues/1020/evidence.zip) · [patch](corpus/evidence/repairs/issue-1020-mr-5334/change.patch) |
| **P0** | [#1022](https://gitcode.com/Ascend/AscendNPU-IR/issues/1022) / [!5336](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5336) | 局部 `PlanMemory` 覆写仍在活跃期的 loop-carried UB 值 | `PlanMemory`、循环携带 UB buffer | `for` + `alloc()` + UB 读写足迹与内存值 $\mu$ | [正文](corpus/evidence/issues/1022/report.md) · [证据包](corpus/evidence/issues/1022/evidence.zip) · [用例](corpus/issue-input/1022/case.json) · [patch](corpus/evidence/repairs/issue-1022-mr-5336/change.patch) |
| **P2** | [#1055](https://gitcode.com/Ascend/AscendNPU-IR/issues/1055) | 条件分支内的 multibuffer 按循环索引而非实际执行轮换 slot，导致复用同一 flag id 引发多余等待 | multibuffer、`if` + `for` + `set_flag`/`wait_flag` | `for` + `if` + 动态 `event` 绑定 | [正文](corpus/evidence/issues/1055/report.md)（性能型多余同步） |

---

## 3. CV 软流水、混合核（MIX）死锁与跨核同步

| 优先级 | 编号 | 缺陷摘要 | 涉及 HIVM 原语 / Pass | 所需 CoreLang 特性 | 本地材料与当前状态 |
|---|---|---|---|---|---|
| **P0** | [#920](https://gitcode.com/Ascend/AscendNPU-IR/issues/920) / [!5025](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5025) | `hivm-cv-pipelining` 对含 CV 反馈边的循环错误启用 skew 流水，导致结果整体滞后一个迭代 | `hivm-cv-pipelining`、AIC↔AIV 跨核反馈 | MIX 双流（$\kappa_{1:1}/\kappa_{1:2}$）+ `for` + 跨核 `syncblock` | [正文](corpus/evidence/issues/920/report.md) · [本地已复现回归](issue920/920.mlir) · [patch](corpus/evidence/repairs/issue-920-mr-5025/change.patch)（**L1 演示用例**） |
| **P0** | [#852](https://gitcode.com/Ascend/AscendNPU-IR/issues/852) | MultiBuffer 流水下 `CrossCoreGSS` 跨核事件复用导致硬件计数器溢出及 AICore 间歇性超时 | `CrossCoreGSS`、`sync_block_set`/`sync_block_wait` | 跨核多轮在途计数器模型 + 容量上限检查 | [正文](corpus/evidence/issues/852/report.md) · [内嵌 MLIR](corpus/evidence/issues/852/quoted) |
| **P0** | [!3261](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3261) | 空 preload 循环导致 **MIX 核间死锁**（一端发/等、另一端空循环跳过） | `hivm-create-preload`、MIX `sync_block` | MIX 双流 + 0 轮 `for` + 死锁 / 残留令牌检查 | [修复元数据](corpus/evidence/repairs/mr-3261/repair.json) · [patch](corpus/evidence/repairs/mr-3261/change.patch) · [回归用例](corpus/repair-regression/mr-3261/case.json) |
| **P0** | [!3508](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3508) | CV-pipelining 中 `CrossCoreGSS` 的 `set/wait` 父作用域查找错误，导致跨核同步位置错放 | `CrossCoreGSS`、CV-pipelining `sync_block` | MIX 双流 + 嵌套控制流中的 `syncblockset/wait` | [修复元数据](corpus/evidence/repairs/mr-3508/repair.json) · [patch](corpus/evidence/repairs/mr-3508/change.patch) · [回归用例](corpus/repair-regression/mr-3508/case.json) |
| **P1** | [#994](https://gitcode.com/Ascend/AscendNPU-IR/issues/994) / [!5161](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5161) | 混合核链式 `scf.while` 的 MMAD L0C 累加结果被 `InsertFixpipe` 提前物化到 UB，后续缓冲区复用破坏结果 | `InsertFixpipe`、`mmadL1`、`L0C→UB/GM` | AIC `L0C` 地址空间与跨循环活跃期语义 | [正文](corpus/evidence/issues/994/report.md) · [用例](corpus/issue-input/994/case.json) · [patch](corpus/evidence/repairs/issue-994-mr-5161/change.patch) |
| **P1** | [#1023](https://gitcode.com/Ascend/AscendNPU-IR/issues/1023) / [!5337](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5337) | MIX kernel 在 AIC 和 AIV 两端重复初始化私有 vector 输入 | `SplitMixKernel` / `Vectorize` | MIX $\kappa_{1:1}/\kappa_{1:2}$ 核归属与 `Space_d` 权限检查 | [正文](corpus/evidence/issues/1023/report.md) · [证据包](corpus/evidence/issues/1023/evidence.zip) · [patch](corpus/evidence/repairs/issue-1023-mr-5337/change.patch) |
| **P1** | [#1049](https://gitcode.com/Ascend/AscendNPU-IR/issues/1049) | 分布式自定义 op 缺少单 sub-block guard，导致 1:2 下两个 AIV 重复修改远端内存与共享 UDMA 队列 | `bind-sub-block`、`get_sub_block_idx` guard | $\kappa_{1:2}$ 双 AIV 流 + `get_sub_block_idx` + `if` 分支 | [正文](corpus/evidence/issues/1049/report.md) |
| **P1** | [!3491](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3491) | 原子返回快照需包裹在 `sync-block lock` 内，防止跨核并发读写撕裂 | `create_sync_block_lock` / `sync_block_lock` | 核间互斥锁扩展 | [修复元数据](corpus/evidence/repairs/mr-3491/repair.json) · [patch](corpus/evidence/repairs/mr-3491/change.patch) |
| **P1** | [!3684](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3684) | MIX 分核保留 TCB yield 并在 preload 后正确克隆局部 buffer | `SplitMixKernel`、`CreatePreload` | MIX 分核 + `alloc()` 局部缓冲生命周期 | [修复元数据](corpus/evidence/repairs/mr-3684/repair.json) · [patch](corpus/evidence/repairs/mr-3684/change.patch) · [回归用例](corpus/repair-regression/mr-3684/case.json) |
| **P2** | [#1013](https://gitcode.com/Ascend/AscendNPU-IR/issues/1013) | 核类型不明确的标量 GM load 触发 HIVM v2 CrossCoreGSS 断言崩溃 | `CrossCoreGSS`、标量 GM 访存归属 | 核类型良构检查 $\mathcal H;\Gamma \vdash_s C$ | [正文](corpus/evidence/issues/1013/report.md) |
| **P2** | [#991](https://gitcode.com/Ascend/AscendNPU-IR/issues/991) | `MergeCVScopes` 按 IR 相邻而非依赖图合并 scope | `MergeCVScopes`、CV scope 依赖 | CV 依赖图分析（偏性能/结构） | [正文](corpus/evidence/issues/991/report.md) |

---

## 4. 标量阻塞、有序锁与硬件挂起

| 优先级 | 编号 | 缺陷摘要 | 涉及 HIVM 原语 / Pass | 所需 CoreLang 特性 | 本地材料与当前状态 |
|---|---|---|---|---|---|
| **P1** | [#992](https://gitcode.com/Ascend/AscendNPU-IR/issues/992) | Vector 阻塞 Scalar 时导致 Scalar 无法发射后续所有管道指令，整条流水被卡死 | `PIPE_V → PIPE_S` 标量等待 | 区分阻塞标量流的 `Scalar-Wait` vs 仅入队目标管道的 `Wait`（`opsem.tex` 已建模） | [正文](corpus/evidence/issues/992/report.md) |
| **P2** | [#1030](https://gitcode.com/Ascend/AscendNPU-IR/issues/1030) | A3 有序锁与带结果的 `atomic_cas` 在 `insert-load-store` 崩溃 | 有序锁、`atomic_cas` | 跨核有序锁协议 | [正文](corpus/evidence/issues/1030/report.md) · [内嵌 MLIR](corpus/evidence/issues/1030/quoted) |
| **P2** | [#1058](https://gitcode.com/Ascend/AscendNPU-IR/issues/1058) | Gen-0501 内核运行挂起（hang） | 端到端死锁 / 卡死 | 需先提炼最小 HIVM 复现，检查残留令牌与循环等待死锁 | [正文](corpus/evidence/issues/1058/report.md) |

---

## 5. 延展对照：内存别名误编译（非同步类，展示内存模型延展能力）

以下 2 项属于 `MemRef` / `canonicalize-ext` 冗余拷贝消除中的 **sibling subview 别名误编译**，不属于管道同步缺陷，但可直接展示在 CoreLang 中引入精确内存足迹 `foot` 与值域 $\mu$ 后的错误定位能力：

| 编号 | 缺陷摘要 | 本地材料与当前状态 |
|---|---|---|
| [#981](https://gitcode.com/Ascend/AscendNPU-IR/issues/981) | `FoldRedundantCopy` 仅检查直接 user，忽略同一 allocation 的 sibling subview 写入，导致最终 copy 绕过 `fill` 直接读旧输入 | [正文](corpus/evidence/issues/981/report.md) · [原始 MLIR](corpus/evidence/issues/981/quoted/fragment-1.mlir) · [本机复现输出](corpus/evidence/issues/981/local-canonicalize.mlir)（**已在本机复现**：lane `0, 63` 由 `0` 错变为 `7`，lane `64, 127` 保持 `7`） |
| [#995](https://gitcode.com/Ascend/AscendNPU-IR/issues/995) | 同类 `FoldRedundantCopy` 误删真实数据写回，导致 SIMD kernel 首个 64 lane 结果变成 `0` | [正文](corpus/evidence/issues/995/report.md) · [内嵌 MLIR](corpus/evidence/issues/995/quoted) |

---

## 6. 明确排除出同步主表的归档项

[corpus/evidence/README.md](corpus/evidence/README.md) 中其余约 50 项（包括 `#982` DMA padding、`#985/#986/#990` NDDMA、`#987/#988` MMAD 数据类型、`#997/#1025/#1028` FP8/HiFloat8、`#1006/#1052` 浮点精度、`#1009` debug metadata、`#1016–#1019/#1021/#1024/#1026/#1027/#1031/#1032/#1038/#1043/#1044/#1046/#1048/#1050/#1051/#1053/#1056/#1059/#1060` 等）属于算子降级、布局、精度、性能或编译崩溃问题，**继续保留在 `corpus/evidence/` 作为原始归档，不计入本同步并发 Benchmark 的有效靶场统计**。

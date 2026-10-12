# Vellvm 对 UnifiedInterpreter 的启示

## 1. 需要区分两个时期的 Vellvm

归档的 POPL 2012 论文描述的是最初的 Vellvm。它在 Coq 中定义 LLVM IR
的语法、类型系统、SSA 约束、内存和操作语义，并给出适合不同证明任务的
多种语义。作者还抽取解释器，与 LLVM 的解释器和编译执行结果做测试，
并实现了经过验证的 SoftBound transformation。

截至 2026 年的 Vellvm 已经采用不同的核心组织方式：

- 前端 AST 与语义使用的 CFG AST 分开；
- 程序的 denotation 是包含 LLVM events 的 interaction tree；
- handlers 按局部环境、全局环境、内存、外部调用等职责分层组合；
- 抽象规范描述一组允许的行为，使用 choice trees/sets of trees 表达
  nondeterminism；
- 可执行解释器不是规范本身，而是被证明为抽象规范的一个 refinement；
- 抽取后的 OCaml driver 用来执行，并与 `llc` 做 differential testing。

因此，对我们最有直接启发的不是 2012 代码的具体数据结构，而是现代
Vellvm 的“语法 -> 开放的 effectful denotation -> 分层 handlers -> 顶层模型”
架构，以及规范和可执行实现之间清晰的 refinement 边界。

## 2. 和我们方案最接近的地方

### 2.1 指令语义可以先产生 effect，而不是直接拥有整个机器状态

Vellvm 的 `LLVMEvents.v` 给出事件集合，`Denotation.v` 把程序解释为带这些
事件的树，`Handlers/` 再逐层解释事件。这正好支持我们希望的工程性质：
一条指令只声明它需要读取 SSA 环境、访问 memory、发起 DMA 或同步，而不
必依赖一个不断膨胀的 `unified_state` 具体 record。

但是这里的 event 不是执行结束后附加的一条日志，而是计算向环境发出的
语义请求。handler 对请求的回答会影响后续计算。我们目前
`Unified/Events.v` 中的 `EInstructionStart`、`EMemoryRead` 等只是 observation
vocabulary，不能替代这种 semantic event。

建议以后明确分成两类：

- **semantic effects**：`ReadSSA`、`WriteSSA`、`Load`、`Store`、`Alloc`、
  `LaunchDMA`、`Wait`、`Barrier`、`ChooseSchedule` 等；
- **diagnostic observations**：指令开始/结束、实际读写地址、数值边界等，
  仅用于 trace 和错误定位，程序不能读取其 history。

这也回答了我们之前关于 event 的争论：HFusion 中纯粹的 tensor 运算可以
继续写成普通 Rocq 函数；只有需要环境交互的部分才提升为 semantic effect。

### 2.2 handler 的分层组合与我们的可分离 state 方向一致

Vellvm 没有让每个操作直接接收一个巨型状态，而是按事件种类拆 handlers，
最后在 `TopLevel.v` 组合。我们的 memory、SSA environment、DMA queues、同步
对象、numeric policy 也应采用这种边界。每个 handler 只持有其私有状态，
跨组件交互通过显式事件完成。

这比仅靠 `HasMemory` lens 更强：lens 只说明如何从大 state 取出小 state；
effect signature 还说明一段计算究竟具有什么能力。我们可以保留 lens 作为
简单 state handler 的实现工具，但不应把 lens 当作分离语义本身。

### 2.3 我们的多阶段 handler 比 Vellvm 多一个维度

Vellvm 的 handlers 主要解释同一层 LLVM 语义中的不同 effect。我们还需要
另一种 handler：把高层 operation 动态 lowering 成较低层 operation，例如
HFusion `linalg.reduce` 变成更低层的循环、局部存储和同步操作。

因此建议把两种组合分开命名：

- **runtime handlers** 解释 memory、SSA、DMA、同步等机器 effect；
- **lowering handlers** 处理某一 dialect/stage 的 operation，并产生下一层
  operation；未处理的低层 operation 向外逃逸。

用户显式放置 H1--H5 scope 的能力属于我们的 mixed-IR 设计，不应误称为
Vellvm 已经提供的能力。Vellvm 提供的是实现这一设计所需的成熟语义骨架。

## 3. 对当前 Rocq 工程的具体建议

### 3.1 保留 raw syntax 与 typed semantic IR 两道边界

Vellvm 的 parser AST (`LLVMAst.v`) 与语义 CFG AST (`CFG.v`) 分开。我们也应
避免让“忠实保存 MLIR 文本”和“便于定义语义”由同一个 datatype 承担：

1. `RawHFusion` 忠实表示 parser 得到的 operation、attributes、regions 和
   SSA names；
2. elaboration/verifier 检查 operation-specific typing、region signature、
   SSA use-def/dominance 和 attributes；
3. `TypedHFusion` 保存语义真正需要的证据或索引，语义函数不再重复检查
   已经由类型系统保证的条件。

我们刚完成的 `mlir_type` 形式化属于两层共享的类型语言，但仅有
`ssa_value.value_type` 还不是完整的 typed IR。下一步的关键不是继续增加
字符串 attribute，而是建立 operation-specific verifier/elaborator。

### 3.2 把“规范”和“CPU 可执行模型”分开

对文档明确、确定性的 HFusion 操作，当前 `sem_linalg_elemwise_binary`、
`sem_linalg_reduce`、`sem_hfusion_cast` 这类可执行函数是合适的。到了 HIVM，
文档可能允许未指定调度、异步完成次序或未定义行为。此时不应强迫规范
过早选择唯一结果。

建议长期保持两层：

- **abstract semantics**：允许行为的集合，保留调度/未指定行为的选择；
- **executable model**：选择具体 schedule、有限 memory 和确定性 policy，
  作为 CPU 上可运行的一个实现。

Vellvm 的“解释器 refinement 规范”正适合表达二者关系。第一阶段不必立即
完成证明，但 API 不应把规范锁死为单一确定性函数。

### 3.3 明确区分四种失败或不确定性

Vellvm 处理 `undef`、`poison`、UB 和外部 nondeterminism 的经验说明，一个
笼统的 `runtime_error` 很快会不够。对 Ascend 文档至少要区分：

- `Unsupported`：模型尚未实现，不是程序语义错误；
- `Stuck/Invalid`：违反静态或动态前置条件；
- `UndefinedBehavior`：规范明确不给出后续行为；
- `Choice`：规范允许多个结果或多个调度。

不要直接复制 LLVM 的 poison/undef 设计；只有 Ascend/MLIR 文档或硬件实验
提供依据时才引入对应概念。

### 3.4 validation 应成为正式组成部分

2012 Vellvm 抽取解释器并和 LLVM 行为比较；现代 Vellvm 继续维护与 `llc`
的 differential tests。我们的对应验证阶梯应是：

1. Rocq 函数计算与抽取 OCaml 一致（by construction）；
2. 对同一 HFusion artifact，比对 Ascend 编译器/runtime 或硬件结果；
3. 保存 toolchain revision、输入、输出和 observable trace；
4. 用官方 FlashAttention 等真实 artifact 逐步扩大 operation coverage。

这不能证明与硬件完全等价，但能持续发现文档、模型和实现三者的不一致。

## 4. 推荐的目标目录结构

```text
rocq/
  Syntax/
    MLIRTypes.v
    RawHFusion.v
    TypedHFusion.v
  Elaboration/
    HFusion.v
  Semantics/
    Events/
      SSA.v Memory.v DMA.v Sync.v
    Denotation.v
    Handlers/
      SSA.v Memory.v DMA.v Sync.v Trace.v
    TopLevel.v
  Lowering/
    H1.v H2.v H3.v H4.v
  Theory/
    Refinement.v
  Extraction/
```

这个结构是目标方向，不要求立即搬迁现有文件。近期最小改动顺序应是：

1. 为 HFusion 增加 raw-to-typed elaboration；
2. 将 semantic effects 与 observation trace 分开；
3. 在出现第一条 memory/async instruction 时引入 interaction-tree 风格的
   denotation 和局部 handler；
4. 到需要未指定调度时再引入 choice/nondeterministic specification；
5. 最后定义 lowering handler 之间的 behavioral refinement。

## 5. 不应照搬的内容

- 不需要复制 LLVM 的完整 pointer/provenance、poison、undef 或 external-call
  模型；我们的范围应由 FlashAttention 所需 HFusion/HIVM 操作驱动。
- 不应现在就把所有纯 tensor 函数改写成树；纯函数是 handler 内部很好的
  reusable semantics。
- 不应把可执行解释器当作唯一规范；但也不应为了未来的 nondeterminism，
  让当前确定性 HFusion 子集失去可计算性。
- 不应把 diagnostic trace 暴露给程序。未来 monitor 可以观察 trace，但
  核心 instruction semantics 不读取历史。

## 6. 资料

- Vellvm project: <https://github.com/vellvm/vellvm>
- Project overview: <https://vellvm.github.io/vellvm/about/>
- Current source organization: <https://vellvm.github.io/vellvm/structure/>
- Related publications: <https://vellvm.github.io/vellvm/research/>
- Archived original paper: `references/papers/vellvm-popl2012.pdf`

本文档依据 2026-10-12 可见的 Vellvm 网站和仓库说明整理。现代架构的结论
不应反向归因给 2012 论文。

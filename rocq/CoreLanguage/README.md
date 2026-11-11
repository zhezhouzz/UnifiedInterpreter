# Pipeline Core Language 的 Rocq 定义

本目录对应 [LaTeX 定义](../../docs/pipeline-core-language.tex)。`pipeline_id`
标识 pipeline，`declared_pipelines` 给出程序使用的有限集合，
`pipeline_kind : pipeline_id -> exec_kind` 指定执行类别。
`exec_kind` 包含 `Cube`、`Vector`、`Scalar` 和 `MTE`；
`OCompute kind function arguments` 显式记录计算的执行类别。

| 文件 | 定义 |
| --- | --- |
| [Syntax.v](Syntax.v) | 值、表达式、操作、命令、顺序上下文、静态模型及表达式求值 |
| [State.v](State.v) | 全局状态、pipeline 局部状态、当前操作进度及初态 |
| [Events.v](Events.v) | 转移标签、运行与错误配置、事件所属 pipeline 及访存分类 |
| [Semantics.v](Semantics.v) | 操作初始化与合法性、pipeline 小步关系、错误、终止及死锁 |
| [Traces.v](Traces.v) | 执行轨迹、程序语义、可选弱公平条件、happens-before 和数据竞争 |
| [Properties.v](Properties.v) | 空闲条件、完成结果、计算类别、终止和最大轨迹性质 |
| [OrderedLocks.v](OrderedLocks.v) | 可选顺序锁策略、轮次状态和相关性质 |
| [Examples.v](Examples.v) | 整数、向量及矩阵计算模型与 Cube/Vector 执行推导 |
| [MemoryExamples.v](MemoryExamples.v) | 两地址区域读取与写入交错的执行推导 |

数值类型是参数 `Numeric`，例子实例化为 `Z`。`primitive_eval` 和 `compute_eval`
是纯偏函数，以 `None` 表示输入不在函数定义域内。`compute_signature` 声明
计算函数的输入和输出类型；`well_typed_computations` 要求成功计算符合签名。
`supports` 检查 pipeline 支持的函数和输入类型；读写权限及存储值类型由
`can_read`、`can_write` 和 `type_ok` 给出。

`pipeline_state` 包含剩余命令 `pipeline_code`、局部环境 `pipeline_locals`
和当前操作进度 `pipeline_operation`。当前操作为空闲状态或一次读取、写入、
计算的进度与结果。全局状态包含共享内存、事件、锁和 pipeline 局部状态。
锁持有者与事件端点均使用 `pipeline_id`。

## 操作语义

程序使用 `COp destination operation` 表示操作及其结果变量。`PipelineStart`
在空闲状态下求值参数并检查权限、类型、计算函数和执行类别，将操作进度
写入当前 pipeline。读取和写入每次处理一个地址；计算根据已求值的输入
产生结果。`PipelineComplete` 将完成的结果写入局部变量，恢复空闲状态。
这些内部步骤通过 `PipelineSeq` 放入顺序上下文；当前操作完成后，同一
pipeline 才能进入后续命令。全局 `step` 在不同 pipeline 的可用步骤之间选择。

`PipelineSet` 设置事件，`PipelineWait` 消费事件并将标志清零。锁规则检查
参与权限和持有者。等待条件未满足时相应规则不可用；非法操作满足
`pipeline_error` 并进入无后继的 `Error`。

`program_semantics` 量化合法初态，包含最大有限轨迹和无限轨迹。
`fair_infinite_execution` 额外要求持续可执行的 pipeline 最终被调度。
`happens_before` 是同一 pipeline 的事件顺序、事件设置与消费以及锁释放与
获取三类边的传递闭包。`Race` 要求两个访问同一地址的事件至少包含一次写入，
且两个方向都没有 happens-before 关系。

顺序锁扩展使用 `lock_order := lock_id -> nat -> pipeline_id` 和每把锁的轮次。
`ordered_step` 在获取时检查该轮参与者，在释放时增加轮次；
`ordered_step_erases` 证明每个顺序锁步骤对应普通语言的一个步骤。

## 已证明的性质与执行例子

- `pipeline_start_requires_idle`、`step_start_requires_idle`、
  `active_pipeline_cannot_start` 和 `pipeline_complete_requires_done` 证明操作
  开始与结果写入的状态条件。
- `pipeline_step_compute_kind` 和 `step_compute_kind` 证明计算类别检查。
- `terminal_has_no_successor` 和 `terminal_execution_maximal` 证明终止与最大轨迹性质。
- `same_pipeline_order`、`same_pipeline_no_race`、`happens_before_forward` 和
  `happens_before_irreflexive` 证明程序顺序和 happens-before 的基本性质。
- 顺序锁的证明覆盖轮次检查、释放后递增、轮次定义域保持及周期轮转。
- `cube_vector_interleaving` 给出 Cube 和 Vector pipeline 并行计算的完整执行；
  `calc6_terminal` 检查终止状态，`vector_cannot_execute_cube` 检查类别约束。
- `sequential_adds_execution`、`flag_write_execution` 和 `locked_write_execution`
  给出顺序计算、事件同步和锁保护写入的具体执行；
  `cyclic_wait_is_deadlocked` 证明循环等待发生全局死锁。
- `interleaved_region_read` 给出两个 pipeline 逐地址读取与写入的执行，返回
  `{0 ↦ 0, 1 ↦ 42}`，并证明读取结果不同于执行中的内存状态。

## 验证

在仓库根目录运行：

```sh
opam exec --switch=unified-interpreter -- make -C rocq -f Makefile all
```

新模块列入 `rocq/_CoqProject`。单独复核这些模块的证明可在 `rocq/` 运行：

```sh
opam exec --switch=unified-interpreter -- rocq check -silent -Q . UnifiedInterpreter \
  UnifiedInterpreter.CoreLanguage.Properties \
  UnifiedInterpreter.CoreLanguage.Traces \
  UnifiedInterpreter.CoreLanguage.OrderedLocks \
  UnifiedInterpreter.CoreLanguage.Examples \
  UnifiedInterpreter.CoreLanguage.MemoryExamples
```

硬件执行到该语言的 refinement，以及任意程序的数据竞争自由、无死锁或
无饥饿证明，需要针对相应硬件模型或程序建立。

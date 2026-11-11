# Pipeline Core Language 的 Rocq 定义

本目录对应 [LaTeX 定义](../../docs/pipeline-core-language.tex)。程序以
`pipeline_id` 标识每个 pipeline，`declared_pipelines` 给出程序使用的有限集合，
`pipeline_kind : pipeline_id -> exec_kind` 指定执行类别。每个 pipeline
具有自己的顺序控制状态、局部变量和操作句柄。`exec_kind` 包含 `Cube`、
`Vector`、`Scalar`、`MTE`；`OCompute kind function arguments` 显式记录执行类别。

## 文件与数学定义

| 文件 | 定义 |
| --- | --- |
| [Syntax.v](Syntax.v) | 值、表达式、操作、命令、顺序上下文、静态模型、纯表达式求值、同步执行语法糖 `synchronous` |
| [State.v](State.v) | 六分量全局状态、局部变量与句柄环境、任务状态、初态及 `drained` |
| [Events.v](Events.v) | 转移标签、运行与错误配置、控制事件与任务事件的分类 |
| [Semantics.v](Semantics.v) | 任务初始化与合法性、控制和后台步骤、错误、小步关系 `step`、正常终止及死锁 |
| [Traces.v](Traces.v) | 有限与无限执行、最大轨迹、`program_semantics`、可选弱公平条件、happens-before 和数据竞争 |
| [Properties.v](Properties.v) | 任务编号新鲜性保持、启动分配的新鲜编号、计算类别检查 |
| [OrderedLocks.v](OrderedLocks.v) | 文档中的可选顺序锁策略、轮次状态、顺序约束及与普通语义的关系 |
| [Examples.v](Examples.v) | 整数算术模型与具体执行推导 |
| [MemoryExamples.v](MemoryExamples.v) | 两地址区域读取与写入交错的完整执行推导 |

数值类型是参数 `Numeric`，例子实例化为 `Z`。`primitive_eval` 和 `compute_eval`
是 Rocq 的纯函数，以 `None` 表示输入不在函数定义域内。
`compute_signature` 声明每个计算函数的输入类型与返回类型，
`well_typed_computations` 要求成功计算符合该签名。
`supports` 检查 pipeline 支持的输入类型及形状；访问权限和存储值类型由 `can_read`、
`can_write`、`type_ok` 给出。模型的声明合法性由 `well_formed_model` 表示。
程序语义要求 `initial_well_formed`，包含声明合法性、程序 pipeline 集合、
初始局部环境范围、内存类型及任务编号条件。

`pipeline_state` 包含 `pipeline_code`、`pipeline_locals`、`pipeline_handles`。
全局状态的 `pipelines` 字段将 `pipeline_id` 映射到这些局部状态；任务的
`task_owner`、锁的持有者和事件端点均使用 `pipeline_id`。

## 操作语义

核心关系的类型为：

```coq
step : model Numeric -> configuration Numeric ->
       label Numeric -> configuration Numeric -> Prop
```

`StepControl` 执行一个控制步骤，`StepTask` 执行一个后台步骤，`StepError`
进入无后继的 `Error`。调度选择由这个归纳关系表示。`pipeline_step` 定义
各个 pipeline 的控制转移；`PipelineSeq` 将控制步骤
放入顺序上下文；条件与循环使用显式控制转移。

`PipelineBegin` 在当前局部环境中求值参数，用 `next_task` 创建任务，并通过
`begin_pipeline` 把编号写入当前 pipeline 的句柄环境。后台读取和写入每次处理
一个地址。`TaskFinishCompute` 根据已捕获的参数计算结果。`PipelineEnd` 要求
任务属于当前 pipeline 且已经 `Done`，通过 `end_pipeline` 写入返回值并删除句柄，
同时从全局任务表中删除该任务。

`PipelineSet` 要求当前 pipeline 的全部在途任务完成，然后将事件设置为 `true`。
`PipelineWait` 消费 `true` 并将事件设置为 `false`。锁规则检查参与权限和持有者；
释放锁时只更新锁状态。程序通过 `end` 保证临界区中的异步访问已经完成。
等待条件未满足时，相应规则不可用；非法操作满足 `pipeline_error`。

`program_semantics` 量化合法初态，包含全部最大有限轨迹和无限轨迹。
`fair_infinite_execution` 额外要求持续可执行的 pipeline 或任务最终被调度；
基本程序语义保留全部调度。

`happens_before` 是控制顺序、任务内部顺序、完成与等待、任务完成与事件设置、
事件设置与消费、锁释放与获取六类边的传递闭包。`po_edge` 和 `task_edge`
直接连接同一主体的所有先后事件，传递闭包与相邻事件形式相同。
`drain_edge` 查询启动历史，包含已经由 `end` 删除的任务。
`flag_edge` 连接最近一次设置与消费它的等待，排除中间发生同一事件的设置或等待。

`Race` 要求两个访问同一地址的不同事件至少包含一次写入，并且两个方向都没有
happens-before 关系。`race_free_from` 对全部有限执行前缀量化。

顺序锁扩展使用 `lock_order := lock_id -> nat -> pipeline_id` 和每把锁的轮次。
`ordered_step` 保留普通语义的标签，在获取时检查该轮参与者，在释放时增加轮次。
`ordered_step_erases` 证明每个顺序锁步骤对应普通语言的一个步骤。

## 已证明的性质

- `step_preserves_freshness`：一次成功执行保持任务编号小于分配计数器。
- `step_begin_allocates_fresh`：启动任务使用的编号在原任务表中不存在。
- `step_compute_kind`：成功启动计算时，操作类别等于所属 pipeline 的类别。
- `terminal_has_no_successor`、`terminal_execution_maximal`：正常终止状态没有后继，到达这种状态的有限执行构成最大轨迹。
- `steps_preserve_freshness`：任务编号条件沿任意有限执行保持。
- `task_step_preserves_control`、`task_step_preserves_sync`：后台步骤保持控制状态、事件和锁。
- `compute_finish_preserves_memory`：纯计算完成时保持共享内存。
- `happens_before_forward`、`happens_before_irreflexive`：happens-before 严格沿轨迹向前，因而无环。
- `independent_async_writes_race`：同一 pipeline 启动的两个独立任务，其相邻冲突写入缺少同步关系时构成竞争。该定理直接描述标签轨迹。
- 顺序锁的获取轮次检查、释放轮次递增、轮次表定义域保持及周期轮转性质。

`Examples.v` 使用实际整数运算，并以 `steps` 构造执行推导。句柄例子得到
`2 + 3 = 5`，pipeline 在等待结果之前计算局部值，最后得到 `15`。
Cube/Vector 例子同时保留两个在途任务，向量结果为 `[11; 22]`，矩阵结果为
`[[19; 22]; [43; 50]]`。另一条执行展示同一 pipeline 上后启动的任务先完成。
错误类别的计算通过 `StepError` 进入 `Error`。

事件例子从异步写入 `41` 开始，依次证明完成、设置事件、取得任务结果和消费事件，
最终检查内存值与清零后的标志。锁例子证明获取锁、异步写入、取得完成结果、
释放锁的完整执行。循环等待例子证明两个 pipeline 等待彼此事件时发生全局死锁。

`MemoryExamples.v` 中的读取先取得地址 `0` 的初值，然后另一个任务写入两个地址，
读取再取得地址 `1` 的新值。最终返回映射同时包含旧值与新值，直接展示区域访问
逐个存储单元推进的语义。

## 验证

在仓库根目录运行：

```sh
opam exec --switch=unified-interpreter -- make -C rocq -f Makefile all
```

新模块已列入 `rocq/_CoqProject`，参与原生 Makefile 构建。单独复核这些模块的
证明可在 `rocq/` 运行：

```sh
opam exec --switch=unified-interpreter -- rocq check -silent -Q . UnifiedInterpreter \
  UnifiedInterpreter.CoreLanguage.Properties \
  UnifiedInterpreter.CoreLanguage.Traces \
  UnifiedInterpreter.CoreLanguage.OrderedLocks \
  UnifiedInterpreter.CoreLanguage.Examples \
  UnifiedInterpreter.CoreLanguage.MemoryExamples
```

形式化覆盖抽象语言定义、上述性质和具体执行推导。硬件执行到该语言的
refinement 定理，以及任意程序的数据竞争自由、无死锁或无饥饿证明，仍需针对
相应硬件模型或程序建立。

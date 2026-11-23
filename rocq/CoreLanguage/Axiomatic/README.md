# Core language 的公理化 trace 定义

定义对应 `docs/core-language-syntax.tex`、`docs/core-language-trace-semantics.tex`，
并包含异步结果提前使用时的取值语义。所有语义条件均定义为 Rocq 谓词。

| 文件 | 审核入口 | 内容 |
| --- | --- | --- |
| `Syntax.v` | `memory_resource`、`SharedAlloc`、`command`、`For` | 内存地址、共享申请、带 SSA 参数的有限循环 |
| `Syntax.v` | `well_formed`、`annotates` | pipeline 声明、作用域、SSA、操作数类别和位置标注 |
| `Syntax.v` | `operations`、`program_order` | 命令头及程序顺序 |
| `Events.v` | `label`、`K`、`interpretation` | 事件种类、载荷及 `EventId -> K` |
| `Events.v` | `command_events`、`program_events` | 从程序递归生成候选事件及使用记录 |
| `TraceSemantics.v` | `candidate_witness`、`Cand` | 有限事件集合的排列和前缀 |
| `TraceSemantics.v` | `A1` 至 `A5`、`A_sync` | 文档中的五项同步公理 |
| `TraceSemantics.v` | `completed_result_values` | 完成之后使用结果的取值约束 |
| `TraceSemantics.v` | `program_semantics`、`raw_program_semantics` | 带标注程序与原始程序的语义 |
| `ResourceExamples.v` | `SharedResource.both_prefixes` | 共享执行资源的两个并发分支可以按两个相反的顺序发起计算 |
| `Issue316.v` | `issue316`、`issue316_trace` | Vector 侧双缓冲程序及其目标配置和计算关系 |
| `Issue316Safety.v` | `issue316_buffer_selection`、`issue316_iteration_address` | 任意合法执行中按轮次选择缓冲区的证明 |

`Float`、`EventId`、`Pipe` 和执行单元类别 `Unit` 是类型参数。
整数使用 `Z`，局部变量使用 `nat`，操作位置使用两个正整数表示分支与位置。
`command unit` 表示原始命令，`command op_id` 表示带位置标注的命令。
`annotates` 要求去除标注后得到展开循环的程序，且位置互异、所属分支正确。
`For index lo hi body next` 在源语法中绑定只读整数变量。标注前按自然数区间 `[lo, hi)`
逐一展开循环体，步长固定为 1。随后 `annotate_program` 按分支和
语法树路径编号。SSA 唯一性和作用域在展开前检查，每轮执行同一静态定义产生该轮的绑定。每个分支的 `AssignPipe`
在赋值事件处取得一个 pipeline 值并更新局部变量，其名称与 SSA 名称分开。
read、write、compute 使用 `Dispatch r None` 直接访问资源，或使用
`Dispatch r (Some v)` 同时指定 pipeline。显式 pipeline 操作数与 flag 的两个
端点均在发起时求值。共享资源本身不产生发起顺序或完成顺序。

有限候选事件集合通过列表枚举；`NoDup` 排除重复，`Permutation` 和 `prefix`
定义其全部排列的前缀。投影使用关系 `projection`，逐个保留所有匹配的事件，
并保持 trace 顺序。`star` 与 `prefix_language` 表达 A4 中 flag 设置与等待交替完成的顺序。
这些定义适用于抽象标识类型，无须要求标识或浮点值具有可计算的相等判定。

异步读取和异步计算均把变量绑定到 `Async producer`。每次实际使用独立选择值，并记录
使用命令、操作数序号、产生结果的操作及使用值。操作数在命令的发起事件处取得；
条件分支和返回在各自的单个事件处取得操作数。`completed_result_values`
要求：当对应 `read_end` 或 `compute_end` 已经先于使用事件出现时，使用值等于完成结果。
提前使用允许任意 `value`，实际命令仍要求 flag 为 `VEvent`、条件为 `VBool`。
读取结果与内存写入之间的关系保持为文档规定的抽象取值。

别名绑定直接传递 `Known` 或 `Async` 绑定，不产生事件。
`Select` 根据已知的布尔条件传递所选操作数的绑定。`let x = compute_atomic[f](args) in C` 对应 `LetAtomic`。它在单个事件中读取实参、执行 `eval_atomic` 并绑定 `Known` 结果。整数运算、整数比较和布尔运算都采用这条规则。`MemoryAt` 根据整数下标取得外部地址表中的一个内存资源。
异步计算按照执行资源的关系 `comp` 选择完成结果，输入采用发起时实际取得的值。
`comp_total` 是该模型参数的全定义性条件。
read、write、compute、setflag 发起后允许当前分支继续执行。
源 pipeline 上先前发起的 compute 必须完成，setflag 才能完成；
目标 pipeline 上 waitflag 后续的 compute 必须等到 waitflag 完成才能发起。
`trace_semantics` 对同一个候选见证同时施加 `A_sync` 和完成结果取值约束。
`program_semantics` 还要求程序良构、标注合法且每个事件满足 `target_allows`。
访问权限按执行资源和内存地址判定。`SharedAlloc` 在启动分支前生成地址，并向所有分支传递同一个绑定。分支内的 `Alloc` 在单个事件中生成地址。共享申请的序号和分支内申请的动态操作标识分别确定地址，地址在一次执行内互异。

在 [GitCode #316](https://gitcode.com/Ascend/AscendNPU-IR/issues/316) 的表示中，
两个 UB 缓冲区分别由一次共享申请取得。搬运分支在第 i 次迭代读取 GM 并写入第 i mod 2
份缓冲区，Vector 分支对 1024 个 f16 元素执行逐元素指数并写回 UB 输出区。
Vector 分支为本次使用的每个 slot 发出初始 released 通知。此后每次搬运等待
该 slot 的 released 并发出 ready，每次计算等待 ready 并在写回后发出 released。程序及同步编码见
`docs/core-language-syntax.tex` 的 Issue #316 一节。`implements_vexp` 由目标提供
单元素 f16 指数语义，`issue316_trace` 沿用抽象内存读取结果。

从 `rocq/` 目录构建：

```sh
opam exec --switch=unified-interpreter -- make CoreLanguage/Axiomatic/Issue316Safety.vo
```

`Issue316.v` 检查任意迭代次数的源程序良构性，以及零次、一次、三次迭代的候选事件。三次迭代的检查覆盖两个分支的读写地址、原子取余和跨 pipeline 通知。`freeA_second_consumption` 证明：对 freeA 的设置和等待各按分支顺序完成时，满足 A4 的交错在第二次等待前已经完成第 0 轮释放。`distinct_allocation_events` 说明 trace 中不同动态申请位置得到不同地址。

`issue316_buffer_selection` 对任意轮数 `count` 和任意满足 `issue316_trace` 的执行成立。按 trace 顺序分别取出 MTE2 搬运写入发起时的地址、Vector 读取发起时的地址，两列都是 `buffer_sequence count` 的前缀。证明对循环展开的轮次列表进行归纳，计算每次 `choose_slot` 选出的共享地址，再用 A2 证明每个分支已发起的访问保持程序顺序。执行可以在任意轮次中途停止，两个前缀的长度可以不同。`issue316_iteration_address` 给出按轮次使用的结论。任一地址序列中下标为 `i` 的地址一旦出现，就有 `i < count`，且偶数轮使用 `bufA`，奇数轮使用 `bufB`。

# 在 HFusion 和 HIVM 模块 AST 上执行 trace

## 1. scheduler 的输入

解释器将内存中的 OCaml 模块 AST 和本次执行的实参传给 `Ir_scheduler.generate_mlir ~configuration stage backend ast`。`stage` 取 `HFusion` 或 `HIVM`，`backend` 取 `Bfs` 或 `Smt`。单个入口使用 `~entry` 和按形参顺序排列的 `arguments`。多个实例通过 `configuration.streams` 分别给出入口和实参。缓冲区通过 `storage` 标识底层分配，`base_bytes` 以字节计，`offset` 和 `strides` 以元素计。命令行从 MLIR 文件读取 AST，供测试使用。[OCaml 接口](../lib/scheduler/ir_scheduler.mli) · [模块 AST 定义](../lib/hivm/hivm_module.mli) · [启动参数](mlir-to-core.md#启动参数)

## 2. scheduler 返回的 trace 结构

两个 IR 层都返回 `hivm-race-1`。报告的 `streams` 给出每个实例的入口，`inputs` 给出 IR 层、AST 标识、实参和初始内存。每个 `races[]` 元素包含两个端点 `first`、`second` 和两条可执行前缀 `forward`、`reverse`。前者以 `second` 结束，后者以 `first` 结束。`status = "complete"` 表示对本次输入完成了分析。`"race"` 表示已找到竞争前缀，可能还有其他竞争。`"unknown"` 表示本次分析无法判定，原因在 `reason` 中。[事件定义](../lib/hivm/hivm_trace.mli)

| 事件字段 | 解释器的使用方式 |
| --- | --- |
| `stream`、`entry`、`path`、`opcode` | 选择实例，在当前函数中用 `Module_ast.resolve ast ~entry path` 取得原始操作。路径从零开始，每进入一层区域，依次给出父操作、region、block 的下标。 |
| `iterations`、`calls` | 循环轮次从零开始。嵌套调用的 `calls` 从最外层开始，每项记录调用者的 `entry`、调用指令的 `path` 和调用时的 `iterations`。事件自身的 `iterations` 属于当前函数。 |
| `phase`、`tasks` | `execute` 执行当前操作。按 `submit` 保存本次调用的实参和待完成任务，按 `complete` 完成相应任务。使用 `(stream, tasks[].id)` 配对。HFusion 的异步任务使用 `HFUSION_ASYNC`，HIVM 的任务记录设备管线。 |
| `action`、`signals`、`part` | `action` 区分计算、置位、等待和屏障。`signals` 给出涉及的同步信号。同一源操作有多个阶段时，`part` 指定当前阶段。 |

## 3. interpreter 如何利用 trace

从同一份初始内存分别执行两次，每次选择一条前缀。解释器自行执行常量、标量运算、分支和地址分配。到达需要调度的位置时，读取下一个事件。若为 `submit` 或 `execute`，推进指定实例到相应的动态位置并执行动作。若为 `complete`，从待完成任务中找到相同编号的任务，执行其中的读写，然后继续读取 trace。每个事件只消费一次。前缀执行完毕后，需要完整执行结果时，可选择任意合法调度运行到程序结束。[位置查询接口](../lib/hivm/hivm_module.mli)

## 4. fifo-copy 例子

`fixture/fifo-copy` 的 HIVM 入口 `@stream_0` 在路径 `[10]` 和 `[19]` 两次调用 `@copy`。第一次将 `x[0]` 复制到 `x[1]`，第二次将 `x[1]` 复制到 `x[2]`。初始值为 `[7, 0, 0]`。解释器依次执行两处调用之前的视图和索引计算，按两个 `submit` 事件保存实参。此时两次复制都还在等待完成。[HIVM 源程序](../benchmarks/ir-pairs/fixture/fifo-copy/hivm.mlir)

| 前缀 | 两个 `complete` 事件对应的调用位置 | 完成后的内存 |
| --- | --- | --- |
| `forward` | `[10]`、`[19]` | `[7, 7, 7]` |
| `reverse` | `[19]`、`[10]` | `[7, 7, 0]` |

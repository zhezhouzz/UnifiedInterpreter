# 用 scheduler 的 trace 执行 HIVM OCaml AST

本文描述已登记 HIVM 程序的 `hivm-race-1`。直接传入解析所得的 OCaml 模块 AST 时，HFusion 和 HIVM 共用模块接口。[模块接口和 fifo-copy 示例](scheduler-traces.md)

## 1. scheduler 的输入

**最终集成时，interpreter 将内存中的 HIVM OCaml AST 直接传给 scheduler。当前从文件读取 AST 仅用于 benchmark 测试。**

对于已登记的 benchmark，调用方传入目录 `catalog`、程序名称 `name` 和 AST，再选择后端。以下代码使用 BFS。对于带参数的程序，可用 `H.generate ~n` 指定具体输入，或用 `Benchmark_traces.Symbolic` 求解 `n`。在 Dune 中声明 `(libraries hivm_trace unified_interpreter)`。[调用接口](../lib/hivm/hivm_trace.mli#L47) · [benchmark 目录](../lib/race_benchmarks.ml#L116)

```ocaml
open Unified_interpreter
module H = Hivm_trace

let report_for catalog name (ast : H.Module_ast.t) =
  H.generate (Benchmark_traces.Concrete Search) (H.registered_module catalog name ast)
```

`fixture/hivm-two-loads`、`issue316/ordered` 和 `issue316/missing-ready` 使用单函数类型 `Attention_runtime.Parser.program`，对应入口是 `H.registered catalog name ast`。文件测试可通过 `race list --json` 的 `hivm_ast` 字段查找文件，再用 `H.registered_file catalog name file` 或命令行的 `--hivm-ast FILE` 传入。[单函数 AST](../attention/parser.ml#L24) · [文件接口](../lib/hivm/hivm_trace.mli#L49) · [命令行接口](../bin/race.ml)

## 2. scheduler 返回的 trace 的结构

scheduler 返回 `H.report`，对应的 JSON 格式为 `hivm-race-1`。`benchmark` 标识程序，`streams` 将流编号映射到入口函数，`n` 是选定的参数值，固定输入时可以为 `null`。`inputs` 描述入口实参和初始内存，`races` 中每一项对应一对竞争访问。[报告与事件类型](../lib/hivm/hivm_trace.mli#L19)

- `first` 和 `second` 是两次目标访存各自生效的事件。
- `forward` 和 `reverse` 的类型都是 `event list`，各自给出包含这对竞争事件的合法执行前缀。`forward` 先经过 `first`，以 `second` 结束。`reverse` 先经过 `second`，以 `first` 结束。前缀结束时，程序可能还有后续指令或已提交但尚未完成的任务。

每个事件包含指令位置、`phase` 和 `action`。位置在 OCaml 中是 `event.location`，在 JSON 中展开为 `stream`、`entry`、`path`、`opcode`、`part` 和 `iterations`。事件位于被调用的函数内时，`calls` 按调用顺序给出各调用点的 `entry`、`path` 和 `iterations`。`phase` 表示提交、完成或立即执行，`tasks` 列出的每个任务有 `id` 和 `pipe`。`action` 表示计算或访存、通知、等待或屏障。`signals` 中的每项包含接收流 `receiver`、源管线 `source`、目标管线 `target`、`flag` 编号和跨流标记 `cross`。等待事件还可以带发送流列表 `senders`。[事件类型](../lib/hivm/hivm_trace.mli#L5) · [JSON 字段](../lib/hivm/hivm_trace.ml#L431)

`status` 为 `"complete"` 或 `"race"` 时可以逐对回放。`races = []` 表示没有可回放的前缀。`"no-race"` 表示没有数据竞争，`"unknown"` 表示尚无判定，原因见 `reason`。[报告状态](../lib/hivm/hivm_trace.mli#L24)

## 3. interpreter 如何利用 trace

分别执行 `forward` 和 `reverse`。每次从相同的入口实参、初始内存和空的待完成任务表开始。每条流独立保存程序位置、SSA 值和循环轮次，即使多条流调用同一个入口。根据 `report.inputs` 准备初始状态。

- **模块格式的 fixture、regression 和 Litao** 使用 `bindings[].stream` 选择流，将 `arguments` 按入口形参顺序绑定。整数直接使用，具有相同 `storage` 名称的实参引用同一块内存，`bytes` 给出字节数。按 `initial` 初始化，再按可选的 `initial_cells` 覆盖指定元素。相同的 `descriptor_slot` 共享一个初始为空的描述符槽。Litao 的 `coordinates` 提供 block、核类型和 subblock。`initial_default` 给出默认值，`ub:流:字节偏移` 和 `cc:流:字节偏移` 从该位置初始化 `tile` 个元素，`"identity"` 表示各通道依次访问连续元素。[输入字段](../lib/hivm/catalog_inputs.ml) · [间接访存输入示例](../benchmarks/litao/L2/indirect-atomic/case.json)
- **vectorlayout** 使用 `inputs.coordinates` 选择 block 和 Cube 或 Vector 子块。`inputs.bindings` 以 `arg0` 至 `arg27` 为键。调用 `Vectorlayout_input.make_hivm (Device_trace.parse_config config)`，其中 `config` 取自 `inputs.config`，即可重建这组实参和初始内存。[输入构造](../lib/vectorlayout_input.ml#L72) · [配置解码](../lib/device_trace.ml#L38)
- **三个单函数用例** 使用调用方的缓冲区。`inputs.arguments` 给出形参名称和顺序，将 `report.n` 绑定到 `inputs.n_argument` 指定的形参。例如 `@two_loads` 接收 `%a`、`%b`、`%dst`、`%n`。[two-loads 入口](../examples/kernels/two_loads_hivm.mlir) · [调用示例](../test/test_hivm_trace.ml)

对 `inputs.ast_format = "hivm-module-1"` 的模块，在传给 scheduler 的同一份 AST 上定位指令。单函数用例调用 `H.resolve ast path`。[模块定位接口](../lib/hivm/hivm_module.mli) · [单函数定位接口](../lib/hivm/hivm_trace.mli#L32)

```ocaml
let instruction ast (event : H.event) =
  let loc = event.location in
  H.Module_ast.resolve ast ~entry:loc.entry loc.origin.path
```

每次查看一个事件，按 `phase` 决定推进指定流还是完成待执行的任务。沿 AST 遇到 `memref.alloc` 或 `memref.alloca` 时，解释器按当前实参分配缓冲区、绑定 SSA 结果，trace 游标保持原位。到达事件指定的动作并执行后，才读取下一项。

| JSON 的 `phase` | 解释器执行的动作 |
| --- | --- |
| `submit` · `Submit tasks` | 沿指定流的 AST 执行到本次调度动作。途中按正常语义执行算术、视图构造、循环和分支。到达目标后求出实参，为 `tasks` 中的每个 `id` 保存指令、阶段、管线、标量值和缓冲区引用。访存计算留到完成时执行。 |
| `complete` · `Complete task` | 取出 `tasks[0].id` 对应的已提交任务，执行它的当前阶段并移除任务。此时读取缓冲区的当前内容并写回结果。提交该任务的流保持当前位置，即使它已经越过原指令，也能完成这个任务。 |
| `execute` · `Execute pipe` | 沿指定流执行普通指令，到达目标后立即执行当前动作。`tasks` 为空，`synchronous_pipe` 给出管线或 `null`。例如标量 `memref.store` 立即写入内存。 |

`path` 从事件的 `entry` 函数体开始，所有下标从零计数。模块路径依次给出指令下标，以及嵌套的 region、block、子指令下标。单函数路径逐层给出 `body` 和 `region` 中的指令下标。`iterations` 是当前函数从外到内的循环轮次，从零开始，实际循环变量由 AST 求值。`scf.while` 每次进入 `do` 区域计一轮。[模块定位](../lib/hivm/hivm_module.mli) · [单函数定位](../lib/hivm/hivm_trace.ml#L13)

`compute` 执行计算或访存。事件指向异步 `func.call` 时，通过节点的 `properties["callee"]` 找到函数，在任务完成时执行函数体。事件带有 `calls` 时，沿这些普通调用进入目标函数。例如在 `fixture/shared-allocation` 中，流 0 进入 `@reserve` 后自行执行 `memref.alloc`，到达将描述符写入共享槽的 `memref.store` 时消费 `execute` 事件。随后流 1 的任务可以通过共享槽访问该缓冲区。[共享分配示例](../benchmarks/ir-pairs/fixture/shared-allocation/hivm.mlir)

`set` 为 `signals` 中的每一项发出通知，`wait` 消耗对应通知。等待事件带有 `senders` 时，从列出的每个发送流各消耗一次通知。对于 `barrier`，每次提交和完成的管线由当前事件的 `tasks` 指定。[同步动作与调用示例](../test/test_vectorlayout_hivm.ml#L11)

同一条指令的一次执行可以对应多个事件。用 `(stream, calls, entry, path, iterations)` 关联这次执行的中间结果，用 `part` 区分阶段。JSON 省略 `calls` 时按空列表处理。例如 `mmadL1` 的 `load` 阶段搬运矩阵，`compute` 阶段使用已搬运的数据，其间的同步按各自事件执行。同一个屏障也可能按管线分别提交。[复合指令的回放示例](../test/test_vectorlayout_hivm.ml)

**前缀执行完毕后，两次竞争访问都已发生。** 如果只需要观察这对访问，interpreter 可以在此返回当前状态。如果需要完整 trace，就从该状态继续，保留各流的程序位置、SSA 值、内存、同步状态和待完成任务。后续可以采用任意合法的调度方式运行至执行结束，将后续事件按发生顺序追加到该前缀。

## 4. 例子

在仓库根目录运行以下命令即可取得 `fixture/fifo-copy` 的两条 trace。[命令行接口](../bin/race.ml)

```sh
dune exec ./bin/main.exe -- race run fixture/fifo-copy --hivm --save _build/fifo.json
```

`@stream_0` 在路径 `[10]` 调用 `@copy`，将 `x[0]` 复制到 `x[1]`。在路径 `[19]` 再次调用它，将 `x[1]` 复制到 `x[2]`。两次调用都在 `PIPE_V` 上。输入为 12 字节的 `gm:0`，三个 `i32` 元素的初始值为 `[7,0,0]`。[fifo-copy 的 HIVM AST](../benchmarks/hivm/fixture/fifo-copy.ast.json)

两条列表的第一个事件相同。解释器先执行路径 `[10]` 之前的常量和索引计算，再将第一次调用的实参保存到任务 1。

```json
{"entry":"@stream_0","stream":0,"path":[10],"opcode":"func.call","part":null,"iterations":[],"action":"compute","phase":"submit","tasks":[{"id":1,"pipe":"PIPE_V"}],"signals":[],"synchronous_pipe":null}
```

第二个事件在路径 `[19]` 提交任务 3。解释器执行两次调用之间的普通指令，保存第二次调用的实参。此时内存仍为 `[7,0,0]`。

- `forward` 随后完成任务 1，再完成任务 3。任务 1 将 7 写入 `x[1]`，任务 3 从中读取 7 并写入 `x[2]`，得到 **`[7,7,7]`**。
- `reverse` 随后完成任务 3，再完成任务 1。任务 3 从 `x[1]` 读取初始值 0，任务 1 随后更新 `x[1]`，得到 **`[7,7,0]`**。[按两条 trace 执行复制函数的示例](../scripts/check_fifo_hivm.py)

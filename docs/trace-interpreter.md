# 在 HIVM OCaml AST 上按 trace 执行

## 取得两条 trace

解释器持有本次调用的 HIVM AST 和输入。`fixture/hivm-two-loads` 和两个 `issue316` 用例使用 `Attention_runtime.Parser.program`。其余 75 个用例使用 `Hivm_trace.Module_ast.t`。将 `hivm_trace` 加入 Dune 的 `libraries` 后可以取得 `Hivm_trace.report`。如果调用方已经传入报告，从 `report.races` 开始即可。[单函数 AST](../attention/parser.ml#L10) · [模块 AST](../lib/hivm/hivm_module.mli) · [trace 类型和接口](../lib/hivm/hivm_trace.mli)

```ocaml
open Unified_interpreter

let traces_for ast =
  let catalog = Race_benchmarks.catalog "benchmarks/litao" in
  let input = Hivm_trace.registered catalog "fixture/hivm-two-loads" ast in
  Hivm_trace.generate ~n:1 (Benchmark_traces.Concrete Search) input
```

`registered` 接收单函数 OCaml AST。持有 AST 文件时，使用 `registered_file catalog name file`。`streams` 给出流编号与入口函数。`n` 是具体参数，包括符号求解找到的值。对于单函数用例，`inputs.n_argument` 给出对应形参。每对竞争包含两条 `event list`，从相同的参数、内存和各流的初始状态分别执行。`forward` 先完成 `first` 再完成 `second`，`reverse` 的顺序相反。[调用接口](../lib/hivm/hivm_trace.mli)

独立进程可以直接使用命令行取得同一结果。两端通过文件传递 `hivm-race-1` JSON，解释器使用自己的 OCaml AST 解析事件路径。`status = "unknown"` 表示没有得出判定。[命令行入口](../bin/race.ml)

```sh
dune exec ./bin/main.exe -- race run fixture/fifo-copy --backend bfs --hivm --save _build/fifo.json
dune exec ./bin/main.exe -- race run fixture/hivm-two-loads --backend bfs --n 1 \
  --hivm-ast benchmarks/hivm/two_loads_hivm.ast.json --save _build/two-loads.json
```

## 何时读取下一个事件

每次查看一项。用 `event.location.stream` 选择流，用 `entry` 选择函数，调用 `Hivm_trace.resolve ast event.location.origin.path` 取得原始指令。路径下标从 0 开始，逐层进入 `body` 和 `region`。`iterations` 是从外到内、本次执行所在的循环轮次，第 0 轮表示第一次进入循环体；循环变量的值按 AST 的初值和步长计算。`origin.part` 在复合指令中指定当前阶段，例如 `mmadL1` 的 `load`、`signal_loaded`、`wait_loaded`、`compute`。[事件字段和定位接口](../lib/hivm/hivm_trace.mli#L5)

| 当前事件的 `phase` | 解释器执行的动作 |
| --- | --- |
| `Submit tasks` | 将相应流推进到指定指令和轮次。沿途按 AST 执行常量计算、视图构造、循环控制等普通操作。在提交点求出标量实参和缓冲区视图，为每个 `task.id` 保存指令、阶段、实参和 `task.pipe`。一个全管线屏障可以一次提交多个任务。 |
| `Complete task` | 用 `task.id` 取出已经提交的任务，按 `action` 执行当前阶段，然后移除任务。计算任务此时读取视图指向的当前内存并写回结果。这个事件可以出现在同一流下一条 AST 指令提交之前。 |
| `Execute pipe` | 将对应流推进到指定位置，当场执行这次操作。例如 `Execute None` 分配缓冲区，`Execute (Some S)` 执行标量访存或标量等待。 |

`action` 区分 `Compute`、`Allocate`、`Barrier`、`Set signals` 和 `Wait signal`。同步事件给出接收流、源管线、目标管线、实际 flag 编号和是否跨流。复合指令用 `(stream, entry, path, iterations)` 关联各阶段的中间结果。例如 `mmadL1` 的 `load` 完成时保存矩阵，`compute` 完成时使用这份矩阵。当前事件完成后才读取下一项。列表结束时返回当前状态，保留此时仍待完成的任务。JSON 中的 `races[i].forward` 和 `reverse` 直接包含按序排列的事件对象。[动作和序列化接口](../lib/hivm/hivm_trace.mli) · [按任务编号消费 trace 的 OCaml 示例](../test/test_hivm_trace.ml#L13)

## 在模块 AST 上执行

当 `inputs.ast_format = "hivm-module-1"` 时，`entry` 标识模块中的入口函数。`path` 从该函数的第一个 block 开始，下标依次表示指令、region、block、子指令。例如 `[56;0;0;19;1;0;14]` 进入下标 56 的循环体，再进入下标 19 的 `scf.if` 的 `else` 区域，取得下标 14 的指令。所有下标从零开始。以下代码直接返回带实参和属性的 HIVM 节点。解释器也可以读取对应的 MLIR 文件，调用 `resolve_in` 并传入自己的函数体和 region 访问函数。[模块 AST 与定位接口](../lib/hivm/hivm_module.mli) · [正确版 MLIR](../benchmarks/hivm/vectorlayout_ok.mlir) · [失败版 MLIR](../benchmarks/hivm/vectorlayout_fail.mlir)

```ocaml
module H = Hivm_trace
let ast = H.Module_ast.read "benchmarks/hivm/vectorlayout_ok.ast.json"
let locate (event : H.event) =
  H.Module_ast.resolve ast ~entry:event.location.entry event.location.origin.path
```

对 Litao、regression 和模块格式的 fixture，`inputs.bindings` 的每项给出 `stream` 和按入口形参顺序排列的 `arguments`。整数直接绑定到形参；具有相同 `storage` 名称的参数共享内存，`bytes` 给出长度。按 `initial` 填充对应内存，再按 `initial_cells`（如有）覆盖指定元素。Litao 的 `coordinates` 给出每条流的核类型、block 和 subblock。`ub:流:字节偏移` 和 `cc:流:字节偏移` 初始化该位置起的 `tile` 个元素，`identity` 表示依次访问连续元素，其余位置使用 `initial_default`。[输入字段](../lib/hivm/catalog_inputs.ml) · [Litao 输入例子](../benchmarks/litao/L2/indirect-atomic/case.json)

遇到 `func.call` 时，按节点的 `callee` 进入同一模块的函数。异步调用在 `Submit` 时保存实参，在 `Complete` 时执行函数体。共享分配用例中，两条流的 `descriptor_slot` 参数指向同一个初始为空的描述符槽。`Execute None` 指定的 `@reserve` 当场分配并写入描述符；另一个入口的访存函数在完成时读取它。对于 `scf.while`，`iterations` 记录进入 `do` 区域的轮次，从零开始。[共享分配的模块](../benchmarks/hivm/fixture/shared-allocation.ast.json) · [嵌套循环的模块](../benchmarks/hivm/regression/nested-descending.ast.json)

### vectorlayout 的 Cube 和 Vector 入口

- `n` 是 token 数。`inputs.coordinates` 给出每条流的 block 和 Cube 或 Vector 子块编号。`inputs.bindings` 按 `arg0` 至 `arg27` 给出两个入口的完整实参。从 `inputs.config` 调用 `Vectorlayout_input.make_hivm (Device_trace.parse_config config)` 可以重建初始内存和实参。两个入口均未引用的 ABI 参数 0、1 使用空 GM 缓冲区，10、11 使用整数零。[输入构造](../lib/vectorlayout_input.ml#L72) · [配置解码](../lib/device_trace.ml#L38)
- `func.call` 的 `Submit` 保存调用实参，`Complete` 通过节点的 `properties["callee"]` 找到函数，在本次完成动作内执行函数体，包括其中的 AVE 指令。`mmadL1` 的 `load` 和 `compute` 分别执行搬运和矩阵计算，其余阶段按事件中的 `Set` 或 `Wait` 执行。标量任务也可能有独立的提交与完成事件，按实际 `phase` 执行。[实际消费示例](../test/test_vectorlayout_hivm.ml)
- 跨核等待 `Wait_all (senders, signal)` 在完成时消耗每个指定发送流的一次通知，JSON 的 `senders` 给出相同的流编号。全管线屏障的各管线可以分别提交同一 AST 节点。每次只处理当前事件列出的任务。[事件类型](../lib/hivm/hivm_trace.mli)

## 例子：同一条管线上的两次复制

`@two_loads` 在第 0 轮先提交 A，将 GM 中的 `%a` 复制到 UB 中的 `%dst`，再提交 B，将 `%b` 复制到同一个 `%dst`。两条指令都是 `PIPE_MTE2` 上的 `hivm.hir.load`。A 的路径是 `[2; 0]`，B 的路径是 `[2; 1]`，两者的 `iterations` 都是 `[0]`。[HIVM 程序](../examples/kernels/two_loads_hivm.mlir#L3) · [程序的 AST](../benchmarks/hivm/two_loads_hivm.ast.json)

取 `%n = 1`、`%a[0] = 7`、`%b[0] = 9`。两条 trace 的前两个事件相同。解释器先执行两个 `arith.constant`，进入 `scf.for`，处理 `Submit A` 并记录任务 2；随后处理 `Submit B` 并记录任务 4。此时两次复制均已提交。

| trace | 第三个事件 | 第四个事件 | 前缀结束时的 `%dst[0]` |
| --- | --- | --- | --- |
| `forward` | `Complete 2`，从 `%a` 读取 7 | `Complete 4`，从 `%b` 读取 9 | 9 |
| `reverse` | `Complete 4`，从 `%b` 读取 9 | `Complete 2`，从 `%a` 读取 7 | 7 |

这里的 2 和 4 是这份报告分配的任务编号。解释器从 `Submit` 事件取得它们。[该输入的回归测试](../test/test_hivm_trace.ml#L42)

`fixture/fifo-copy` 的模块入口 `@stream_0` 有两次对 `@copy` 的调用。A 复制 `x[0] → x[1]`，B 复制 `x[1] → x[2]`。两条 trace 都从 `x = [7,0,0]` 开始，先提交 A 和 B。按 A、B 的顺序完成时，B 读取 A 写入的 7，得到 `[7,7,7]`。按 B、A 的顺序完成时，B 读取初始值 0，得到 `[7,7,0]`。[fifo-copy 模块](../benchmarks/hivm/fixture/fifo-copy.ast.json) · [执行两个完成顺序的示例](../scripts/check_fifo_hivm.py)

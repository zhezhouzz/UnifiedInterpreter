# 在 HFusion AST 上使用 scheduler trace

本文介绍单函数张量 AST 的 `hfusion-race-1` 接口。直接传入解析所得的 OCaml 模块 AST 时，使用支持跨函数调用和多个 region 的模块接口。[两层共用的模块接口](scheduler-traces.md)

## 1. scheduler 的输入

调用 `Hfusion_trace.prepare program launch`。直接传入解释器的 `Attention_runtime.Parser.program`。一个 launch 是同一个函数的并发实例列表，列表下标就是 `stream`。每个实例按照 AST 顺序运行，拥有独立的 SSA 环境。命令行的 MLIR 和 AST JSON 输入供测试使用。[OCaml 接口](../lib/hfusion/hfusion_trace.mli) · [AST 定义](../attention/parser.ml)

每个实例按 SSA 参数名提供实参。整数和浮点数使用 `Integer` 和 `Float`。每个 `Buffer` 给出底层分配标识 `allocation`、容量 `elements`、视图的 `offset`、`shape`、`strides`。偏移、容量和步长以元素计数。同一个分配标识表示共享内存，所有引用须具有相同的容量、元素类型和初始状态。`initialized=true` 表示启动时整块分配都可读取，`false` 表示启动时整块都未初始化。解释器保留实际张量数据。

调用 `generate Bfs` 或 `generate Smt` 获取具体输入上的竞争。实参中出现 `Parameter` 时，通过 `~n` 指定其值。调用 `generate Symbolic` 时，所有 `Parameter` 代表同一个非负整数，范围由参数的 IR 类型决定。解释器使用报告的 `n` 回放两条 trace。[调用示例和数值回放测试](../test/test_hfusion_trace.ml)

单函数接口支持 vector-add、row-sum、flash-attention 和 strided-output 使用的张量计算、缓冲区操作、索引运算和 `scf.for`。`linalg.reduce` 的 region 支持标量算术和 `linalg.yield`。每个实例内的指令依程序顺序完成，实例之间可以交错执行。[HFusion 指令范围](hfusion-instruction-scope.md)

## 2. scheduler 返回的 trace 结构

报告包含 `entry`、启动实参、`n`、`status` 和 `races`。JSON 格式为 `hfusion-race-1`，启动实参在 `inputs` 中。具体分析的 `complete` 表示已列出该输入上所有可以交换完成顺序的冲突指令对。符号分析返回 `race`、`no-race` 或带原因的 `unknown`。每个竞争包含 `first`、`second` 和两条合法前缀。两次执行使用相同的输入和初始内存。

| 字段 | 如何使用 |
| --- | --- |
| `forward` | `first` 先完成，最后一个事件是 `second`。 |
| `reverse` | `second` 先完成，最后一个事件是 `first`。 |
| `event.stream`、`event.entry` | 确定程序实例和函数。 |
| `event.path`、`event.opcode` | `resolve program path` 返回原 AST 指令。路径是函数体及嵌套 region 中从零开始的指令下标。 |
| `event.iterations` | 从外到内的循环轮次，各自从零开始计数。 |
| `phase` | JSON 中固定为 `execute`。一次事件执行一条同步 AST 指令。 |

## 3. interpreter 如何利用 trace

1. 为每个实例保留程序位置、循环轮次和 SSA 环境。共享分配对应同一份内存。执行第二条前缀前，重新建立初始状态。
2. 读取下一个 trace 事件，选择它指定的实例。沿该实例的正常控制流执行，遇到 `memref.alloc` 时自行分配缓冲区并绑定 SSA 结果，trace 游标保持原位。当 `scheduling_point prepared ~stream ~path` 为真时，核对当前路径、opcode 和循环轮次，执行整条指令，再消费该事件。
3. `bufferization.to_tensor` 创建的是可引用原内存的张量视图。带 `restrict` 时，建立别名约束本身是一个调度点。使用该视图的张量指令才读取数据。`memref.copy` 在同一条指令内读取源视图并写入目标视图，`bufferization.materialize_in_destination` 写入目标视图。普通索引计算和只处理自有张量的计算由解释器自行执行。[指令执行函数](../attention/runner.ml) · [缓冲区与张量的内存语义](../rocq/HFusion/Semantics/Memory.v)
4. 前缀结束时保留所有实例的当前位置和内存。如果需要完整执行，可继续使用任意合法调度，直到程序结束。`replay` 可以检查单条前缀，`verify_race` 可以核对两条前缀及其竞争端点。[接口](../lib/hfusion/hfusion_trace.mli)

## 4. 例子

`strided-output` 启动两个实例，共用一个有 7 个元素的输出。每个实例把自己的输入转换为 f16，然后在循环中写入 `output[lane + iv % 4]`。实例 0 的 `lane=0`，实例 1 的 `lane=3`，两个实例都从 `iv=0` 开始。[HFusion 程序](../benchmarks/hfusion/strided-output.mlir) · [启动参数](../bin/hfusion_race.ml)

运行以下命令，符号分析返回 `n=4`。前四轮中，实例 0 写入下标 0、1、2、3，实例 1 写入下标 3、4、5、6。第一处竞争发生在 `output[3]`。两条指令的 AST 路径都是 `[5,3]`，opcode 都是 `bufferization.materialize_in_destination`。

```sh
opam exec --switch=unified-interpreter -- dune exec unified-interpreter -- \
  race run strided-output --hfusion --backend symbolic --save _build/hfusion-race.json
opam exec --switch=unified-interpreter -- dune exec unified-interpreter -- \
  race replay _build/hfusion-race.json --hfusion
```

在 `forward` 中，实例 0 第四轮的写入先完成，前缀以实例 1 第一轮的写入结束。在 `reverse` 中，实例 1 第一轮的写入先完成，前缀以实例 0 第四轮的写入结束。解释器在两次回放中都自行执行 `arith.remsi`、`arith.addi` 和 `memref.reinterpret_cast` 来计算实际写入地址。

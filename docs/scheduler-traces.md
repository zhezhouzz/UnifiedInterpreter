# HFusion 和 HIVM 的调度 trace

## 1. scheduler 的输入

在 OCaml 中调用 `Ir_scheduler.generate ~name backend program`，其中 `backend` 为 `Bfs` 或 `Smt`。对于模块 AST，传入 `Module (stage, ast, Ir_scheduler.explicit inputs)`，`stage` 选择 `HFusion` 或 `HIVM`。解释器直接传入内存中的 AST。命令行使用登记的文件测试同一接口。[公共接口](../lib/scheduler/ir_scheduler.mli) · [模块 AST 和位置查询](../lib/hivm/hivm_module.mli)

`inputs.instances` 中每项给出 `stream`、入口函数 `entry` 和按参数顺序排列的 `arguments`。缓冲区的 `storage` 标识底层分配，`bytes` 是容量，`offset_bits` 是起始位偏移，`shape` 是逻辑形状，`strides` 以元素计数。共用分配的视图共用内存。场景 1 的 `grid`、各实例的 `core/block/subblock` 和 `local_storage_bits` 描述配置。`memory[storage][位偏移]` 覆盖 `initial_default`，`model` 记录选出的长度和索引。其他 benchmark 沿用各自的初始内存约定。[输入绑定](../scripts/scheduler_inputs.py) · [场景 1 输入](../scripts/scheduler_scene.py) · [已有的内存初始化约定](trace-interpreter.md#3-interpreter-如何利用-trace)

已有的单函数张量 AST 可以传入 `Tensor (Hfusion_trace.prepare ast launch)`，已有的 HIVM 配对可以传入 `Device pairing`。这两个入口保留原有的输出格式。[张量 trace](hfusion-trace-interpreter.md) · [HIVM trace](trace-interpreter.md)

## 2. scheduler 返回的 trace 结构

模块报告使用 `format = "ir-race-1"`。`stage` 和 `source_sha256` 标识 IR，`inputs` 固定本次执行的实参和内存。每个 `races[]` 元素含 `first`、`second`、`forward` 和 `reverse`。两条前缀分别以第二个和第一个端点结束。`complete` 表示所给输入上的分析已完成，`races=[]` 表示没有竞争前缀。`race` 表示已找到可回放的竞争，后面可能还有其他竞争。

| 事件字段 | 解释器中的含义 |
| --- | --- |
| `stream`、`entry`、`path`、`opcode` | 指定实例和当前函数的原始指令。路径由外到内，每深入一层给出指令、region、block 三个下标，最后一个下标选择指令。下标从零开始。 |
| `iterations`、`calls` | 当前函数从外到内的循环轮次，以及从入口到当前函数的调用位置。每个调用位置含调用者的函数、指令路径和循环轮次。 |
| `phase` | `execute` 立即执行，`submit` 提交任务，`complete` 完成指定任务。后两种事件携带 `task` 和 `pipe`。以 `(stream, task)` 区分待完成任务。向量函数调用另带 `callee`。 |
| `reads`、`writes` | 设备访存事件可附带实际访问区间。每项为 `[storage, begin_bit, end_bit]`，包含起始位，结束位取开区间。 |

## 3. interpreter 如何利用 trace

两次运行均从报告中的同一初始状态开始。查看下一个事件，选择对应实例，沿实际控制流执行其中的普通指令。到达 trace 指定的同步指令或任务提交位置时，执行该动作并消费事件。遇到 `complete` 时，从待完成任务表取出相应任务，使其读写生效。未获调度的实例可以保持就绪。前缀结束后，需要完整执行结果时，继续使用任意合法调度直到程序结束。可以用 `Ir_scheduler.replay_module ast report` 检查模块 trace。[回放接口](../lib/scheduler/ir_scheduler.mli)

## 4. CV 场景 1 的例子

```sh
dune exec unified-interpreter -- race run cv/scene1/error --hivm --backend smt --save _build/scene1.json
dune exec unified-interpreter -- race replay _build/scene1.json --hivm
```

在登记的单个 block 配置下，HIVM 启动一个 AIC 和两个 AIV。报告中的一个 AIV 在第一轮循环里提交两个 `PIPE_V` 任务。第一个向量函数写入 UB 字节区间 `[64,576)`，第二个向量函数读取并写回同一区间。`forward` 先完成第一个任务，`reverse` 先完成第二个任务。两个变体的 HIVM 都能生成这对前缀。相同配置的 HFusion 只有一个顺序执行的函数实例，返回空集。这里检查的性质是访存完成顺序能否交换。归档中的 `correct` 和 `error` 是精度标签。[HIVM 源程序](../benchmarks/ir-pairs/cv/scene1/error/hivm.mlir) · [HFusion 源程序](../benchmarks/ir-pairs/cv/scene1/error/hfusion.mlir)

在仓库根目录运行以下命令可复现全量测试。逐条结果包含每个后端的状态和竞争对数，原始 JSON 报告保存在 `_build/scheduler-matrix`。测试核对两种后端的输入、端点、正反顺序、原始 AST 位置和异步任务身份。[测试脚本](../scripts/check_scheduler_matrix.py) · [168 行测试结果](../benchmarks/results/scheduler-matrix.csv)

```sh
dune build bin/main.exe
.venv-attention/bin/python -B scripts/check_scheduler_matrix.py --results benchmarks/results/scheduler-matrix.csv
```

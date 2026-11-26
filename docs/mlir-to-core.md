# HFusion 和 HIVM 到 Core Language

## 从模块 AST 生成源级 trace

解释器持有 OCaml 模块 AST 时，调用 `Ir_scheduler.generate_mlir ~configuration stage backend ast`。测试可以调用 `Hivm_trace.Module_ast.parse` 从 MLIR 文本取得相同类型的 AST。自定义汇编由 xDSL 读取，需要注册设备方言时，向解析器传入 `BiSheng path`，使用 `bishengir-opt` 输出 generic assembly 后读取。[公共接口](../lib/scheduler/ir_scheduler.mli) · [解析接口](../lib/hivm/hivm_module.mli) · [解释器使用指南](scheduler-traces.md)

转换在生成每个可调度的 Core 指令时登记来源。查询键为实例编号和 Core 指令路径，记录内容包括源函数中的操作路径、操作名称、调用位置和复合操作的阶段。BFS 和 SMT 使用转换得到的 Core 程序及本次启动的输入生成 trace。导出时，静态来源与每个事件的循环轮次、调用实例和任务编号共同确定解释器要执行的源动作。[Core 转换](../lib/hivm/mlir_lowering.ml) · [设备操作转换](../lib/hivm/mlir_device.ml) · [trace 导出和回放](../lib/hivm/hivm_trace.ml)

## 启动参数

- `stage` 可以指定为 `hfusion` 或 `hivm`。单个实例使用 `entry` 和按入口形参顺序排列的 `arguments`。标量使用 JSON 数字或布尔值。静态形状的缓冲区可以用 `null`，动态形状使用 `{"shape":[...]}`。
- 缓冲区的 `storage` 指定底层分配，同名存储允许别名。`bytes` 是底层分配的字节数，`base_bytes` 是相对分配起点的字节偏移，`offset` 和 `strides` 按元素计。`initial` 从底层存储起点按元素给出初始内容。
- 多个实例使用 `streams`，每个实例可以给出入口、实参、`block`、`core`、`subblock` 和 `pipes`。实例按数组顺序从零编号。跨实例同步的 `edges` 包含发送和接收实例的编号对。[启动参数实现](../lib/hivm/mlir_launch.ml)

## 从命令行生成、回放和导出

配置项目 OCaml switch 和 xDSL 环境后，在仓库根目录运行。例如，将以下启动参数保存为 `_build/issue316-launch.json`。对应程序的循环执行三次。[#316 缺少等待的 HIVM 程序](../examples/kernels/issue316_missing_ready_hivm.mlir)

```json
{"stage":"hivm","arguments":[{"shape":[3072]},null,3]}
```

```sh
dune exec unified-interpreter -- race mlir examples/kernels/issue316_missing_ready_hivm.mlir \
  --launch _build/issue316-launch.json --backend smt --save _build/issue316-core.json
dune exec unified-interpreter -- race mlir examples/kernels/issue316_missing_ready_hivm.mlir \
  --launch _build/issue316-launch.json --replay _build/issue316-core.json
dune exec unified-interpreter -- race mlir examples/kernels/issue316_missing_ready_hivm.mlir \
  --launch _build/issue316-launch.json --project _build/issue316-core.json --save _build/issue316-trace.json
```

`--project` 检查源模块和启动输入，并按已保存的两条前缀映射每个事件。需要直接生成解释器报告时，使用 `--backend bfs --hivm` 或 `--backend smt --hivm`。两个 IR 层都使用 `hivm-race-1` 作为源级报告格式。

## 分析范围与全量测试

Core 转换保留调度所需的标量计算、循环和分支、函数调用、张量 SSA 依赖、内存别名、读写范围和显式同步。HFusion 中按异步任务建模的操作使用逻辑任务队列。HIVM 使用源操作给出的管线、flag 和 barrier。一个源操作可以对应多个 Core 动作，例如 `mmadL1` 的分阶段执行。源级 trace 用 `part` 标出这些动作。[向量访存转换](../lib/hivm/mlir_vector.ml) · [Core 调度实现](../lib/race_schedule.ml)

同一次函数调用中，同一代码块里的 `hivm.hir.multi_buffer_counter` 共享从零开始的计数，每次进入该块递增一次。异步任务保留提交时选定的缓冲区。普通局部标量写入后，后续读取按底层地址和元素类型取值，已经读出的 SSA 值保留。打印缓冲区的 `hivm.hir.debug` 对该视图产生读取事件，可以与重叠的写入构成竞争。[标量和缓冲区转换](../lib/hivm/mlir_lowering.ml)

当向量函数生成间接访存所用的掩码和偏移时，转换器将这些指令编译为 `Core_lang.Device.program`。每条候选 trace 使用相应顺序下的寄存器值和内存值计算实际访问的位区间。源级 trace 用原始 `func.call` 的位置标识向量任务的提交和完成。[向量函数与间接访存转换](../lib/hivm/mlir_indexed_kernel.ml) · [访问区间和回放](../lib/device_races.ml)

`complete` 表示完成了当前模型对给定输入的分析。遇到尚未建模的操作或调度所需的数据时，分析保留可执行的前缀。找到能够按两种相反顺序回放的冲突端点时返回 `race`；缺少这样的前缀时返回 `unknown` 并给出原因。

全量测试直接读取目录登记的 84 个 benchmark 在两个 IR 层的源文件，校验源码摘要，分别运行 BFS 和 SMT，回放 Core 前缀，并逐事件核对源函数、操作路径、调用和完成顺序。运行以下命令，环境变量 `BISHENGIR_OPT` 需指向本机的编译器可执行文件。[测试脚本](../scripts/check_mlir_matrix.py) · [启动输入](../scripts/mlir_benchmark_launch.py) · [逐项结果](../benchmarks/results/scheduler-mlir-matrix.csv)

```sh
dune build bin/main.exe
.venv-attention/bin/python -B scripts/check_mlir_matrix.py \
  --bishengir-opt "$BISHENGIR_OPT" --output _build/scheduler-mlir-matrix --jobs 8 --timeout 300
```

测试要求每份报告的状态为 `complete`。每对竞争都需要回放两条前缀，两个后端需要给出相同的源操作端点。CV 场景 1 的启动配置包含两个稀疏索引位置，两个位置均按本次模型给出的索引初始化。[场景 1 启动输入](../scripts/scheduler_scene.py)

84 个 benchmark 在 HFusion 和 HIVM 两层分别通过 BFS 和 SMT 的全程序分析，共 336 次。下表给出四个 HIVM 用例在本次启动输入下的结果。两个后端分别得到表中的竞争数量，并各自回放了最后一列所列的前缀数。

| HIVM benchmark | 竞争事件对 | 每种后端回放的 trace 前缀 |
| --- | ---: | ---: |
| `cv/scene1/correct` | 68 | 136 |
| `cv/scene1/error` | 68 | 136 |
| `vectorlayout/fail` | 29 | 58 |
| `vectorlayout/ok` | 33 | 66 |

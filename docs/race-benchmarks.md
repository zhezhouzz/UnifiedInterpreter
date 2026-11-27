# 已登记的 Core Language benchmark 模型

`race run NAME` 按名称加载已登记的模型。例如 `issue316/missing-ready` 使用 OCaml 中定义的 `Race_benchmarks.issue316`。要分析调用方提供的 HIVM 或 HFusion 模块，使用 `Ir_scheduler.generate_mlir` 或文件命令 `race mlir FILE`。[#316 模型](../lib/race_benchmarks.ml) · [源码 AST 入口](mlir-to-core.md)

在仓库根目录使用安装了项目依赖的 OCaml 5 switch 执行以下命令。本地的 `unified-interpreter` switch 可以通过 `opam exec --switch=unified-interpreter -- dune build` 构建。每个报告中的 `forward`、`reverse` 分别给出同一对操作按两个相反顺序完成的合法前缀。

```sh
dune exec ./bin/main.exe -- race list --json
dune exec ./bin/main.exe -- race run litao/double-buffer/fixed --backend bfs --save _build/double-buffer.json
dune exec ./bin/main.exe -- race replay _build/double-buffer.json
dune exec ./bin/main.exe -- race run issue316/missing-ready --backend symbolic --save _build/issue316.json
dune exec ./bin/main.exe -- race run vectorlayout/fail --backend smt --n 160 --save _build/layout-races.json
```

在 OCaml 中可以通过同一入口生成报告并重放两条 trace。

```ocaml
open Unified_interpreter

let catalog = Race_benchmarks.catalog "benchmark"
let report = Benchmark_traces.generate catalog (Concrete Solve) "litao/missing-wait/buggy"
let replayed_prefixes = Benchmark_traces.replay catalog report
```

## 输入

| 名称前缀 | 程序 |
| --- | --- |
| `issue316/` | GM 加载到交替使用的 UB 输入，Vector 异步计算后写入调用者的输出。两个程序分别保留和移除就绪等待。 |
| `litao/` | 14 个用例各自的 `buggy` 与 `fixed` 程序，使用本地 `case.json` 中的流、入口参数、初始内存和令牌容量。 |
| `vectorlayout/` | `ok` 与 `fail` 的设备 AST。默认序列长度为 160，KV head 数量为 1。使用 `--n 4096 --kv-heads 4` 可以执行 8 个 query head 的输入。 |
| `regression/`、`fixture/` | 标量控制、循环、别名、分配、屏障、广播、多个发送者及跨管线访问等调度回归程序。 |

Litao 的原始文件和提交历史通过 `core_language` 合入。scheduler 从 `benchmark/L1` 和 `benchmark/L2` 读取包含 `execution` 配置的 14 组用例。每组的 `case.json` 提供启动参数，`buggy.program.core` 和 `fixed.program.core` 提供两个变体的程序。可使用 `--root DIR` 指定用例目录。[原始 benchmark](../benchmark/README.md) · [许可证](../benchmark/licenses)

## 具体输入的判定

对于同一启动配置，两条前缀必须包含同一对动态操作，并在同一物理地址发生冲突。至少一个操作写入该地址。判定允许两次写入相同的值。设备 AST 中同一个 `Issue` 内部的指令随同一次完成事件执行，标量流直接执行的访存也参与判定。

给定同一组入口参数，一对冲突访问只有在两种相反的完成顺序下都能继续执行到所有流结束、所有已提交任务完成时才会返回。两个方向需要共享冲突地址。短循环可以返回截止到第二个端点的前缀。报告的 `complete` 表示对本次输入完成了这个查询；空列表表示没有满足条件的竞争对。

- `bfs` 在队列和令牌给出唯一前驱时按层遍历事件的前驱图。共同前驱只需要执行一次。多个发送者竞争同一令牌时，Core 后端对可达状态执行 BFS。
- `smt` 对 Core 程序要求每个动态事件都发生，并约束完成时钟和令牌的置位、消费顺序。在这些约束下分别求解两个方向的竞争前缀。对设备程序，Z3 求解每个事件的传递前驱位向量，每个直接前驱及其前驱集合都包含在结果中。
- 对 `vectorlayout` 的间接读取与写入，分析使用物理位区间。可能冲突而当前顺序无法产生数据竞争 trace 时，分析根据掩码和偏移量的写入来源划分调度，重新执行对应前缀。跨 block 的分析会检查共享内存的读写范围及同步边，再组合可以独立执行的前缀。

## 符号 N

`race list --json` 中的 `symbolic_n` 标记可使用 `--backend symbolic` 的程序。该后端求解存在量化的非负整数 `N`。找到竞争时，报告保存整数模型以及该输入上的两条 trace。Core 后端还可返回 `no-race` 或 `unknown`。超时预算可用 `--timeout-ms` 设置。

已知实际输入时，例如运行 `race run regression/repeated-write --backend smt --n 100`，报告中的 `n` 保留为 100。`prefix_rounds` 为 2，表示前两轮的两次写入就可以交换完成顺序。两条 trace 各自给出全部 100 轮的调度。OCaml 调用方可以将参数化 Core Lang 程序传给 `Historical_schedule.family ~input ~capacity backend`，其中 `input` 是原始的 `Z.t` 入口参数。[历史模型的循环调度](../lib/historical_schedule.ml)

对于 `vectorlayout`，求解器沿实际 AST 的入口提取首轮路径条件、连续发射的 Vector 计算和物理缓冲区访问，寻找可产生数据竞争 trace 的 `N`。找到模型后使用该长度重新生成页表、缓冲区与启动参数，并检查完整设备程序上的两个完成顺序。该方法对这两个程序都可以找到两个方向的 trace。入口路径无法给出数据竞争 trace 时返回 `unknown`。

## 阅读和验证报告

全部 78 个 benchmark 都可以通过 `race run NAME --hivm` 生成 `hivm-race-1`。使用 `race list --json` 中的 `hivm_ast` 可以取得对应的文件路径，也可以通过 `--hivm-ast FILE` 显式提供这个文件。每个程序都支持 `bfs` 和 `smt`，标记为 `symbolic_n` 的程序还支持 `symbolic`。没有数据竞争时，`races` 是空列表。[配对接口](../lib/hivm/hivm_trace.mli) · [HIVM AST 归档](../benchmarks/hivm) · [解释器如何使用 trace](trace-interpreter.md)

28 个 Litao 模块取自提交 `ee071f0409535dd13fcb2e2e96fd3e5f5ce050eb` 中对应变体的 `*.hivm.mlir`。31 个 Core fixture 和 14 个 regression 的 HIVM 模块从各自的 Core 程序生成。可用 `race source fixture/fifo-copy` 查看生成的 MLIR。重新生成归档时，在仓库根目录运行以下命令，使用安装了项目 xDSL 依赖的 Python。导出器调用 BiShengIR 验证每个模块，保存所有入口、函数体、SSA 操作数和 region。[MLIR 生成器](../lib/hivm/fixture_source.ml) · [归档导出器](../scripts/export_catalog_ast.py)

```sh
dune build bin/main.exe
python scripts/export_catalog_ast.py --opt /path/to/bishengir-opt
```

```sh
dune exec ./bin/main.exe -- race run fixture/hivm-two-loads --backend bfs --n 1 \
  --hivm-ast benchmarks/hivm/two_loads_hivm.ast.json --save _build/two-loads.json
dune exec ./bin/main.exe -- race run fixture/fifo-copy --backend bfs --hivm --save _build/fifo.json
dune exec ./bin/main.exe -- race run litao/zero-trip-alias/buggy --backend symbolic --hivm
dune exec ./bin/main.exe -- race run issue316/missing-ready --backend symbolic \
  --hivm-ast benchmarks/hivm/issue316_missing_ready_hivm.ast.json --save _build/issue316-hivm.json
dune exec ./bin/main.exe -- race run vectorlayout/ok --backend bfs --n 160 \
  --hivm-ast benchmarks/hivm/vectorlayout_ok.ast.json --save _build/layout-ok.json
dune exec ./bin/main.exe -- race run vectorlayout/fail --backend symbolic \
  --hivm-ast benchmarks/hivm/vectorlayout_fail.ast.json --save _build/layout-fail.json
```

以下字段和 `race replay` 用于默认的 `core-race-1` 报告。

`events` 是按从零开始的事件编号索引的数组。`nodes` 标识目标事件，`first` 与 `second` 包含流、源位置和迭代坐标。冲突范围为左闭右开区间。报告使用 `address_unit` 标明单位，设备程序使用位，Litao 使用字节，原有 Core 回归程序使用元素地址。Litao 的 GM 输入按参数位置编号，第 `s` 条流的 UB 和 CC 分别编号为 `100+2*s`、`101+2*s`。`indirect-atomic` 的具名 offsets 和 mask 输入分别编号为 `-2`、`-3`。

`race replay` 重新构造输入，检查事件身份、队列与令牌条件、完成顺序以及两个方向实际命中的冲突区间。Litao 归档中的精度、协议及死锁判定有各自的观察条件，`buggy` 与 `fixed` 保留原始变体名称。

```sh
dune runtest
python3 scripts/check_race_benchmarks.py --symbolic
python3 scripts/check_race_benchmarks.py --filter vectorlayout/ --n 4096 --kv-heads 4 --output _build/race-4096
```

## HIVM trace 全量测试结果

在 `scheduler` 提交 `b004cb0` 上，78 个 benchmark 各使用默认输入运行 BFS 和 SMT，另外 35 个支持符号参数的 benchmark 运行了符号 SMT，191 次运行全部通过。两个具体后端在每个程序上找到的目标事件对均一致。35 个程序共检出 116 对竞争，其余 43 个程序在默认输入下没有检出竞争。符号求解有 19 个程序返回 `race` 和具体的 `N`，16 个返回 `no-race`。[逐项结果 CSV](../benchmarks/results/hivm-races.csv)

CSV 每行记录一个 benchmark 的默认 `N`、两个具体后端各自找到的竞争对数、符号求解状态及本次找到的 `N`。固定输入的程序留空参数和符号求解列。`no-race` 的模型列也留空，整数 `0` 表示实际参数值。仓库回归测试通过。另用两个后端各自生成的 `fifo-copy` 前缀执行复制函数，正向和反向分别得到 `[7,7,7]` 和 `[7,7,0]`。[数值重放脚本](../scripts/check_fifo_hivm.py)

在仓库根目录运行以下命令可以复现全量测试。脚本从当前 benchmark 目录读取用例，检查每条前缀中两次目标访问的顺序和结束事件，并逐项比较 BFS 与 SMT 找到的目标事件对。各次运行的 JSON 报告和 `results.csv` 保存在 `_build/hivm-race-results/`。[全量测试脚本](../scripts/check_hivm_race_benchmarks.py)

```sh
dune build bin/main.exe
python3 scripts/check_hivm_race_benchmarks.py
```

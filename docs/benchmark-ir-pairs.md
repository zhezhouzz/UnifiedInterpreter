# Benchmark 的 HFusion 和 HIVM 文件

在仓库根目录运行以下命令。每行依次给出 benchmark 名称、HFusion 文件路径和 HIVM 文件路径。`--json` 还会输出文件的 SHA-256、生成方式和来源。

```sh
dune exec unified-interpreter -- race pairs
dune exec unified-interpreter -- race pairs cv/scene1/error --json
```

目录按变体计数，共 84 对，包括 32 个 fixture、14 个 regression、28 个 Litao 变体、2 个 Issue #316 变体、2 个 vectorlayout 变体、4 个张量计算用例和 2 个 CV 场景 1 变体。每个条目都有 HFusion 和 HIVM 两份 MLIR。两层均支持 BFS 和 SMT，分别通过 `race list --hfusion` 和 `race list --hivm` 查看。[完整目录](../benchmarks/ir-pairs/catalog.json) · [从 MLIR 源码运行的结果](../benchmarks/results/scheduler-mlir-matrix.csv)

使用归档模块时，两个 CV 场景 1 的 HIVM 模型和 `fixture/invalid-allocation-offset` 的 HFusion 模型只覆盖执行前缀，scheduler 返回 `unknown`。直接使用这三个条目的 MLIR 源码和测试启动参数时，BFS 和 SMT 均完成了分析。[归档模块测试结果](../benchmarks/results/scheduler-matrix.csv) · [源码测试入口](mlir-to-core.md)

## 文件来源

| 目录中的 `origin` | 变体数 | 两份文件的关系 |
| --- | ---: | --- |
| `forward` | 4 | 从 vector-add、row-sum、flash-attention、strided-output 的 HFusion 输入运行 BiShengIR 的 `--convert-hfusion-to-hivm`。 |
| `compiler-source` | 2 | Litao 的 `add-Ascend910B1` 两个变体共用原始编译输入，分别保留各自自动同步配置下的 HIVM。目录记录 Git 修订号及源文件路径。 |
| `compiler-dump` | 4 | 从 CV 的原始编译日志提取 HFusion，保留同一次编译的后期 HIVM。 |
| `computation-projection` | 74 | 从已有 HIVM 提取计算，通过 BiShengIR 生成 HFusion 阶段的 MLIR。内存复制、算术、分支和循环使用该阶段允许的 Linalg、MemRef、Arith 和 SCF 操作表示。设备管线、标志及屏障在原始 HIVM 中检查。 |

在计算版本中，原来由 `pointer_cast` 指定的设备存储和 `get_sub_block_idx` 取得的编号可由函数参数传入。目录的 `extra_arguments` 按函数记录参数位置，位置从零开始。`local-memory` 给出地址空间、字节偏移和视图类型。执行时，同一设备实例中指向同一段存储的视图需要共享底层内存。`mix-handoff` 的 CC 输入是该用例的 256 个逻辑 f32 元素，`indirect-atomic` 保留逐元素掩码、间接下标、原子加法和旧值写回。两个仅在同步上不同的 HIVM 变体可以得到相同的 HFusion 计算。

#316 的两个 HFusion 版本每轮都向选中的缓冲区复制输入，随后计算指数并写入共同的输出。`ordered` 在复制和计算之间执行 `hfusion.barrier`，等待本核此前的任务完成。`missing-ready` 的循环体没有屏障。HIVM 的 `ordered` 通过指定管线和事件编号表达等待，HFusion 的屏障同步整个核。[HFusion ordered](../benchmarks/ir-pairs/issue316/ordered/hfusion.mlir) · [HFusion missing-ready](../benchmarks/ir-pairs/issue316/missing-ready/hfusion.mlir)

## CV 精度用例

| benchmark | HFusion | HIVM |
| --- | --- | --- |
| `vectorlayout/ok` | [HFusion](../benchmarks/ir-pairs/vectorlayout/ok/hfusion.mlir) | [HIVM](../benchmarks/hivm/vectorlayout_ok.mlir) |
| `vectorlayout/fail` | [HFusion](../benchmarks/ir-pairs/vectorlayout/fail/hfusion.mlir) | [HIVM](../benchmarks/hivm/vectorlayout_fail.mlir) |
| `cv/scene1/correct` | [HFusion](../benchmarks/ir-pairs/cv/scene1/correct/hfusion.mlir) | [HIVM](../benchmarks/ir-pairs/cv/scene1/correct/hivm.mlir) |
| `cv/scene1/error` | [HFusion](../benchmarks/ir-pairs/cv/scene1/error/hfusion.mlir) | [HIVM](../benchmarks/ir-pairs/cv/scene1/error/hivm.mlir) |

场景 1 的入口是 `_gqa_sparse_fwd_kernel`，两个变体分别来自 `场景1 IR.zip` 中的 `correct.log` 和 `error.log`。保留的两份后期 HIVM 各有 20 个函数，取自转入标准方言前的完整模块。`correct` 和 `error` 沿用原始精度用例的标记。两份 vectorlayout HIVM 延用调度器使用的布局和同步快照。

## 编译验证

在仓库根目录构建命令行程序，使用项目的 xDSL 环境和 BiShengIR 运行验证。目录记录了生成时使用的编译器版本，此次为 `bishengir-opt 2.0.0 f94ebe365e88`。

```sh
dune build bin/main.exe
.venv-attention/bin/python scripts/benchmark_ir_pairs.py check --opt /path/to/bishengir-opt
.venv-attention/bin/python scripts/export_scheduler_modules.py --check --opt /path/to/bishengir-opt
```

第一条 Python 命令核对目录覆盖范围和文件摘要，用 BiShengIR 验证每份 HIVM，并将每份 HFusion 编译到 HIVM。对于计算版本，它还从原始 HIVM 重新生成 HFusion 并比较文件和参数。对于四个 CV 变体，它使用 `mm-map-mode=macro_instr`，将转换结果与原始日志中 `After ConvertHFusionToHIVM` 快照经同一编译器打印后的摘要比较。第二条命令从原始 MLIR 重新导出模块 AST，逐个比较操作、类型、属性和 region。多个变体共享完全相同的 IR 时，按 SHA-256 只保存一份 AST。

目录中的 28 个 Litao HIVM 文件直接引用合并进来的原始路径。`add-Ascend910B1` 的两个变体也直接读取同一份高层输入。用 `git log -- benchmark/L2/double-buffer/buggy.hivm.mlir` 可以查看该文件的原始提交和作者。[Litao benchmark](../benchmark/README.md)

从原始归档重新生成目录时，传入场景 1 的 ZIP 和解压后包含两个 vectorlayout 编译日志的目录。

```sh
.venv-attention/bin/python scripts/benchmark_ir_pairs.py generate \
  --opt /path/to/bishengir-opt --scene-zip '/path/to/场景1 IR.zip' \
  --layout-dumps '/path/to/vectorlayout精度问题'
```

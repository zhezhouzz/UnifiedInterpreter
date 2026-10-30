# 使用指南：运行与检查 attention

## 1. 准备环境

需要 Linux 环境、Git、已初始化的 opam、C 编译器、make、pkg-config、GMP 开发文件，以及支持 `venv` 的 Python 3.12。运行仓库中的 attention 示例使用 CPU，无需安装 Ascend 编译器或连接 NPU。

获取仓库后，本文所有命令均在仓库根目录执行：

```sh
git clone https://github.com/zhezhouzz/UnifiedInterpreter.git
cd UnifiedInterpreter
mkdir -p _build/task-tmp reports
export TMPDIR="$PWD/_build/task-tmp"
```

已经拥有本仓库时，直接进入该目录并执行 `mkdir` 和 `export` 两条命令。

### 创建独立的 OCaml 环境

下面的命令创建名为 `unified-interpreter` 的 opam switch。已经建立此 switch 时，跳过创建命令。本文使用 `opam exec --switch=unified-interpreter` 明确指定环境，无需修改当前终端默认使用的 switch。

```sh
opam switch create unified-interpreter ocaml-base-compiler.5.3.0
opam repository add coq-released https://coq.inria.fr/opam/released --switch=unified-interpreter
opam install --switch=unified-interpreter dune.3.23.1 rocq-prover rocq-core.9.1.0 rocq-runtime.9.1.0 rocq-stdlib.9.1.0 rocq-stdpp.1.13.0 zarith.1.14 yojson.2.2.2
```

这些版本取自本项目已安装的环境；`rocq-prover` 是元包，其版本与 `rocq-core` 的版本编号不同。仓库依赖声明位于 [dune-project](../dune-project)。若 `coq-released` 已经关联此 switch，可跳过添加仓库的命令；使用 `opam repository list --switch=unified-interpreter` 查看关联情况。

### 安装 MLIR 前端并构建

```sh
ATTENTION_PYTHON=python3.12 sh scripts/bootstrap_attention.sh
opam exec --switch=unified-interpreter -- dune build @all
opam exec --switch=unified-interpreter -- dune exec attention -- --help
```

`ATTENTION_PYTHON` 可以设置为 Python 3.12 可执行文件的完整路径。安装脚本创建项目内的 `.venv-attention`，安装固定版本 `xdsl==0.74.0`，并创建 `reports/`。已有虚拟环境会被复用。确认其版本：

```sh
.venv-attention/bin/python --version
.venv-attention/bin/python -m pip show xdsl
```

构建会编译 Rocq 文件、导出 OCaml 语义并构建解释器。内存 buffer 使用官方 `PArray`，通过 `rocq-runtime.kernel` 链接其 OCaml 实现；设计和验证见 [PArray 内存模型](parray-memory.md)。生成文件位于 `_build/`，无需手动编辑导出的 `.ml` 文件。后续打开新终端时，进入仓库根目录并重新设置 `TMPDIR`，然后使用下面的运行命令。

内存 buffer 使用分页 `PArray`，提取后链接官方 `rocq-runtime.kernel`。数据表示、语义证明和验证方法见 [PArray 内存模型与验证](parray-memory.md)。

## 2. 运行同一个 attention 的两个 IR 阶段

```sh
opam exec --switch=unified-interpreter -- dune exec attention -- \
  --stage both \
  --output reports/attention.json \
  --trace reports/attention.jsonl
```

此命令使用相同输入，分别执行以下文件，每次执行具有独立的内存状态：

| 阶段 | 输入文件 |
| --- | --- |
| HFusion | [hfusion_level.mlir](../artifacts/flash_attention/ir/hfusion_level.mlir) |
| HIVM | [attention_hivm_compute.mlir](../artifacts/flash_attention/ir/attention_hivm_compute.mlir) |

默认输入由固定随机种子生成，Q、K、V 的元素位于 `[-0.25, 0.25)`。当前执行配置如下：

| 配置 | 数值 |
| --- | --- |
| batch、head 数量 | 均为 1 |
| 序列长度 N、head 维度 D | 均为 128 |
| Q、K、V、O 的形状 | 128×128 |
| log_sum_exp 的长度 | 128 |
| scale | `1 / sqrt(128)` |
| causal mask | 关闭 |
| 数值计算 | host-float64 |

计算目标为 `S = scale × Q × transpose(K)`、`O = softmax(S) × V`，其中 softmax 按行计算；`log_sum_exp[i] = log(sum(exp(S[i, :])))`。实现采用减去行最大值的计算方式。

每次执行顺序启动逻辑 program 0–19。现有 IR 的循环按 32 行划分四个块，program 0–3 各自计算一个块，program 4–19 的循环为空。同一次执行中的 program 共享内存，各自建立 SSA 环境。

HFusion 执行涉及逐元素解释，运行可能需要数分钟。终端在一个阶段完成后打印该阶段统计。成功运行时，统计具有以下形式：

```text
hfusion: steps=66076 calls=33286 max_error(O)=0 max_error(LSE)=0
hivm: steps=592 calls=570 max_error(O)=0 max_error(LSE)=0
```

`steps` 是解释器执行的操作计数，`calls` 是原语调用计数。数值零表示相对数学参考结果的最大绝对误差为零。输入和 IR 改动后，统计与误差可能变化。

## 3. 检查结果

在上述命令成功结束后运行：

```sh
.venv-attention/bin/python scripts/check_attention_output.py
```

检查脚本读取固定路径 `reports/attention.json` 和 `reports/attention.jsonl`，验证输出形状、有限数值、参考比较，以及 program 的 trace。正常结束时打印：

```text
Result shapes, finite values, reference comparisons and program traces passed
```

结果 JSON 包含：

| 字段 | 含义 |
| --- | --- |
| `profile` | 当前数值模型 `host-float64` |
| `configuration` | 输入规模、scale 和 program 数量 |
| `stages` | 每次执行的结果，包括 `O` 和 `log_sum_exp` |
| `stages[].reference_passed` | 与独立数学参考结果比较是否通过 |
| `stages[].max_absolute_error_O` / `max_absolute_error_LSE` | 两种输出的最大绝对误差 |
| `cross_stage` | `both` 模式下 HFusion 与 HIVM 输出之间的比较 |
| `passed` | 本次全部数值比较是否通过 |

比较逐元素使用 `abs(actual - expected) <= 1e-10 + 1e-9 × abs(expected)`，并要求数值有限。单个阶段及混合执行的 `cross_stage` 为 `null`。出现参考比较失败时，CLI 写出结果文件，然后以非零状态退出。

完整结果文件在计算结束后写出；执行中途产生的 trace 文件只包含已经记录的调用。重复使用同一输出路径会覆盖文件，请为需要保留的实验选择不同文件名。

## 4. 在一个函数中混合执行 HFusion 和 HIVM

```sh
opam exec --switch=unified-interpreter -- dune exec attention -- \
  --stage mixed --ir examples/attention_mixed.mlir \
  --output reports/attention-mixed.json \
  --trace reports/attention-mixed.jsonl
.venv-attention/bin/python scripts/check_attention_mixed_output.py
```

[attention_mixed.mlir](../examples/attention_mixed.mlir) 从 HFusion 示例人工构造，保留原来的计算流程，将以下四个操作替换为 HIVM 操作：

| SSA 结果 | 混合示例中的操作 | 用途 |
| --- | --- | --- |
| `%18` | `hivm.hir.vmul` | 缩放矩阵乘法结果 |
| `%20` | `hivm.hir.vexp` | 计算指数 |
| `%31` | `hivm.hir.vln` | 计算自然对数 |
| `%37` | `hivm.hir.vcast` | 输出类型转换 |

阅读文件时可以顺着 `%17`、`%18`、`%reduced` 查看矩阵乘法、缩放与求最大值：它们依次属于 HFusion、HIVM、HFusion。解析器为每个操作记录阶段，解释器选择对应的计算 handler；不同阶段通过同一个 SSA 环境传递结果，并访问同一份内存。

混合运行输出一组 attention 结果，与相同的数学参考比较。检查脚本还验证上述操作实际调用了对应的语义入口。默认示例的统计为 `steps=66076`、`calls=33286`。

### 阅读 trace

`.jsonl` 文件每行都是一个完整 JSON 对象，记录一次原语调用。可以使用文本编辑器搜索 `"result":"%18"`，查看缩放操作的调用；搜索 `"result":"%17"` 查看前面的矩阵乘法。

| 字段 | 阅读方式 |
| --- | --- |
| `stage` | 本次运行模式，例如 `mixed` |
| `ir_stage` | 当前操作所属阶段：`common`、`hfusion`、`hivm` |
| `program_id` | 当前逻辑 program 编号 |
| `loops` | 当前循环变量及数值 |
| `file`、`line`、`column` | 调用对应的 MLIR 源码位置 |
| `opcode`、`result` | 操作名称与 SSA 结果名称 |
| `entry` | 实际调用的语义入口 |

例如 `%17` 的计算入口为 `sem_linalg_matmul`，`%18` 的 HIVM 计算入口为 `HIVM.evaluate`。一个操作可能引发多次原语调用，包括读取内存视图，所以应当同时阅读 `opcode` 与 `entry`。宿主侧内存分配和最终输出读取没有对应 MLIR 操作，`ir_stage` 为 `null`。trace 的行数对应原语调用数量；部分控制操作没有独立的原语调用记录。

## 5. 使用自己的输入

`--input` 接受 JSON 对象，必须包含大写字段 `Q`、`K`、`V`。每个字段都是包含 128 个数组的数组，每个内部数组包含 128 个有限数值。可选字段 `scale` 为有限数值，省略时使用 `1 / sqrt(128)`。

为了生成一个容易手工核对的输入，可以将以下 Python 代码保存为 `reports/make_input.py`：

```python
import json
from pathlib import Path

size = 128
data = {
    "Q": [[0.0] * size for _ in range(size)],
    "K": [[0.0] * size for _ in range(size)],
    "V": [[0.75] * size for _ in range(size)],
}
Path("reports/input.json").write_text(json.dumps(data), encoding="utf-8")
```

然后执行：

```sh
.venv-attention/bin/python reports/make_input.py
opam exec --switch=unified-interpreter -- dune exec attention -- \
  --stage hivm --input reports/input.json \
  --output reports/custom-attention.json
```

这里每个 attention score 都是零，因此 softmax 的每个权重都是 `1/128`；O 的全部元素应为 `0.75`，log_sum_exp 的全部元素应为 `log(128)`，约 `4.852030263919617`。可在结果文件中检查这些数值与 `passed`。上述两个检查脚本要求特定模式和固定文件名，检查本节的单阶段输出时直接阅读结果 JSON。

## 6. 命令行参数与修改 IR

| 参数 | 用法 |
| --- | --- |
| `--stage both` | 默认模式，分别执行仓库中的 HFusion 与 HIVM 示例 |
| `--stage hfusion` / `--stage hivm` | 执行指定阶段，省略 `--ir` 时使用仓库示例 |
| `--stage mixed` | 允许同一函数包含两个阶段的操作，必须提供 `--ir` |
| `--ir PATH` | 指定 MLIR 文件；不能与 `--stage both` 一起使用 |
| `--input PATH` | 指定输入 JSON；省略时生成固定种子的输入 |
| `--output PATH` | 保存结果 JSON；省略时输出到标准输出 |
| `--trace PATH` | 保存原语调用 JSONL；省略时不保存 trace |
| `--max-steps N` | 正整数执行预算，默认 1000000；每次阶段执行单独计数 |

输出与 trace 文件的父目录必须事先存在。运行命令应当保留 `dune exec attention --` 中的 `--`，其后的参数传给 attention 程序。

修改示例时，将副本保存在自己的目录中，再通过 `--ir` 指定。输入函数仍须遵循现有 attention 的 16 个参数约定、形状和计算目标，CLI 会持续使用 attention 数学参考校验结果。具体参数绑定见 [attention.ml](../attention/attention.ml) 的 `run`，支持的操作和属性见 [validate.ml](../attention/validate.ml)。

可以先执行纯解析检查：

```sh
.venv-attention/bin/python scripts/check_attention_xdsl.py examples/attention_mixed.mlir
```

该命令执行 xDSL 解析和验证。解释器随后还有自己的阶段、操作和属性检查，完整运行仍然需要执行 CLI。

当前范围为现有示例使用的 HFusion 与 HIVM compute 原语及必要公共操作。f16/f32 保留类型标记，计算使用宿主 float64，转换不会模拟对应硬件舍入。CPU 顺序执行结果可用于检查当前模型中的计算行为；硬件精度、异步流水线和任意 Ascend IR 程序均超出本使用入口的验证范围。

## 7. 排查错误与运行测试

| 现象 | 检查方法 |
| --- | --- |
| 找不到 `python3.12` | 将 `ATTENTION_PYTHON` 设置为本机 Python 3.12 的可执行文件路径 |
| xDSL 导入或 Python 语法错误 | 检查 `.venv-attention/bin/python --version` 和 `pip show xdsl`；安装脚本会复用已有虚拟环境 |
| 找不到前端或默认 IR 文件 | 在仓库根目录执行命令，确认已经执行 bootstrap 脚本 |
| 输出文件无法打开 | 创建 `--output` 和 `--trace` 指定路径的父目录 |
| `matrix must have 128 rows/columns` | 检查输入的每个矩阵形状及 JSON 数组层次 |
| `unsupported` 或阶段不匹配错误 | 根据错误中的源码位置检查操作、类型、属性及 `--stage` |
| 执行预算耗尽 | 检查循环边界和操作数量，再设置适合该程序的 `--max-steps` |
| `attention reference comparison failed` | 查看结果 JSON 的阶段误差，使用 trace 定位修改过的操作 |

验证仓库测试：

```sh
opam exec --switch=unified-interpreter -- dune runtest
```

完整测试包含 attention 执行，可能需要数分钟。Dune 会缓存成功测试；需要明确重新执行所有测试时使用 `dune runtest --force`。

## 8. 阅读实现

| 想了解的内容 | 阅读位置 |
| --- | --- |
| MLIR 如何进入解释器 | [attention_frontend.py](../scripts/attention_frontend.py)、[parser.ml](../attention/parser.ml) |
| 如何定义各操作的阶段 | [stage.ml](../attention/stage.ml) |
| 如何执行 SSA、循环和 region | [runner.ml](../attention/runner.ml) |
| algebraic effects、内存状态与 lens | [handlers.ml](../attention/handlers.ml) |
| 输入绑定、program 启动与数学参考 | [attention.ml](../attention/attention.ml) |
| Rocq 导出哪些语义 | [Extract.v](../rocq/Extraction/Extract.v) |
| 语义、handler 与执行设计 | [attention-interpreter-design.md](attention-interpreter-design.md) |
| 与官方语义文档的对应及当前限制 | [semantics-audit-report.md](semantics-audit-report.md) |

## 9. 运行两个小型 kernel

构建和 Python 环境沿用第 1 节。`kernel-example` 提供向量加法与逐行求和，每个 kernel 都有手写的 HFusion 和 HIVM 两份 MLIR，使用现有解析器、effect handler、内存 lens 和 Rocq 导出的原语语义执行。每份 MLIR 启动一次，使用自身的函数参数约定。

### 向量加法

```sh
opam exec --switch=unified-interpreter -- dune exec kernel-example -- \
  --kernel vector-add --stage both \
  --output reports/vector-add.json --trace reports/vector-add.jsonl
```

输入为两个长度为 8 的向量，计算 `out[i] = a[i] + b[i]`：

- 输入 a：`[-3, -1, 0, 0.5, 2, 4, 8, 16]`。
- 输入 b：`[1, 2, 3, 4, -2, -4, 0.25, -0.5]`。
- 输出：`[-2, 1, 3, 4.5, 0, 0, 8.25, 15.5]`。

阅读 [vector_add_hfusion.mlir](../examples/kernels/vector_add_hfusion.mlir) 与 [vector_add_hivm.mlir](../examples/kernels/vector_add_hivm.mlir)：先将输入 memref 转为 tensor 视图，执行加法，最后将结果写入输出 memref。HFusion 使用 `linalg.elemwise_binary`，HIVM 使用 `hivm.hir.vadd`。trace 中对应的计算入口分别为 `sem_linalg_elemwise_binary` 和 `HIVM.evaluate`。

### 矩阵逐行求和

```sh
opam exec --switch=unified-interpreter -- dune exec kernel-example -- \
  --kernel row-sum --stage both \
  --output reports/row-sum.json --trace reports/row-sum.jsonl
```

输入矩阵形状为 3×4，按行存储的数值为 `[1, 2, 3, 4, -1, 0, 1, 2, 0.5, 0.25, -0.5, -0.25]`。计算 `out[i] = sum(input[i, :])`，输出形状为 `[3]`，结果为 `[10, 2, 0]`。

阅读 [row_sum_hfusion.mlir](../examples/kernels/row_sum_hfusion.mlir)：`linalg.fill` 初始化零累加器，`linalg.reduce` 在维度 1 上执行 region 内的 `arith.addf`。阅读 [row_sum_hivm.mlir](../examples/kernels/row_sum_hivm.mlir)：`hivm.hir.vreduce <sum>` 在维度 1 上求和并保留该维度，得到 3×1 的 tensor；`tensor.collapse_shape` 将其转换为长度 3 的输出。HIVM 求和不读取 destination 的初始元素，因此这里使用 `tensor.empty` 作为 destination。

### 结果与参数

结果 JSON 的 `stages` 数组保存各阶段的 `shape`、按行展开的 `output`、独立 OCaml 参考计算 `reference`、`reference_passed` 和 `max_absolute_error`。顶层 `passed` 表示所有参考比较通过。默认数据的两种 kernel 在两个阶段中的误差均为零。比较容差与 attention 相同；失败时写出结果并以非零状态退出。

`--stage` 默认为 `both`，也支持 `hfusion`、`hivm`。使用修改后的 MLIR 时，提供单个阶段和 `--ir PATH`；含两种阶段操作的文件使用 `--stage mixed --ir PATH`。输入绑定及参考计算由 `--kernel` 选择，修改后的文件需保留该例子的参数名称、形状和计算目标。`--output`、`--trace`、`--max-steps` 的用法与 attention 相同，输出目录需要事先存在。

### 从 OCaml 传入自己的数据

[kernel.ml](../attention/kernel.ml) 的 `Kernel.run` 接受参数名与绑定的列表。输入数组按行展开，输出参数标记为 `Kernel.Output`；每次调用创建独立内存，执行结束后读取输出缓冲区。

```ocaml
open Attention_runtime

let result = Kernel.run ~stage:"hfusion"
  ~file:"examples/kernels/vector_add_hfusion.mlir"
  ["%a", Kernel.Input [|1.; 2.; 3.; 4.; 5.; 6.; 7.; 8.|];
   "%b", Kernel.Input [|8.; 7.; 6.; 5.; 4.; 3.; 2.; 1.|];
   "%out", Kernel.Output]
```

`result.outputs` 包含输出的 `name`、`shape` 和 `data`，此例的输出元素均为 9。该入口接受静态形状的 f32 memref 参数，检查参数名称、数据长度和有限数值。尚未初始化的输出缓冲区通过原有内存语义检测非法读取。数值计算仍使用 host-float64。

两个 kernel 的输入与参考计算定义位于 [kernel_examples.ml](../attention/kernel_examples.ml)。对应测试使用两组不同输入检查两个阶段的实际计算、handler trace，并检查错误参数、未初始化内存和执行预算：

```sh
opam exec --switch=unified-interpreter -- dune build @attention_test/runtest
```

该命令运行 attention 测试目录中的全部测试。仅运行小型 kernel 测试时，在仓库根目录执行：

```sh
opam exec --switch=unified-interpreter -- dune build attention_test/kernel_test.exe
(cd attention_test && opam exec --switch=unified-interpreter -- ../_build/default/attention_test/kernel_test.exe)
```

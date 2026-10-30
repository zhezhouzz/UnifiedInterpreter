# 使用指南：从 Triton 编译并执行 kernel

## 1. 准备环境

准备 Linux x86_64、Git、支持 `venv` 的 Python 3.10 和 Python 3.12。编译和解释执行使用 CPU，无需连接 NPU。

```sh
git clone https://github.com/zhezhouzz/UnifiedInterpreter.git
cd UnifiedInterpreter
mkdir -p _build/task-tmp _build/pip-cache reports
export TMPDIR="$PWD/_build/task-tmp"
export PIP_CACHE_DIR="$PWD/_build/pip-cache"
export TRITON_CACHE_DIR="$PWD/_build/triton-cache"
```

已有仓库时，进入仓库根目录执行目录创建和环境变量命令。后续命令均在此目录执行。

### 安装编译器与 MLIR 前端

```sh
python3.10 -m venv _build/kernel-compiler
_build/kernel-compiler/bin/python -m pip install -r requirements-kernel-compiler.txt
ATTENTION_PYTHON=python3.12 sh scripts/bootstrap_attention.sh
```

已有虚拟环境时跳过创建命令。Python 命令可以替换为对应可执行文件的完整路径。依赖固定为 `triton-ascend==3.2.0`、`ascendnpu-ir==1.2.0` 和 `xdsl==0.74.0`，首次安装需要网络。

### 从源码构建解释器

准备已初始化的 opam、C 编译器、make、pkg-config 和 GMP 开发文件。已有 `unified-interpreter` switch 时跳过创建命令；已关联 `coq-released` 时跳过添加仓库命令。

```sh
opam switch create unified-interpreter ocaml-base-compiler.5.3.0
opam repository add coq-released https://coq.inria.fr/opam/released --switch=unified-interpreter
opam install --switch=unified-interpreter dune.3.23.1 rocq-prover rocq-core.9.1.0 rocq-stdlib.9.1.0 rocq-stdpp.1.13.0 zarith.1.14 yojson.2.2.2
opam exec --switch=unified-interpreter -- dune build @all
export ATTENTION_BIN="$PWD/_build/default/attention_cli/main.exe"
export KERNEL_BIN="$PWD/_build/default/kernel_cli/main.exe"
```

构建会编译 Rocq、导出 OCaml 语义并生成解释器。依赖声明见 [dune-project](../dune-project)。

### 使用发布包中的解释器

发布包要求 Linux x86_64、glibc 2.39 或更新版本，可使用 Ubuntu 24.04。使用发布包时可以省略源码构建步骤；Triton 编译仍使用当前仓库及前述 Python 环境。

在 GitHub 仓库的 **Actions** 页面选择目标提交的成功运行，下载 **Artifacts** 中的 `unified-interpreter-linux-x86_64`。解开 ZIP，将其中的 `.tar.gz` 和 `.sha256` 放在仓库的 `_build/downloads/` 中。

```sh
sudo apt-get update
sudo apt-get install -y python3 python3-venv libgmp10
(cd _build/downloads && sha256sum --check unified-interpreter-linux-x86_64.tar.gz.sha256)
mkdir -p _build/distribution
tar -xzf _build/downloads/unified-interpreter-linux-x86_64.tar.gz -C _build/distribution
ATTENTION_PYTHON=python3 sh _build/distribution/unified-interpreter/scripts/bootstrap_attention.sh
export ATTENTION_BIN="$PWD/_build/distribution/unified-interpreter/bin/attention"
export KERNEL_BIN="$PWD/_build/distribution/unified-interpreter/bin/kernel-example"
```

后续命令通过这两个变量选择解释器。发布包与 Docker 的详细说明见 [binary-distribution.md](binary-distribution.md)。

## 2. 从 Triton 生成 IR

使用以下完整参数命令。attention 使用归档教程中的 Triton JIT 函数，vector-add 和 row-sum 使用 [kernels.py](../examples/kernels/source/kernels.py)。编译脚本生成 TTIR、HFusion、计算阶段 HIVM，并使用官方 `bishengir-opt` 验证结果。每个输出目录中的 `provenance.json` 记录源码、signature、constants、转换参数和文件哈希。

### attention

```sh
_build/kernel-compiler/bin/python scripts/compile_kernel_ir.py \
  --kernel _attn_fwd --target Ascend910B1 --num-warps 4 \
  --output _build/compiled-attention \
  --signature '{
    "Q": "*fp16", "K": "*fp16", "V": "*fp16",
    "M": "*fp32", "Out": "*fp16", "acc": "*fp32",
    "sm_scale": "fp32"
  }' \
  --constants '{
    "stride_qz": 16384, "stride_qh": 16384, "stride_qm": 128, "stride_qk": 1,
    "stride_kz": 16384, "stride_kh": 16384, "stride_kn": 128, "stride_kk": 1,
    "stride_vz": 16384, "stride_vh": 16384, "stride_vn": 128, "stride_vk": 1,
    "stride_oz": 16384, "stride_oh": 16384, "stride_om": 128, "stride_on": 1,
    "Z": 1, "H": 1, "N_CTX": 128, "HEAD_DIM": 128,
    "BLOCK_M": 32, "BLOCK_N": 128, "STAGE": 1
  }'
```

### vector-add

```sh
_build/kernel-compiler/bin/python scripts/compile_kernel_ir.py \
  --kernel add_kernel --target Ascend910B1 --num-warps 4 \
  --signature '{"X":"*fp32","Y":"*fp32","Z":"*fp32","n_elements":"i32"}' \
  --constants '{"BLOCK_SIZE":256}' --output _build/compiled-vector-add
```

### row-sum

```sh
_build/kernel-compiler/bin/python scripts/compile_kernel_ir.py \
  --kernel row_sum --target Ascend910B1 --num-warps 4 \
  --signature '{"input":"*fp32","out":"*fp32"}' \
  --constants '{"ROWS":3,"COLS":4}' --output _build/compiled-row-sum

.venv-attention/bin/python scripts/prepare_kernel_ir.py \
  --kernel row_sum --input _build/compiled-row-sum \
  --output _build/runnable-row-sum
```

入口准备使用 xDSL 保留编译得到的计算操作，指定静态输入形状和参数名称，并移除未使用的隐式入口参数。同时生成 mixed IR，将第一行计算取自 HFusion，其余两行取自 HIVM。

## 3. 执行并检查三个 kernel

### attention

```sh
for stage in hfusion hivm; do
  "$ATTENTION_BIN" --stage "$stage" \
    --ir "_build/compiled-attention/_attn_fwd.$stage.mlir" \
    --output "reports/attention-$stage.json" \
    --trace "reports/attention-$stage.jsonl"
done
```

默认输入使用固定随机种子生成 Q、K、V，计算 `S = scale × Q × transpose(K)`、`O = softmax(S) × V` 和逐行 `log_sum_exp`。每次运行使用独立内存，顺序执行 20 个逻辑 program。同次运行中的 program 共享内存。

### vector-add

```sh
for stage in hfusion hivm; do
  for length in 0 1 255 256 257 512 513 777; do
    "$KERNEL_BIN" --kernel vector-add --stage "$stage" \
      --ir "_build/compiled-vector-add/add_kernel.$stage.mlir" \
      --length "$length" --output "reports/vector-add-$stage-$length.json"
  done
done
```

CLI 生成确定性输入，逐元素检查 `Z[i] = X[i] + Y[i]`。输入和输出按真实长度分配，末尾 program 通过编译得到的分支、动态子视图和 tensor 切片处理有效范围。

### row-sum

```sh
for stage in hfusion hivm mixed; do
  "$KERNEL_BIN" --kernel row-sum --stage "$stage" \
    --ir "_build/runnable-row-sum/row_sum_$stage.mlir" \
    --output "reports/row-sum-$stage.json" \
    --trace "reports/row-sum-$stage.jsonl"
done
```

计算 `out[i] = sum(input[i, :])`。默认输入按行展开为 `[1, 2, 3, 4, -1, 0, 1, 2, 0.5, 0.25, -0.5, -0.25]`，输出为 `[10, 2, 0]`。mixed 各阶段共享函数参数、SSA 依赖和内存。

### 读取结果与 trace

执行命令自动与独立参考计算比较，失败时保存结果并以非零状态退出。JSON 顶层 `passed` 表示全部比较通过，`stages[].reference_passed` 表示阶段结果通过。attention 保存 `O`、`log_sum_exp` 和对应最大绝对误差；小型 kernel 保存 `shape`、`output`、`reference` 和 `max_absolute_error`。

比较条件为 `abs(actual - expected) <= 1e-10 + 1e-9 × abs(expected)`，并要求数值有限。数值计算采用 host-float64；f16/f32 保留 IR 类型标记，转换不模拟硬件舍入。这里验证 CPU 解释模型中的计算行为。

trace 每行是一个 JSON 对象：

| 字段 | 含义 |
| --- | --- |
| `stage`、`ir_stage` | 执行模式和当前操作所属阶段 |
| `program_id`、`loops` | 逻辑 program 和当前循环变量 |
| `file`、`line`、`column` | MLIR 源码位置 |
| `opcode`、`result` | 操作名称和 SSA 结果 |
| `entry` | 实际调用的语义入口 |

终端中的 `steps` 和 `calls` 分别表示操作计数和原语调用计数。结果在执行结束后写出，trace 在执行过程中写出；重复使用输出路径会覆盖文件。

## 4. 从编译结果生成 vector-add mixed 示例

```sh
_build/kernel-compiler/bin/python scripts/compile_kernel_ir.py \
  --kernel vector_add --target Ascend910B1 --num-warps 4 \
  --signature '{"a":"*fp32","b":"*fp32","out":"*fp32"}' \
  --constants '{"BLOCK":4}' --output _build/compiled-vector-add-static

.venv-attention/bin/python scripts/prepare_kernel_ir.py \
  --kernel vector_add --input _build/compiled-vector-add-static \
  --output _build/runnable-vector-add-static

for stage in hfusion hivm mixed; do
  "$KERNEL_BIN" --kernel vector-add --stage "$stage" \
    --ir "_build/runnable-vector-add-static/vector_add_$stage.mlir" \
    --output "reports/vector-add-static-$stage.json" \
    --trace "reports/vector-add-static-$stage.jsonl"
done
```

该 Triton 函数展开两个分块。mixed IR 的第一个分块取自 HFusion，第二个分块取自 HIVM，通过 xDSL 维护 SSA 引用。默认输入对应输出 `[-2, 1, 3, 4.5, 0, 0, 8.25, 15.5]`。

## 5. 使用自己的 attention 输入

将以下代码保存为 `reports/make_input.py`：

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

```sh
.venv-attention/bin/python reports/make_input.py
"$ATTENTION_BIN" --stage hivm \
  --ir _build/compiled-attention/_attn_fwd.hivm.mlir \
  --input reports/input.json --output reports/custom-attention.json
```

O 的每个元素应为 `0.75`，log_sum_exp 的每个元素应为 `log(128)`。输入 JSON 的 `Q`、`K`、`V` 使用二维数组，可选 `scale` 省略时使用 `1 / sqrt(128)`，所有数值必须有限。

## 6. 命令参数和错误检查

| 参数 | 用法 |
| --- | --- |
| `--stage hfusion/hivm/mixed` | 选择执行阶段 |
| `--ir PATH` | 指定本次编译生成的 MLIR |
| `--kernel vector-add/row-sum` | 选择小型 kernel 的输入绑定和参考计算 |
| `--length N` | 指定动态 vector-add 的输入长度 |
| `--input PATH` | 指定 attention 输入 JSON |
| `--output PATH` | 指定结果 JSON，省略时输出到终端 |
| `--trace PATH` | 指定原语调用 JSONL |
| `--max-steps N` | 指定正整数执行预算，默认 1000000 |

输出文件的父目录必须存在。编译命令发现不支持的 signature 或 constants 时立即报错；解释执行还会检查阶段、操作、类型、内存访问和计算结果。

```sh
.venv-attention/bin/python scripts/check_attention_xdsl.py _build/compiled-attention/_attn_fwd.hfusion.mlir
.venv-attention/bin/python scripts/check_attention_xdsl.py _build/compiled-attention/_attn_fwd.hivm.mlir
```

| 错误 | 检查方法 |
| --- | --- |
| 找不到 Python | 使用对应 Python 可执行文件的完整路径 |
| xDSL 导入失败 | 检查 `.venv-attention`，重新执行 bootstrap 安装依赖 |
| 输出文件无法打开 | 创建输出路径的父目录 |
| 输入形状错误 | 检查输入数组的尺寸和层次 |
| `unsupported` 或阶段不匹配 | 根据源码位置检查操作、类型、属性和 `--stage` |
| 执行预算耗尽 | 检查循环边界和操作数量 |
| 参考比较失败 | 阅读结果误差，通过 trace 定位相关操作 |

## 7. 运行仓库回归测试

源码构建环境中执行：

```sh
opam exec --switch=unified-interpreter -- dune runtest --force
```

仓库归档的批量更新及检查使用同一编译流程：

```sh
TRITON_PYTHON=python3.10 ATTENTION_PYTHON=python3.12 sh scripts/generate_kernel_ir.sh
sh scripts/check_compiled_kernels.sh
```

批量脚本更新 `artifacts/kernels/` 和 `examples/kernels/`，检查 24 次执行，结果写入 `reports/compiled-kernels/`。

## 8. 阅读实现

| 内容 | 文件 |
| --- | --- |
| Triton 编译和参数检查 | [compile_kernel_ir.py](../scripts/compile_kernel_ir.py) |
| 静态入口准备与 mixed 组合 | [prepare_kernel_ir.py](../scripts/prepare_kernel_ir.py) |
| MLIR 前端 | [attention_frontend.py](../scripts/attention_frontend.py)、[parser.ml](../attention/parser.ml) |
| 操作验证和执行 | [validate.ml](../attention/validate.ml)、[runner.ml](../attention/runner.ml) |
| effect handler 与内存 | [handlers.ml](../attention/handlers.ml) |
| attention 输入和参考计算 | [attention.ml](../attention/attention.ml) |
| 动态 vector-add 执行 | [vector_add.ml](../attention/vector_add.ml) |
| 小型 kernel 自定义数据接口 | [kernel.ml](../attention/kernel.ml) |
| Rocq 导出语义 | [Extract.v](../rocq/Extraction/Extract.v) |
| 解释器设计 | [attention-interpreter-design.md](attention-interpreter-design.md) |

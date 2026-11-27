# release_v0 开发与发布指南

## 从源码构建离线可执行文件

### 在 Ubuntu 上用 OCaml 和 Dune 编译

以下命令适用于 Ubuntu 24.04 x86_64。在 `release_v0` 分支的仓库根目录执行。首次安装需要联网。

**安装系统依赖并创建 OCaml 环境。** 首次使用 opam 时执行 `opam init`。已有名为 `unified-interpreter` 的 OCaml 5.3.0 switch 时可以直接使用它。

```sh
sudo apt-get update
sudo apt-get install -y build-essential ca-certificates curl git libgmp-dev \
  libsqlite3-dev opam pkg-config python3 python3-venv unzip bubblewrap
mkdir -p _build/task-tmp
export TMPDIR="$PWD/_build/task-tmp"
opam init --bare --no-setup -y
opam switch create unified-interpreter ocaml-base-compiler.5.3.0
opam repository add coq-released https://coq.inria.fr/opam/released --switch=unified-interpreter
opam install --switch=unified-interpreter -y rocq-core.9.1.0 rocq-stdlib.9.1.0 \
  rocq-runtime.9.1.0 rocq-stdpp.1.13.0
opam install --switch=unified-interpreter -y . --deps-only --with-test
```

**编译并运行解释器。** Python 环境用于解析 MLIR；解释器和调度器由 Dune 编译。最后一条命令直接运行生成的 OCaml 程序，预期 JSON 中的 `status` 为 `returned`。

```sh
ATTENTION_PYTHON=python3 sh scripts/bootstrap_attention.sh
opam exec --switch=unified-interpreter -- dune build --profile release bin/main.exe
opam exec --switch=unified-interpreter -- _build/default/bin/main.exe \
  run examples/kernels/vector_add_hivm.mlir --stage hivm --seed 17 --trace-db :memory:
```

修改 OCaml 代码后可重复执行上述 Dune 命令。运行仓库测试使用 `opam exec --switch=unified-interpreter -- dune runtest`。

**生成可复制到其他机器的离线单文件。** 在同一工作区安装发布版本使用的 BiShengIR，使用刚才的 Python 虚拟环境执行打包脚本。脚本会把该环境、厂商解析器和已编译的 OCaml 程序一起打入 `_build/offline/unified-interpreter`。[打包脚本](../scripts/build_offline.py)

```sh
.venv-attention/bin/python -m pip install --no-deps --target "$PWD/_build/vendor" \
  --index-url https://mirrors.huaweicloud.com/ascend/repos/pypi triton-ascend==3.6.0.post2
vendor_opt="$PWD/_build/vendor/triton/backends/ascend/bishengir/bin/bishengir-opt"
opam exec --switch=unified-interpreter -- .venv-attention/bin/python \
  scripts/build_offline.py --bishengir-opt "$vendor_opt"
./_build/offline/unified-interpreter run examples/kernels/vector_add_hivm.mlir \
  --stage hivm --seed 17 --trace-db :memory:
```

在源码目录调试厂商语法时，可给 `_build/default/bin/main.exe run` 显式传入 `--bishengir-opt "$vendor_opt"`。发布单文件会自动找到随包提供的解析器。

### 使用 Docker 构建

在安装了 Docker 的 Linux x86_64 机器上检出 `release_v0`，进入仓库根目录。首次构建需要联网下载依赖。以下命令使用与 CI 相同的 `offline-builder` 目标，在容器中编译并测试，再将单文件产物复制到当前工作区。

```sh
docker build --target offline-builder -t unified-interpreter:release-v0 .
mkdir -p _build/offline
container=$(docker create unified-interpreter:release-v0)
docker cp "$container:/build/_build/offline/unified-interpreter" _build/offline/
docker rm "$container"

./_build/offline/unified-interpreter run examples/kernels/vector_add_hivm.mlir \
  --stage hivm --seed 17 --trace-db :memory:
```

最后一条命令应输出 JSON，`status` 为 `returned`。构建环境使用 Ubuntu 24.04、OCaml 5.3.0 和 Rocq 9.1.0。OCaml 依赖、Python 依赖和厂商编译器版本分别由 opam 文件、Python 依赖清单和 Dockerfile 管理。[Dockerfile](../Dockerfile) · [OCaml 依赖](../unified_interpreter.opam) · [Python 依赖](../requirements-attention.txt)

## 修改代码时从哪里开始

| 要修改的行为 | 源码入口 |
|---|---|
| 命令行输入和结果 JSON | [source_run.ml](../bin/source_run.ml) 读取源文件、选择 IR 层、取得启动配置，最后输出状态、内存和函数返回值。 |
| HIVM 与 HFusion 解析 | [mlir_frontend.py](../scripts/mlir_frontend.py) 导出模块 JSON，[hivm_module.ml](../lib/hivm/hivm_module.ml) 将其读入两层共用的 OCaml AST。离线运行时先尝试 xDSL，遇到语法解析错误时调用随包提供的 BiShengIR。 |
| kernel 输入与启动实例 | [random_launch.ml](../bin/random_launch.ml) 生成输入，[mlir_launch.ml](../lib/hivm/mlir_launch.ml) 按入口类型绑定参数、缓冲区和执行流。已登记用例按 IR 层和源文件 SHA-256 查找[启动配置模板](../benchmarks/scheduler/launch-profiles.json)。修改用例源码后应同步核对目录摘要和模板键。 |
| 调度与 trace | [module_execution.ml](../lib/hivm/module_execution.ml) 的 `next_trace` 将同一个源 AST 和启动配置交给分析器，默认选择 BFS。[mlir_trace.ml](../lib/hivm/mlir_trace.ml) 组织程序分析，[trace_delivery.ml](../lib/scheduler/trace_delivery.ml) 选择并记录本次返回的调度。 |
| 源程序执行与回放 | [source_execution.ml](../lib/hivm/source_execution.ml) 实现执行。`execute_trace` 在调度点使用 trace 给出的选择，结束时核验终止状态。调试时可用 `--builtin` 单独检查解释器自身的调度行为。 |

复现输入时固定 `--seed` 或使用同一份 `--launch`。复现首次调度时使用 `--trace-db :memory:`。研究同一输入的两个调度顺序时，连续两次使用同一个数据库文件。启动配置字段和输出格式见[使用文档](offline-executable.md)。

## 修改后怎样验证

**验证自动解析和启动配置。** 在仓库根目录使用 Python 3 运行以下脚本。它遍历目录中的 84 个 benchmark，每个程序的 HIVM 和 HFusion 各执行一次。测试向实际发布文件传入源文件、IR 层和固定种子，检查返回的配置和执行状态；另用一个带动态维度的小程序检查输入复现和返回值。[测试脚本](../scripts/check_random_launch.py) · [用例目录](../benchmarks/ir-pairs/catalog.json)

```sh
python3 scripts/check_random_launch.py _build/offline/unified-interpreter
```

**验证离线执行和调度回放。** 修改调度、解释执行或打包依赖后，可按 CI 的方式在禁用网络的容器中运行基准测试。测试驱动用镜像中的编译器准备输入，隔离环境中的可执行文件自行选择解析器。每个 IR 版本使用相同输入和同一份调度历史执行两次，共 336 次。下列命令把逐次结果保存到宿主机的 `_build/offline/results.csv`。[测试驱动](../scripts/check_interpreter_matrix.py) · [CI 工作流](../.github/workflows/build.yml)

```sh
docker run --name release-v0-matrix --network none --privileged \
  unified-interpreter:release-v0 sh -ec '
    .venv-attention/bin/python scripts/check_interpreter_matrix.py \
      --offline _build/offline/unified-interpreter --scheduled \
      --output _build/offline-validation --results _build/offline/results.csv \
      --bishengir-opt "$BISHENGIR_OPT"
  '
docker cp release-v0-matrix:/build/_build/offline/results.csv _build/offline/
docker rm release-v0-matrix
```

检查 CSV 中的 `status`、`check` 和 `race_order`。部分用例预期报告死锁或无效内存访问。`race_order=opposite` 表示两次执行中同一对竞争事件的顺序相反。`wall_seconds` 包含启动、解析、调度、解释执行以及收取输出的时间。仓库中有可供核对的[逐次执行记录](../benchmarks/results/scheduled-interpreter-matrix.csv)和[自动解析测试记录](../benchmarks/results/offline-auto-parser.md)。

### 发布版本的 benchmark 运行结果

按默认测试输入和项目的 IR 语义，源码核查与执行记录在 84 个 benchmark 中确认了 **55 个有问题的用例**，两次调度在这 55 个用例中均检出了至少一种问题。HIVM 和 HFusion 分别计数时，已确认有问题的 IR 版本为 74 个，检出 74 个。同一版本即使同时存在死锁和竞争，也只计入总数一次。[逐个用例的源码判断](../benchmarks/results/source-fault-audit.md)

| IR 层 | 测试版本数 | 已确认有问题 | 检出至少一种问题 | 两条 trace 显示竞争 | 报告死锁 | 报告越界 | 报告未初始化描述符 | 两次运行累计耗时 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| HIVM | 84 | 46 | 46 | 36 | 9 | 1 | 0 | 96.52 秒 |
| HFusion | 84 | 28 | 28 | 26 | 0 | 1 | 1 | 129.57 秒 |
| 合计 | 168 | 74 | 74 | 62 | 9 | 2 | 1 | 226.09 秒 |

已确认存在竞争的 IR 版本共 **64 个**。其中 **62 个**在两条 trace 中展示了同一对冲突访问以相反顺序完成。其余两个 HIVM 版本 `fixture/duplicate-set` 和 `issue316/missing-ready` 在死锁前存在竞争，本次运行报告了死锁。[源码核查](../benchmarks/results/source-fault-audit.md) · [逐次执行结果](../benchmarks/results/scheduled-interpreter-matrix.csv)

每个 IR 版本执行两次，共 336 次。各版本首次运行耗时合计 144.48 秒，第二次合计 81.61 秒。表中使用每次从进程启动到收完输出的 `wall_seconds`，包括解析、调度和解释执行。226.09 秒是逐次耗时之和，并行运行整批测试的实际经过时间未单独记录。

## 打包与发布

[打包脚本](../scripts/build_offline.py)将 OCaml 可执行文件、Python 运行环境、前端脚本、启动配置模板、BiShengIR 和所需动态库归档，编译 [C 启动器](../release/launcher.c)，并将归档追加到启动器末尾。新增前端模块或运行时数据文件时，应检查打包脚本的复制清单，再用重新生成的单文件运行相关用例。

启动器按归档 SHA-256 在用户缓存目录中选择解包位置，设置运行时路径，再启动 OCaml 解释器。排查“源码可以运行，发行文件缺少模块或文件”时，可指定新的绝对缓存目录，用下面的命令复现首次启动。

```sh
XDG_CACHE_HOME="$PWD/_build/release-cache-check" \
  ./_build/offline/unified-interpreter run examples/kernels/vector_add_hivm.mlir \
  --stage hivm --seed 17 --trace-db :memory:
```

推送分支或手动触发 GitHub Actions 后，查看 `Build and verify offline interpreter` 工作流。离线基准测试通过后，工作流上传 `offline-interpreter-linux-x86_64` 构建产物，其中包含带 SHA-256 校验文件的发布压缩包、`results.csv` 和用户使用文档。[发布步骤](../.github/workflows/build.yml)

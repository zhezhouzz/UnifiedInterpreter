# 语料库与过渡版工具链运行手册（L3 / L4）

> 本文件是 `benchmark/corpus/` 的**技术运行手册**。项目总览、分层体系（L1–L4）、语义对齐与重建规范请见 [../README.md](../README.md)；精选同步/并发靶场请见 [../SYNC_ISSUES.md](../SYNC_ISSUES.md)。

本目录当前存放 **16 个来源组、212 个去重可重放 MLIR 输入**（[CATALOG.md](CATALOG.md)），以及 **72 份 GitCode issue、39 个修复 MR patch、8 份证据包** 的原始归档（[evidence/README.md](evidence/README.md)）。

> **过渡态说明**：当前 `tools/elaborate.py` 与各用例的 `Fixture.v` 面向的是上游 `core_language` 分支（固定在 `d3317199a98a81e235af54d2fa30a6cfbf81bf62`）的直线单流子集。它**尚未**接入 [docs/core-language-opsem.tex](../../docs/core-language-opsem.tex) 中的 `pipebarrier`、跨核 `syncblock`、动态 `for` 与完整 `alloc` 语义，因此真实 MLIR 整函数翻译率偏低（17/212），其余主要通过基本块切片（197/212）验证解析器与事件抽取能力。

---

## 1. 环境依赖与一键运行

依赖：Python 3、Rocq（实测 `9.1.0`）、带 `compile_commands.json` 的 AscendNPU-IR Ninja build（实测 `bishengir-opt 1.2.0`，提交 `fbdf863a8c8c268e5cfea0d5f1d921e227267fd5`，指纹见 [../toolchain.txt](../toolchain.txt)），以及含上述 upstream commit 的 UnifiedInterpreter checkout。

```sh
cd benchmark/corpus
build="${ASCEND_BUILD:-$HOME/GIT/Distributed/AscendNPU-IR/build}"
scratch=$(mktemp -d)
git clone -q --single-branch -b core_language https://github.com/zhezhouzz/UnifiedInterpreter.git "$scratch/upstream"

# 1) 编译基于 AscendNPU-IR dialect registry 的原生 MLIR reader
python3 tools/build_reader.py "$build" "$scratch/reader"

# 2) 运行同步正负对照与 #981 内存别名演示
python3 tools/demo.py --bin "$build/bin" --reader "$scratch/reader"

# 3) 全量校验：212 例重编译比对 + 翻译/诊断复核 + 215 个 Rocq Fixture 类型检查
python3 tools/check.py --bin "$build/bin" --reader "$scratch/reader" --upstream "$scratch/upstream"
```

单文件翻译入口（成功时向 stdout 输出 `.core`，遇到不支持结构时向 stderr 输出 JSON 诊断并返回退出码 `2`）：

```sh
# 整函数翻译并观察 UB 字节 0
python3 tools/elaborate.py handwritten/ready-and-drain/hivm.mlir \
  --reader "$scratch/reader" --function ready_and_drain --watch-ub-byte 0

# 指定同一基本块内的行区间切片（起止行均包含）
python3 tools/elaborate.py tutorial/vector_sum/hivm.mlir \
  --reader "$scratch/reader" --function vector_sum --lines 9 16

# 将 .core 转换为上游 Axiomatic.Syntax Rocq 模块
python3 tools/core_to_rocq.py handwritten/ready-and-drain/expected.core
```

---

## 2. 工具链与用例文件说明

### `tools/` 脚本职责

| 文件 | 作用 |
|---|---|
| `ir.cpp` / `build_reader.py` | 复用 AscendNPU-IR build 的编译与链接参数注册 MLIR/BiShengIR dialect，将真实 MLIR 解析为 JSON AST（保留 SSA、类型、属性、region 与基本块） |
| `elaborate.py` | 将 post-sync HIVM 翻译为直线 core 片段，保留有向 `(set_pipe, wait_pipe, event_id)`；不支持的结构输出位置、op 与原因 |
| `core_to_rocq.py` | 将 `.core` 文本转为上游 `CoreLanguage.Axiomatic.Syntax` 的 `shared_program` |
| `memref_lane.py` | 针对 `#981` 等 MemRef/subview 案例构造按 lane 观察的顺序完成对照模型 |
| `demo.py` | 运行手写同步正负对照（缺 wait 最短 witness、A4 检查）、`#981` lane 对照与 `#920` 回归检查 |
| `check.py` | 全量自动化校验脚本，输出应与 [verification.txt](verification.txt) 一致 |

### 单个用例目录内文件约定

| 文件 | 含义与边界说明 |
|---|---|
| `case.json` | 元数据：输入层、编译 `argv`、原始来源/issue、目标函数、切片行号与预期诊断 |
| `source.mlir` / `hivm.mlir` | 可重放的编译输入与固定编译器实际输出（注意：部分回归用例仍在 tensor/CV 中间层） |
| `actual.core` / `slice.actual.core` | `elaborate.py` 在整函数或指定基本块切片模式下的实际产出；**切片仅表示“控制流已到达此处”，不能脱离入口状态直接判死锁** |
| `expected.core` / `expected.kernel.core` | 手写组为独立编写的协议预期；其余组多为 LLM 辅助生成的直线投影（12 个教程组另附带逻辑围栏键 90/91 的参考模型，非硬件事件） |
| `diagnostics.json` | 整函数与切片分别记录的未支持操作、位置与原因 |
| `Fixture.v` | 可导入上游 `Axiomatic.Syntax` 的 Rocq 定义；编译通过仅表示 AST 良构，**不代表已证明同步安全** |

---

## 3. 来源取材与许可声明

- **官方测试（13 组）**：源自固定提交 `fbdf863a8c8c268e5cfea0d5f1d921e227267fd5` 下的 GSS、InjectSync、控制流、unit flag、custom macro、内存规划、DMA、对齐、CV 等测试，去除了 lit/FileCheck 注释并按独立 split 去重。许可证与声明见 [../licenses](../licenses)。
- **手写协议族（14 例）**：[handwritten/](handwritten/) 提供核内同步正负对照（缺 wait、重复 set、反方向同号事件、错误消费者 pipe、两轮交接等）。
- **教程特化（12 例）**：[tutorial/](tutorial/) 保留原 Python 表达式行号与手工 32-lane MLIR 特化；另在 [evidence/triton-tutorials/index.json](evidence/triton-tutorials/index.json) 与 [evidence/distributed-tutorials/index.json](evidence/distributed-tutorials/index.json) 归档了 14 个算子教程与 20 个分布式教程原文件。
- **GitCode Issue 与修复 MR 归档**：全量 72 份 issue、39 个 MR patch 与 8 份报告者 ZIP 位于 [evidence/](evidence/README.md)；其中真正属于同步/并发验证目标的精选清单见 [../SYNC_ISSUES.md](../SYNC_ISSUES.md)。

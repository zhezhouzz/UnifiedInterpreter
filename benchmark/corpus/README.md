# 用新版 core 检查 AscendNPU-IR

从 [212 个可编译输入](CATALOG.md) 或 [72 个 GitCode issue 和 39 个关联 MR](evidence/README.md) 开始。主表有 16 个来源组，每组 10–28 例。来源组指教程、回归套件、pass 测试或手写协议族，同一仓库可贡献多组。计数按不同的编译输入内容去重。变异有独立输入；同一输入的芯片、pass 开关、不同切片和附件中的日志不再增加例数。

**目标语义**采用上游 `core_language` 的公理化 AST，固定在 `d3317199a98a81e235af54d2fa30a6cfbf81bf62`。附来的 syntax 和 trace 两份 PDF 与该提交里的 PDF 逐字节相同。每例的 `Fixture.v` 导入 `CoreLanguage.Axiomatic.Syntax` 并构造 `shared_program`。该层把单个执行流的管道、执行单元和事件作为参数；不同流不能仅凭同名管道合并。跨核广播需要另外提供实际参与者和协议。[上游语法](https://github.com/zhezhouzz/UnifiedInterpreter/blob/d3317199a98a81e235af54d2fa30a6cfbf81bf62/rocq/CoreLanguage/Axiomatic/Syntax.v) · [上游 trace 谓词](https://github.com/zhezhouzz/UnifiedInterpreter/blob/d3317199a98a81e235af54d2fa30a6cfbf81bf62/rocq/CoreLanguage/Axiomatic/TraceSemantics.v) · [本分支的芯片配置](../profiles/README.md)

## 三分钟演示

1. **第 1 分钟，解释一个允许轨迹上的错误。** 依次打开 [正常例的 HIVM](handwritten/ready-and-drain/hivm.mlir)、[观察 UB 地址 0 的 core](handwritten/ready-and-drain/watch-ub0.core) 和 [删除 wait 的 core](handwritten/ready-without-wait/watch-ub0.core)。检查“V 开始读这个地址时，MTE2 的写是否已完成”。在此单分支、静态键、有限 start/end 模型中，正常例穷尽 21 个可达状态。删 wait 后的最短见证是 load 发起、set 发起、V 发起，此时 load 尚未完成。这个见证只需操作时间和同址访问。
2. **第 2 分钟，解释非法候选。** 打开 [两次 set 的程序](handwritten/overlapping-sets/expected.core)。让两个 set 先后完成，第二个完成就违反 A4。改成 S W S W 或在另一个有向键上 set，可通过该投影检查。负例标注的是这一候选完成序列；同一源程序还可能有其他候选。另一项 [单分支对照](handwritten/wrong-consumer-pipe/case.json) 说明，即使匹配的 wait 发给 MTE3，A2 也会阻塞本分支后续的 V 指令；只看目标 pipe 容易误报。
3. **第 3 分钟，给出真实误编译。** [#981 原始 MLIR](evidence/issues/981/quoted/fragment-1.mlir) 用两个重叠 subview 修改前 64 个元素。旧版 `canonicalize-ext` 仍保留 fill，却把最后的 copy 改成直接从输入读。用常数 7 作为输入，只观察一个坐标，源程序与优化程序在 lane 0、63 分别给出 0 和 7，在 lane 64、127 都给出 7。此处用顺序完成、不同参数不别名的 copy/fill 模型，对应优化发生的 MemRef 层。另可展示 [#920 修复测试](repair-regression/issue-920-mr-5025/case.json)，同一本机编译器的 skew 输出触发了两个上游禁止条件。[实际运行记录](verification.txt)

## 运行与接入

需要 Python 3、Rocq、带 compile_commands.json 的 AscendNPU-IR Ninja build，以及含上述 upstream SHA 的 UnifiedInterpreter checkout。实测使用本机 bishengir-opt 1.2.0，源提交 `fbdf863a8c8c268e5cfea0d5f1d921e227267fd5`，Rocq 9.1.0。reader 用该 build 自己的编译与链接参数注册 MLIR/BiShengIR dialect，单独生成一个可执行文件。[编译器指纹](../toolchain.txt)

```sh
cd ~/GIT/Distributed/UnifiedInterpreter/benchmark/corpus
build=~/GIT/Distributed/AscendNPU-IR/build
scratch=$(mktemp -d)
git clone -q --single-branch -b core_language https://github.com/zhezhouzz/UnifiedInterpreter.git "$scratch/upstream"
python3 tools/build_reader.py "$build" "$scratch/reader"
python3 tools/demo.py --bin "$build/bin" --reader "$scratch/reader"
python3 tools/check.py --bin "$build/bin" --reader "$scratch/reader" --upstream "$scratch/upstream"
```

对一个新文件使用以下入口。正常结果输出 core 到 stdout。解析错误或不支持的操作输出 JSON 到 stderr，进程退出码为 2。行号起止均包含，按输入文件编号；可用切片必须在一个基本块内。对原始带有其他调试位置的 MLIR，先用 bishengir-opt 普通打印后再按该文件选行。

```sh
python3 tools/elaborate.py handwritten/ready-and-drain/hivm.mlir \
  --reader "$scratch/reader" --function ready_and_drain --watch-ub-byte 0
python3 tools/elaborate.py tutorial/vector_sum/hivm.mlir \
  --reader "$scratch/reader" --function vector_sum --lines 9 16
python3 tools/core_to_rocq.py handwritten/ready-and-drain/expected.core
```

`tools/check.py` 从每份 `source.mlir` 重跑 case.json 中的 argv，逐字节比较 `hivm.mlir`，重跑整函数与切片 elaboration（含预期诊断），把 core 转成真实上游 AST，并编译所有 Fixture。215 个模块通过了 Rocq 类型检查。trace 语义是谓词；该数目不表示已对 215 个程序证明安全。

## 每例如何读

| 文件 | 用途 |
|---|---|
| source.mlir、hivm.mlir | 可重放的编译输入和本机实际输出。case.json 记录输入层、pass 参数、原始文件或 issue、切段号和选定函数。 |
| expected.core | 手写组使用独立的预期指令序列。其他组提供 LLM 设计、按源行物化的直线协议投影，范围见 projection；单个片段可能从已发出通知的中间状态开始。 |
| expected.kernel.core | 12 个教程例子另有 LLM 编写的整段时间顺序参考模型。它覆盖手工特化的全部算术步骤及末尾排空，用新逻辑键 90/91 的同 pipe set/wait 表达加强的顺序约束。人工围栏事件只用于参考，不是硬件事件，也没有证明它与 barrier 轨迹等价。 |
| actual.core、slice.actual.core | 原生 parser 加 elaborator 成功时生成。整函数通过 17/212；显式切片通过 197/212，全部与对应 expected 的 AST 在局部变量改名后相同。两个分母相同，不能相加。 |
| diagnostics.json | 失败的位置、原操作和原因，整函数与切片分别记录。常见缺口是地址/别名、循环携带值、barrier、tensor 阶段和跨核参与者。 |
| Fixture.v | 下游 Rocq 工具的直接入口。expected、actual 和 slice_actual 在存在时分别定义。用原生类型参数、操作构造子与地址类型，无需下游先实现文本 parser。 |

默认翻译观察**单流发起/完成及核内通知顺序**。原生 reader 读取 SSA、类型、属性、嵌套 region 和基本块。静态地址准备与常量可折叠；DMA 和支持的 Vector 操作用无数据操作数的抽象 compute 保留异步时间点。局部有向键保留 set_pipe、wait_pipe 与 event ID，SSA 常整数事件可折叠，真正依赖运行时的事件会诊断。需要观察内存时，`--watch-ub-byte` 只跟踪一个具体 UB 字节上的已解析访问，写值是用于区分写入的标记。读写同址的复合操作、模糊视图、未知目的 pipe 等需要附加规则。教程模型与通用协议翻译均未验证浮点值、物理延时或硬件计数器。

**切片输入的使用条件。** 片段只声明“控制流已到达此处”。必须由调用方提供适当的在途工作、通知和内存状态；在独立空状态运行中间片段不能据此判上游死锁。只有明确选择 `--lines` 才裁剪；遇到不支持操作的整函数不输出残缺程序。修复回归组会保留回归测试自己的 pass；部分实际产物仍处于 tensor/CV 中间层。顶层芯片核数、源测试名称以及局部 GSS 的执行均不能单独证明例子已经完成分核或跨核同步。

## 取材、许可和后续计划

- **GitCode** 保存 72 份带正文和更新时间的报告，覆盖同步、地址别名、缓冲生命周期、精度、布局、标量/向量、分核和性能。从报告中另抽了 48 个标为 MLIR 的 fenced block。正文片段可能是解释性片段。39 个不同 MR 的元数据与 patch 单列，测试按提交和路径归档。标题里的 feature、讨论的历史 MR 和报告者推测均保留原意；链接本身不证明某个缺陷已经修好。8 份原始 ZIP 的 manifest 文件摘要已比对，其中的日志属于报告者。对 #1022 等例同时保存**证据包的修复提交**与**下载时的 MR head**。[问题与修复索引](evidence/README.md)
- **教程** 主表 12 项保留原 Python、函数、表达式、行号和手写的 32-lane MLIR 特化。编译器对这个特化真正运行 GSS；掩码、原数据类型、整 kernel 的 Triton front end 与真实地址生成不在这些算术切片内。另收了 14 个 triton-ascend-ops 和 20 个分布式教程原文件，便于后续取通信与跨核片段。[算子教程](evidence/triton-tutorials/index.json) · [分布式教程](evidence/distributed-tutorials/index.json)
- **官方测试** 以独立函数/可单独解析的 split 为单位，保留固定提交、路径和 split_index；本机编译输入删去 lit 指令与 FileCheck 注释。各组有 GSS、InjectSync、控制流、unit flag、custom macro、内存规划、DMA、对齐、CV 等。常用方法是对测试源实际运行核内 GSS；收集自内存规划或 CV 目录不等于本次运行了该目录原 RUN 的所有 pass。修复 MR 的原始测试另以未剪裁形式保存。[AscendNPU-IR 许可证与 NOTICE](../licenses)
- **手写** 14 个协议模型提供正负对照，变更可定位到等待、方向、事件号或重复通知。后续优先对能观察值/顺序的真实报告做修复前后成对比较，再围绕最小 witness 变异。跨核 1:2 优先收集同一次编译的 AIC/AIV 及 subblock guard；有了参与者身份，再检验两个不同收件人都 wait。#852 的容量溢出另需计数器边界。#316 已有上游给出的双缓冲程序与已证明性质，适合作为接入循环时的参考。[#316 的上游 Rocq 程序](https://github.com/zhezhouzz/UnifiedInterpreter/blob/d3317199a98a81e235af54d2fa30a6cfbf81bf62/rocq/CoreLanguage/Axiomatic/Issue316.v)

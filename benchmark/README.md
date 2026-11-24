# Ascend HIVM 同步与并发 benchmark

从固定编译器输出的 HIVM 出发，用 BiShengIR 原生 reader 读取整函数，再对具体启动配置探索所有小步交错。面向演示的入口是 [L1](L1)，Issue/MR 的证据和优先级见 [SYNC_ISSUES.md](SYNC_ISSUES.md)。

## 1. 重放与演示

在仓库根目录执行。默认使用本机 `~/GIT/Distributed/AscendNPU-IR/build` 的 Ninja build，验证三个工具的 SHA-256，重新生成两种芯片配置，在临时目录编译 C++ reader。

```sh
python3 benchmark/bench.py
python3 benchmark/bench.py --demo
python3 benchmark/bench.py --demo --case add-Ascend910B1
```

全量运行逐个重编译、逐字节比较 HIVM，随后重跑翻译、静态检查、BFS，并逐文件核对预存结果。任一差异都会返回非零。演示输出 stream 编号、动态指令序号、队列完成、观察结果和状态数。已有匹配 build 的 reader 可用 `--reader /absolute/path/to/reader` 复用。其他 Ninja build 位置由 `--build` 指定。

## 2. 实测结果

| 层   | 用例目录 | 字节一致的编译产物 | 所有指定入口均整函数翻译 | 静态良构通过   | buggy 有反例且 fixed 穷尽通过 |
| --- | ---: | --------: | -----------: | -------: | --------------------: |
| L1  | 7    | 12        | 8            | 8        | 4 对                   |
| L2  | 11   | 22·       | 20           | 20       | 8 对主语义 + 2 对显式扩展      |
| L3  | 213  | 213       | 80           | 14       | 未设执行 oracle           |
| 合计  | 231  | 247 / 247 | 108 / 247    | 42 / 108 | 12 对主语义 + 2 对扩展       |

同一目录可包含两个编译变体。247 个产物来自 243 份按内容去重的输入。243 个产物由成功退出的 `bishengir-opt` 生成，含仅 parse/print 或 canonicalize 的输入；4 个是 `bishengir-compile` 的整模块 pass dump，后端完成不在这个指标内。139 个变体产生整函数诊断。另有 66 个已翻译变体缺少活动流配置，静态检查给出原因。扩展配置占翻译和静态通过数各 4 个。全量基线见 [verification.json](verification.json)。

### 演示入口

| 用例 | buggy 可观察行为 | fixed 的检查范围 |
|---|---|---|
| [910B1 Triton add](L1/triton-add/Ascend910B1) | 两个 GM 输入为 2、3，store 可在 vadd 前完成，输出 2 | block 0、一个完整 256 元素 tile、普通 mask；全部交错输出 5 |
| [MIX 交接](L1/mix-handoff) | AIV 可在 Fixpipe 写回前从 workspace 读到 2 | AIC FIX 通知、AIV 标量 wait 后读到 7 |
| [双缓冲](L2/double-buffer) | 第三轮写回 A 槽，第一轮 V 操作随后读到 7 | 动态三轮 A/B/A，期望读值 3、3、7 |
| [零轮循环](L2/zero-trip-alias) | 丢失初始别名的依赖，最终 GM 值可为 uninit | trip count 为 0 时消费初始 view，写回 7 |
| [间接原子](L2/indirect-atomic) | 去掉 atomic→reload 边后观察到错误输出 | MR 回归的 16 个活动 lane、各自寻址一个独立位置，reload 读到加法结果 |
| [空生产者](L2/empty-preload)、[同步错置](L2/cross-loop-placement)、[广播 guard](L2/broadcast-guard) | 标量等待死锁、队列等待死锁、第二个 AIV 的残留令牌 | 分别检查两个接收者、两个动态轮次和 sub-block 条件 |
| [#1047](L2/scalar-fallback)、[#852](L2/counter-capacity) | 在标量写后读到被替换的 UB 值；第 16 次同键通知触及假设的容量边界 | 两个命名扩展，分别检查单 lane V/S 交接与 15+1 事件分配 |

[950PR 同源开关](L1/triton-add/Ascend950PR_9579) 在同一个 pass 边界得到相同的整模块输出。两边均含 4 set、4 wait、1 barrier；outlined VF 和控制寄存器操作目前给出诊断。[#920](L1/issue-920) 重现两处 FileCheck 排除项失败。[kern3](L1/kern3) 和 [attention](L3/attention) 均以同一次编译的 AIC/AIV 为输入；真实整函数的未支持项记录在各自的 diagnostics.json。

## 3. 目录与入库契约

- [L1](L1) 保存手写协议、真实算子差分以及编译器回归展示。
- [L2](L2) 保存带 issue/MR 溯源的配对模型及报告者前后版本。trace 中的模型结论限定于 case.json 的输入和 oracle。
- [L3](L3) 保存原有 212 份去重输入及一份完整 attention 模块，用于翻译和诊断回归。
- [L4](L4/index.json) 按编号区分 19 个同步候选、2 个内存别名延展（#981、#995）和 51 个其余归档项。原始池包含 72 份报告、39 个 patch、8 份 ZIP 以及教程源码。[归档索引](L4/archive/README.md)
- [profiles](profiles/README.md) 保存芯片配置，[licenses](licenses) 保存原始许可。

每个用例的 `case.json` 声明 id、tier、category、source_ref、chip_profile、core_ratio、compile_argv、entry_functions、expected_verdict 和 oracle_note。通用编译器单测没有声明芯片或 launch 时记为 null。仅有编译回归、无安全 oracle 时 expected_verdict 也为 null。执行案例另存具体输入、活动流及读值或最终值期望。

单变体保存 `source.mlir`、`hivm.mlir` 和自动生成的 `program.core` 或 `diagnostics.json`。双变体使用 `buggy.`、`fixed.` 前缀。源级变异另存 `buggy.source.mlir`，开关差分共用 `source.mlir` 并记录两套 argv。每个通过翻译的变体保存 `static.json`。有执行 oracle 的变体还保存 `execution.json`。L2 附件案例的设备头适配记录在元数据，原件保存在 L4。

## 4. Core 与检查器

[原生 reader](tools/ir.cpp) 导出 SSA、类型、属性、region、block 和位置。[整函数翻译器](tools/elaborate.py) 输出结构化 JSON Core AST。顺序命令数组表示 continuation，if 的局部 end 接回后续命令，for 保存循环体、诱导变量和动态上下界。单个未支持操作会使整个入口集合产生诊断。无行号切片或手写预期 Core 输入。

[操作语义](../docs/core-language-opsem.tex) 的普通 DPS 运算使用实际视图和读写操作数索引。issue 时捕获操作数，完成时读取内存。普通操作可越过已打开的前缀；set 和 barrier 必须在队首完成；wait 和 barrier 遮挡其后的操作。ALL 向本流各数据管道同时入队。局部 flag 与跨流通知使用不同的键，1:2 广播由每个 AIV 分别消费。跨流等待的目标为 S 时阻塞控制流，其他目标在接收队列等待。

[具体执行器](tools/concrete.py) 在给定 launch 下求值不依赖共享内存的标量和动态控制，保留相应控制步骤。[BFS](tools/explore.py) 按步数探索发射、队列完成与可见内存更新，记录首个最短反例。均匀 tile 的每个 lane 初值和操作相同，使用一个代表值。间接原子实例另外固定连续独立地址与全活动 mask。safe 表示该实例的全部可达状态通过 case oracle。重叠 set 与残留令牌由协议观察器报告。

[静态检查](tools/wellformed.py) 在原生 dialect 校验基础上检查 Core 的基本类别、SSA 作用域、region 出口、DPS 视图、计算单元、活动管道及同步端点。前端覆盖面大于具体执行器；每次执行均需给出算子和内存的具体解释。两个可选配置分别为 `local-scalar-memory`（核内标量访存和 V/S 通知）和 `bounded-counter`（容量 15 的反向通知实验）。容量取自报告中的假设。

## 5. 已知缺口

- `allocation()` 单独构造 alloc 节点并保留空间、类型和动态尺寸；后续可集中对齐规范的 alloc 语法。
- 无携带值的动态 for/if 及一类循环不变的 yielded view 已接入。一般迭代携带别名、带结果的分支与多基本块仍输出诊断。
- 带内部同步参数的 `mmadL1`、FFTS、VF 调用、控制寄存器和完整布局解释仍待建模。#920 的编译器回归与真实 950PR 开关结果均未取得执行级安全结论。

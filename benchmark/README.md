# 分核与同步插入后的 HIVM Benchmark

2026-11-23。本机 bishengir-opt 1.2.0，报告源提交 fbdf863a8c8c268e5cfea0d5f1d921e227267fd5，LLVM 19.1.7。本文将每个源 kernel/上游回归函数计作一个输入族，芯片、pass 开关、变异和随机数据记作变体。目录中的材料用于选择下一批翻译目标。

## 第一批入口

| 来源 | 输入 | 供分析的产物 |
|---|---|---|
| 手写 Triton | [masked add 源码](triton/kernels.py)、[此次重放起点 HFusion](triton/add.hfusion.mlir) | [910B1 开启同步](triton/910B1-on.mlir)、[关闭同步](triton/910B1-off.mlir)；跨芯片用 [910B1](triton/910B1-on.after-gss.mlir) 和 [950PR](triton/950-on.mlir) 的同一 GSS 后捕获点 |
| 官方 MLIR 选段 | [kern3 的 backup、AIC、AIV 三个函数](official/mix.mlir) | [跨核同步后](official/mix-v2.mlir)、[跨核和核内同步后](official/mix-both.mlir)。入口为设备端 AIC/AIV 函数 |
| Issue 与修复回归 | [#920 修复 MR 的三个函数](issue920/920.mlir) | [旧版 CV pass 输出](issue920/920-exact.mlir)、[FileCheck 诊断](issue920/920-exact.check)。仍待收集分核及同步插入后的双端产物 |

[分代参数与活动流约定](profiles/README.md) · [重放脚本](replay.py) · [参考输出](actual.txt) · [工具版本与二进制指纹](toolchain.txt)。官方选段及回归输入随附 [AscendNPU-IR 许可和声明](licenses/)。

## 收集方法与后续计划

1. **固定来源与入口层。** 保存仓库、commit、函数和 specialization。手写 Triton 同时登记源码与最后一个可重放的前端产物；issue 记录受影响版、修复 MR 和该测试原始 RUN 行。
2. **确定观察点。** 纯 AIV 在核内同步插入后抓函数；MIX 取同一次编译分核后的 AIC/AIV，确认跨核和核内同步已落实。记录 buffer/view 别名、跨函数参数映射和实际活动 sub-block；有 outlined 函数时一起收集。
3. **建立差分。** 固定输入、芯片和捕获点，只换一个 pass 开关；另外单独做同阶段跨芯片对照。保留日志中的 pass 证据，用 bishengir-opt 复核 IR，再对比有向键、读写位置和收件人。
4. **转 core 并验收。** 优先翻译 add 与 kern3；给定初始 GM/UB、期望值与允许观察，分别检查最终内存、阻塞和通知残留。第二批补 barrier、B0/B1/B0 重用、1:2 与回退、attention 交接。后续 fuzz 可按固定种子变输入、别名偏移、event ID、遗漏等待与 sub-block guard，保存最小见证。第一批当前交付的是编译样例与结构差分。

## 输入目录

| 来源 / 函数 | 现有输入与编译阶段 | 建议观察与优先级 |
|---|---|---|
| 手写 Triton / add_kernel | triton/kernels.py 中的带边界 mask 的 add；triton/add.hfusion.mlir 是同提交的编译归档。此轮从 HFusion 重新编译到同步后 AIV；两代芯片均已取样。 | 第一批。固定满 tile 与尾 tile；比较有效 lane 的输出和无效 lane 的访存。保留条件分支，或给出输入并声明取了哪个分支。 |
| 手写 Triton / vector_add、row_sum | 同一 kernels.py，前者静态展开两个 tile，后者按行归约，上游有 TTIR、HFusion、HIVM 和 provenance。两者此次只登记。 | 第二批。前者适合检验跨 tile 的 UB 重用，后者检验 reduce 与 store 的依赖；以实际 post-sync IR 确认重用或依赖再入库。 |
| 官方同步测试 / kern3_mix_aic + kern3_mix_aiv | official/mix.mlir 是 hivm-dccgss.mlir 的第三个 module，输入已拆为 backup/AIC/AIV。mix-v2.mlir 为 delayed solver 后，mix-both.mlir 再应用核内 GraphSyncSolver。 | 第一批 MIX。选同一 arg1 的 GM 单元，研究 Cube fixpipe 写与 Vector load 读的时序。core 的运行主体只取两个设备函数。保留 backup 作来源对照；anchor 是编译器标记。该单测没有确定运行时 1:2 比例。mmad、nd2nz 若抽象为给定数据须声明。 |
| 官方编译测试 / test_brc_mul__kernel0、test_clampf | 同版 bishengir/test/bishengir-compile/triton/compile-triton-{brc-mul,clampf}.mlir，前次调查已抓到 post-sync AIV。先选 brc-mul；clampf 内有多处 pipe_barrier。 | 第二批。前者扩展算子；后者适合单独删 barrier，比对同管道读写依赖。没有为这两条建立数值 oracle。 |
| 官方 multibuffer / multi_buffer_alloc_manual_for_vadd | bishengir/test/Dialect/HIVM/enable-multi-buffer.mlir，全文件按 RUN 执行 enable-multi-buffer、lower-multi-buffer-counter，FileCheck 通过。 | 第二批。阶段是 slot 轮换，仍需走同步插入。截三轮 B0/B1/B0，同时检查数据就绪和覆写时机。关联 #316 特性需求。 |
| 官方 subtiling / mm_01_mix_aiv 及 simple_testcase_dynamic | bishengir/test/Dialect/HIVM/tile-and-bind-sub-block.mlir，按 RUN 执行 bind-sub-block、FileCheck 通过。动态样本实际报告 revert。 | 作为 1:2 与回退候选。记录 sub-block guard、每个参与者、地址区间与匹配 Cube 函数，补齐同步后模块，再做运行用例。仅有 AIV 或开启 tiling 不能证明双接收者均参与。 |
| 官方 attention 教程 / _attn_fwd | UnifiedInterpreter 归档 Triton 源、阶段化 IR 与 specialization，现有 attention_hivm_lowered.mlir 有已拆分的 AIC/AIV。 | 第二批真实 kernel。先抽一条 workspace producer/consumer 链；记录 flag、视图与参数对应后再对整 kernel 扩展。不把整段 attention 计作已支持。 |
| GitCode #920 / feedback_cycle、feedback_cycle_hoisted、forwarding_only | issue920/920.mlir 来自关联 MR !5025 head 3c6f582cd505845e7465f4344bbf96af22c3ec2d 的 lit 回归文件，入口是 MIX 的 CV-skew pass。 | 第一批回归来源。前两条是应禁止 skew 的 L1/UB 反馈环；后者是允许 skew 的前向对照。当前版本 exact RUN 的 pass 返回 0，FileCheck 在前两条 CHECK-NOT 报错。目标 core 还需得到该例分核及同步后的成对输出。 |

### 来源锚点

- [手写 Triton 和仓库固定 revision](https://github.com/zhezhouzz/UnifiedInterpreter/blob/df70f659d4a7aa7fa75eb27d894388ad8aefc460/examples/kernels/source/kernels.py)；[阶段产物与 provenance](https://github.com/zhezhouzz/UnifiedInterpreter/tree/df70f659d4a7aa7fa75eb27d894388ad8aefc460/artifacts/kernels)。归档生成环境标为 triton-ascend 3.2.0、ascendnpu-ir 1.2.0、Ascend910B1；本次 A5 也是从这份相同 HFusion 开始，前端未针对 A5 重生成。
- [官方 DCCGSS 单测](https://gitcode.com/Ascend/AscendNPU-IR/blob/fbdf863a8c8c268e5cfea0d5f1d921e227267fd5/bishengir/test/Dialect/HIVM/SyncSolver/hivm-dccgss.mlir)；[官方同步 pass 说明](https://ascendnpu-ir.gitcode.com/en/developer_guide/features/auto_sync.html)；[官方 subtiling 说明](https://ascendnpu-ir.gitcode.com/en/developer_guide/features/auto_subtiling.html)。
- [#920](https://gitcode.com/Ascend/AscendNPU-IR/issues/920)；[MR !5025](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5025)；[修复分支回归 MLIR](https://gitcode.com/Ascend/AscendNPU-IR/blob/3c6f582cd505845e7465f4344bbf96af22c3ec2d/bishengir/test/Dialect/HIVM/cv-pipelining-buffer-feedback-cycle.mlir)；[#316](https://gitcode.com/Ascend/AscendNPU-IR/issues/316)。

## 重放第一批实验

在本目录运行以下命令，将 BISHENG_BIN 指向同版本的 build/bin。

```sh
export BISHENG_BIN=/path/to/AscendNPU-IR/build/bin
python3 replay.py --bin "$BISHENG_BIN" --output "$(mktemp -d)"
```

重放程序包含完整命令、核函数提取和比对，屏幕输出应与 actual.txt 一致。匹配的本机二进制 SHA-256 在 toolchain.txt。未运行 NPU；无需上传材料。

- **单开关差分**用同一份 add HFusion、同一 910B1 和同一共同下游 dump 点 hivm-add-ffts-to-syncblocksetop。只改 disable-hivm-auto-inject-sync；通过全程 pass 日志确认 GraphSyncSolver 开/关，函数内静态 set/wait/barrier 数量为 4/4/1 与 0/0/0。两份文件均由 bishengir-opt 重解析。关闭同步是负对照配置，错误数值还要在 core 内检查。
- **芯片对照**用两份 after GraphSyncSolver 的产物 triton/910B1-on.after-gss.mlir、triton/950-on.mlir。910B1 内联 vadd，950PR_9579 把 vector 逻辑放进三个 outlined VF，包内保留定义与调用。两者各有 4/4/1 条静态同步操作。跨芯片是多个 pipeline 差异的合成，不能单独归因于某 pass。
- **solver 对照**在同一已分核模块显式运行 delayed solver v1 与 v2，两份输出字节相同。再显式组合核内 GraphSyncSolver，得到 mix-both.mlir。该组合用于 fixture 实验；它没有运行全套生产 pipeline。跨核 flag 0 是 FIX→S；统计运行时事件只读 AIC/AIV，不重复计入 backup。
- **历史回归**使用修复 MR 的原始 RUN 参数，当前编译器给两个反馈环都加上 hivm.cv_pipelined_loop。FileCheck 日志与完整 pass 输出已保存。尝试直接从该 mid-pass 输入启动 950 完整 driver，在 program id / program num 参数类型检查处退出，未达到同步捕获点。尚未以修复版二进制重跑，未做数值复现。
- 三次 add 的完整 driver 均在晚期返回 1，910B1 缺最终 BiSheng compiler，950 缺 device bitcode。用于比较的是报错前已经输出、并再次解析成功的中间阶段。实际执行过的额外两个官方局部 pass 的命令在下方。

```sh
b=$(cd "$BISHENG_BIN/../.." && pwd)
f="$b/bishengir/test/Dialect/HIVM/enable-multi-buffer.mlir"
"$b/build/bin/bishengir-opt" "$f" -hivm-enable-multi-buffer -hivm-lower-multi-buffer-counter -split-input-file | "$b/build/bin/FileCheck" "$f"
f="$b/bishengir/test/Dialect/HIVM/tile-and-bind-sub-block.mlir"
"$b/build/bin/bishengir-opt" "$f" -hivm-bind-sub-block -split-input-file -verify-diagnostics | "$b/build/bin/FileCheck" "$f"
```

## 后续入库与差分规则

每组保存来源 commit/函数、输入层、固定输入及期望输出、chip/实际 core 配置、唯一改动的 flag、实际执行过的 pass、共同捕获点、AIC/AIV 函数与参数映射。一个 kernel 的多个调参变体共用来源标识。对数值算子使用独立参考结果；对同步同时检查终态输出、阻塞、每个接收者是否完成消费。pass 运行、IR 改变、产生错误执行是三种独立的观察。初期只翻译具体的数据与同步片段，任何省略的运算、分支、初始值及内存别名都写进该例说明。

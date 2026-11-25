# Vectorlayout 的具体执行

`Vectorlayout.make` 构造 `_prefill_bnsd_score_kernel` 的 OCaml AST。每个 block group 有一个 Cube 和两个 Vector 子块。两份 AST 由归档的 HIVM 和 AVE 指令手工转写，共用 `Core_lang.Device.Execution.run`。归档提供了两份编译 IR。以下数值来自可重复构造的输入。

## 运行和重放

```sh
dune exec unified-interpreter -- vectorlayout --variant ok
dune exec unified-interpreter -- vectorlayout --variant fail --save-trace _build/vectorlayout-fail.json
dune exec unified-interpreter -- vectorlayout --replay _build/vectorlayout-fail.json
dune exec unified-interpreter -- vectorlayout --variant ok --length 407 --dimension 97 --group 1 --kv-heads 2
```

默认输入包含 160 个 token、两个 query head、一个 KV head，head dimension 为 128。两个版本都执行最后一个 query block 的 32 个 token。输出张量形状为 `[160;2;2]`，其中 128 个有效位置保存计算结果，另外 512 个位置保留初值 12345。正确版的 640 个位置均与参考值逐位相同。

失败版的第一个相关写入位于 block 0 的 Vector 子块 0。每一行的两个存储目标及其物理覆盖如下。字节区间为左闭右开。

| 目标 | 失败版第 0 行 | 正确版第 0 行 | 每行元素数 |
| --- | --- | --- | --- |
| `mask : i8` | `pk4` 写入 [33856, 33920) | `pk` 写入 [17472, 17600) | 64 / 128 |
| `other : f16` | `pk` 写入 [37952, 38080) | 两次 `norm` 分别写入 [1056, 1184)、[1184, 1312) | 64 / 128 |

默认初始 UB 全部为零。失败版第 0 行第 64 列的 `mask` 保留零值，`indirect_load` 从 UB 字节 38080 读取 `other[0,64]`，得到 0。正确版在该位置从 GM 读取 `query[128,0,64]`。这会改变该页上的点积及其最大值。最终有 128 个输出位置不同，首处为 `output[128,0,0]`，实测 286.374969，参考值 563.192078。

## 输入和参考公式

命令行的 `--length`、`--dimension`、`--group`、`--kv-heads`、`--splits` 分别设置单 batch 的 token 数、维度、每组 query head 数、KV head 数和页分区数。页长度为 128，设页数为 P。输入张量和页表按以下公式构造。

- `query[q,h,k] = f16(1 + (3*q + 5*h + k) mod 7)`。
- 逻辑页 p 内的 `key[p,j,h,k] = f16(1 + (p + 2*j + 3*h + 5*k) mod 11)`。页表将 p 映射到物理页 `P - 1 - p`。
- 初始 GM 输出全部为 `f32(12345)`，本地存储全部为零。`arg16` 为 `f32(0.125)`。

`Vectorlayout_input.reference` 直接读取初始 GM，为每个有效的 query token q、head h 和逻辑页 p 计算点积，再乘以 `f32(arg16 * f32(1.44269502))`。只对该页内满足 `key_position <= q` 且小于 KV 长度的位置取最大值，NaN 被排除，空集合取负无穷。该计算独立于 UB 地址、寄存器布局、NZ 存储和管线调度。

```ocaml
open Unified_interpreter
let input = Vectorlayout_input.make Vectorlayout_input.default
let ast = Vectorlayout.make Vectorlayout.Fail input.blocks
let result = Core_lang.Device.Execution.run ast input.memory input.bindings
let scores = Vectorlayout_input.output input result
let replayed = Core_lang.Device.Execution.run ~schedule:result.choices ast input.memory input.bindings
```

`bindings` 绑定入口的视图和标量。`memory` 以存储空间和所属核心标识物理内存。调用者可以提供实际 GM 和初始本地内容；执行器复制初始内存，返回最终内存、事件和调度选择。通过 `Device_trace.replay ~input path` 可以使用调用者提供的初始内容验证已保存的执行。

## 原语和执行事件

视图的物理位地址为 `base_bit + element_bits * Σ(index[i] * stride[i])`。`i1` 以位寻址。两个视图指向同一存储空间中的同一位置时可以观察到彼此的写入。正确版先在 UB 1056 存放 `i32 q_offsets`，随后逐块读取、扩展至另一区域的 `i64`，并复用 1056 开始的空间写入 `f16 other`。

带布局的寄存器以逻辑元素值和 `lane_bits` 表示，逻辑元素 i 对应寄存器组内的位偏移 `i * lane_bits`。本例每个寄存器容量为 256 字节。`Masked_store` 检查打包模式、元素宽度和谓词粒度，只对谓词为真且 `i < registers * 2048 / lane_bits` 的逻辑元素写入目标视图。`mask`、`other` 的源数据各占一个寄存器；正确版的 `vextsi` 将 64 个 i32 扩展为两个寄存器中的 64 个 i64，按 pb32 谓词写入另一区域。数据为零也会写入内存。谓词为假或超出容量时保留旧值。

每个管线操作有发射和完成事件，访存效果在完成步骤执行。普通操作可在管线规则允许的位置完成，`set` 必须等待先前的同管线操作，后续操作也必须等待先前的 `wait` 和屏障。跨核通知以 block group 中的发送者和接收者为单位，Cube 等待两个 Vector 子块的通知。默认调度按流编号和发射次序选择可执行步骤。该调度产生一次具体执行。

JSON trace 的 `path` 是 AST 中的指令路径，`iterations` 是动态循环下标。`read_bits` 和 `write_bits` 给出各物理存储的左闭右开位区间。`masked_store` 还保存目标视图、起始坐标、谓词各位、源布局、打包模式及容量。`indirect_load.source_lanes` 按目标视图的逻辑顺序记录每个元素的来源存储、位地址和原始数值位。重放会检查调度合法性，重新执行原语，逐项核对事件，并核对所有最终存储的摘要。

## 归档对应关系

原始文件名为 `b1_tq4096_ih8_kvh4_d128_c2_s4096-device-print-{fail,ok}.mlir`。失败版 SHA-256 为 `f5ce22f8993f97e7b5efe9ad11dbdb7a12482fb191fe8402385345cda44d2f29`，正确版为 `10b036e929601b3436971e55b64faf828f3cd8b447b2233f98764305327ef4cd`。下表的数字是本地提取的 GraphSyncSolver 快照编号。函数列省略共同前缀 `_prefill_bnsd_score_kernel_mix_`。

使用支持 AVE 和 Ascend950 的 `bishengir-opt` 可以复查两份归档。检查器从原文件提取各入口、被调用函数和目标布局函数，把同一阶段的函数交给 MLIR 验证器，并将操作名与执行覆盖表核对。失败版有 13 个函数、79 种操作名，正确版有 14 个函数、80 种操作名，计数包含声明和编译标记。

用于解释执行的模块取自 GraphSyncSolver，布局函数 `aiv_fused_5_outlined_merged_vf_0` 取自对应的 AnalyzeVectorLayout 快照。导出脚本核对原始文件 SHA-256，再用 BiShengIR 验证组合后的完整模块，使用 xDSL 读取 generic assembly 并保存操作数、全部 SSA 结果、属性、region 和 block。以下命令可以从归档重新生成 AST。[导出脚本](../scripts/export_vectorlayout_ast.py) · [trace 接口](trace-interpreter.md)

```sh
.venv-attention/bin/python scripts/export_vectorlayout_ast.py ok "$OK_DUMP" --opt "$BISHENGIR_OPT" --output _build/layout-ok.ast.json --mlir _build/layout-ok.mlir
.venv-attention/bin/python scripts/export_vectorlayout_ast.py fail "$FAIL_DUMP" --opt "$BISHENGIR_OPT" --output _build/layout-fail.ast.json --mlir _build/layout-fail.mlir
```

```sh
python3 scripts/check_vectorlayout_sources.py --opt "$BISHENGIR_OPT" --fail "$FAIL_DUMP" --ok "$OK_DUMP"
```

| 函数 | 失败版 | 正确版 | AST 中的计算 |
| --- | ---: | ---: | --- |
| `aic` | 467644 | 471667 | 页表、尾块清零、ND 到 NZ、L1 操作数搬运、转置 B 的 MMAD、FIX 的 NZ 到 ND 和 ROW_SPLIT |
| `aiv` | 467191 | 471964 | 入口标量、地址规划、调试读取、间接读写、多缓冲及跨核同步 |
| `aiv_outlined_vf_2` | 467628 | 471079 | 按块生成列号 |
| `aiv_fused_4_outlined_vf_0 / vf_1` | 466652 / 467021 | 470974 / 471172 | token、head、行谓词和裁剪后的 token 下标 |
| `aiv_outlined_vf_3` | 467060 | 471860 | 比较列号和 head dimension |
| `aiv_fused_6_outlined_{merged_,}vf_0` | 466584 | 471033 | 计算 query 地址；失败版同时计算行谓词 |
| `aiv_fused_5_outlined_vf_0` | 已合入 fused_6 | 471397 | 计算行谓词 |
| `aiv_fused_5_outlined_merged_vf_0` | 466971 | 470905 | 采用 AnalyzeVectorLayout 的 631463 / 642335 两份函数体，生成 `mask`、`other`，正确版同时扩展地址 |
| `aiv_fused_7_outlined_vf_0 / fused_8_outlined_vf_0` | 467599 / 466698 | 471655 / 471210 | score 比例因子、输出行基址 |
| `aiv_fused_1_outlined_merged_vf_0` | 467164 | 471123 | 将 query 排列为有填充的 16 列片段，生成页内 key 的位置 |
| `aiv_fused_0_outlined_merged_merged_vf_0` | 466497 | 470817 | causal 谓词、输出下标、NaN 检查用的位掩码和归约初值 |
| `aiv_fused_3_outlined_vf_0` | 467121 | 471921 | 缩放、掩码、按位识别 NaN、携带结果的循环和行归约 |

| 归档操作 | 具体执行 |
| --- | --- |
| `arith.constant/addi/subi/muli/mulf/divsi/remsi/remui/shrsi/andi/ori/minsi/maxsi/maximumf/cmpi/cmpf/select`、`affine.apply` | 定宽标量及逐元素运算。非负计数器的余数采用相同整数余数计算；非负行号的移位及位运算用除以二和对二取余表示。 |
| `arith.index_cast/trunci/extsi/extui/bitcast` | 数值转换、截断、谓词零扩展和保持位表示的重解释。 |
| `memref.cast/reinterpret_cast/extract_strided_metadata/subview/expand_shape/collapse_shape/load/store`、`hivm.hir.pointer_cast` | 同一物理内存的具类型视图、基址和步长、子视图、连续形状变换、标量读取和写入。多地址指针按循环计数取余选择。 |
| `vector.transfer_read/transfer_write/constant_mask/shape_cast/broadcast/multi_reduction` | 读取和写入有效元素，排列逻辑坐标，广播和归约。使用常量前缀谓词的传输直接转写为相同有效元素数的访存。 |
| `func.call/return`、`scf.if/for/yield` | 入口和带函数名的管线操作、动态分支、循环、携带的 SSA 值及其返回值。 |
| `ave.hir.vload/pge/plt/scalar_broadcast/broadcast/vector_broadcast/vcmp/vsel/preg.and/preg.xor/vor/vintlv/vxor` | 读取压缩谓词、生成前缀谓词及剩余长度、选取行、八次双结果交错及异或、广播并与列谓词结合。 |
| `ave.hir.vector.layout_cast/vextsi/masked_store`、`builtin.unrealized_conversion_cast` | 保留逻辑元素、选择物理间距和谓词粒度、符号扩展及物理存储。用于改写向量宽度的转换由相应的有效元素选择或广播表达。 |
| `hivm.hir.get_block_idx/get_sub_block_idx/multi_buffer_counter/set_ctrl/debug` | 读取启动坐标、每次内层迭代递增一次的函数局部计数器、控制寄存器位和调试输出。 |
| `hivm.hir.set_flag/wait_flag/sync_block_set/sync_block_wait/pipe_barrier` | 每个管线的任务、通知和等待，跨核通知和屏障。 |
| `hivm.hir.indirect_load/indirect_store/copy/vbrc/nd2nz/mmadL1/fixpipe` | 读取实际谓词和地址后执行 gather/scatter，数据搬运、清零、NZ 坐标映射、f16 输入与 f32 累加、两个 Vector 子块各接收 32 行。MMAD 的 MTE1 读入和 M 计算分开执行。 |

`annotation.mark`、`func.func` 声明和编译属性提供静态信息。多缓冲个数、preload 相位、地址轮换、转置及 ROW_SPLIT 已体现在 AST 中。解释器接受构造好的 AST；这份对应关系适用于以上归档快照。原有 race 搜索与 SMT 接口使用 `Core_lang.program`。

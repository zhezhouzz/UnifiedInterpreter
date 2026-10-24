# HFusion / HIVM 语义核查报告与代码阅读路线

核查日期：2026-10-22。对象为当前工作区的 Rocq 语义和 attention CPU 解释器。
解析、effect handler、float64 执行及数值验证见[解释器设计文档](attention-interpreter-design.md)。

## 1. 证据与适用范围

| 证据层次 | 当前情况 | 不能据此推出什么 |
| --- | --- | --- |
| 官方规则到代码的人工逐项比对 | 本报告给出入口、判断条件及证据 | 仍需机器检查的规范符合性证明 |
| Rocq 一般性引理 | 张量长度、部分 shape/type 保持、reshape 保序、lens 独立组件保持 | 不证明算术后端或 NPU 硬件符合这些定义 |
| Rocq 具体示例 | 对指定输入规约求值，证明得到指定结果 | 不覆盖所有形状、属性、浮点特殊值 |
| 提取后的 OCaml 检查 | 运行 attention 两个阶段，与独立 float64 参考比较；检查 NaN 和内存/lens | 硬件差分验证仍待完成 |
| 完整模型一致性 | 尚无对官方参考语义的 refinement/equivalence 定理 | 不能声称整个 dialect、attention 或 lowering 已验证 |

### 版本与来源边界

- 本地 Ascend 官方快照固定在 `22e3d51df4642fb0f74060af36f5c5c80be80d08`，
  本次校验 113 项 SHA256 全部通过。可从[快照说明][snapshot]核查。
- HFusion/HIVM 的 TableGen/YAML 以此固定版本为主要依据；网页便于阅读，但会更新。
- 对 `linalg`、`memref`、`tensor`、`bufferization` 这些公共操作，需要查 MLIR 定义，
  不能只看 Ascend 的 HFusion 页面。Ascend 的[框架接入文档][framework]也使用这些公共操作。
- 上述 Ascend commit 的 `.gitmodules` 指向 GitCode 的 LLVM 19.1.7 维护分支，
  gitlink 为 `06913395ef8aca66a9814723f4ccc616570b0fed`。本仓库未归档该子模块；
  本次没能读取该精确 commit 的文件。MLIR 比对采用社区 `llvmorg-19.1.7` 源码，
  并参考当前官方网页。因此公共操作的 Ascend 分支补丁仍是一项待核验边界。
- 两个 attention artifact 的实际编译器 revision 没有在归档 README 中完整记录。
  所以“某条转换源码解释了该属性”与“已证明 artifact 由该源码产生”须分开。

当前文件指纹：

```text
hfusion_level.mlir:
e1a4a761750428433d0b757e9087c07b2fd632491399a472f3a5a2fb98ec552c
attention_hivm_compute.mlir:
bcf2542c1915b135dfd223f37a5b491ee306b80b53592831b0b7c6c22094078e
```

## 2. 建议先读的五组代码

每一组按“官方规则 → 实现 → 例子/证明”阅读。表中“结构对应”仅指所列规则，
限定于所列输入域；host-float64 数值模型与前端检查见解释器设计文档。

| 顺序 | 对照规则与官方入口 | 实现入口 | 用什么检查 |
| --- | --- | --- | --- |
| 1. HIVM 广播 | [VBrcOp][src-vbrc]：scalar 的广播轴为空；张量源/目标同 rank/type，广播轴源尺寸为 1 | [sem_broadcast][hivm-broadcast]；检查 `dims=[]` 或 `[1]`、`m=m'`、源第二维为 1，再看 `repeat` / `flat_map` | [scalar_broadcast、column_broadcast、wrong_broadcast_dimension][test-broadcast] |
| 2. 两层归约的区别 | [Linalg ReduceOp][src-linalg-reduce] 使用 combiner 与 init；[HIVM VReduceOp][src-vreduce] 保留 rank、归约轴目标尺寸为 1 | [HFusion reduce_output_coordinates][hf-reduce-init] 读取 init；[HIVM reduce_rows/sem_reduce][hivm-reduce] 由后端提供 identity、输出 `M×1` | [HFusion 初始值 10/20 的例子][test-hf-reduce]；[HIVM 旧目标值 100/200 不参与求和][test-hivm-reduce] |
| 3. 矩阵乘加 | [MMAD 参数定义][src-mmad]：init 表示是否清理累加器；[转换源码][src-mmad-conversion]：本截面 M/K/N 是零占位 | [sem_mmad][hivm-mmad] 检查零占位和矩阵形状；init=true 用零，false 读取目标；[Matrix.v](../rocq/Tensor/Matrix.v) 按行、列顺序计算内积 | [handler_test.ml](../attention_test/handler_test.ml) 检查真实 float64 矩阵结果；[AttentionStructured.v](../rocq/Examples/AttentionStructured.v) 证明指定矩阵形状下泛化标量计算与索引实现相等 |
| 4. 类型转换与数值边界 | [HFusion Cast YAML][src-hf-cast]；[HIVM VCastOp][src-vcast] 默认 RINT/cast_signed | [HFusion sem_hfusion_cast][hf-cast] 把属性打包传给后端；[HIVM sem_cast][hivm-cast] 仅允许本 artifact 的 f32→f16 默认模式 | 先读[测试后端][mock]，再读 cast 例子；测试用加 3000 标记调用，**不是浮点转换精度证据** |
| 5. 内存与 lens | [MemRef 文档][web-memref]、[Bufferization 文档][web-bufferization]；lens 是项目自己的组合设计 | [Memory.v][hf-memory] 生成请求 → [Handler.v][memory-handler] 执行 → [Execution.run_memory][hivm-run] 使用 zoom | [视图→复制→计算→写回及 larger_state 例子][test-memory]，同时阅读第 5 节差异，不能只看成功结果 |

最快的第一项审查是广播：对照 `VBrcOp` 的限制逐个检查 `if` 条件，然后手算
`[[7],[9]] → [[7,7,7],[9,9,9]]`。这里基本不依赖浮点运算，最容易独立核实。

## 3. HFusion：实际实现的范围及证据

HFusion 目录的 `instr` 定义 artifact 的混合方言语法。
[eval_memory_instruction][hf-dispatch] 分派 memref 和 bufferization。
完整 `_attn_fwd` 由 [runner.ml](../attention/runner.ml) 调度，经
[handlers.ml](../attention/handlers.ml) 调用各个 Rocq 提取入口。

| 操作/基础 | 官方要求或来源 | 当前代码做了什么 | 核查结论与限制 |
| --- | --- | --- | --- |
| `linalg.elemwise_binary` | [社区 19.1.7 YAML][src-linalg-binary]：输入提升到输出类型，再逐元素调用 fun | [expand_elementwise_operand / sem_linalg_elemwise_binary][hf-binary]：标量 repeat、输入 cast、逐元素二元运算 | 输入转换与逐元素结构对应；同 shape 由 indexed value 保证。`linalg_cast_spec` 额外指定 RINT、overflow/saturation 策略，这些不能仅从 Linalg TypeFn 描述中推出，应继续核对转换实现 |
| `linalg.reduce` | [ReduceOp][src-linalg-reduce]：有序维度、combiner region、目标 init | [Reduce.v][hf-reduce]：验证维度；从 init 取值；按坐标顺序调用 combiner；去掉归约维度 | runner 将真实 region 解释为 combiner，并通过 handler 执行其中的标量原语；顺序 fold 属于 CPU 模型的计算顺序 |
| `hfusion.cast` | [本地官方 YAML][hf-cast-yaml]：逐元素；round/cast/unsigned/overflow/saturate 属性 | [Cast.v][hf-cast] 完整打包属性，逐元素调用 `scalar_cast` | 属性传递可逐字段核对；没有合法源/目标类型与模式组合的完整 verifier，也没有位级转换后端 |
| `memref.alloc` | [MemRef 文档][web-memref]：新存储 | [allocate_memref][memory-alloc] 新 allocation/descriptor，单元未初始化 | 分配身份与描述符结构清楚；不建模容量、地址对齐、释放或物理字节布局 |
| `memref.reinterpret_cast` | 修改 descriptor；base 保留，新 offset/sizes/strides 相对底层存储 | [handle_reinterpret][memory-reinterpret] 保留 allocation、替换元数据 | 寻址核心对应；额外进行了全视图越界检查，见 F02 |
| `memref.copy` | 相同逻辑 shape/type，允许不同 layout | [sem_memref_copy][memory-copy] 按逻辑坐标读写 | 非重叠、已验证输入的计算路径合理；**自复制行为存在差异，见 F01**；完整前置 verifier 尚未提供 |
| `bufferization.to_tensor` | buffer/tensor 的形状与元素类型兼容；restrict/writable 有 bufferization 含义 | [sem_bufferization_to_tensor][memory-to-tensor] 记录 live view；消费时读取；handler 检查 restrict 声明冲突 | shape/type 与延迟读取结构可检查；不能据此声称实现完整 One-Shot Bufferize 别名/写入分析，见 F05 |
| 写回目标 | `materialize_in_destination` 的数据应写入指定 buffer；memref 目标要求 writable | [sem_bufferization_materialize_in_destination][memory-writeback] 验证 descriptor，按坐标写入 | 对 artifact 的 memref+writable 模式有实现；不覆盖任意 tensor destination |

[Structured.v](../rocq/HFusion/Semantics/Structured.v) 定义 `linalg.matmul`、
`fill/transpose/broadcast/unary`。runner 执行 `scf.for` 和归约 region，
[numeric.ml](../attention/numeric.ml) 提供真实主机 exp/log 与 float64 算术。

### 特别注意：数值证明的前提

[ScalarOps][hf-numeric] 是可调用函数的接口。它不自动证明实现符合 IEEE、MLIR 或
Ascend。`ScalarLaws` 是另一个可选的 Prop 接口，而这些语义函数没有普遍要求它。
当前 [ZScalarOps][hf-mock] 把转换做成 identity，exp/log 返回错误。
因此 `hfusion_cast_executes` 只证明该整数后端下的结构调用成功，
不证明 f32→f16 的舍入正确。

## 4. HIVM：限定子集的规则与审查点

唯一范围是 compute snapshot，不包括 memory/lowered。覆盖清单见
[HIVM 范围说明][compute-report]；词法清单脚本会确认 28 类操作名称，其中 10 类
是 HIVM 计算原语。**它不解析属性，也不能证明真实 MLIR 已被执行。**

| 原语 | 当前可核实的实现规则 | 关键阅读位置 | 尚未保证的部分 |
| --- | --- | --- | --- |
| vadd/vsub/vmul/vdiv | f32、相同目标 shape/type；标量扩展；逐元素调用对应枚举 | [expand_operand / sem_binary][hivm-binary]、[Numeric][hivm-numeric] | 实际浮点结果、舍入、异常值取决于后端；非完整 opcode 域 |
| vexp/vln | 输入/输出 shape/type 对应；逐元素调用带类型的后端函数 | [sem_unary][hivm-unary] | attention 使用主机 exp/log；f16/f32 精度模拟不在当前数值模型范围内 |
| vbrc | scalar+空 dims；或 `[M,1] → [M,N]` 且 dims=[1] | [sem_broadcast][hivm-broadcast]、[VBrcOp][src-vbrc] | 其他 rank/广播轴/type 未实现，返回错误 |
| vreduce | `[M,N] → [M,1]`；dims=[1]；按后端 identity 顺序 fold | [sem_reduce][hivm-reduce]、[官方 getInit][src-vreduce-impl] | identity、NaN 规则只是后端契约，没有强制法律；后端可违约，见 F03 |
| vcast | f32→f16、默认 signed/RINT，源/目标类型传入后端 | [sem_cast][hivm-cast]、[VCastOp 默认值][src-vcast] | attention 保留类型标签，cast 保持 float64 数值 |
| `mmadL1` | f16 输入、f32 输出；B 转置寻址；init 清零/累加；零 M/K/N 用 tensor shape | [sem_mmad][hivm-mmad]、[matrix_product](../rocq/Tensor/Matrix.v)、[官方参数][src-mmad] | 顺序 MAC 是参考策略；不包含 L1/L0 容量、数据格式或流水线；artifact 编译版本待补齐 |
| tensor.empty / reshape | 未初始化值与 DefinedTensor 分开；重关联是连续有序轴分区，元素顺序不变 | [Value.v][hivm-value]、[sem_reshape][hivm-reshape] | 只允许正尺寸 rank 1/2；empty 读取报错比“未指定内容”更严格，见 F04 |
| 公共整数操作 | 模位宽加乘、向零截断除余、符号扩展；index 固定 64 位 | [Arith.v][hivm-arith] | index 宽度是所选 profile；没有 poison/UB 的一般关系语义 |

归约的两个关键依据：

1. 本地 `HIVMVectorOps.td` 明确要求归约维度的目标尺寸为 1，并规定 min/max 传播 NaN。
2. 官方固定版本 `HIVMVectorOps.cpp` 的 `VReduceOp::getInit` 为 f32 sum 选择零，
   为 f32 max 选择负无穷；这比仅凭名字猜“是否读取 outs”更可靠。

矩阵乘法的关键依据：官方 `Matmul.cpp` 中明确将 real M/K/N 标为 stub value 0；
所以这里不能把三个零解释为零尺寸。`sem_mmad` 对非零值直接拒绝，避免冒充支持
后续编译阶段。其支持范围为当前固定截面。

## 5. 已发现的差异、开放问题和影响

### F01：`memref.copy(x,x)` 被错误地一概归入重叠复制错误

当前 [Memory.v:35][memory-copy] 无条件发出 `AssertDisjoint`；同一 descriptor 的
地址集合自然相交，所以 [handle_disjoint][memory-disjoint] 返回
`UndefinedBehavior CopySourceDestinationOverlap`。

然而社区 LLVM 19.1.7 的 [FoldSelfCopy][src-self-copy] 将 source==target 的
`memref.copy` 直接消去。这是不能同时忽略的语义差异。现有
`overlapping_copy_is_undefined` 恰好证明了当前模型的拒绝行为，
**并没有证明该行为符合官方规则**。

核查结论：相对社区基线的可复现差异；Ascend 精确 LLVM 子模块仍需确认。
不能把所有 overlap 都直接称为已获官方支持的 UB 规则。
当前 attention 将输入复制到新 allocation，没有自复制，故此问题不直接反驳该路径；
但在宣称通用 memref.copy 或验证优化前必须处理。

### F02：创建 reinterpret descriptor 时提前检查全部地址

当前 [handle_reinterpret][memory-reinterpret] 在任何读写之前调用
`descriptor_in_bounds`。而[当前 MLIR 文档][web-reinterpret]明确区分元数据创建与
实际越界访问：创建时不做该检查，越界访问才是 UB。

例如，从 6 个元素的 allocation 创建 offset=5、size=2 的视图但从不读取，
当前模型已经失败。报告探针会复现。

核查结论：这是额外的安全诊断策略，不能无条件称为完整官方操作语义。
本次文件的正常 in-bounds 视图不受影响；泛化时应推迟检查到读写，或明确限制输入域。
这里还需核对 Ascend 精确版本，不能把当前网页新增解释误称为固定分支的原文。

### F03：数值接口没有证明“后端必须遵守官方规则”

[Numeric][hivm-numeric] 的注释要求 max 传播 NaN，但 class 里没有对应 Prop 定律；
zero/seed/rounding 也都是调用方可提供的函数。同样，[ScalarOps][hf-numeric] 的
定义本身不保证任何 IEEE 后端性质。

已有有限整数 mock 的 max seed=-1000000。使用它处理 [-2000000,-3000000]，
当前 `sem_reduce` 返回 -1000000。探针能证明这个结果。
**语义符合性必须是“在已验证数值后端满足某契约的条件下”成立。**

[HIVMExceptional.v][test-exceptional] 验证特定 NaN 后端的传播行为。
attention 使用 float64 后端，max identity 为负无穷；接口的通用契约仍需独立 Prop 层和证明。

### F04：`tensor.empty` 的“未指定内容”被细化为“读取即报错”

[官方 Tensor 文档][web-empty]说内容未指定。当前 [elements][hivm-value] 对
EmptyTensor 返回 ReadUninitialized。这是避免误把空目标当零的保守设计，
不等价于已经表示了所有未指定值/poison 行为。

当前 artifact 中 empty 用作完全覆盖写入的目标，或由 init=true 的 MMAD 清零；
在这个限制下该设计适用。若输入程序会消费 empty 原值，需要补定义或显式排除。

### F05：前端合法性与 bufferization 契约还没有全部落实

- [HFusion 内存语义注释][memory-copy]把 copy 的 shape/type 合法性交给 elaboration。
  attention 前端经过 xDSL verification 和 [validate.ml](../attention/validate.ml) 的
  shape/type 检查；直接调用提取函数仍需满足相应前提。
- [handle_claim][memory-claim]按地址重叠和永久 claim 集合处理 restrict，
  `writable` 在该函数中不决定 bufferization 的 in-place/out-of-place 选择。
  [官方 One-Shot Bufferization 契约][web-bufferization]还涉及完整的别名与写入分析。
- [HFusion 写回分派][hf-writeback-dispatch]忽略底层返回的 bool；正常受验证输入中
  预期不会返回 false，但对 malformed 输入还缺少完整拒绝路径。
- 两层的真实 MLIR 经 xDSL 解析为类型化 AST；当前验证域限于归档 attention 子集。

这些项中有的是显式范围限制，有的是需要补实现的验证缺口；本报告不把它们都判为
会影响现有 attention 输入的 bug。但它们会阻止“任意官方合法 IR 都可正确执行”这一主张。

### F06：Linalg 输入转换的额外策略需要单独核对

[linalg_cast_spec][hf-binary-cast] 设置 RINT、enable_overflow=true、
enable_saturate=false 等 HFusion 属性。Linalg 的 YAML 明确了输入提升和 TypeFn，
但这些额外策略不能只靠那段描述认定。当前整数测试使用 identity cast，
没有区分这些政策。应对照 Ascend 维护版 Linalg scalar conversion 的实现，
在补齐来源之前，将这些策略标为模型选择。当前 float64 后端保持 cast 数值。

## 6. 证明究竟证明了什么：以 lens 为例

建议读这条链：

1. [Lens.v][lens]：get/put 三条定律，及独立组件的交换/保持定律。
2. [StateM.zoom][zoom]：取出局部组件，执行局部计算，成功后放回。
3. [Execution.run_memory][hivm-run]：内存 handler 的结果通过 zoom 嵌入完整状态。
4. [every_success_preserves_marker][lens-test]：任意这类成功内存计算保持独立 marker。

这条一般性质证明：在所给 lawful/independent lens 前提下，无关状态保持。
内存读写规则与 MLIR 的对应关系需要单独审查。

同理，[binary_preserves_shape_type][shape-proof] 证明成功结果的 shape/type 不变，
没有证明加法满足 IEEE。形状证明、内存局部性证明与官方功能语义对应证明，
必须分别审查。

## 7. 可复现检查

本次实际运行并通过：

```sh
ROCQ_OPAM_SWITCH=unified-interpreter ./scripts/check_rocq.sh
opam exec --switch=unified-interpreter -- dune build @all
opam exec --switch=unified-interpreter -- dune test
```

提取检查输出：

```text
HIVM scope: 28 operation kinds, including 10 HIVM compute primitives.
HIVM extraction: 5 compute, 2 NaN checks and memory/lens composition passed.
```

另有[审查探针][probes]，独立编译，不加入正常验收套件：

```sh
opam exec --switch=unified-interpreter -- rocq compile \
  -Q rocq UnifiedInterpreter docs/semantics-audit/Probes.v
```

它证明当前模型确实会：①拒绝自复制；②在未读取前拒绝越界 descriptor；
③接受错误的 max identity 后端并返回错误的数学最大值。
探针用于检查模型的适用边界。attention 的实际数值验证使用 float64 后端，
运行方式与结果记录见[解释器设计文档](attention-interpreter-design.md)。

## 引用与代码入口

[snapshot]: ../vendor/ascendnpu-ir/README.md
[framework]: ../vendor/ascendnpu-ir/upstream/docs/source/zh_cn/developer_guide/conversion/framework_interface.md#L22
[hf-binary]: ../rocq/HFusion/Semantics/ElemwiseBinary.v#L64
[hf-binary-cast]: ../rocq/HFusion/Semantics/ElemwiseBinary.v#L46
[hf-reduce]: ../rocq/HFusion/Semantics/Reduce.v#L106
[hf-reduce-init]: ../rocq/HFusion/Semantics/Reduce.v#L59
[hf-cast]: ../rocq/HFusion/Semantics/Cast.v#L24
[hf-cast-yaml]: ../vendor/ascendnpu-ir/upstream/bishengir/include/bishengir/Dialect/HFusion/IR/HFusionNamedStructuredOps.yaml#L375
[hf-memory]: ../rocq/HFusion/Semantics/Memory.v#L11
[hf-dispatch]: ../rocq/HFusion/Interpreter.v#L144
[hf-writeback-dispatch]: ../rocq/HFusion/Interpreter.v#L134
[hf-numeric]: ../rocq/Value/Scalar.v#L21
[hf-mock]: ../rocq/Examples/FrameworkSmoke.v#L16
[memory-alloc]: ../rocq/Memory/Model.v#L167
[memory-copy]: ../rocq/HFusion/Semantics/Memory.v#L35
[memory-to-tensor]: ../rocq/HFusion/Semantics/Memory.v#L40
[memory-writeback]: ../rocq/HFusion/Semantics/Memory.v#L81
[memory-handler]: ../rocq/Memory/Handler.v#L219
[memory-reinterpret]: ../rocq/Memory/Handler.v#L62
[memory-claim]: ../rocq/Memory/Handler.v#L144
[memory-disjoint]: ../rocq/Memory/Handler.v#L169
[hivm-binary]: ../rocq/HIVM/Semantics.v#L31
[hivm-unary]: ../rocq/HIVM/Semantics.v#L40
[hivm-broadcast]: ../rocq/HIVM/Semantics.v#L48
[hivm-reduce]: ../rocq/HIVM/Semantics.v#L91
[hivm-cast]: ../rocq/HIVM/Semantics.v#L105
[hivm-dot]: ../rocq/HIVM/Semantics.v#L117
[hivm-mmad]: ../rocq/HIVM/Semantics.v#L145
[hivm-reshape]: ../rocq/HIVM/Semantics.v#L186
[hivm-value]: ../rocq/HIVM/Value.v#L12
[hivm-arith]: ../rocq/HIVM/Arith.v#L14
[hivm-numeric]: ../rocq/HIVM/Numeric.v#L11
[hivm-run]: ../rocq/HIVM/Execution.v#L67
[shape-proof]: ../rocq/HIVM/Semantics.v#L211
[test-broadcast]: ../rocq/Examples/HIVMCompute.v#L91
[test-hf-reduce]: ../rocq/Examples/FrameworkSmoke.v#L129
[test-hivm-reduce]: ../rocq/Examples/HIVMCompute.v#L102
[test-mmad]: ../rocq/Examples/HIVMCompute.v#L118
[test-memory]: ../rocq/Examples/HIVMMemory.v#L17
[test-exceptional]: ../rocq/Examples/HIVMExceptional.v#L38
[mock]: ../rocq/Examples/HIVMCompute.v#L15
[lens]: ../rocq/Base/Lens.v#L3
[zoom]: ../rocq/Base/StateM.v#L35
[lens-test]: ../rocq/Examples/HIVMMemory.v#L82
[compute-report]: hivm-compute-semantics.md
[probes]: semantics-audit/Probes.v
[src-vbrc]: https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/include/bishengir/Dialect/HIVM/IR/HIVMVectorOps.td#L1280
[src-vreduce]: https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/include/bishengir/Dialect/HIVM/IR/HIVMVectorOps.td#L1353
[src-vcast]: https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/include/bishengir/Dialect/HIVM/IR/HIVMVectorOps.td#L629
[src-hf-cast]: https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/include/bishengir/Dialect/HFusion/IR/HFusionNamedStructuredOps.yaml#L375
[src-mmad]: https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/include/bishengir/Dialect/HIVM/IR/HIVMMacroOps.td#L61
[src-vreduce-impl]: https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/lib/Dialect/HIVM/IR/HIVMVectorOps.cpp#L592
[src-mmad-conversion]: https://github.com/Ascend/AscendNPU-IR/blob/22e3d51df4642fb0f74060af36f5c5c80be80d08/bishengir/lib/Conversion/HFusionToHIVM/Matmul.cpp#L225
[src-linalg-binary]: https://github.com/llvm/llvm-project/blob/llvmorg-19.1.7/mlir/include/mlir/Dialect/Linalg/IR/LinalgNamedStructuredOps.yaml#L553
[src-linalg-reduce]: https://github.com/llvm/llvm-project/blob/llvmorg-19.1.7/mlir/include/mlir/Dialect/Linalg/IR/LinalgStructuredOps.td#L311
[src-self-copy]: https://github.com/llvm/llvm-project/blob/llvmorg-19.1.7/mlir/lib/Dialect/MemRef/IR/MemRefOps.cpp#L823
[web-memref]: https://mlir.llvm.org/docs/Dialects/MemRef/#memrefcopy-memrefcopyop
[web-reinterpret]: https://mlir.llvm.org/docs/Dialects/MemRef/#memrefreinterpret_cast-memrefreinterpretcastop
[web-bufferization]: https://mlir.llvm.org/docs/Dialects/BufferizationOps/#bufferizationto_tensor-bufferizationtotensorop
[web-empty]: https://mlir.llvm.org/docs/Dialects/TensorOps/#tensorempty-tensoremptyop

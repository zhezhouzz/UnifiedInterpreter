

**状态（Status）：** Draft
**作者（Authors）：** [@BaiSifan](https://gitcode.com/BaiSifan)
**创建日期（Created）：** 2026-11-05
**更新日期（Updated）：** 2026-11-18
**相关 Issue/PR：** https://gitcode.com/Ascend/AscendNPU-IR/pull/4962
### 1. 概述
            
#### 1.1 简介
A6（Ascend960）硬件为 MMAD（`mmadL1`）指令新增了异构（混合精度）A/B 数据类型支持与 packed 4bit（s4）系列 mad 重载。本提案在编译器侧同步该变更：

- **6 组异构 mad 重载**：bf16/f16 × int8、bf16/f16 × fp8_e4m3、fp8_e4m3 × fp8_e5m2 及其反向；
- **packed s4 系列**：mad_s8s4 / mad_f16s4 / mad_bf16s4；
- IR 层将 `AllElementTypesMatch<["a", "b"]>` 约束从基类 `HIVM_L1MmadOp` 下移至 `BatchMmadL1Op`（批量算子保持同构约束），`MmadL1Op::verify()` 仅在 Ascend960 上按白名单放行异构组合；
- 模板库（`LocalMmad.cpp`）为 `mma_tile_core` / `mma_tile_bias` 新增 `B_TYPE` 模板参数及异构注册宏，库函数名在 A/B 类型不同时追加 B 元素类型后缀（`mma_tile_<a>_<b>_to_<dst>`）；
- `enable_I4` 路径复用 i8 载体（每字节 2 个 s4，存储侧 K 减半），nibble 解码与 s4→s8 符号扩展由硬件执行单元完成，无需软件 pack。

由于当前前端 TA 侧尚未定义对应的异构组合类型，NPUIR 侧修改仅参照后端实现（`cce_aicore_intrinsics.h` 提供的 `mad` 重载集）进行初步定义与 IR 层面校验；端到端执行依赖后续后端硬件指令注册，TA 前端类型契约定型后再进一步完善与验证。

#### 1.2 动机
- 大模型推理/训练中权重低位宽化（W8/W4）是主流趋势，A/B 异构 MMAD（如 f16 激活 × s8/int4 权重）可避免激活/权重的反复往返转换，直接在 Cube 上完成混合精度矩阵乘，访存减半。
- 旧架构 IR 契约强制"A/B 同元素类型"，无法表达 A6 硬件已支持的混合精度组合；若不放开，上层只能通过显式 cast 往返模拟，引入额外搬运与精度损失。
- `BatchMmadL1Op` 与 `MmadL1Op` 共享基类 `HIVM_L1MmadOp`，同构 trait 定义在基类上导致两条指令被一起锁死；硬件上 batch 形态暂无对应异构重载，需要拆分约束粒度。
- s4 量化权重若走软件 pack/unpack 会在 NPUIR 侧引入大量辅助指令；硬件 `mad_*s4` 直接消费打包 s4 字节流，软件层只需传递逻辑 K 并将存储侧 K 折半。

#### 1.3 目标
**目标：**

1. `mmadL1` 在 Ascend960 上支持异构 A/B 白名单组合：(f16|bf16) × (int8 | fp8_e4m3)、fp8_e4m3 × fp8_e5m2 及反向（共 6 组），累加器 f32。
2. `mmadL1` 在 Ascend960 上支持 `enable_I4` packed s4 路径：bf16/f16 × s4 → f32、s8 × s4 → i32；存储侧以 i8 载体承载，K 折半。
3. `AllElementTypesMatch<["a", "b"]>` trait 从 `HIVM_L1MmadOp` 下沉到 `BatchMmadL1Op`，`batchMmadL1` 契约保持不变。
4. 模板库提供与白名单一一对应的异构库符号（`mma_tile_<a>_<b>_to_<dst>` 及 bias 变体）与 s4 符号（`_i4` 后缀），`BISHENG_TPL_920R1` 宏隔离。
5. 非 Ascend960 架构上所有新能力在 `MmadL1Op::verify()` 硬性拒绝，旧架构合法性集合不变。

**非目标：**

- `batchMmadL1` 不放开异构约束（硬件无对应 batch 异构重载）。
- 不承诺端到端数值正确性：新组合的可执行性依赖后续后端硬件指令注册。
- 不涉及 Triton 前端 / HFusion lowering 到 `mmadL1` 的路径改造；TA 前端异构组合类型契约定型后的接口适配不在本提案范围。
- i4→打包字节转换与 pad-nibble 清零的完整契约属于前端/权重预处理侧，NPUIR 不做 pack/unpack 指令插入。

### 2. 用例分析
            
| 场景 | 组合 | 累加器 | 说明 |
|---|---|---|---|
| LLM 推理 W8A16 | f16/bf16 × int8 | f32 | 激活保持高精度，权重 INT8 量化，1×FP16 等效算力 |
| LLM 推理 W8A16-FP8 | f16/bf16 × fp8_e4m3 | f32 | FP8 权重 + 高精度激活 |
| FP8 双侧低精度 | fp8_e4m3 × fp8_e5m2 及反向 | f32 | 1×FP8 等效算力，吞吐优先 |
| W4A16（packed s4） | f16/bf16 × s4（enable_I4） | f32 | 权重 4bit 量化，访存减半，硬件 nibble 解码 |
| W4A8（packed s4） | s8 × s4（enable_I4） | i32 | 双侧低精度 |

**DFX 要求：**

- **兼容性**：非 Ascend960 架构上既有 IR 行为完全不变（A/B 必须同类型，报错文案不变）；同类型路径（homo）库符号名保持原样，`_with_<bias>_bias_` 顺序与库宏一致。
- **可靠性**：非法组合（白名单外、非 Ascend960）在编译期 `emitOpError` 报错，不漏到运行期。
- **可测试性**：白名单/门控为纯函数式校验，lit 正反用例全覆盖。

**使用约束：**

- 异构组合仅允许 A/B 元素类型不同且命中白名单，且仅限 Ascend960；`batchMmadL1` 不受影响（保持同构）。
- s4 权重的 i4→打包字节转换、pad-nibble 清零由前端/权重预处理完成；NPUIR 侧软件只传逻辑 K，存储侧 K = ⌈logicalK/2⌉ 用于 L0B/L1B 布局寻址。
### 3. 方案设计
            
#### 3.1 总体方案
采用四层贯通设计，每层职责单一：

```
IR 定义层 (TableGen trait 下沉) → 语义校验层 (MmadL1Op::verify 白名单)
  → 符号映射层 (LibraryCall 命名) → 设备执行层 (Catlass 模板注册 + mad 重载)
```

**IR 定义层**（`HIVMMacroOps.td`）

- 仅将 `AllElementTypesMatch<["a", "b"]>` 从 `HIVM_L1MmadOp` 基类下沉到 `BatchMmadL1Op`。全仓库仅 `MmadL1Op` 与 `BatchMmadL1Op` 派生自该基类，批量算子契约未变，`mmadL1` 获得表达异构的 IR 合法性空间。

**语义校验层**（`HIVMMacroOps.cpp`，`MmadL1Op::verify()`）

- A/B 元素类型不同时：
  - 要求所在 Module 为 Ascend960（`hacc::utils::isAscend960`），否则报错 "only supported on Ascend960 series"；
  - 白名单校验 `isSupported`：`(f16|bf16) × (fp8_e4m3 | int8)` 或 `(e4m3 × e5m2)` 双向，白名单外报错 "unsupported heterogeneous A/B element types"。
- `enable_I4` 存在时：
  - 要求 Ascend960；
  - 校验 C 累加器类型与组合匹配（f16/bf16 × s4 → f32；s8 × s4 → i32）。
- verifier 白名单与 `LocalMmad.cpp` 实际注册的 6 个异构入口严格对应。

**符号映射层**（`LibraryFunctionOpInterfaceImpl.cpp`）

- A/B 元素类型不一致且位于 Ascend960 时，符号名前缀改为 `mma_tile_<a>_<b>_to_<dst>`（bias 变体 `mma_tile_with_<bias>_bias_<a>_<b>_to_<dst>`），`getDpsInputs()[0]/[1]` 取 A/B 顺序；
- 同类型路径（homo）符号名保持原样；`_ta/_tb/_hf32/_i4` 后缀规则沿用既有拼接逻辑（已知缺口见第 5 节风险 1）。

**设备执行层**（`LocalMmad.cpp`）

- `mma_tile_core` / `mma_tile_bias` 新增尾随默认模板参数 `typename B_TYPE = SRC_TYPE`，既有 6 参数显式实例化不受影响；
- 新增 `DECLARE_MMA_TILE_HETERO` / `REGISTER_MMA_TILE_HETERO`（及 `_BIAS` 变体）异构注册宏，展开为 `TA=TB=HF32=false` 的 `mma_tile_core<a_type, dst_type, bias_type, false, false, false, b_type>` 调用；注册 6 组白名单组合 ×（基础 + bias）共 12 个符号；
- packed s4 系列注册符号带 `_i4` 后缀，尾随模板参数在设备层选择专用 `mad_bf16s4` / `mad_f16s4` / `mad_s8s4` intrinsic；
- 全部新注册以 `BISHENG_TPL_920R1` 编译宏隔离，非 920R1 目标零影响。

#### 3.2 技术选型
- **Verifier 白名单 vs Trait**：选择 `hasVerifier` 白名单。异构合法性依赖目标架构（需访问 Module 的 `hacc.target`）与 A/B/C 三元组联合判断，trait 无法访问 Module 上下文。batch 与单条指令约束粒度不同，故将同构 trait 下沉到 `BatchMmadL1Op`、异构逻辑放进 `MmadL1Op::verify()`。
- **白名单 vs 黑名单**：选择白名单。白名单与模板库注册一一对应（6 组），新增组合必须同时改 verifier 与模板库，符合"硬件能力显式建模"；黑名单随硬件迭代会持续漂移。
- **s4 复用 i8 载体 vs 新增 i4 MLIR 类型**：选择复用 i8 载体 + `enable_I4` 开关。MLIR 侧无原生 4bit 有符号整数类型；`enable_I4` 已是既有 IR 旗标，复用可使 IR 形状/stride 逻辑沿用 i8 既有路径，仅存储侧 K 折半，nibble 解码下沉到硬件。
- **异构符号携带双类型 token vs 仅 B 后缀**：选择 `<a>_<b>` 双 token 前缀，与设备宏生成的符号逐字一致，避免 A 类型无法从符号恢复的歧义。

#### 3.3 功能与性能设计
- 核心流程：前端产出 `mmadL1`（异构 A/B 类型或 `enable_I4`）→ verifier 校验（Ascend960 门控 + 白名单 / 累加器匹配）→ LibraryCall 命名生成 `mma_tile_<a>_<b>_to_<dst>`（或 `_i4` 后缀符号）→ 设备端 Catlass 模板按 B_TYPE 模板参数调用 `L1Mmad<SRC_TYPE, B_TYPE, ...>` → 设备层按 B_TYPE 选择 `mad` 重载（含 `mad_*s4`）。
- 性能预期由硬件保证：W8A16 / W4A16 消除激活↔权重的往返 cast，s4 路径访存减半且 nibble 解码零软件开销；编译器层不引入额外运行期开销。
- 影响范围：HIVM 宏指令 IR 定义与校验、库函数符号命名、RegBase Cube 设备模板；不涉及其他 dialect。

#### 3.4 安全隐私与DFX设计
- **兼容性**：非 Ascend960 硬门控拒绝全部新能力，旧架构 IR 合法性集合与报错文案不变；同类型库符号不变，二进制兼容；`B_TYPE = SRC_TYPE` 尾随默认参数保证既有同构实例化零改动。
- **可靠性**：白名单外的组合编译期报错；`enable_I4` 与异构类型的交叉约束（累加器类型）有独立校验分支。
- **可维护性**：verifier 白名单、库符号命名、模板注册三处需同步维护（当前已严格对齐 6 组）。

#### 3.5 编程与调用设计
*若本提案相关特性/功能组件/模块等支持被开发者集成调用（二次开发），则需要提供便捷易用的编程与调用能力。要站在开发者如何进行编程开发、接口调用及系统集成的使用方式上，给出相应的编程模型定义和设计，包括各要素的可获取方式和途径。*

##### 3.5.1 编程模型基本设计
- 开发环境：Ascend960 硬件，BiShengIR/HIVM 方言编译链。
- 开发约束：异构与 `enable_I4` 仅限 Ascend960；TA 前端尚未定义对应组合类型，现阶段仅 IR/库层面可表达；s4 权重的打包与 nibble 清零由前端/权重预处理侧完成。
- 可验收设计：lit 用例验证 verifier 接受/拒绝边界与库符号命名；端到端数值用例待后端硬件指令注册与 TA 前端定型后补充。

##### 3.5.2 接口定义与设计
*给出相关组件/模块被集成调用的API定义或变更、对接上下游主流生态技术栈的适配方案、提供功能被使用或集成的参考代码或方法等。*

###### 3.5.2.1 mmadL1（MMAD 宏指令）— 异构与 s4 扩展
- 接口描述：L1 层矩阵乘宏指令，本次放开 A/B 异构（Ascend960 白名单）并扩展 `enable_I4` 语义（packed s4）。
- 接口原型（变更部分）：

```mlir
// 异构组合（6 组白名单，累加器 f32）
hivm.mmad_l1 %a, %b, %c, ... :
  (A: f16|bf16 × B: int8|fp8_e4m3 | A/B: fp8_e4m3×fp8_e5m2 双向) -> C: f32

// packed s4（enable_I4，B 以 i8 载体承载，存储 K 折半）
hivm.mmad_l1 %a, %b_packed_i8, %c, ... { enable_I4 } :
  (A: f16|bf16 -> C: f32 | A: i8 -> C: i32)
```

- 输入/输出参数（变更部分）：

| 参数名称 | 输入/输出 | 类型 | 描述 | 取值范围 |
| --- | --- | --- | --- | --- |
| a × b（异构） | 输入 | (f16\|bf16)×(int8\|fp8_e4m3)、fp8_e4m3×fp8_e5m2 双向 | A/B 元素类型组合 | 白名单内，仅 Ascend960 |
| b（enable_I4） | 输入 | int8 载体 | 每字节 2 个 s4，存储侧 K = ⌈logicalK/2⌉ | 仅 Ascend960 |
| enable_I4 | 输入 | UnitAttr（可选，既有旗标） | packed s4 路径开关 | present 时选 mad_s8s4/mad_f16s4/mad_bf16s4 重载 |
| c | 输出 | f32 \| i32 | 累加器 | 须与组合匹配（s4：i8×s4→i32，其余→f32） |

- 异常处理：非 Ascend960 使用新能力、白名单外组合、累加器不匹配 → `emitOpError` 编译失败。
- 变更说明：`AllElementTypesMatch<["a","b"]>` 从 `HIVM_L1MmadOp` 下沉至 `BatchMmadL1Op`（Breaking Change：此前非法的异构 IR 在 Ascend960 上变为条件合法；`batchMmadL1` 行为不变）。


###### 3.5.2.2 MMAD 外部库符号（隐式接口）
- 接口描述：HIVMToStandard 生成的 `_mlir_ciface_*` 外部库符号，本提案扩展其命名规则。
- 接口原型（命名规则）：

```text
异构:      mma_tile_<a>_<b>_to_<dst>
           mma_tile_with_<bias>_bias_<a>_<b>_to_<dst>
packed s4: mma_tile_<a>_<b>_to_<dst>_i4
同构:      既有符号形式保持不变
```

- 异常处理：符号未注册时在 ccec 编译链接阶段以缺符号形式暴露（见第 5 节风险 1）。
- 变更说明：`mma_tile_core` / `mma_tile_bias` 模板签名新增尾随默认参数 `B_TYPE = SRC_TYPE`（模板库内部接口变更，既有实例化零改动）。

##### 3.5.3 编程手册设计
在 HIVM 方言宏指令文档 `mmadL1` / `batchMmadL1` 节更新：异构 A/B 支持矩阵（6 组白名单）、`enable_I4` packed s4 语义（i8 载体、K 折半、前端打包契约）、Ascend960 限制说明，随后续实现完善 PR 同步输出。

### 4. 测试设计
            
- **单元测试（lit）**：
  - 正向（`test/Dialect/HIVM/IR/ops.mlir`）：两个带 `hacc.target = "Ascend960"` 的 module，覆盖白名单全集 6 组异构组合（tensor DPS + bias 形式），全部解析通过；
  - 负向（`test/Dialect/HIVM/IR/invalid.mlir`）：无 target 属性 → 非 Ascend960 分支报错；Ascend960 模块内白名单外组合 → "unsupported heterogeneous" 报错，文案与 `emitOpError` 逐字匹配；
  - 符号命名（`test/Conversion/HIVMToStandard/RegBase/mmadl1-hetero.mlir`）：6 组组合的期望符号与 `getTypeName` 映射（f8E4M3FN→`float8_e4m3_t`、f8E5M2→`float8_e5m2_t`、i8→`int8_t`、bf16→`bfloat16_t`、f16→`half`）及库宏生成名逐一核对。
- **回归测试**：`check-bishengir` 全量回归；同构路径库符号与既有用例不变（PR CI 全部流水线已通过）。
- **端到端测试**：Ascend960 上 W8A16 / W4A16 / FP8×FP8 / s4 系列数值正确性用例——**依赖后续后端硬件指令注册与 TA 前端类型定型，暂不具备条件**（见第 7 节）。
### 5. 缺点和风险
            
1. **「异构 + 转置/HF32/I4」组合的契约分歧（P2，评审唯一发现）**：`LibraryFunctionOpInterfaceImpl.cpp` 中异构符号名前缀已改为 `mma_tile_<a>_<b>`，但 `_ta/_tb/_hf32/_i4` 后缀仍无条件拼接；而 `LocalMmad.cpp` 新增的异构入口全部是 `TA=TB=HF32=false`，verifier 也未排除「异构 + 转置/HF32/I4」组合。带转置的异构 `mmadL1` 会生成模板库中不存在的 `_mlir_ciface_..._tb` 符号，导致生成 kernel 在 ccec 编译链接阶段失败。应对措施（二选一，合入前定稿）：收紧 `MmadL1Op::verify()` 异构分支（拒绝转置/HF32），或补齐 `_ta/_tb/_hf32` 异构注册并补负向测试。
2. **Breaking Change（受控）**：异构 IR 从"非法"变为"Ascend960 条件合法"；trait 下沉对 `batchMmadL1` 用户无感。依赖全局同构 trait 的下游工具需确认。
3. **端到端正确性未闭环**：本提案不含对应指令的后端注册，新组合在 Ascend960 上不可运行；注册就绪前仅保证 IR → 符号命名的静态一致性。
4. **前端契约占位**：TA 前端未定义异构组合类型，当前类型集仅参照后端 `cce_aicore_intrinsics.h` 重载集初步圈定；前端定型后可能调整白名单与符号命名。
5. **三处同步维护**：verifier 白名单、符号命名、模板注册需保持一一对应，新增组合时漏改任意一处都会产生编译期/链接期不一致。
6. **实现成本**：涉及 IR 定义、verifier、库命名、设备模板四层约 4 个源文件 + 3 个测试文件；模板宏体系（HETERO/HETERO_BIAS/S4 三套）有轻度膨胀。
### 6. 现有技术
            
- **NVIDIA IMMA/mma 混合精度**（s8×s4→s32、INT4 Tensor Core）：同为白名单式组合枚举，本提案白名单与 Ascend960 硬件规格对齐；差异在于 s4 打包契约本提案完全下沉到硬件与前端权重预处理，编译器 IR 零辅助指令。
- **MLIR `AllElementTypesMatch` trait 惯例**：同构约束用 trait、架构相关约束用 verifier 是 MLIR 通行实践；本提案将同一 trait 在派生类间差异化下沉（batch 保 trait、单条走 verifier），符合约束粒度最小化原则。
- **仓库内姊妹提案**：MMAD_MX 数据格式扩展 RFC（!4912，`hif4`/A16W4/异构 native-A×packed-B）覆盖 MX 侧；本提案覆盖 L1 侧。两条链路共用"异构符号携带双类型 token"的命名思想（MX 为后缀 `_<B类型名>`，L1 为前缀 `mma_tile_<a>_<b>`），后续可评估统一。
### 7. 未解决问题
            
1. P2 契约分歧的定稿方向：收紧 verifier（异构仅允许非转置/非 HF32/非 I4）还是补齐 `_ta/_tb/_hf32` 异构注册与负向测试？（合入前必须决策）
2. TA 前端异构组合类型契约何时定型？定型后白名单与符号命名是否需要调整？
3. `enable_I4` 与异构类型（如 f16 × e4m3 且 enable_I4）的交叉组合是否需要显式 verifier 拒绝（当前仅累加器校验间接约束）？
4. s4 权重的 pad-nibble 清零与 i4→打包字节转换的前端/权重预处理契约文档何时输出？
5. 端到端数值用例依赖的 Ascend960 后端硬件指令注册与外部库版本就绪时间。
6. L1 侧 `mma_tile_<a>_<b>` 前缀命名与 MX 侧 `_<B类型名>` 后缀命名是否统一？
### 附录
            
- **参考资料链接**
  - 相关 PR：!4962（mmadL1 的 A6 新增异构 A/B 数据类型支持）；姊妹 PR：!4912（MMAD_MX 数据格式扩展）
  - RFC 模板：`.gitcode/ISSUE_TEMPLATE/510-RFC.yml`
  - 涉及文件：
    - `bishengir/include/bishengir/Dialect/HIVM/IR/HIVMMacroOps.td`
    - `bishengir/lib/Dialect/HIVM/IR/HIVMMacroOps.cpp`
    - `bishengir/lib/Dialect/HIVM/IR/LibraryFunctionOpInterface/LibraryFunctionOpInterfaceImpl.cpp`
    - `bishengir/lib/Template/lib/RegBase/Cube/LocalMmad.cpp`
    - `bishengir/test/Conversion/HIVMToStandard/RegBase/mmadl1-hetero.mlir`
    - `bishengir/test/Dialect/HIVM/IR/invalid.mlir`、`bishengir/test/Dialect/HIVM/IR/ops.mlir`
- **术语表**

| 术语 | 含义 |
| --- | --- |
| W8A16 | 权重 8bit（int8/fp8_e4m3），激活 16bit（f16/bf16） |
| W4A16 / W4A8 | 权重 4bit（packed s4），激活 16bit / 8bit |
| 异构组合 | A/B 元素类型不同的 MMAD，共 6 组白名单 |
| enable_I4 | 既有 IR 旗标，本提案扩展为 packed s4 路径：B 以 i8 载体承载，存储侧 K 折半 |
| mad_*s4 | 硬件 native 重载（mad_s8s4/mad_f16s4/mad_bf16s4），直接消费打包 s4 字节流，硬件完成 nibble 解码与 s4→s8 符号扩展 |
| B_TYPE | `mma_tile_core`/`mma_tile_bias` 新增的尾随默认模板参数（`B_TYPE = SRC_TYPE`） |
| 920R1 | Ascend960 对应的模板编译宏 `BISHENG_TPL_920R1` 门控 |
- **文档更新计划**：P2 契约分歧定稿后更新本 RFC 状态（Draft → Reviewing），随后续实现 PR 同步更新 HIVM 宏指令编程手册。

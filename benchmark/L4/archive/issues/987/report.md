

# [RFC]: Ascend960 MMAD_MX 新增数据类型支持（hif4 / A16W4 / 异构组合）

**状态（Status）：** Draft
**作者（Authors）：** [@BaiSifan](https://gitcode.com/BaiSifan)
**创建日期（Created）：** 2026-11-05
**更新日期（Updated）：** 2026-11-18
**相关 Issue/PR：** https://gitcode.com/Ascend/AscendNPU-IR/pull/4912（已合入）
### 1. 概述
            
#### 1.1 简介
A6（Ascend960）后端为 MMAD_MX 指令新增了 4bit 自定义浮点格式 `hif4` 及异构（混合精度）矩阵乘组合。本提案在编译器侧同步该硬件变更：`HIVMMatmulDataformat` 枚举新增 `HIF4_T`（值 4），并贯通 TableGen 枚举 → 库符号命名 → Template 设备库注册 → 设备 kernel 层四层链路，同时由 HFusionToHIVM Matmul 转换透传新格式。

由于当前前端 TA 侧尚未定义对应类型，本提案的 NPUIR 侧修改仅参照后端实现进行初步定义；待 TA 前端类型契约明确后再进一步完善与验证。端到端数值正确性依赖后续后端硬件指令注册。

#### 1.2 动机
- 大模型推理中 W4A16 / A4W4 低位宽化是主流趋势，`hif4` 4bit 自定义浮点与异构组合（原生 A × 打包 4bit B）可避免激活/权重的反复往返转换，直接在 Cube 上完成混合精度矩阵乘，访存减半。
- 后端硬件指令与模板库已先行定型，编译器侧若不同步，上层无法在 Ascend960 上表达这些组合。
- `gemv_ctrl` / `BTbuf_ctrl` / `zero_cmatrix_ctrl` 三个 MMAD 配置控制位（config bit [61]/[62]/[63]）尚无消费方；在 TA 前端契约定型前，作为 IR 属性暴露会提前固化不成熟的接口面，故本提案选择仅在 INTRINSIC 调用层内部置位。

#### 1.3 目标
**目标：**

1. `HIVMAttrs.td`：`HIVM_LocalMatmulMx_DataFormat` 枚举新增 `HIF4_T = 4`（序列化名 `fp4_hif4_t`），并与库调用符号后缀建立映射。
2. 库函数命名（`LibraryFunctionOpInterfaceImpl.cpp`）：异构 A/B 组合在库名中同时携带 A、B 类型 token；支持 fp4/hif4 的 transpose 后缀；`legacyInt8Format` 后缀逻辑仅对 Ascend960 生效（非 legacy 格式组合受 960 门控）。
3. 模板库注册（`LocalMmadMx.cpp`）：新增 hif4×hif4、A16W4（f16/bf16 × packed 4bit B）以及异构 native-A（half/bfloat16_t/float8_e4m3_t，临时占位集）× packed-B 组合的 DECLARE/REGISTER 宏注册；`LocalMmadUtils.h` 对应宏统一追加 `uint64_t mmadConfig` 参数。
4. 设备层（`kernel_operator_mm_impl.h`）：将 9201 从 3510 分支拆出，新增 isMx 类型表（16 组注册）与 `btbufCtrl` / `cmatrixInitVal` 归一化逻辑。
5. 前端传播（`HFusionToHIVM/Matmul.cpp`）：Matmul 转换透传新增格式。

**非目标：**

- `gemv_ctrl` / `BTbuf_ctrl` / `zero_cmatrix_ctrl` 控制位**不作为 IR 属性暴露**，仅在调用 INTRINSIC 时内部置位（true / cmatrixSource / cmatrixInitVal），待前端契约明确后再评估是否上升为 IR 接口。
- `MmadMxL1Op` 的 `hasVerifier` 保持为 0，本提案不新增 MX 侧 verifier；随 verifier 逻辑回退已移除对应负向覆盖用例。
- 不承诺端到端数值正确性：新组合的可执行性依赖后续后端硬件指令注册。
- 不处理 MX scale（fp8_e8m0）粒度与新组合的配比规格定义（见第 7 节）。

### 2. 用例分析
            
| 场景 | 组合 | 算力 | 说明 |
|---|---|---|---|
| 全 4bit | hif4 × hif4（MX） | 1×FP8 | 极致压缩场景，双侧均为打包 4bit |
| LLM 推理 W4A16 | f16/bf16 × hif4、f16/bf16 × e2m1（A16W4） | 1×FP16 | 权重 4bit 量化，访存减半 |
| 异构 FP8×FP4 | e4m3 × e2m1 / e4m3 × hif4 | 1×FP8 | 双侧低精度，吞吐优先 |

**DFX 要求：**

- **兼容性**：传统 i8×i8 MX 库符号命名保持不变；`btBufCtrl` 追加在 `MmadParams` 末尾且默认 `false`，不改变既有 ABI/语义；主链路（不带新控制位、沿用既有 fp8/fp4 组合）端到端一致性完整，无默认路径回归。
- **可维护性**：格式枚举在 IR 侧（TableGen）与设备端（Catlass/kernel 层）多处定义，需同步维护（已对齐为 1~4）。
- **可测试性**：新增 `convert-hivm-to-standard-ascend960.mlir` lit 用例覆盖命名映射。

**使用约束：**

- hif4 与异构组合仅限 Ascend960（模板注册以 `BISHENG_TPL_920R1` 编译宏隔离）。
- 异构 native-A 类型集（half/bfloat16_t/float8_e4m3_t）为**临时占位**，TA 前端未定型，注册与 helper 派发逻辑在前端契约落地后需重新审视。
### 3. 方案设计
            
#### 3.1 总体方案
采用四层贯通设计，每层职责单一：

```
IR 定义层 (TableGen 枚举) → 前端传播层 (HFusionToHIVM 透传)
  → 符号映射层 (LibraryCall 命名) → 设备执行层 (Catlass 模板 + kernel 层)
```

**IR 定义层**（`HIVMAttrs.td`）

- `HIVM_LocalMatmulMx_DataFormat` 枚举追加 `HIF4_T = 4`（`fp4_hif4_t`），追加在枚举行末尾，与 `LibraryFunctionOpInterfaceImpl.cpp`、`LocalMmadMx.cpp` 的枚举值/字符串逐字一致。

**前端传播层**（`HFusionToHIVM/Matmul.cpp`）

- Matmul 转换透传新增格式：17 个实参与 `MmadMxL1Op` 自定义 builder 形参个数、顺序完全吻合（3 个 `UnitAttr{}` 占位对应未来控制位，`Value{}` 仍为 per_channel_bias）。

**符号映射层**（`LibraryFunctionOpInterfaceImpl.cpp`）

- lhs 后缀优先由 A 元素类型决定（`fp16` / `bf16` / `fp8_e4m3_t`，即异构 native-A 白名单），否则回退 `lhsFormat` 枚举（新增 case 4 → `fp4_hif4_t`）；rhs 后缀由 `rhsFormat` 枚举决定（同样支持 hif4）。
- 异构 A/B（元素类型不一致且位于 Ascend960）在库名中同时携带 A、B 类型 token（`_<B类型名>` 后缀），为异构组合生成独立外部库符号。
- fp4/hif4 支持 transpose 后缀；`legacyInt8Format`（i8×i8）符号形式保持不变，非 legacy 格式组合的后缀仅对 Ascend960 生效。

**模板注册层**（`LocalMmadMx.cpp` + `LocalMmadUtils.h`）

- 设备端 `HIVMMatmulDataformat` 枚举同步新增 `HIF4_T = 4`；`isFp4Format` 覆盖 hif4，复用既有 FP4 半字节存储路径（K 因子 2，存储 K = ⌈logicalK/2⌉，L0 ping-pong 偏移按半字节对齐）。
- isMx 分派表新增 `BISHENG_TPL_920R1` 门控注册：hif4×hif4（双侧均为打包 i8 存储，复用既有 int8-to-int8 符号形式、双 format 置 hif4）、f16/bf16/e4m3 native-A × e2m1/hif4 packed-B；每条注册同时生成基础与 bias-format 两个符号。
- 异构注册宏 `REGISTER_MMA_MX_HETERO` 成对展开 `REGISTER_MMA_MX_HETERO_FORMAT` / `REGISTER_MMA_MX_HETERO_BIAS_FORMAT`；`LocalMmadUtils.h` 全部 DECLARE/REGISTER 宏统一追加 `uint64_t mmadConfig` 参数，与 HIVMToStandard 的实参一一对应。

**设备执行层**（`kernel_operator_mm_impl.h` + `kernel_struct_mm.h`）

- 9201 从 3510 分支拆出独立处理；新增 isMx 类型表（16 组注册）与 `btbufCtrl` / `cmatrixInitVal` 归一化逻辑。
- `kernel_struct_mm.h`：`btBufCtrl` 追加在 `MmadParams` 末尾，默认 `false`，不改变既有 ABI/语义。

**控制位编码（INTRINSIC 调用层）**

- `gemv_ctrl`（bit 61）/ `BTbuf_ctrl`（bit 62）/ `zero_cmatrix_ctrl`（bit 63）不作为 IR 属性暴露；HIVMToStandard 生成库调用时内部置位（true / cmatrixSource / cmatrixInitVal），编码进 i64 `mmadConfig` 运行期参数追加到库调用尾部。bit 61/62/63 定义与 `LocalMmadMx.cpp`、模板库注释三处一致；`mmadConfig` 位于 sync args 之后的形参末尾，与 C++ 形参位置一致。

#### 3.2 技术选型
- **控制位不暴露为 IR 属性 vs 暴露为可选 UnitAttr**：本提案选择**不暴露**。前期设计（见《Ascend960-MMAD-MX-format-extension-design.md》）曾计划以可选 UnitAttr 暴露三个控制位，但 TA 前端契约尚未定型，提前固化为 IR 接口面会在前端定型后被迫承担 Breaking Change。INTRINSIC 层内部置位将接口面收敛到编译器内部，前端定型后再评估是否上升为 IR 属性。
- **MmadMxL1Op hasVerifier 保持 0 vs 启用为 1**：保持 0。前期计划新增 MX verifier（f16/bf16/hif4 仅限 960 等），随 verifier 逻辑回退已一并移除负向覆盖用例；架构门控当前由库符号命名与模板 `BISHENG_TPL_920R1` 编译宏兜底（代价见第 5 节风险 1）。
- **异构符号命名携带双类型 token vs 仅 format 后缀**：选择双类型 token。异构组合的 A 类型无法从 `lhsFormat` 枚举唯一恢复（native-A 走元素类型、packed-B 走 format 两条路径），符号必须同时携带两侧信息才能与模板库一一对应。
- **hif4×hif4 复用 int8 符号形式 vs 新建符号**：选择复用。hif4 双侧均保持打包 i8 存储，与既有 int8-to-int8 模板的存储布局一致，仅 format 元数据不同，复用可避免模板膨胀。

#### 3.3 功能与性能设计
- 核心流程：前端产出 `mmadMx`（HFusionToHIVM 透传新格式）→ LibraryCall 命名生成带 A/B 类型 token 与 format 后缀的外部库符号 → 设备端 Catlass 模板按 `(lhsFormat, rhsFormat)` 查 isMx 类型表分派 → kernel 层按 isMx 类型表选择 btbufCtrl/cmatrixInitVal 归一化路径。
- 性能预期由硬件保证；编译器层不引入额外运行期开销，hif4 复用 FP4 半字节存储与 K 折算路径（K 因子 2）。
- 影响范围：HIVM 属性枚举、库函数符号命名、HFusionToHIVM Matmul 转换、RegBase Cube 设备模板与 kernel 层；不涉及其他 dialect 的行为变更。

#### 3.4 安全隐私与DFX设计
- **兼容性**：主链路（不带新控制位、沿用既有 fp8/fp4 组合）从 IR → 库函数名 → 模板库签名的端到端一致性完整，未发现默认路径回归或编译断裂；`btBufCtrl` 默认 `false` 不改变既有 ABI。
- **可维护性**：格式枚举在 IR（TableGen）、Catlass 模板、kernel 层多处定义，已对齐（1~4），存在多处同步维护成本。
- **可靠性**：在注册就绪前，新增组合仅通过 IR 校验与符号命名，不可运行；端到端数值正确性依赖后续后端硬件指令注册。

#### 3.5 编程与调用设计

##### 3.5.1 编程模型基本设计
- 开发环境：Ascend960 硬件，BiShengIR/HIVM 方言编译链（或经 Triton 前端 lowering）。
- 开发约束：hif4 与异构组合仅限 Ascend960（模板以 `BISHENG_TPL_920R1` 编译宏隔离）；TA 前端尚未定义对应类型，现阶段仅 IR/库层面可表达。
- 可验收设计：lit 用例验证库符号命名映射；端到端数值用例待后端硬件指令注册与 TA 前端定型后补充。

##### 3.5.2 接口定义与设计

###### 3.5.2.1 xxx（API1 Name）
- 接口描述：MX 矩阵乘宏指令，本次扩展 `lhsFormat`/`rhsFormat` 数据格式枚举（IR 属性面不变，无新增属性）。
- 接口原型（变更部分）：

```mlir
hivm.mmad_mx %a, %b, %scaleA, %scaleB ... {
  lhsFormat = #hivm<mx_dataformat fp4_hif4_t>,  // 新增枚举值 4
  rhsFormat = #hivm<mx_dataformat fp4_hif4_t>
}
```

- 输入/输出参数（变更部分）：

| 参数名称 | 输入/输出 | 类型 | 描述 | 取值范围 |
| --- | --- | --- | --- | --- |
| lhsFormat / rhsFormat | 输入 | HIVM_LocalMatmulMx_DataFormat | MX 数据格式 | 1=e5m2, 2=e4m3, 3=e2m1, **4=hif4**（新增）；hif4 与 f16/bf16 A/B 仅 Ascend960 |

- 异常处理：本提案未新增 verifier（`hasVerifier` 保持 0）；非法组合由库符号解析失败或模板编译宏隔离兜底。
- 约束说明：hif4 复用 FP4 半字节存储，存储 K = ⌈logicalK/2⌉；hif4×hif4 双侧均为打包 i8 存储。
- 变更说明：纯增量扩展，既有格式取值语义不变。

###### 3.5.2.2 MMAD_MX 外部库符号（隐式接口）
- 接口描述：HIVMToStandard 生成的 `_mlir_ciface_*` 外部库符号，本提案扩展其命名规则。
- 接口原型（命名规则）：

```text
异构组合:   ..._<A类型名>_<B类型名>[_<X>transpose]_...   // A、B 类型 token 同时携带
新格式后缀: fp4_hif4_t                                    // 枚举值 4 的序列化名
传统 i8×i8: ..._lhs_format_..._rhs_format_...             // 保持不变
```

- 输入/输出参数：

| 参数名称 | 输入/输出 | 类型 | 描述 | 取值范围 |
| --- | --- | --- | --- | --- |
| mmadConfig | 输入 | uint64_t | MMAD 配置位（追加在库调用形参末尾，位于 sync args 之后） | bit 61=gemv, 62=BTbuf, 63=zero_cmatrix；由 HIVMToStandard 内部置位 |

- 异常处理：符号未注册时在 codegen/链接阶段以缺符号形式暴露（见第 5 节风险 1）。
- 变更说明：`LocalMmadUtils.h` 全部 DECLARE/REGISTER 宏签名追加 `uint64_t mmadConfig`（模板库内部接口变更，随本提案同 PR 适配）。


##### 3.5.3 编程手册设计
在 HIVM 方言宏指令文档 `mmadMx` 一节更新数据格式支持矩阵（新增 hif4/枚举值 4）与 Ascend960 限制说明，随后续实现完善 PR 同步输出。

### 4. 测试设计
            
- **单元测试（lit）**：新增 `convert-hivm-to-standard-ascend960.mlir`，覆盖：
  - fp4/hif4 命名映射（枚举值 4 → `fp4_hif4_t` 后缀）；
  - fp4/hif4 的 transpose 后缀；
  - 异构 e4m3×hif4 组合的双类型 token 后缀。
- **回归测试**：传统 i8×i8 MX 符号命名回归不变；`check-bishengir` 全量回归。
- **端到端测试**：Ascend960 上 hif4×hif4 / A16W4 / 异构 FP8×FP4 数值正确性用例——**依赖后续后端硬件指令注册与 TA 前端类型定型，暂不具备条件**（见第 7 节）。
### 5. 缺点和风险
            
1. **verifier 放行但模板库未注册/未派发的组合**：`hasVerifier` 保持 0 且无 IR 层白名单拦截，fp8_e5m2 原生 A、异构 + transpose 等组合可通过 IR 校验，但在 codegen 阶段才以缺符号或静默漏算形式暴露。应对措施：后续补齐 MX verifier 白名单（强度与 MMAD 侧对齐）或在模板库补注册。
2. **920r1 gemv 控制位缺省极性与其它架构相反**：gemv 控制位在 920r1 上的缺省极性与其它架构相反，需与后端确认硬件语义后定稿内部置位策略。
3. **异构 native-A 类型集为临时占位**：half/bfloat16_t/float8_e4m3_t 的选择仅参照后端实现，TA 前端未定型；前端契约落地后必须重新审视注册与 helper 派发逻辑，可能涉及符号命名调整。
4. **端到端正确性未闭环**：本提案不含对应宏指令的后端硬件指令注册，新组合在 Ascend960 上不可运行；注册就绪前仅保证 IR → 符号命名的静态一致性。
5. **多处枚举定义需同步**：格式枚举在 IR（TableGen）、Catlass 模板、kernel 层各定义一份，存在漂移风险（当前已对齐为 1~4）。
6. **verifier 负向用例移除**：随 verifier 逻辑回退移除了对应负向覆盖用例，存在覆盖缺口；待 verifier 方案定稿后补齐。
### 6. 现有技术
            
- **NVIDIA IMMA/mma 混合精度**（s8×s4→s32 等）：同为白名单式组合枚举；本提案的组合矩阵与 Ascend960 硬件规格对齐，差异在于本提案现阶段由符号命名 + 编译宏门控而非 verifier 静态拦截。
- **MLIR LibraryCall 既有实践**：格式枚举属性 + 外部库符号命名，与本仓库 HIVM 既有 `lhsFormat` 机制一致，本提案为其自然扩展（新增异构双类型 token）。
- **仓库内前期设计**：《Ascend960-MMAD-MX-format-extension-design.md》覆盖了更大范围（含 mmadL1 异构与控制位 IR 属性化）；本提案为其 MMAD_MX 数据类型部分的落地修订——控制位从「IR 属性暴露」收敛为「INTRINSIC 内部置位」，MX verifier 从「启用」回退为「保持关闭」。
### 7. 未解决问题
            
1. TA 前端对应类型契约何时定型？定型后异构 native-A 占位类型集与注册/helper 派发逻辑需重新审视。
2. fp8_e5m2 原生 A、异构 + transpose 组合：补模板注册还是补 MX verifier 白名单拦截？
3. 920r1 gemv 控制位缺省极性与其它架构相反：内部置位的缺省值如何定稿（需后端确认硬件语义）？
4. MX scale（fp8_e8m0）粒度与新增 f16/bf16、4bit B 侧组合的配比规格（scale 沿 K/N/M 方向的粒度是否随 W 位宽变化）？
5. MmadMxL1Op verifier 最终方案（启用时机、白名单范围）及对应负向用例何时补齐？
6. 端到端数值用例依赖的 Ascend960 后端硬件指令注册与外部库版本就绪时间。
### 附录
            
- **参考资料链接**
  - 相关 PR：!4912（MMAD_MX 的 A6 新增数据类型支持，已合入）
  - RFC 模板：`.gitcode/ISSUE_TEMPLATE/510-RFC.yml`
  - 仓库内前期设计：《Ascend960-MMAD-MX-format-extension-design.md》
  - 涉及文件：
    - `bishengir/include/bishengir/Dialect/HIVM/IR/HIVMAttrs.td`
    - `bishengir/lib/Dialect/HIVM/IR/LibraryFunctionOpInterface/LibraryFunctionOpInterfaceImpl.cpp`
    - `bishengir/lib/Conversion/HFusionToHIVM/Matmul.cpp`
    - `bishengir/lib/Template/lib/RegBase/Cube/LocalMmadMx.cpp`
    - `bishengir/lib/Template/lib/RegBase/Cube/include/ascendc_bisheng/utils/LocalMmad/LocalMmadUtils.h`
    - `bishengir/lib/Template/lib/RegBase/Cube/include/ascendc_bisheng/utils/kernel_operator_mm_impl.h`
    - `bishengir/lib/Template/lib/RegBase/Cube/include/ascendc_bisheng/utils/kernel_struct_mm.h`
- **术语表**

| 术语 | 含义 |
| --- | --- |
| hif4 | 新增 4bit 自定义浮点格式，枚举值 4，序列化名 `fp4_hif4_t` |
| A16W4 | A 操作数 16bit（f16/bf16），B 操作数 4bit（packed s4/e2m1/hif4） |
| A4W4 | A、B 均为 4bit（hif4×hif4） |
| 异构组合 | A/B 元素类型不同的 MMAD（native-A × packed-B） |
| mmadConfig | i64/uint64_t MMAD 配置位运行期参数，bit 61/62/63 分别为 gemv/BTbuf/zero_cmatrix |
| MX | Microscaling，带 fp8_e8m0 scale 的块缩放矩阵乘 |
| 920R1 | Ascend960 对应的模板编译宏 `BISHENG_TPL_920R1` 门控 |
- **文档更新计划**：TA 前端契约定型后更新本 RFC 状态（Draft → Reviewing），随后续实现 PR 同步更新 HIVM 宏指令编程手册。


### 💻 需求背景、当前现状、期望实现的功能内容、具体的设计方案、以及测试方案
            
# [bf16] Issue 1：vmula / vmadd / vsqz 支持 bf16（三元乘加族 + squeeze 压缩）

## 背景与范围

在 Ascend 950（regbased，A5）上为 `vmula`、`vmadd`（fma 族三元指令）与 `vsqz`
（有效 lane 压缩）启用 bf16。前提：`-enable-bf16` 选项与 `LegalizeBF16` 的
`isAscend950Arch && enableNativeBF16` 门控模式已就绪
（参见 `docs/bf16-instruction-enablement-analysis.md`）。

## 现状与卡点（file:line 为 master/1d5988134 基准）

### vmula / vmadd（三元乘加）
- HFusion 层来源算子：`hfusion.elemwise_ternary{fun=fma}`（`TernaryFn::fma`，
  `bishengir/include/bishengir/Dialect/HFusion/IR/HFusionEnums.td:105-111`）。
  `LegalizeBF16.cpp:86` 的 950 分支未排除 → bf16 fma 被降级 f32。**放行点**：
  加 `hfusion::ElemwiseTernaryOp` fun==fma 排除（flag 门控下）。
- **注意点 1（连带放行）**：fma 放行会同时放行同源产生的 vfma/vfms/vfnma/vfnms
  家族，而 `TenaryLowerToIntrinsic::isAscend960OnlyTenaryOp()`
  （`bishengir/lib/Conversion/HIVMAVEToAVEIntrin/HIVMAVEToAVEIntrin.cpp:3813-3822`）
  把 VFmaOp/VMaddOp/VMsubOp/VNmaddOp/VNmsubOp 全部标为 **Ascend960(V121)-only**，
  非 960 目标直接 match-failure。950 上启用 vmadd 必须先确认 ISA 是否提供、
  并放开该门控（或按目标架构细分放行）。
- **注意点 2（下游已就绪部分）**：`TenaryRegistry` 的 bf16 槽已填好——
  VFMulaOp→`VmulaSMInstrOp`（:3952-3956）、VMaddOp→`VmaddInstrOp`（:3984-3988）、
  VFmaOp→`VfmaInstrOp`；regbase `VmulaSMInstrOp/VmaddInstrOp`
  （`HIVMRegbaseIntrins.td:1006-1021/:1075`）经 `ValidVector`（:80-93）已接受
  `vector<128xbf16>`，且 `hivm.vmula.s.m.v128bf16`/`hivm.vmadd.m.v128bf16`
  的 LLVM IR 翻译已实测可发出。
- **注意点 3（上游产生方确认）**：HFusionToHIVM 不转换 ElemwiseTernaryOp；
  向量级入口 `ArithToHIVMAVE.cpp:2429-2431` 已明确支持 fma 的 bf16
  （"AVE fused multiply-add supports only f16, bf16, and f32"）。tensor 级 fma
  在 950 流程中的产生路径需先确认，避免放行后无实际来源。

### vsqz
- `AVE_VsqzOp` 操作数限 `[I8, I16, I32, F16, F32]`
  （`bishengir/include/bishengir/Dialect/HIVMAVE/IR/HIVMAVEOps.td:1059-1070`）→
  加 BF16。
- `HIVMVsqzOpLowering` 显式拒绝非列表类型
  （`HIVMAVEToAVEIntrin.cpp:567-594`，"unsupported vsqz element type"）→
  加 `elementType.isBF16()` 分支。
- regbase 层无需改动（ValidVector + 实测 `hivm.vsqz.x.v128bf16` 可翻译）。

## 代码实现方案

**第 1 步：ISA 确认 vmadd/vfma 在 950 的可用性**（非代码，硬前置）——
决定第 3 步门控的处理方式。

**第 2 步：LegalizeBF16 放行 fma**（上游唯一改动，照 min/max 同款模式）：
在 `shouldLegalizeBF16Op` 的 `if (enableNativeBF16)` 块内追加
`dyn_cast<hfusion::ElemwiseTernaryOp>` 分支，排除 `TernaryFn::fma`。
若 ISA 确认 950 不含 vfma 系，则不能整 fun 放行——改为放行时同步在下游
把非 vmula/vmadd 的 ternary 变体按架构 match-failure（或改用更细粒度的
fun/属性区分，需与前端确认产生方式）。

**第 3 步：vmadd 960-only 门控**：`isAscend960OnlyTenaryOp()`
按 ISA 结论处理——950 有 vmadd 则直接把 VMaddOp 从该列表移除（一行）；
若只有部分形态可用，则把常量函数改为按 target 判断。配合
`TenaryRegistry` 已有的 VMaddOp→`VmaddInstrOp` bf16 槽即可通路。

**第 4 步：vsqz 放行**（两处）：
- `AVE_VsqzOp` 类型列表加 BF16（一行）；
- `HIVMVsqzOpLowering` 的元素类型分支加 `elementType.isBF16()` →
  `VsqzXInstrOp`（照现有 i8/i16/i32/f16/f32 分支样式）。

**第 5 步：测试**：
- 双前缀 UT：`hfusion.elemwise_ternary{fun=fma}` + `ave.hir.vsqz` bf16
  用例加入 `legalize-bf16-enable-flag-910_95.mlir`（裸=bf16 直达 /
  `=false`=f32），模式同现有 8 用例；
- AVEToAVEIntrin 转换用例：`ave.hir.vsqz`/`ave.hir.vmadd` bf16 →
  `hivm.intr.*` 形态断言；
- E2E：save-temps 断言（`compile-pure-elemwise-bf16-flag.mlir` 模式）。

实施顺序建议：vsqz（低风险，先打通）→ fma/vmula → vmadd 门控。

## 涉及代码文件

| 文件 | 改动 |
|---|---|
| `bishengir/lib/Dialect/HFusion/Transforms/LegalizeBF16.cpp` | fma 放行（flag 门控） |
| `bishengir/include/bishengir/Dialect/HIVMAVE/IR/HIVMAVEOps.td` | AVE_VsqzOp 类型列表加 BF16 |
| `bishengir/lib/Conversion/HIVMAVEToAVEIntrin/HIVMAVEToAVEIntrin.cpp` | HIVMVsqzOpLowering 放行；评估 isAscend960OnlyTenaryOp 门控 |
| `bishengir/lib/Conversion/HFusionToHIVM/HFusionToHIVM.cpp` | 只读确认（当前不转换 ternary） |
| 测试 | `legalize-bf16-enable-flag-910_95.mlir` 加 fma/vsqz 双前缀用例；`bishengir/test/Conversion/HIVMAVEToAVEIntrin/` 加 bf16 形态用例 |

## 测试与验收

1. 双前缀 UT（裸调用=bf16 直达 / `enable-bf16=false`=f32），模式同现有 8 用例。
2. AVEToAVEIntrin 转换测试：`ave.hir.vsqz` bf16 → `hivm.intr.hivm.vsqz.x`。
3. 编译级 E2E：bf16 fma/vsqz 内核 save-temps 断言（模式同
   `compile-pure-elemwise-bf16-flag.mlir`）。
4. CANN 工具链对照：`llvm.hivm.vmula.s.m.v128bf16` / `hivm.vmadd` 相关命名
   是否被 bisheng-llc 接受（9.3.0-weekly 的 bisheng-llc.h）。

## 风险与依赖

- vmadd 的 960-only 门控是硬前置，**先与 ISA 文档确认 950 的 vmadd/vfma 可用性再动手**。
- fma 放行是"全家放行"，若 950 不含 vfma 系，需按 fun+架构细化而非整 fun 放行。
- 构建约束：`./build-local.sh -j 16`（硬上限 16 进程）。

### 替代方案
            

### 补充说明
            


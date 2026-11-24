## 背景

`DecomposeAllocTensorCopy` 会把 `bufferization.alloc_tensor() copy(%vbrc)` 拆成一次新分配加一条 `hivm.hir.copy`。在 AIC 上这等价于保留一次对广播结果的读取，再付一次全尺寸拷贝的代价；而广播本身重算很便宜，拷贝反而更贵。

同一 PR 还暴露了两个相关问题：SCF bufferization 的外部模型用 `assert` 保护 `alloc_tensor` 不变量，release 构建会丢弃断言；bufferization pipeline 的 pass 组织存在锚点、kernel 声明和重复注册问题。

## 问题拆解

1. **AIC 上的 VBrc 拷贝**：`alloc_tensor(copy %vbrc)` 分解后仍然读一次广播结果并整块拷贝，AIC kernel 上没有必要。
2. **断言不可用**：`resolveConflicts` 里的 `allocTensor.getCopy()` 空值、`hasOneUse()` 等前置条件只用 `assert` 保护。release 构建下对空 `Value` 调 `getDefiningOp()` 会崩溃，或在无诊断的情况下移入非法 IR。
3. **pipeline 组织**：
   - `DecomposeAllocTensorCopy` 锚在 `ModuleOp`，实际只改单个函数；
   - `NormalizeTmpBufferInVf` 未声明支持的 kernel 类型；
   - `convert-to-hivm` 依据 triton 开关注册两次；
   - `OutlineScopeOptions` 逐字段构造，冗长。

## 方案

- 新增 `DecomposeAllocTensorVBrcPattern`，仅在 `queryFuncCoreType` 返回 AIC 时注册：把 `alloc_tensor` 改写为一次新分配加一个克隆的 VBrc 写入，直接重算广播。带 discardable 属性的分配、以及源为 memref 类型且 producer 可能已变化的场景会被跳过。
- 用 `utils` 中的辅助函数替换两处 `assert`：dump 违规 value 后调用 `llvm::report_fatal_error`，保证 release 构建也有明确诊断；顺带用 `getCopy()` 替代 `getOperand(0)`（避免带 `dynamic_sizes` 的 `alloc_tensor` 取错操作数），scope 判断改用 `dyn_cast_if_present`。
- pipeline 整理：`DecomposeAllocTensorCopy` 锚到 `func::FuncOp` 并嵌入流水线；`NormalizeTmpBufferInVf` 注册 `MixKernel` 与 `PureAivKernel`；`convert-to-hivm` 在 canonicalize 之前对所有 kernel 调度一次；`OutlineScopeOptions` 改为聚合初始化。

## 测试

- 新增 `bishengir/test/Dialect/HIVM/decompose-alloc-tensor-copy.mlir`，覆盖 AIC 重算广播与其他 kernel 保持拷贝的行为。
- SCF / Bufferization / HIVM plan-memory 相关用例回归通过。

## 风险

- AIC 上广播会执行两次；pattern 已限定 AIC 函数与 tensor 类型源，避免影响别的 kernel。
- 断言改成 fatal error 后，非法 IR 的行为由“release 下崩溃/静默”变为“稳定报错”，不改变实际变换条件。

关联 PR !5103（分支 `fix-oneShotBufferize`）。

### 环境信息
            
```
例如：
- 操作系统
- 昇腾硬件信息
- CANN软件版本
- 安装的对应软件版本
```


### 🐛 问题描述
这次修复解决的是： `hivm-split-mix-kernel` 把一个 MIX 函数拆成 AIC/AIV 两份后，AIC 侧会残留“只读不写”的`bufferization.alloc_tensor` /`tensor.empty` ，后续 PlanMemory 直接报`read before first write` 失败。 修复的做法是在拆分完成后做一次“无 writer 的 tensor 根”清理
            
## 根因链
1. 输入里`cur_max` 的 reduce 形态是：`bufferization.alloc_tensor() : tensor<f32>` →`linalg.fill(-inf)` →`linalg.reduce(max)` →`tensor.extract` →`arith.cmpf` →`scf.if` 。
2. split 前（`--mlir-print-ir-before=hivm-split-mix-kernel` ）该函数中：

%48 = bufferization.alloc_tensor() : tensor<f32>
%49 = hivm.hir.vbrc {hivm.tcore_type = VECTOR} ins(-inf) outs(%48)
%58 = hivm.hir.vreduce <max> ... outs(%expanded)
%collapsed_3 = tensor.collapse_shape %58
%extracted = tensor.extract %collapsed_3[] {"DuplicateTensorExtractForCube::visitedLabel"}

关键点：这个`tensor.extract` 没有`hivm.tcore_type` 属性 ，因此 getCoreType 走到最后一行，返回`CUBE_OR_VECTOR` 。

3. AIC 侧过滤（filter VECTOR）时：
   
   - 判断`isCoreTypeOp(extract, VECTOR)` 为 false → extract 被保留（ SplitMixKernel.cpp ）；
   - 外层`scf.for` 走`shouldPreserveForSplit` /`LoopLikeOpInterface` 分支，骨架连同 anchor 一起保留（ SplitMixKernel.cpp 、 L668-L673 ）；
   - 真正的写者`vbrc` /`vreduce` （DPS 且 VECTOR）被 erase，结果用 DPS init 回代（ SplitMixKernel.cpp ），一路回溯就落到了最初的`bufferization.alloc_tensor()` 。
4. 于是 AIC 函数里变成（split 后 dump）：

%11 = bufferization.alloc_tensor() : tensor<f32>
%extracted = tensor.extract %11[] {"DuplicateTensorExtractForCube::visitedLabel"=1,
                                   "PostCubeReplacement::visitedLabel"=1}
%12 = arith.cmpf ogt, %extracted, 0
%13 = scf.if %12 -> (tensor<16x16xf32>) { /* 只剩 anchor */ } else { /* 只剩 anchor */ }

bufferize 后就是`memref.alloc : memref<f32, cbuf>` +`memref.load` ，alloc 没有任何写者。PlanMemory 在 AllocToPointerCast.cpp 检查`buffer2Offsets` ，找不到该 alloc 的规划 → 报错。

5. 为什么`DuplicateTensorExtractForCube` 没兜住：该 pattern 只在 extract 当前存在 cube user 时才会复制成「存 workspace + 新 extract + replacement mark」（ InsertLoadStoreForMixCV.cpp ）。这里 extract 的所有用户都是 vector 运算，pattern 只打了个`visitedLabel` 就返回，没有产生 replacement。split 后 cube 侧仅剩一个空壳`scf.if` ，`PostCubeReplacement` 找不到带`replacementLabel` 的 mark，于是也只是打标签、不删 op（ SplitMixKernel.cpp ）。
6. 值得注意：项目里其实已经知道这类问题，`PipelineStaging` 里有一段专门注释和 workaround（ PipelineStaging.cpp ），但它只处理 VECTOR`scope.scope` 内 残留的`scf.if` （给它们打`hivm.vec_only` ）。本 kernel 的这个 if 直接位于被保留的 VECTOR`scf.for` 体内、且该循环不是 CV-pipelined loop（`collectCVPipelinedLoops` 不会收），所以 workaround 覆盖不到。
## 性质判断
- 语义上这个 load 是死代码：AIC 的 if 两个分支只剩 anchor，循环结果也无人使用。但 PlanMemory 无法跳过「分配了却从未写」的 buffer，报错是合理的。
- 这不是 PlanMemory 过于严格，而是 SplitMixKernel 在做「按 op 核心类型过滤」时没有考虑 写者被删、读者（被判定为 CUBE_OR_VECTOR）被留 的数据流一致性。
## 可选修复方向
1. 在 split 后（`postProcessCubeFunc` ）做针对性清理：删除「tensor 来源是无写者的`alloc_tensor` /`alloc` 」的`tensor.extract` （其标量结果用 0 stub 替代），让残留骨架不再持有该 alloc。
2. 扩展`markVectorScopeIfs` 的适用范围：对 AIC 中保留下来的 VECTOR`scf.for` /骨架 if 也打`hivm.vec_only` （或在 SplitMixKernel 保留骨架时同步标记），由后续流程清掉

出错IR片段
`%buf = bufferization.alloc_tensor() : tensor<f32>            // 未初始化的 tensor buffer
%f   = hivm.hir.vbrc {VECTOR} ins(-inf) outs(%buf) : tensor<f32>   // 写者①：把 -inf 填进 %buf
%e   = tensor.expand_shape %f [] output_shape [1] : tensor<f32> into tensor<1xf32>  // 纯形状变换
%r   = hivm.hir.vreduce <max> {VECTOR} ins(%v) outs(%e) : tensor<1xf32>             // 写者②：把 max 写进同一块 buffer
%c   = tensor.collapse_shape %r [] : tensor<1xf32> into tensor<f32>   // 纯形状变换
%x   = tensor.extract %c[] : tensor<f32>                    // 读者：读这块 buffer 的第 0 个元素
%p   = arith.cmpf ogt, %x, 0
%y   = scf.if %p -> (tensor<16x16xf32>) { ... }              // AIC 侧分支内容已被删空，只剩 anchor`

经过split，
在 AIC 上过滤 VECTOR（`filterMixFunc` 的后序 walk）：

Step 1：删`vbrc` （它带`hivm.tcore_type = VECTOR` ）

- `annotateOpOperand` 先处理它的 init；
- `getOutOperands(vbrc)` →`getDpsInits()` →`%buf` ；
- `%f` 的所有使用者（只有`expand_shape` ）被替换为`%buf` ；
- `vbrc` 被 erase。
此时：

%buf = bufferization.alloc_tensor() : tensor<f32>
%e   = tensor.expand_shape %buf [] output_shape [1] : tensor<f32> into tensor<1xf32>
%r   = hivm.hir.vreduce <max> {VECTOR} ins(%v) outs(%e)
%c   = tensor.collapse_shape %r []
%x   = tensor.extract %c[]

Step 2：删`vreduce`

- `getOutOperands(vreduce)` →`%e` ；
- `%r` 的使用者（`collapse_shape` ）被替换为`%e` ；
- `vreduce` 被 erase。

%buf = bufferization.alloc_tensor() : tensor<f32>
%e   = tensor.expand_shape %buf [] output_shape [1] : tensor<f32> into tensor<1xf32>
%c   = tensor.collapse_shape %e [] : tensor<1xf32> into tensor<f32>
%x   = tensor.extract %c[]

Step 3：形状 op 被折叠

`collapse_shape(expand_shape(%buf)) → %buf` ，`%e` 、`%c` 消失：

%buf = bufferization.alloc_tensor() : tensor<f32>
%x   = tensor.extract %buf[]
变成了只读不写，最后lowering到planmemory报错

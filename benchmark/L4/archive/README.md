# Issue 与修复索引

issue 正文取自 GitCode 公开页面。时间为报告自身更新时间。附件中的日志保留报告者运行环境。MR 头与报告中的修复 SHA 可能不同，分别记录。

| Issue | 本地材料 | 关联 MR 和提交 |
|---|---|---|
| [#316 [Feature]: 【Multibuffer】CV场景Vector侧开启multibuffer](https://gitcode.com/Ascend/AscendNPU-IR/issues/316) | [正文](issues/316/report.md) · [内嵌 MLIR](issues/316/quoted) |  |
| [#579 [Feature]: 【Q4】为 LIB_EVENT_ID 与 GraphSyncSolver/InjectSync 的 id 分配增加一致性防护](https://gitcode.com/Ascend/AscendNPU-IR/issues/579) | [正文](issues/579/report.md) |  |
| [#708 [Bug]: SIMD-SIMT混编SIMT VF的同步问题](https://gitcode.com/Ascend/AscendNPU-IR/issues/708) | [正文](issues/708/report.md) |  |
| [#852 [Bug]: MultiBuffer 流水场景下 CrossCoreGSS 跨核事件复用可能导致计数溢出及 AICore 间歇性超时](https://gitcode.com/Ascend/AscendNPU-IR/issues/852) | [正文](issues/852/report.md) · [内嵌 MLIR](issues/852/quoted) |  |
| [#920 [Bug]: hivm-cv-pipelining skew 流水错误处理 CV 反馈边 loop，结果整体滞后一个迭代](https://gitcode.com/Ascend/AscendNPU-IR/issues/920) | [正文](issues/920/report.md) | [!5025](repairs/issue-920-mr-5025/repair.json) |
| [#981 [MemRef] FoldRedundantCopy 在 copy 目标为共享 allocation 的 subview 时丢弃中间更新](https://gitcode.com/Ascend/AscendNPU-IR/issues/981) | [正文](issues/981/report.md) · [内嵌 MLIR](issues/981/quoted) |  |
| [#982 [A5] GM→UB DMA 左右 padding 能力缺失](https://gitcode.com/Ascend/AscendNPU-IR/issues/982) | [正文](issues/982/report.md) |  |
| [#983 [Bug]: [HIVMAVE][AnalyzeVectorLayout] Parallel causes occasional card death/crash](https://gitcode.com/Ascend/AscendNPU-IR/issues/983) | [正文](issues/983/report.md) |  |
| [#985 [Feature]: A6 NDDMA transpose 扩展](https://gitcode.com/Ascend/AscendNPU-IR/issues/985) | [正文](issues/985/report.md) |  |
| [#986 [NDDMA] NddmaDesc硬编码上限需代际隔离](https://gitcode.com/Ascend/AscendNPU-IR/issues/986) | [正文](issues/986/report.md) |  |
| [#987 [RFC]: ](https://gitcode.com/Ascend/AscendNPU-IR/issues/987) | [正文](issues/987/report.md) · [内嵌 MLIR](issues/987/quoted) · [三件套](../../L3/issue-input/987/case.json) | [!4912](repairs/issue-987-mr-4912/repair.json) |
| [#988 [RFC]: Ascend960 MMAD（mmadL1）异构 A/B 数据类型与 packed s4 支持](https://gitcode.com/Ascend/AscendNPU-IR/issues/988) | [正文](issues/988/report.md) · [内嵌 MLIR](issues/988/quoted) | [!4962](repairs/issue-988-mr-4962/repair.json) |
| [#989 Infer predicate width for `pge <H>` before dual B8 gather lowering](https://gitcode.com/Ascend/AscendNPU-IR/issues/989) | [正文](issues/989/report.md) |  |
| [#990 [Feature]: A6 NDDMA broadcast 扩展](https://gitcode.com/Ascend/AscendNPU-IR/issues/990) | [正文](issues/990/report.md) |  |
| [#991 [Bug]: Incorrect merging behavior in MergeCVScopes phase](https://gitcode.com/Ascend/AscendNPU-IR/issues/991) | [正文](issues/991/report.md) |  |
| [#992 [Performance]: 当vector阻塞scalar时，会导致scalar无法发射后续指令，导致所有流水被vector阻塞](https://gitcode.com/Ascend/AscendNPU-IR/issues/992) | [正文](issues/992/report.md) |  |
| [#994 [HIVM] chained scf.while MMAD accumulation is prematurely materialized by fixpipe](https://gitcode.com/Ascend/AscendNPU-IR/issues/994) | [正文](issues/994/report.md) · [内嵌 MLIR](issues/994/quoted) · [三件套](../../L3/issue-input/994/case.json) | [!5161](repairs/issue-994-mr-5161/repair.json) |
| [#995 [canonicalize-ext] FoldRedundantCopy 误删写入真实数据的 memref.copy，SIMD kernel 首个 64 lane 结果变成 0](https://gitcode.com/Ascend/AscendNPU-IR/issues/995) | [正文](issues/995/report.md) · [内嵌 MLIR](issues/995/quoted) |  |
| [#996 [Bug]: [HIVM] Rank-4 device printing aborts when sharing a load with batch matmul](https://gitcode.com/Ascend/AscendNPU-IR/issues/996) | [正文](issues/996/report.md) · [内嵌 MLIR](issues/996/quoted) | [!4950](repairs/issue-996-mr-4950/repair.json) |
| [#997 [Bug]: Scalar FP8 (f8E4M3FN / f8E5M2) conversions fail to compile](https://gitcode.com/Ascend/AscendNPU-IR/issues/997) | [正文](issues/997/report.md) · [内嵌 MLIR](issues/997/quoted) |  |
| [#1000 [Bug]: CustomOps for __builtin_indirect_atomic do not follow Destination-Passing Style](https://gitcode.com/Ascend/AscendNPU-IR/issues/1000) | [正文](issues/1000/report.md) · [内嵌 MLIR](issues/1000/quoted) |  |
| [#1001 SIMT function call from SIMD code (sin)](https://gitcode.com/Ascend/AscendNPU-IR/issues/1001) | [正文](issues/1001/report.md) |  |
| [#1003 ub mte2 merge](https://gitcode.com/Ascend/AscendNPU-IR/issues/1003) | [正文](issues/1003/report.md) |  |
| [#1004 [HFusion][AutoVectorizeV2] RA 形态 addf-reduce 的物化树路线与 single-trip 兄弟融合修复](https://gitcode.com/Ascend/AscendNPU-IR/issues/1004) | [正文](issues/1004/report.md) |  |
| [#1005 [Performance] AutoVectorizeV2 开启多消费者融合后，在 attention 算子上重复清理和验证 IR](https://gitcode.com/Ascend/AscendNPU-IR/issues/1005) | [正文](issues/1005/report.md) |  |
| [#1006 div 用例对照结论：标杆按 f32 真除法、Triton 按 dtype 语义，tl.store 隐式截断放大差异](https://gitcode.com/Ascend/AscendNPU-IR/issues/1006) | [正文](issues/1006/report.md) |  |
| [#1007 [HIVMAVE] Aligned load marked unaligned after memref.expand_shape](https://gitcode.com/Ascend/AscendNPU-IR/issues/1007) | [正文](issues/1007/report.md) · [内嵌 MLIR](issues/1007/quoted) |  |
| [#1008 [Feature]: 在 A2 和 A3 上默认启用 Cube 布局优化 / Enable Cube layout optimization by default on A2 and A3](https://gitcode.com/Ascend/AscendNPU-IR/issues/1008) | [正文](issues/1008/report.md) · [三件套](../../L3/issue-input/1008/case.json) | [!5285](repairs/issue-1008-mr-5285/repair.json) |
| [#1009 [Bug]: A5 SIMT debug metadata loses source files and variable locations](https://gitcode.com/Ascend/AscendNPU-IR/issues/1009) | [正文](issues/1009/report.md) |  |
| [#1010 [HIVM][SplitMixKernel]: 'memref.alloc' op error: read before first write](https://gitcode.com/Ascend/AscendNPU-IR/issues/1010) | [正文](issues/1010/report.md) |  |
| [#1011 A5 3D tl.dot（batched matmul）：A 由向量核产生时结果错误，缺 UB→L1 的 NZ 布局转换](https://gitcode.com/Ascend/AscendNPU-IR/issues/1011) | [正文](issues/1011/report.md) · [内嵌 MLIR](issues/1011/quoted) |  |
| [#1012 [Bug] HIVM v2 pipeline ignores compiler auto-sync options](https://gitcode.com/Ascend/AscendNPU-IR/issues/1012) | [正文](issues/1012/report.md) · [三件套](../../L3/issue-input/1012/case.json) | [!5074](repairs/issue-1012-mr-5074/repair.json) |
| [#1013 [Bug] HIVM v2 cross-core GSS asserts on scalar GM loads with ambiguous core types](https://gitcode.com/Ascend/AscendNPU-IR/issues/1013) | [正文](issues/1013/report.md) |  |
| [#1014 [A5][性能] 非对齐 pointwise cat 的第二路 load 退化为逐元素搬运](https://gitcode.com/Ascend/AscendNPU-IR/issues/1014) | [正文](issues/1014/report.md) · [内嵌 MLIR](issues/1014/quoted) |  |
| [#1015 [Feature]: Automatic GET_BUF/RLS_BUF intra-core synchronization](https://gitcode.com/Ascend/AscendNPU-IR/issues/1015) | [正文](issues/1015/report.md) |  |
| [#1016 [Bug][A6] Oversubscribed Triton grids skip logical programs after the first wave](https://gitcode.com/Ascend/AscendNPU-IR/issues/1016) | [正文](issues/1016/report.md) · [证据包](issues/1016/evidence.zip) · [报告修复](issues/1016/reported-fix/source.json) | [!5330](repairs/issue-1016-mr-5330/repair.json) |
| [#1017 [Bug][A6] Unscaled FP8 grouped GEMM selects the microscaled matrix instruction](https://gitcode.com/Ascend/AscendNPU-IR/issues/1017) | [正文](issues/1017/report.md) · [证据包](issues/1017/evidence.zip) · [报告修复](issues/1017/reported-fix/source.json) | [!5331](repairs/issue-1017-mr-5331/repair.json) |
| [#1018 [Bug][A6] Reverse vector cumsum exhausts memory during CANN device compilation](https://gitcode.com/Ascend/AscendNPU-IR/issues/1018) | [正文](issues/1018/report.md) · [证据包](issues/1018/evidence.zip) · [报告修复](issues/1018/reported-fix/source.json) | [!5332](repairs/issue-1018-mr-5332/repair.json) |
| [#1019 [Bug][A6] A6 rejection sampling fails to compile i64 select and integer interleave](https://gitcode.com/Ascend/AscendNPU-IR/issues/1019) | [正文](issues/1019/report.md) · [证据包](issues/1019/evidence.zip) · [报告修复](issues/1019/reported-fix/source.json) | [!5333](repairs/issue-1019-mr-5333/repair.json) |
| [#1020 [Bug][A6] CreatePreload aborts on affine tile sizes and can reuse a live buffer slot](https://gitcode.com/Ascend/AscendNPU-IR/issues/1020) | [正文](issues/1020/report.md) · [证据包](issues/1020/evidence.zip) · [报告修复](issues/1020/reported-fix/source.json) | [!5334](repairs/issue-1020-mr-5334/repair.json) |
| [#1021 [Bug][A6] A6 vector stores can overrun short predicate rows or corrupt transposed output](https://gitcode.com/Ascend/AscendNPU-IR/issues/1021) | [正文](issues/1021/report.md) · [证据包](issues/1021/evidence.zip) · [报告修复](issues/1021/reported-fix/source.json) · [三件套](../../L3/issue-input/1021/case.json) | [!5335](repairs/issue-1021-mr-5335/repair.json) |
| [#1022 [Bug][A6] Local PlanMemory overwrites a live loop-carried UB value](https://gitcode.com/Ascend/AscendNPU-IR/issues/1022) | [正文](issues/1022/report.md) · [证据包](issues/1022/evidence.zip) · [报告修复](issues/1022/reported-fix/source.json) · [三件套](../../L3/issue-input/1022/case.json) | [!5336](repairs/issue-1022-mr-5336/repair.json) |
| [#1023 [Bug][A6] MIX kernels initialize a private vector input on both cores](https://gitcode.com/Ascend/AscendNPU-IR/issues/1023) | [正文](issues/1023/report.md) · [证据包](issues/1023/evidence.zip) · [报告修复](issues/1023/reported-fix/source.json) | [!5337](repairs/issue-1023-mr-5337/repair.json) |
| [#1024 [Bug]: rank-1 静态带步长 `vector.transfer_write` 被 `ConvertVectorToHIVMAVE` 静默降为连续写，丢失 lane 间步长](https://gitcode.com/Ascend/AscendNPU-IR/issues/1024) | [正文](issues/1024/report.md) · [内嵌 MLIR](issues/1024/quoted) | [!5314](repairs/issue-1024-mr-5314/repair.json) |
| [#1025 [Bug]: HFusion folds away FP8 quantization in FP32 → FP8 → FP32 cast chains](https://gitcode.com/Ascend/AscendNPU-IR/issues/1025) | [正文](issues/1025/report.md) · [内嵌 MLIR](issues/1025/quoted) · [三件套](../../L3/issue-input/1025/case.json) | [!4137](repairs/issue-1025-mr-4137/repair.json) · [!5175](repairs/issue-1025-mr-5175/repair.json) |
| [#1026 [Bug][HIVM] Invalid Fractal reshape for sliced matmul inputs (GEN-1749)](https://gitcode.com/Ascend/AscendNPU-IR/issues/1026) | [正文](issues/1026/report.md) · [内嵌 MLIR](issues/1026/quoted) · [三件套](../../L3/issue-input/1026/case.json) | [!5303](repairs/issue-1026-mr-5303/repair.json) |
| [#1027 [HIVM] A5 fixpipe insertion breaks L0C-bound conditional matmul results (DTS2026111745590)](https://gitcode.com/Ascend/AscendNPU-IR/issues/1027) | [正文](issues/1027/report.md) · [三件套](../../L3/issue-input/1027/case.json) | [!5305](repairs/issue-1027-mr-5305/repair.json) |
| [#1028 [Feature]: End-to-End HiFloat8 Support in Triton Ascend](https://gitcode.com/Ascend/AscendNPU-IR/issues/1028) | [正文](issues/1028/report.md) |  |
| [#1029 flatten while signatures](https://gitcode.com/Ascend/AscendNPU-IR/issues/1029) | [正文](issues/1029/report.md) · [内嵌 MLIR](issues/1029/quoted) |  |
| [#1030 [HIVM][Atomic] A3 仍用有序锁，带结果的 atomic_cas 在 insert-load-store 崩溃](https://gitcode.com/Ascend/AscendNPU-IR/issues/1030) | [正文](issues/1030/report.md) · [内嵌 MLIR](issues/1030/quoted) |  |
| [#1031 [Bug]: HFusion flattener generates invalid IR for rank-reducing slices](https://gitcode.com/Ascend/AscendNPU-IR/issues/1031) | [正文](issues/1031/report.md) |  |
| [#1032 [Performance]: Optimize two-stage SIMT sampling on Ascend 950](https://gitcode.com/Ascend/AscendNPU-IR/issues/1032) | [正文](issues/1032/report.md) |  |
| [#1033 [Performance]: [A5]parallel_path_fwd使用PipelineV2场景软流水优化](https://gitcode.com/Ascend/AscendNPU-IR/issues/1033) | [正文](issues/1033/report.md) |  |
| [#1034 [Bug]: A5 memory planning fails when Fixpipe and scf.if share a matmul accumulator](https://gitcode.com/Ascend/AscendNPU-IR/issues/1034) | [正文](issues/1034/report.md) · [三件套](../../L3/issue-input/1034/case.json) | [!5289](repairs/issue-1034-mr-5289/repair.json) |
| [#1036 [Bufferization] normalize-to-tensor 支持 arith.select 别名追踪并增强写识别](https://gitcode.com/Ascend/AscendNPU-IR/issues/1036) | [正文](issues/1036/report.md) · [内嵌 MLIR](issues/1036/quoted) |  |
| [#1037 [HIVM][DecomposeAllocTensorCopy] AIC 上 alloc_tensor(copy %vbrc) 应重算广播而非全量拷贝](https://gitcode.com/Ascend/AscendNPU-IR/issues/1037) | [正文](issues/1037/report.md) |  |
| [#1038 [Feature]: enable A5 BF16 vmula vmadd vsqz](https://gitcode.com/Ascend/AscendNPU-IR/issues/1038) | [正文](issues/1038/report.md) |  |
| [#1043 [Bug]: pairing 失败时仍执行 mask 下沉和 vbrc 前移，存在未知性能回退风险](https://gitcode.com/Ascend/AscendNPU-IR/issues/1043) | [正文](issues/1043/report.md) |  |
| [#1044 [Bug]: stride_align 1d failed in triton-ascend suite in test_index_select.py test](https://gitcode.com/Ascend/AscendNPU-IR/issues/1044) | [正文](issues/1044/report.md) |  |
| [#1046 [Feature]: Simplify the L1-to-L0 copy API by inferring copy parameters from buffer views](https://gitcode.com/Ascend/AscendNPU-IR/issues/1046) | [正文](issues/1046/report.md) · [三件套](../../L3/issue-input/1046/case.json) | [!5251](repairs/issue-1046-mr-5251/repair.json) |
| [#1047 [Arange] 3D 标量回退路径缺少 PIPE_V/PIPE_S 同步](https://gitcode.com/Ascend/AscendNPU-IR/issues/1047) | [正文](issues/1047/report.md) | [!5282](repairs/issue-1047-mr-5282/repair.json) |
| [#1048 [Bug]: hfusion-flatten-ops crashes on slices of scf.while region arguments](https://gitcode.com/Ascend/AscendNPU-IR/issues/1048) | [正文](issues/1048/report.md) |  |
| [#1049 [Bug]: Missing single-subblock guard for distributed custom ops](https://gitcode.com/Ascend/AscendNPU-IR/issues/1049) | [正文](issues/1049/report.md) |  |
| [#1050 [Performance]: use NDDMA for short slice rows](https://gitcode.com/Ascend/AscendNPU-IR/issues/1050) | [正文](issues/1050/report.md) |  |
| [#1051 [Bug]: HFusion flattener unnecessarily preserves dimensions around rank-reducing slices](https://gitcode.com/Ascend/AscendNPU-IR/issues/1051) | [正文](issues/1051/report.md) |  |
| [#1052 Can FP32 reduce_sum on Ascend 910B4 match PyTorch eager more closely for row-weight gradients?](https://gitcode.com/Ascend/AscendNPU-IR/issues/1052) | [正文](issues/1052/report.md) |  |
| [#1053 [Feature] Teach hfusion-flatten-ops to collapse arith.select on tensors](https://gitcode.com/Ascend/AscendNPU-IR/issues/1053) | [正文](issues/1053/report.md) |  |
| [#1055 [Performance]: Rotate multibuffer slot with actual execution, not the loop itself](https://gitcode.com/Ascend/AscendNPU-IR/issues/1055) | [正文](issues/1055/report.md) |  |
| [#1056 [Bug]: PropgateReshape stride 计算错误](https://gitcode.com/Ascend/AscendNPU-IR/issues/1056) | [正文](issues/1056/report.md) · [内嵌 MLIR](issues/1056/quoted) |  |
| [#1058 [Bug]: Gen-0501 hangs](https://gitcode.com/Ascend/AscendNPU-IR/issues/1058) | [正文](issues/1058/report.md) |  |
| [#1059 [Feature]: Avoid redundant computations after broadcast](https://gitcode.com/Ascend/AscendNPU-IR/issues/1059) | [正文](issues/1059/report.md) · [内嵌 MLIR](issues/1059/quoted) |  |
| [#1060 [Feature]: Use grouped reduction instructions for independent reductions](https://gitcode.com/Ascend/AscendNPU-IR/issues/1060) | [正文](issues/1060/report.md) · [内嵌 MLIR](issues/1060/quoted) |  |

## 修复历史

这里也列出从 Git 合并历史发现的修复。测试数指该比较范围内新增或修改的已收录测试文件。打开元数据可以查父版本、提交和路径。

| MR | 提交 | 测试文件 | 改动 |
|---|---|---:|---|
| [!5285](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5285) | [[HIVM] feat: Enable Cube layout optimization on A2 and A3](repairs/issue-1008-mr-5285/repair.json) | 10 | [patch](repairs/issue-1008-mr-5285/change.patch) |
| [!5074](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5074) | [[HIVM][Pipelines] fix: Honor v2 auto-sync options](repairs/issue-1012-mr-5074/repair.json) | 2 | [patch](repairs/issue-1012-mr-5074/change.patch) |
| [!5330](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5330) | [[HIVM][V2] fix: run the A6 blockify test with the process backend](repairs/issue-1016-mr-5330/repair.json) | 1 | [patch](repairs/issue-1016-mr-5330/change.patch) |
| [!5331](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5331) | [[Template][Cube] fix: remove MX dispatch from A6 MmadCal](repairs/issue-1017-mr-5331/repair.json) | 0 | [patch](repairs/issue-1017-mr-5331/change.patch) |
| [!5332](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5332) | [[Template][Cumsum] fix: use positive reverse scan strides](repairs/issue-1018-mr-5332/repair.json) | 0 | [patch](repairs/issue-1018-mr-5332/change.patch) |
| [!5333](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5333) | [[HIVM][V2] fix: lower A6 integer selects and shuffle intrinsics](repairs/issue-1019-mr-5333/repair.json) | 2 | [patch](repairs/issue-1019-mr-5333/change.patch) |
| [!5334](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5334) | [[HIVM][Preload] fix: preserve affine extents and rotate A6 preload slots](repairs/issue-1020-mr-5334/repair.json) | 2 | [patch](repairs/issue-1020-mr-5334/change.patch) |
| [!5335](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5335) | [[HIVM][Vectorize] fix: preserve AVE vector store bounds and strides](repairs/issue-1021-mr-5335/repair.json) | 5 | [patch](repairs/issue-1021-mr-5335/change.patch) |
| [!5336](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5336) | [[HIVM][PipelineV2] fix: fold tensor transfers before bufferization](repairs/issue-1022-mr-5336/repair.json) | 2 | [patch](repairs/issue-1022-mr-5336/change.patch) |
| [!5337](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5337) | [[HIVM][Vectorize] fix: initialize private scalar inputs on the AIV](repairs/issue-1023-mr-5337/repair.json) | 1 | [patch](repairs/issue-1023-mr-5337/change.patch) |
| [!5314](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5314) | [[Vector] fix: preserve lane-zero mask proofs through shape-only UCCs](repairs/issue-1024-mr-5314/repair.json) | 4 | [patch](repairs/issue-1024-mr-5314/change.patch) |
| [!4137](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/4137) | [[AscendNPU IR][HFusion][SimplifyOps] fix: support all FP types in hfusion-simplify-ops](repairs/issue-1025-mr-4137/repair.json) | 1 | [patch](repairs/issue-1025-mr-4137/change.patch) |
| [!5175](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5175) | [[HFusion][SimplifyOps] fix: rank fp8 types so f32->fp8->f32 is not folded](repairs/issue-1025-mr-5175/repair.json) | 1 | [patch](repairs/issue-1025-mr-5175/change.patch) |
| [!5303](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5303) | [[HFusion][HIVM] fix: Lower counted loops with sliced matmul inputs](repairs/issue-1026-mr-5303/repair.json) | 3 | [patch](repairs/issue-1026-mr-5303/change.patch) |
| [!5305](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5305) | [[HIVM] fix: preserve L0C-bound conditional accumulators](repairs/issue-1027-mr-5305/repair.json) | 2 | [patch](repairs/issue-1027-mr-5305/change.patch) |
| [!5289](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5289) | [[HIVM][ConvertLayout] fix: propagate shared scf.if yields](repairs/issue-1034-mr-5289/repair.json) | 1 | [patch](repairs/issue-1034-mr-5289/change.patch) |
| [!5251](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5251) | [[HIVM] feat: simplify L1-to-L0 copy](repairs/issue-1046-mr-5251/repair.json) | 2 | [patch](repairs/issue-1046-mr-5251/change.patch) |
| [!5282](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5282) | [[Template][Arange] fix: synchronize 3D scalar stores](repairs/issue-1047-mr-5282/repair.json) | 0 | [patch](repairs/issue-1047-mr-5282/change.patch) |
| [!5025](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5025) | [[HIVM][CVPipelining] fix: keep feedback loops out of skew pipelining](repairs/issue-920-mr-5025/repair.json) | 1 | [patch](repairs/issue-920-mr-5025/change.patch) |
| [!4912](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/4912) | [[HIVM] feat: extend MMAD_MX for Ascend960 hif4 and mmadConfig support](repairs/issue-987-mr-4912/repair.json) | 1 | [patch](repairs/issue-987-mr-4912/change.patch) |
| [!4962](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/4962) | [[HIVM][mmadL1] refactor: derive s4 addressing from B type](repairs/issue-988-mr-4962/repair.json) | 3 | [patch](repairs/issue-988-mr-4962/change.patch) |
| [!5161](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5161) | [[HIVM] fix: preserve L0C across while accumulation loops](repairs/issue-994-mr-5161/repair.json) | 1 | [patch](repairs/issue-994-mr-5161/change.patch) |
| [!4950](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/4950) | [[Tensor][Reshape] fix: share Vector print snapshots](repairs/issue-996-mr-4950/repair.json) | 3 | [patch](repairs/issue-996-mr-4950/change.patch) |
| [!2994](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/2994) | [[HIVM] Normalize for-carried matmul with side users](repairs/mr-2994/repair.json) | 1 | [patch](repairs/mr-2994/change.patch) |
| [!3007](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3007) | [[AscendNPU IR][CV][InsertFixpipe] feat: not to replace l0c use](repairs/mr-3007/repair.json) | 7 | [patch](repairs/mr-3007/change.patch) |
| [!3168](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3168) | [[HIVM] fix: guard fixpipe loop hoist on yield type](repairs/mr-3168/repair.json) | 1 | [patch](repairs/mr-3168/change.patch) |
| [!3261](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3261) | [[HIVM] Fix MIX deadlock on empty preload loops](repairs/mr-3261/repair.json) | 2 | [patch](repairs/mr-3261/change.patch) |
| [!3406](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3406) | [[HIVM][Subtiling] fix: preserve common tiling axis](repairs/mr-3406/repair.json) | 1 | [patch](repairs/mr-3406/change.patch) |
| [!3472](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3472) | [[HIVM][GraphSyncSolver] fix: trace zero-trip aliases](repairs/mr-3472/repair.json) | 1 | [patch](repairs/mr-3472/change.patch) |
| [!3491](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3491) | [[HFusion] fix: wrap atomic return snapshots in sync-block lock](repairs/mr-3491/repair.json) | 15 | [patch](repairs/mr-3491/change.patch) |
| [!3495](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3495) | [fix(core_ratio): disable tight buffers for CV11 on Ascend950](repairs/mr-3495/repair.json) | 3 | [patch](repairs/mr-3495/change.patch) |
| [!3508](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3508) | [[AscendNPU-IR] fix: correct CV-pipelining set/wait parent lookup](repairs/mr-3508/repair.json) | 3 | [patch](repairs/mr-3508/change.patch) |
| [!3512](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3512) | [[Huawei][AscendNPU-IR][GraphSyncSolver] fix: treat builtin indirect atomic GM address arg as read-write parameter](repairs/mr-3512/repair.json) | 1 | [patch](repairs/mr-3512/change.patch) |
| [!3520](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3520) | [[HIVM] fix: preserve memref traceback scope inference](repairs/mr-3520/repair.json) | 2 | [patch](repairs/mr-3520/change.patch) |
| [!3545](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3545) | [[AscendNPU IR][CV][InsertFixpipe] fix: enhance tracing](repairs/mr-3545/repair.json) | 1 | [patch](repairs/mr-3545/change.patch) |
| [!3547](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3547) | [[AscendNPU IR][CV][InsertFixpipe] fix: nz2nz shape](repairs/mr-3547/repair.json) | 1 | [patch](repairs/mr-3547/change.patch) |
| [!3626](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3626) | [[HIVM][PlanMemory] fix: skip alloc size align for high-rank VCast](repairs/mr-3626/repair.json) | 2 | [patch](repairs/mr-3626/change.patch) |
| [!3653](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3653) | [[HIVM][ConvertLayout] fix: clone multi-use conversion](repairs/mr-3653/repair.json) | 1 | [patch](repairs/mr-3653/change.patch) |
| [!3684](https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/3684) | [[AscendNPU IR]: keep mix-split TCB yields and clone after preload](repairs/mr-3684/repair.json) | 2 | [patch](repairs/mr-3684/change.patch) |

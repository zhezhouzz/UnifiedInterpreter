## 问题现象

Ascend950 混合 CUBE/VECTOR 编译中，第一段 scf.while 的 MMAD 累加结果已标记留在 L0C，并作为第二段 scf.while 中 MMAD 的 outs 初值。InsertFixpipe 仍可能在两段循环之间插入 fixpipe，将累加值提前物化到 UB。

在 flex_attention_backward_dq_kernel 的复现中，这会导致后续缓冲区复用把最终 dual-destination fixpipe 的源绑定到 UB，出现以下诊断：

```text
'hivm.hir.fixpipe' op if dual_dst_mode is enabled, the data movement must be performed from L0C to UB!
```

## 触发场景（伪 IR）

```mlir
%w1 = scf.while (..., %acc = %init) ... do {
  %merged = scf.if %do_mmad {
    %next = hivm.hir.mmadL1 ins(...) outs(%acc)
    scf.yield %next
  } else {
    scf.yield %acc
  }
  scf.yield ..., %merged, ...
} attributes {normalized_in_L0C = [1]}

// 异常插入的中间搬运
%ub = hivm.hir.fixpipe ins(%w1#1) outs(...)
%w2 = scf.while (..., %acc = %ub) ... do {
  %next = hivm.hir.mmadL1 ins(...) outs(%acc)
  scf.yield ..., %next, ...
}
hivm.hir.fixpipe ins(%w2#1) outs(%output)
    dual_dst_mode = <ROW_SPLIT>
```

同类循环累加结构也可能嵌套在 scf.for 中。

## 预期行为

确认第一段循环的出口结果需留在 L0C，且经第二段 while 的 init、before/after 参数流入后续 MMAD outs 后，应直接将该 L0C 结果传给第二段循环，跳过两段循环之间的 fixpipe。最终需要搬出的结果仍应保留出口 fixpipe。

## 相关分析

循环累加识别需依据累加参数所属块选择 for/while。插入点选择与跳过检查需使用一致的出口追踪规则，支持内层 scf.if。while 的 init 到 before 参数，以及 yield 经 before 参数和 scf.condition 到结果的映射都需要正确处理。

相关修复 PR：https://gitcode.com/Ascend/AscendNPU-IR/pull/5161

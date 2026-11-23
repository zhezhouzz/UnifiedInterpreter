### 环境信息

```
- 操作系统: Ubuntu 24.04
- 昇腾硬件: Ascend950PR (A5)
- CANN: 9.2.0-beta.2 (Ascend950 目标)
- AscendNPU-IR: master 22359d197 (bishengir 2.0.0)
- 编译选项（Triton 后端下发）: --target=Ascend950 --enable-auto-multi-buffer=True
  --enable-auto-bind-sub-block=True --enable-auto-blockify-loop
  --enable-hfusion-compile=true（skew CV 流水默认开启）
```

### 🐛 问题描述

`hivm-cv-pipelining` 的 skew 模式会把「两个 work item 通过本地 staging buffer
双向交接」的 loop 错误流水化，导致 CUBE 的 fixpipe 结果整体滞后一个迭代，
kernel 静默返回上一轮数值：无编译告警、无运行时报错、数值断言失败但错误值稳定。

**触发形态（VEC -> CUBE -> VEC 反馈边）**

1. VECTOR 侧把数据写入本地 L1 buffer；
2. CUBE 侧读该 L1 buffer 做 mmad；
3. CUBE 的 fixpipe 结果写入本地 UB buffer；
4. VECTOR 侧读该 UB buffer 参与后续计算（`tensor.extract` 标量读）。

即 work item 之间形成 VECTOR->CUBE 与 CUBE->VECTOR 的双向 buffer 握手。

**根因**

skew 模式按 work item 顺序给每个 item 分配 preload
（`maxPreloadNum = worklist.size()`，`preloadNum = maxPreloadNum - 1`，
`itemPreloadNum = hasLoopCarriedDep ? 0 : preloadNum`），等价于把每个 item 整体
平移一个迭代，隐含假设跨 item 数据流单向。上述环上无论哪个 item 领跑，都会在
本迭代读到对方下一迭代才产出的 buffer，因此不存在合法的 stage 分配。

而 pass 现有的合法性检查只覆盖「用 GM 当中间 buffer」的跨 item 读写
（诊断信息 `[cv-pipelining] using GM as intermediate buffer is unsupported`），
对本地 staging buffer（L1/UB）上的双向依赖没有任何检查，于是该 loop 被静默流水化。

**期望行为**：skew 模式下检测到跨 work item 的本地 buffer 双向依赖环时，不做
skew 流水化，回退到常规跨核同步。

**实际行为**：错误流水化，数值为上一迭代结果或未初始化值。

**观测证据**

- 三个迭代的输出为 `0 / 528 / 560`，期望 `528 / 560 / 592`，即整体滞后一轮；
- 同一编译产物内错值完全一致（跨进程固定），换编译产物后是否复现取决于
  stage 分配结果；
- 关闭 `enable_dynamic_cv_pipeline`、把 `tl.dot` 移出循环、或改用
  `compile_mode="simt_only"` 均正常，指向 CV 流水阶段；
- 离线 IR 中 `hivm.cv_pipelined_loop` 的 scope 属性为
  `hivm.preload_num = 1 : i32`（VECTOR）/ `hivm.preload_num = 0 : i32`（CUBE），
  与「vector 领先一个迭代」一致；
- 按原始语义顺序执行（不做 skew）时数值全对。

**关联修复**：MR !5025
https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5025
（skew 模式下按本地 buffer 读写依赖构建 work item 依赖图，发现环则跳过该 loop 的
流水化，交由常规跨核 TCB 计数器同步处理；新增 lit 用例
`bishengir/test/Dialect/HIVM/cv-pipelining-buffer-feedback-cycle.mlir`）

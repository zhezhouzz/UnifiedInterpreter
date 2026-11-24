## 当前状态

`tla.load_gm_to_ub` 不提供显式 padding 能力。`LoadGM2UBParams` 仅保留
`eviction_policy`，Python/native binding 不接收或透传 padding 属性及操作数。
需要初始化无效 UB 元素时，使用独立操作。

后端仍有两类未解决的缺口：

- **显式右补未贯通 A5 legacy 链路**，不能指定超出固有对齐范围的右侧填充。
- **左补及其填充值处理不完整**，部分已接受组合会破坏有效数据、生成错误填充值
  或静默漏填。对齐连续的部分组合可用，不能概括为左补完全没有实现。

后端支持范围与正式验证明确后，再评审恢复 TLA 公开参数。
[当前 API](tla-programming-api.md#422-tlaload_gm_to_ub)。

## 与硬件固有补齐的边界

所选 A5 GM→UB DMA 的32B补齐属于正常硬件行为：Normal 模式每个 burst
分别补至32B对齐；Ascend 950 Compact 模式将连续 bursts 视为整体，仅在
整体末尾补至32B对齐。目的 UB 容量、别名复用及同步必须覆盖该物理写入范围。

固有补齐不属于本 issue 的后端缺陷，也不能代替显式左右 padding。
LP=RP=0 不保证逻辑窗口外不写；常量填充选择位控制补值来源，不能关闭补齐。
该规则适用于对应 DMA 路径，scalar fallback 等路径另按各自契约。
[AscendC 定义与最终汇编对应](artifacts/tla-load-e2e-20261117/assembly-audit-20261118/ascendc-alignment-contract.md)。

## 显式右补：参数未贯通

`HIVMToStandard.cpp::calculatePaddingNum` 仅在 span-padded load 路径将显式
right 传入 helper；A5 legacy helper 接口仅接 left，并按对齐派生尾部计数。
A6 span 路径不能证明 A5 legacy 支持显式 right。

最小需求是一维连续 FP32，固定 UB 容量256，搬入232个有效元素后右补24个零：

```text
UB[0:232]   = GM[0:232]
UB[232:256] = 0
```

有效搬入为928字节，已满足32B对齐；显式右补为额外96字节。仅执行固有对齐
补齐不能满足此需求。GM 读取范围应限制在232个有效元素内。

正式 HIVM→A5 链路尚未提供经真机验证的显式右补能力。单指令可表达的长度
须依据目标型号及 dtype 的硬件规格确定。

## 左补及填充值：已确认的设备缺陷

以下是尚未修复缺口的设备证据。offset、stride 和 left 均以元素计；prefix、
有效数据、尾部及 guard 位于同一合法 backing 内，以非零哨兵初始化并逐元素
零容差比较。表中尾部由 legacy 对齐派生，未请求非零显式 right。

| 缺口 | 最小已测配置 | 实际结果与证据 |
| --- | --- | --- |
| GM stride + left 破坏有效数据 | fp32，W13，GM stride2，UB stride1，dst offset40，left8，PadValue7 | 13个有效元素全错，3个尾元素漏填；8个前缀正确。[结果](artifacts/tla-load-e2e-20261117/results/pad_value_strided_gm/result.json)、[独立复测](artifacts/tla-load-e2e-20261117/followup/pad_value_strided_gm/result.json) |
| PadFirstElem 未使用源首元素 | fp32，W13，dst offset40，left8，源首元素-43 | 有效数据正确，8个前缀及3个尾元素均为0；2D同类配置有33处填充值错误。[1D](artifacts/tla-load-e2e-20261117/results/pad_first_1d/result.json)、[2D](artifacts/tla-load-e2e-20261117/results/pad_first_2d/result.json)、[独立复测](artifacts/tla-load-e2e-20261117/followup/pad_first_1d/result.json) |
| i64 非零 PadValue 丢失高32位 | i64，W13，dst offset36，left4 | 有效数据正确，4个前缀及3个尾元素错误；7变为 `0x0000000700000007`，`0x1122334455667788` 变为 `0x5566778855667788`；零值对照通过。[7](artifacts/tla-load-e2e-20261117/results/pad_value_i64/result.json)、[宽值](artifacts/tla-load-e2e-20261117/followup/pad_i64_wide/result.json)、[零值](artifacts/tla-load-e2e-20261117/followup/pad_i64_zero/result.json) |
| scalar fallback 不执行 padding | fp32 W13、dst offset36、left4；或shape3x13、GM strides32/2、UB row32、left8；或UB row29、left8 | 有效数据正确，prefix/tail保留哨兵，分别漏填11、33、33个元素。[非对齐](artifacts/tla-load-e2e-20261117/results/pad_value_small_left/result.json)、[GM stride](artifacts/tla-load-e2e-20261117/results/pad_value_2d_inner_stride/result.json)、[UB行pitch](artifacts/tla-load-e2e-20261117/results/pad_value_ub_unaligned_pitch/result.json) |
| 3D transpose 路由丢失配置 | fp32，shape2x3x13，GM strides3/1/8，UB shape2x5x32，dst offsets0/1/8，left8，PadValue7 | 有效数据正确，6行共66个padding元素保留哨兵。[结果](artifacts/tla-load-e2e-20261117/followup/pad_rank3_transpose/result.json) |

源码定位与设备结果对应如下：

- Copy1D 对 GM 非单位 stride 构造每元素一个 burst，仍携带 left。具体数据
  覆盖机制尚未通过指令 trace 证明，不能将 descriptor 推测当作硬件根因。
- FirstElem 模式未传入 legacy intrinsic；前置普通 load 后实际使用零填充值。
  非零 PadValue→FirstElem 的状态顺序尚未验证。
- b64 以 u32 intrinsic 搬运后依靠 `apply_padding_b64` 修复完整值，但修复
  guard 在 left>=4 时直接返回，与非零 left 的32B对齐入口条件不匹配。
- scalar helper 及 Copy3D transpose 使用的 NDDMA helper 不接收相应 padding
  配置，也没有等价补填逻辑。

left 非负、字段上界、bool/i1 及容量检查仍有静态缺口，未以危险输入执行设备
验证。FP8 非零填充值被覆盖为零只有独立后端 pass 证据，不列为已确认 TLA
设备缺陷。[后端分析](artifacts/tla-load-e2e-20261117/backend-analysis.md)。

## 实现要求

1. 贯通 HIVM load、A5 lowering/helper 的左右计数、模式及填充值，处理
   Copy1D/2D/3D 和 fallback。按实际目标、dtype、布局给出支持矩阵；未支持的
   组合不得被接受后静默忽略配置或破坏有效数据。
2. 明确计数以元素为单位、DMA 长度以字节为单位，明确 `dst.offset` 与有效
   数据起点、左前缀的关系。目标容量及依赖分析覆盖 prefix/data/显式 right、
   固有32B补齐和受影响孔洞，不能跨越 allocation 或相邻别名。
3. 明确静态与运行时计数的合法范围、字段位宽、对齐及容量要求，禁止静默截断。
   定义 PadNull、零计数、空有效块和多 burst/多维的行为。
4. FirstElem 使用本次搬运对应的源首元素；非零 PadValue 保留完整 dtype
   位模式，包括 b64 高32位。正确处理前序填充值状态及后继普通 load。
5. 显式右补候选首批为一维连续 FP32、left=0、常量零；静态232→256可独立
   验收。运行时有效前缀依赖[动态 subview 能力](tla-dynamic-subview-issue.md)，
   两项能力分别实现和验收。

## 重新开放前的验收标准

- [ ] 通过正式 TLA→HIVM→A5 路径完成静态232→256，不依赖 monkeypatch、
  文本 IR 改写或 helper 替换；目标支持时生成一次带显式右补的 DMA，无独立
  fill、不额外读取 GM padding 区。
- [ ] 覆盖表中左补缺陷，检查有效数据、FirstElem、i64 完整填充值及各路由
  的补填行为；其余组合在公开入口恢复前明确限制。
- [ ] 以非零哨兵读回完整 backing，分别检查 prefix/data/派生尾部/显式
  right/孔洞/guard；区分固有对齐补齐与显式 padding，不以有效输出正确代替
  填充正确。
- [ ] 验证静态和运行时 left/right/value、零计数及目标合法上界，明确非法值、
  容量不足和未支持组合的处理；覆盖非零 PadValue→FirstElem 及后继普通 load。
- [ ] 正确建模完整物理写入范围及后续消费者依赖，核对同步和相邻别名；普通
  load 保持符合对应指令的固有对齐契约。
- [ ] 在正式构建上完成目标编译、A5 模型和真机功能验证，注明型号、dtype、
  支持范围；动态 subview 就绪后，同一二进制覆盖不同有效尾长。
- [ ] API、IR 契约和支持矩阵与实际结果一致，再恢复公开参数及相应 UT。

## 复现材料

- [设备缺陷结果、工具链身份与运行入口](artifacts/tla-load-e2e-20261117/README.md)
- [设备探针](artifacts/tla-load-e2e-20261117/load_probe_v2.py)：依赖带 padding
  的实验接口；当前公开 API 不能直接运行该脚本。后端复现可使用配套保存的
  ttadapter、npubin 及输入/实际/参考输出。`device_run=pass` 仅表示运行及回读
  完成，精度结论以顶层 status 和 runs 为准。
- [后端源码及隔离 pass 证据](artifacts/tla-load-e2e-20261117/backend-analysis.md)
- [AscendC 对齐契约、最终汇编与设备快照对应](artifacts/tla-load-e2e-20261117/assembly-audit-20261118/ascendc-alignment-contract.md)

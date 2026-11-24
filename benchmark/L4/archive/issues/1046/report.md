# [Feature]: 简化 L1→L0 拷贝接口，支持从源、目标视图推导拷贝参数
### 💻 需求背景、当前现状、期望实现的功能内容、具体的设计方案、以及测试方案
            
## 需求背景与当前现状

在 A5 TLA 显式管理 L1/L0 buffer 的场景下，前端通过 src/dst 视图描述拷贝区域。现有 hivm.hir.l12l0 接口仍要求调用方提供 k_part_idx、`k_part`、`k_part_ceil`、`k_part_loop`、`k_part_actual` 和 m 等分块属性。

对于单矩阵、完整视图拷贝，这些属性可以从目标视图推导。要求前端重复计算会增加接口复杂度，也容易造成视图尺寸与分块属性不一致。

## 期望实现的功能

支持前端仅提供 src、dst 和可选的转置配置，即可完成一次 L1→L0A/L0B 拷贝，无需手动填写六个分块属性。

以 FP16、`M=48`、`K=32` 的 L1→L0A 完整矩阵拷贝为例，假设 src_l1 和 dst_l0a 已是合法的矩阵视图，物理 shape 均为 [2,3,16,16]。

瘦身前，调用方需要重复提供视图中已包含的尺寸信息：

    tla.copy_l1_to_l0(
        src_l1,
        dst_l0a,
        params=tla.CopyL1ToL0Params(
            is_transpose=False,
            k_part_idx=0,
            k_part=32,
            k_part_ceil=32,
            k_part_loop=1,
            k_part_actual=32,
            m=48,
        )
        
瘦身后，配套前端同步接口，通过视图推导拷贝参数：

    tla.copy_l1_to_l0(src_l1, dst_l0a)
CopyL1ToL0Params 仅保留 is_transpose 配置，默认为 False。需要分块拷贝时，通过 tla.subview 指定拷贝区域；后端保留原有显式分块接口，兼容已有调用方。

## 设计方案
- 为 L12L0Op 增加基于视图的便利 builder，根据 dst 地址空间区分 L0A/L0B，并从目标视图推导 M/N 和 K。
- 将完整视图拷贝映射为 k_part_idx=0、`k_part_loop=1`、`k_part=k_part_ceil=k_part_actual=K`，`m` 为 M 或 N。
- 支持四维分形物理视图，衔接布局推断、A5 lowering 和模板库调用，保留受支持视图的 offset、stride 及转置语义。
- 保留原有显式分块属性及模板调用 ABI，兼容已有调用方。
- 校验 A5 拷贝所需的类型、布局、对齐和存储范围约束，并支持独立拷贝场景下的 L0 内存规划。

## 测试方案
- Builder 单元测试：覆盖 L0A/L0B、逻辑与物理视图、转置、父视图 stride，以及原有显式分块接口。
- lit 测试：覆盖布局推断、转置与布局提示、子视图、lowering 和内存规划。
- 回归验证：运行相关 DMA、MMAD L0 和同步测试，并在 A5 开发环境验证拷贝及后续矩阵计算结果。
### 替代方案
            

### 补充说明
            
关联实现：[PR #5251](https://gitcode.com/Ascend/AscendNPU-IR/pull/5251)

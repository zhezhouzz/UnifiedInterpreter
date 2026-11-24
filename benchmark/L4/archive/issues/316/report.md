

**提交提案之前，请先检索仓库内是否已有相同的提案，如已有请在同一提案中进行讨论。**

### 💻 需求背景、当前现状、期望实现的功能内容、具体的设计方案、以及测试方案
            
# 1. 需求介绍

在 CV（Cube + Vector）场景中，Cube 侧负责矩阵计算，Vector 侧负责数据搬运、逐元素计算、规约和结果写回。

开启自动 Multibuffer 后，当前默认策略仅对 Cube 侧 buffer 生效，Vector 侧由 MTE2 搬入的本地 buffer 仍采用单 buffer。由于相邻迭代复用同一块本地内存，下一次 MTE2 搬入需要等待上一迭代完成对该 buffer 的使用，限制了 MTE2 与 Vector 计算的并行程度。

本特性在 CV 场景下默认同时开启 Cube 侧和 Vector 侧 Multibuffer。Vector 侧使用两组本地 buffer 轮转，使下一迭代的 MTE2 搬入可以与当前迭代的 Vector 计算并行，从而减少流水空闲，提高 MTE2 并发程度和整体执行性能。

# 2. 功能描述

当自动 Multibuffer 开启时，编译器对 CV 场景中符合条件的 Vector 侧 Load/Store 本地 buffer 自动应用双缓冲：

1. 识别循环内 Vector 侧使用的本地 buffer。
2. 为同一逻辑 buffer 规划两块独立的物理空间。
3. 按照循环迭代号在两个 buffer slot 之间轮转。
4. 为每个 slot 生成对应的同步关系，避免新一轮搬入覆盖仍在使用的数据。

概念上的执行过程如下：

```text
迭代 i:
  MTE2 将数据搬入 buffer[i % 2]
  Vector 使用 buffer[i % 2] 进行计算

迭代 i + 1:
  MTE2 将下一份数据搬入另一个 buffer
  与迭代 i 的 Vector 计算并行执行
```

该特性复用现有 Multibuffer、PlanMemory 和自动同步能力，不改变 CV-Pipelining、Workspace Multibuffer 或 Preload 的语义。

## 2.1 接口描述

自动 Multibuffer 总开关保持不变：

```text
--enable-auto-multi-buffer=true
```

CV 场景的 Multibuffer 范围由以下选项控制：

```text
--limit-auto-multi-buffer-buffer={only-cube|only-vector|no-limit}
```

本特性将该选项的默认值由：

```text
only-cube
```

调整为：

```text
no-limit
```

因此，开启自动 Multibuffer 后，CV 场景默认同时允许 Cube 侧和 Vector 侧应用 Multibuffer。用户仍可通过显式配置 `only-cube` 或 `only-vector` 限制生效范围。

### 2.1.1 接口兼容性变更

- 不新增编译选项。
- 未开启自动 Multibuffer 时，编译行为不变。
- 显式设置 `only-cube`、`only-vector` 或 `no-limit` 时，行为不变。
- 仅改变未显式配置范围时的默认行为：由 Cube 侧 Multibuffer 调整为 Cube、Vector 两侧 Multibuffer。
- 不改变算子接口和运行时接口。

## 2.2 输入示例

以下示例表示 CV 循环中 Vector 侧使用 MTE2 将 GM 数据搬入 UB，并执行 Vector 计算：

```mlir
scf.for %iv = %lb to %ub step %step {
  %local = memref.alloc()
      : memref<1024xf16, #hivm.address_space<ub>>

  hivm.hir.load
      ins(%input : memref<1024xf16, #hivm.address_space<gm>>)
      outs(%local : memref<1024xf16, #hivm.address_space<ub>>)

  %result = hivm.hir.vexp
      ins(%local : memref<1024xf16, #hivm.address_space<ub>>)
      outs(%output : memref<1024xf16, #hivm.address_space<ub>>)
}
```

单 buffer 下，下一迭代的 MTE2 Load 需要等待当前迭代完成对 `%local` 的使用。

## 2.3 输出示例

应用 Vector 侧 Multibuffer 后，PlanMemory 为本地 buffer 分配两个物理 slot：

```mlir
%local = hivm.hir.pointer_cast(%addr0, %addr1)
    : memref<1024xf16, #hivm.address_space<ub>>
```

循环执行时，根据当前迭代选择对应 slot，并通过同步关系保护该 slot：

```text
for i:
  slot = i % 2
  wait until buffer[slot] is available
  MTE2 load input[i] -> buffer[slot]
  Vector compute buffer[slot]
  signal buffer[slot] is available for reuse
```

在稳定流水阶段，可以形成以下重叠：

```text
MTE2:    load(i)      load(i+1)    load(i+2)
Vector:        compute(i)    compute(i+1)    compute(i+2)
Buffer:  slot 0       slot 1       slot 0
```

# 3. 特性限制（支持范围）

1. 仅在开启自动 Multibuffer 时生效。
2. 适用于 CV 场景中 Vector 侧循环内的本地 Load/Store buffer。
3. 本地 Vector buffer 默认采用双缓冲。
4. Buffer 必须能够在编译期确定内存空间和规划大小。
5. 支持现有 Multibuffer 流程可识别的 `scf.for` 和 `scf.while` 循环。
6. 不适用于 GM buffer；本特性主要针对 UB 等片上本地内存。
7. 不改变 CV Workspace Multibuffer、Preload 和 Cube/Vector 跨核同步的既有语义。
8. 双缓冲会增加片上内存占用。当 UB 空间不足时，可能无法应用该优化。
9. 性能收益与循环长度、数据搬运量和 MTE2 是否处于性能瓶颈相关。
10. 对于标量的读取不支持multibuffer。

# 4. 性能需求

本特性的目标是提高 CV 场景中 MTE2 与 Vector 计算的并行程度：

- 减少因复用单一 UB buffer 导致的跨迭代等待。
- 允许下一迭代的 MTE2 Load 与当前迭代的 Vector 计算重叠。
- 降低流水空闲，提高 MTE2 利用率。
- 在 MTE2 搬运耗时较高、循环迭代数较多的场景中获得性能收益。

该特性不承诺固定的性能提升比例。对于短循环、搬运量较小或瓶颈不在 MTE2 的场景，性能收益可能不明显。

# 5. 精度需求

本特性仅调整内存分配和执行调度，不改变数值计算逻辑，算子精度应保持不变。

需要保证：

- 每次迭代选择正确的 buffer slot。
- MTE2 写入前，目标 slot 已不再被上一轮计算使用。
- Vector 读取前，对应 slot 的 MTE2 搬入已经完成。
- 循环次数、数据顺序和输出结果保持不变。
- 开启与关闭 Vector 侧 Multibuffer 时，结果精度一致。

# 6. 设计方案

本特性沿用现有 Multibuffer 处理流程：

1. Buffer 识别
   - 自动识别 CV 场景中 Vector 侧 Load/Store 使用的本地 buffer。
   - 开启自动 Multibuffer 后，默认同时允许 Cube 和 Vector 两侧参与优化。
2. 内存规划
   - PlanMemory 为 Vector 本地 buffer 分配两个独立的物理 slot。
   - 两个 slot 在循环迭代间交替使用。
3. 同步保护
   - 自动同步为不同 slot 建立对应的等待和释放关系。
   - 保证 MTE2、Vector 和其他相关流水之间的数据依赖正确。
4. Buffer 选择
   - 根据循环迭代选择当前 slot。
   - 在不破坏数据依赖的前提下形成跨迭代并行。

#### 可测试性

- 验证 CV 场景默认同时标记 Cube 和 Vector 侧候选 buffer。
- 验证 `only-cube`、`only-vector` 和 `no-limit` 配置。
- 验证 PlanMemory 为 Vector buffer 分配两个独立地址。
- 验证同步关系能够正确保护两个 slot。
- 验证开启和关闭特性时的端到端精度一致。
- 通过性能数据验证 MTE2 与 Vector 计算的重叠程度。

#### 可维护性

- 复用现有 Multibuffer、PlanMemory 和同步流程。
- 保留 Cube/Vector 范围控制选项，便于问题定位和性能调优。
- Vector 侧与 Cube 侧使用统一的 Multibuffer 标记和内存规划语义。

#### 可移植性

该特性基于通用的 Multibuffer、内存规划和同步能力，不依赖新增硬件指令。不同硬件平台可根据片上内存容量和流水能力决定是否启用或调整策略。

### 替代方案
            

### 补充说明
            



欢迎加入社区，感谢您对社区的贡献 🎉!


### 需求背景、当前现状、期望实现的功能内容、具体的设计方案、以及测试方案

#### 需求背景

昇腾 AIV 向量核（Ascend 910_95 / A5）上的行收集（row gather）类 kernel——按行索引把 GM 中的若干行搬入 UB tile（如 paged-attention KV 收集、按行索引查表等）——在 regbase IR 上的典型形态是：一个带 parallel 标记、步长 1 的 `scf.for` 循环，每次迭代构造一个指向 GM 第 `ids[i]` 行的单行 `memref.reinterpret_cast` 描述符，执行一次单行 `hivm.load`（GM→UB DMA），写入 UB 目标 tile 的单行 `memref.subview`。该形态存在三个问题：

1. **DMA 下发条数多**：每行一条 DMA，N 行 tile 即 N 次下发。单行有效负载小，而指令下发、地址计算、循环控制开销固定，A5 上瓶颈在 DMA issue 带宽而非搬运带宽。
2. **tile 级行掩码**：搬运完成后常有 `select(行掩码, 结果, 默认值)` 逐元素选择；掩码本质是行级谓词，却以整 tile 的代价执行。
3. **重复初始化**：行无效时的 fallback 填充（守卫 else 分支）在循环内逐行执行，目的 tile 全量覆盖时属于重复初始化。

#### 当前现状

- regbase 管线对该形态没有任何合并优化，逐行 load 原样下发。
- 模板库 `load_gm_to_ubuf_2d_core` 对源行 stride ≤ 0（行重复/逆序）的 2D 搬运直接退化为标量逐元素 copy；gap 计算存在有符号溢出与字节/元素单位混用隐患，无法支撑“任意行间距”的合批描述符。

#### 期望实现的功能内容（设计方案）

新增 HIVM pass `hivm-optimize-row-loads`（`OptimizeRowLoads.cpp`，1841 行），接入 regbase 管线 pre-bufferization 阶段（`TileAndBindSubBlock` 之后）。单 pass 内完成“识别 + 合法性证明 + 重写”，匹配失败零改动。仅对 Ascend 910_95、AIV 核、非 SIMT 区域、非 backup 函数生效；支持 i8/i16/i32/i64/f16/bf16/f32。

**识别条件**：步长 1、无 region iter_args 的 parallel `scf.for`；体内恰一个 plain 单行 `hivm.load`（无内联 layout、padding、隐式转置等修饰），目标为循环不变 2D UB dense tile 的单行 subview（可穿过 subblock 绑定引入的 descriptor-only collapse）；源为指向固定 GM base（函数入口参数，或带 GM 空间/标记的指针）的行描述符；行地址 DAG 限定为归纳变量与循环不变量上的有界标量整数运算，以及循环不变 tensor 的 `tensor.extract` 行索引读取。

**两行合批**：将相邻两次迭代重写为步长 2 的循环，每次以一条 `{2, cols}` 的 GM→UB DMA 搬运相邻目的行，DMA 下发条数约减半；奇数次迭代保留单行尾部；带守卫/掩码的循环以“两行谓词均成立”为条件做 pair 搬运，否则回退为两个守卫单行搬运，语义不变（回退形态可由 `--fallback-loop` 选择嵌套双 lane 并行循环或顺序两单行）。

**地址重放**：不引入独立的准备 pass；按原序克隆循环内地址计算 DAG（描述符、偏移、守卫条件、行索引读取）逐行重放，合批前后每行 GM 地址逐位一致。注意合批的“行间距”= 第 i+1 行源地址 − 第 i 行源地址，是任意动态值（可为 0 或负：同一 GM 行被收集两次、地址逆序），这正是模板侧需要适配的点。

**行掩码下沉**：识别消费端 `hivm.vsel` / `arith.select(行掩码, 数据, fallback)`（可穿过保形数值 `vcast` 链）；fallback 为可证明精确的常量（整数扩展、精确整浮互转、浮点扩展，均做往返校验）或支配循环的标量时，把掩码下沉为循环内 per-row 谓词守卫 load，并删除 tile 级 select。掩码支持两种形态：a) 标量化重建（varange/fill/broadcast/vadd/vsub/vmul/vand/vor/vxor/vnot/vcmp 及 Scalarizable arith）；b) 对循环不变 mask tensor 的逐行字节读取。

**填充外提**：目的 tile 被完整覆盖且私有（唯一 UB `memref.alloc`、循环前单一 `bufferization.to_tensor` 观察点、别名链逐层核验）时，将 fallback 填充外提到循环前一次完成。

**合法性证明**：基于 MLIR `ValueBoundsConstraintSet` 的行几何证明类 `RowGeometryBounds`，扩展支持 subblock 裁剪产生的 `arith.minsi/maxsi`（上游无 bounds 模型，本地加约束）；等值查询列以 symbol 方式追加，修复二次 insert 导致已排队操作数列号漂移的问题；目的行偏移须等于 `iv − lowerBound`（全覆盖），部分窗口退而证明单位步进（可 pair，但不下沉掩码/外提填充）；另有 GM base/空间/标记分类、UB 存储链核验、DMA burst 上限（2MB−32B）与 32B 对齐校验、别名/活跃性/支配检查。

**开关**：`--enabled`（默认开）；`--fallback-loop`，与 bishengir-compile 控制选项 `enableHivmUbRowGatherFallbackLoop` 同步。

**模板库配套适配**（支撑合批描述符的任意/非正行间距）：

- `Copy2D.cpp` `load_gm_to_ubuf_2d_core`：源行 stride ≤ 0 且末维连续、行宽与 UB 行距按块对齐、无 padding 时，新增快速路径按行独立下发 DMA，不再退化为标量 copy。
- `DMAUtils.h` `load_gm_to_ubuf_2d_core_with_contiguous_last_dim`：先按元素数校验 stride 合法性（拒绝行重叠、拒绝超出硬件无符号 stride 字段范围的大 stride）再计算字节 gap，消除有符号溢出；对齐判断由“字节乘积取模”修正为“元素数取模”。

#### 测试方案

新增 14 个 lit/FileCheck 用例（`bishengir/test/Dialect/HIVM/OptimizeRowLoads/`）：

| 用例 | 覆盖点 |
|---|---|
| recognition / general / pairing | 识别条件、合批主路径、奇数尾部、步长 2 重写、`enabled=false` |
| address-analysis / pointer | 地址 DAG 重放、GM base 分类（入口参数/指针标记） |
| mask / mask-casts / storage-casts | 行掩码下沉、vcast 链、精确回退常量（含 ±0 符号保持） |
| guard-and-observers / reuse | 守卫循环、别名/观察者分析、行读取复用 |
| window-contract | 部分窗口的单位步进证明及随之禁用的变换 |
| subblock | subblock collapse 场景 |
| bufferization-handoff | 下游 one-shot-bufferize / infer-mem-scope / graph-sync-solver 一致性 |

验收标准：

1. 新增 lit 用例及 `check-bishengir` 相关目标全部通过；
2. A5 实机：行收集类算子合批场景 DMA 下发条数约减半，kernel 端到端时延下降（实测数据待远端验证后补充）；
3. 掩码/回退路径数值语义等价，精度无回退；
4. `enabled=false` 时编译产物与主干一致，可一键回退。

#### 已知不足（初版方案）

1. **掩码标量化可能引入新的标量瓶颈。** 掩码下沉后，每行的掩码值改为标量求值（varange/fill/broadcast/velemwise 公式逐行重放，或每行一次 `tensor.extract + cmp` 的字节读取）；masked pair 还要额外计算两份行谓词、一次与运算和外层 `scf.if`。行数多、掩码公式深时，这部分标量开销可能超过省下的 DMA 下发开销，使标量单元成为新瓶颈。
2. **收益依赖行索引升序。** pair 的源 stride 取相邻两行地址之差：升序相邻时才是真正的 2D 连续搬运；索引降序或平坦（同一 GM 行被收集多次）时，模板侧只能按行独立下发两条 DMA，硬件 DMA 条数不变，仅省循环控制开销；升序但行距超出硬件 stride 上限时同样退化为按行搬运。
3. **小数据量场景控制流开销不可忽略。** pair 循环每对引入谓词合并与 `scf.if`，奇数尾部引入 remainder 判断与 tail `scf.if`。行数少、行宽小时这些判断与谓词计算占比高，可能净负收益；当前没有数据量/收益预估门槛，一律尝试合批。
4. **匹配条件偏死，泛化性有限。** 识别框架本身窄（仅带 parallel 标记、步长 1、无 region iter_args 的 `scf.for`）；不足一行的搬运不支持——要求源行宽与目的 tile 行宽一致，如 alloc 64×512、每次 load 1×448 的形态无法识别；行宽还须 32B 对齐且不超 burst 上限，非对齐行宽整体放弃。
5. **合批宽度固定为 2。** 步长与描述符形状硬编码为 2 行，未按行宽/数据量自适应（窄行可合更多行，宽行 2 行已近上限），也未与收益模型联动。
6. **循环体内仅支持单个 load。** 体内恰允许一个（可守卫的）单行 load，其余操作必须全部属于地址 DAG/描述符/元数据；用同一份行索引同时收集多个 tile（如 K/V 双收集，本可共享行地址计算）、体内还有其他计算或 store 的常见形态均不匹配。
7. **掩码下沉与填充外提的隐私条件极窄。** 要求目的 tile 为私有 `memref.alloc`、掩码场景唯一 `to_tensor` 观察点、select 为唯一数据消费者、tile 全覆盖、fallback 可精确重写；tile 切自 workspace/multi_buffer 或存在多个消费者/后续复用时无法命中，真实图命中率预计有限。
8. **pass 与模板运行时策略解耦，无静态收益保证。** pass 只保证 IR 层两条 load 合一，实际 DMA 策略由模板按运行时 stride/对齐选择；行距、对齐等约束常量分散在 pass 与模板两处维护，二者漂移时 pair 会静默落入按行或 by-scalar 慢路径。
9. **缺少可观测性。** 匹配失败即静默跳过（原因仅 `--debug` 可见），无匹配率/合批率/掩码下沉率等 pass 统计，无法在真实模型上量化覆盖率与收益，不利于调参与后续重构验证。
10. **与 pinned MLIR 内部实现耦合。** 行几何证明类直接扩展 `ValueBoundsConstraintSet` 内部机制（为 min/max 补 bounds 模型、以 symbol 列追加规避列号漂移），LLVM 升级时较脆弱。

**定位说明：** 本 pass 为初版方案，目标是先打通“识别—合法性证明—重写—模板适配”的端到端链路并验证收益方向；初版仅覆盖 GM→UB load 侧，逐行 UB→GM 写回（scatter）未动。上述不足——尤其是匹配泛化性、掩码的向量化处理、自适应合批与收益模型、多 load 合批、可观测性——将在后续重构中逐步完善，重构时保持当前“匹配失败零改动”的安全边界，并在本 issue 内跟踪迭代。

### 替代方案

- **两阶段（准备 pass + 合并 pass）**：需要 pass 间契约与额外管线阶段；本方案单 pass 完成、失败零改动，已放弃。
- **更宽合批（4/8 行）**：burst 上限、UB 容量与回退复杂度风险更高；先以 2 行验证收益，匹配框架按“目的行组”设计，后续可扩展。
- **前端直接产出 2D load**：前端形态多样（间接索引、守卫、掩码、subblock），改造面大且无法覆盖存量图。
- **仅做模板侧适配**：运行时只能优化单条指令内部，无法减少下发条数。

### 补充说明

- 对应提交：`3e680da98` `[HIVM][RowGather] feat: pair row loads to reduce DMA issue`（分支 `codex/ub-row-gather-consumer-select`），21 个文件、约 +7064 行（实现约 1900 行，其余为测试与接线）。
- 本 issue 为该特性的初版跟踪入口，后续重构与功能完善在本 issue 内持续更新。
- 该版本尚未本地编译/运行，需远端构建 + 回归验证后再合入（提交说明已注明）。
- `fallback-loop` 两种回退形态的实机性能差异待测，据测定默认值。

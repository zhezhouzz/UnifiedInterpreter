### 环境信息
            
NPU：Ascend910_9382
CANN：9.2.0
PyTorch：2.9.0+cpu
torch_npu：2.9.0.post6
triton-ascend：3.2.2
triton.version：3.2.0
BiShengIR：1.2.0
### 🐛 问题描述
            
## 问题摘要
在 Ascend910_9382 上运行 GDN 的 Triton 输出内核 `chunk_o_fwd_kernel` 时，开启 MultiBuffer 会间歇性停滞。关闭 MultiBuffer 后，现有对照测试未再出现该问题。

我们进一步获得了未插桩原生内核的设备超时现场，并进行了只改变同步事件分配的对照：

- 原生超时三次均停在 Cube 侧 `WAIT_FLAG_DEV #6`，PC 偏移为 `0x694`。
- 优化后 IR 中，K 循环的四组 Vector→Cube 数据就绪通知共用事件 6，CV 流水展开因子为 4，可能在 Cube 消费前积累 `4 × 4 = 16` 次通知。
- 让 Cube 在消费前固定延迟后，16 次共用一个事件的版本在三个独立进程中均首调用设备超时。
- 同样延迟下，仅将其中一次发送及对应等待改到事件 7，即事件 6 保留 15 次、事件 7 为 1 次，两轮各 10 次调用均完成，输出逐次完全相等。
- 保留 MultiBuffer，启用现有 `enable_flag_id_overflow_workaround` 后，固定输入 50,000 次调用通过；完整图模式测试连续十轮、1,290 个用例通过。

这些结果支持：当前默认 CrossCoreGSS 事件复用策略在该 CV 流水场景中缺少未消费事件计数的容量约束。希望维护者确认该分析，明确现有 workaround 的使用范围，并提供正式修复或建议升级版本。

## 触发条件与现象

最初由 GDN 图模式测试暴露，测试中超时用例并不固定。同一输入、同一原生 ELF，在不同进程或不同调用次数下也可能成功或超时。

我们随后绕开完整 GDN 调用链，直接重复启动固定输入的输出内核。在该复现进程中没有创建 NPUGraph、没有进行 capture/replay，仍可复现。因此，图模式专用内核的形状/代码路径是暴露条件，NPUGraph replay 引擎不是该复现成立的必要条件。

固定复现使用 `BK=32`。`native-timeout-dump-1/manifest.json` 中的其他关键启动参数如下，摘录保留原值：

```json
{
  "allocator": "native",
  "multibuffer": true,
  "extra_compiler_options": {},
  "grid": [24],
  "layout": "original",
  "variant": "original",
  "fix_sender": "none",
  "scalars": {
    "T": 193,
    "H": 2,
    "HV": 2,
    "K": 128,
    "V": 128,
    "N": 4,
    "total_chunks": 7,
    "task_num": 14,
    "num_core": 24,
    "BT": 64,
    "BV": 128,
    "USE_G": true,
    "USE_G_GAMMA": false,
    "STATE_V_FIRST": false,
    "IS_VARLEN": true,
    "USE_GRAPH": true
  },
  "input_sha256": "cd62d1655a88f097b6a364576e7f9383a3363f0a374e965666d5908f8657f656",
  "binary_sha256": "b4ed3c244bff4beb70e694ada55f8a6b4d38bc59fdc276c269e0fee17eb729e4"
}
```

## 证据一：未插桩原生内核的真实超时 PC

使用原生 allocator，关闭 sanitizer，没有修改原生 ELF。为了在合理时间内取得设备现场，在诊断进程中设置：

```python
torch.npu.set_op_timeout_ms(5000)
```

运行时记录的实际有效超时约为 8,590 ms。这是为了取得设备报错与 PC，并非将正常耗时接近阈值的计算判为超时。

`native-timeout-excerpt.log` 中的原始 PC 日志行：

```text
[ERROR] IDEDD(2807715,python):2026-11-02-11:45:12.971.459 [kernel_symbol_locator.cpp:725][tid:2808156] [Dump][Exception] Error PC information. coreId=5, coreType=0, originalStartPC=0x124000001000, fixedStartPC=0x124000001000, originalCurrentPC=0x124000001694, fixedCurrentPC=0x124000001694, fixedPCOffset=0x694.
```

同次设备错误的关键字段，以下为日志字段整理：

```text
fault kernel_name = chunk_o_fwd_kernel
symbol            = chunk_o_fwd_kernel_mix_aic+0x694
error             = aicore timeout
ErrCode           = 507014
pc start          = 0x124000001000
current pc        = 0x124000001694
```

`native-on-disassembly.txt` 中的实际反汇编摘录：

```asm
690: XOR.b64                 X27, X26, X16
694: WAIT_FLAG_DEV           #6
698: ADD.s64                 X7, X24, X17
69c: WAIT_FLAG.MTE1.MTE2      X27
6a0: MOV_OUT_TO_L1_MULTI_ND2NZ.b16 [X3], [X7], X22, X14
```

三个独立进程的结果，摘自 `causal-evidence-summary.json`，只保留本节相关字段：

```json
[
  {"label": "native-timeout-dump-1", "checked": 13878, "completed": false, "native_device_timeout": true, "pc_offsets": ["0x694"]},
  {"label": "native-sweep-native2", "checked": 251, "completed": false, "native_device_timeout": true, "pc_offsets": ["0x694"]},
  {"label": "native-sweep-native3", "checked": 1282, "completed": false, "native_device_timeout": true, "pc_offsets": ["0x694"]}
]
```

三个进程使用相同输入 SHA256 和上述同一原生 ELF。`checked` 表示超时前已经完成并核对输出的调用数，不包含最终停滞的调用。

CPU 最终阻塞在 `torch.npu.synchronize()`；设备 PC 表明等待不能完成的原因位于内核的跨核同步，而不是仅有主机侧调用栈线索。

关闭 MultiBuffer 的同输入原生对照，`native-sweep-off/manifest.json` 摘录：

```json
{"allocator": "native", "multibuffer": false, "extra_compiler_options": {}, "iterations": 10000, "grid": [24], "layout": "original", "variant": "original"}
```

对应 `native-sweep-off/result.json`：

```json
{"completed": true, "iterations": 10000, "outputs_checked": 10000, "allocations": []}
```

该对照说明关闭优化可以规避本机已观察的问题，但单独的开关对照不足以解释根因，因此下面继续验证事件容量。

## 证据二：四组数据就绪通知复用同一事件

文件：`recompile-temps/module.hivm.opt.mlir`。

以下是同一 K 分块循环中四次 Cube 等待的非连续原始摘录。省略了中间计算、类型转换和数据搬运操作，因此此代码块不是可独立编译的完整 IR：

```mlir
// Lines 287, 294, 300, 306:
hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 6
hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 6
hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 6
hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 6
```

对应的 Vector 发送，非连续原始摘录：

```mlir
// Lines 791, 800, 828, 855:
hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_S>] flag = 6 ffts_base_addr = %arg0
hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_S>] flag = 6 ffts_base_addr = %arg0
hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_S>] flag = 6 ffts_base_addr = %arg0
hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_S>] flag = 6 ffts_base_addr = %arg0
```

该循环的实际属性：

```mlir
{hivm.loop_core_type = #hivm.tcore_type<VECTOR>, multibuffer_unroll_factor = 4 : i32}
```

K=128、BK=32，对应四个 K 分块。每个 Vector 子核可在该组流水中发出四个分块、每块四次通知，即同一事件最多先积累 16 次通知。Cube 若及时消费则可能正常完成；若 Vector 领先，可能超过事件计数容量。

[A2/A3 CrossCoreWaitFlag 官方文档](https://www.hiascend.com/doc_center/source/en/CANNCommunityEdition/850/API/ascendcopapi/atlasascendc_api_07_0274.html)给出的约束是：同一个 flagId 的计数器最多设置 15 次；等待时计数为 0，后续指令阻塞。这里讨论的是同一事件的计数容量，不是事件编号范围。

## 证据三：15/16 次临界对照

为减少普通复现的随机性，我们从同一份优化后 IR 构造受控时序：在 Cube 发送该组同步事件 14 后、进入数据消费循环前，加入有限次延迟；Vector 侧不加延迟。延迟后基线与所有对照都保留 MultiBuffer、原计算和数据布局。

文件：`delay-baseline.mlir`。实际插入内容及相邻上下文：

```mlir
hivm.hir.sync_block_set[<CUBE>, <PIPE_S>, <PIPE_S>] flag = 14 ffts_base_addr = %arg0
%counter_delay_limit = arith.constant 100000 : index
scf.for %counter_delay_i = %c0 to %counter_delay_limit step %c1 {
  hivm.hir.pipe_barrier[<PIPE_ALL>]
}
```

边界对照只修改第四份数据的同步：当内层分块索引 `%arg28 == 3` 时，把这一次发送及对应等待移到事件 7。其余 15 次继续使用事件 6。与延迟基线相比，只有以下两处同步位置改变；来自 `delay-boundary15.diff` 的同步部分摘录：

```diff
- hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 6
+ %boundary_three = arith.constant 3 : index
+ %boundary_last = arith.cmpi eq, %arg28, %boundary_three : index
+ scf.if %boundary_last {
+   hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 7
+ } else {
+   hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 6
+ }
```

```diff
- hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_S>] flag = 6 ffts_base_addr = %arg0
+ %boundary_three = arith.constant 3 : index
+ %boundary_last = arith.cmpi eq, %arg28, %boundary_three : index
+ scf.if %boundary_last {
+   hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_S>] flag = 7 ffts_base_addr = %arg0
+ } else {
+   hivm.hir.sync_block_set[<VECTOR>, <PIPE_MTE3>, <PIPE_S>] flag = 6 ffts_base_addr = %arg0
+ }
```

结果摘自 `causal-evidence-summary.json`：

```json
[
  {"label": "delay-baseline-1", "checked": 0, "completed": false, "native_device_timeout": true, "pc_offsets": ["0x69c"]},
  {"label": "delay-baseline-2", "checked": 0, "completed": false, "native_device_timeout": true, "pc_offsets": ["0x69c"]},
  {"label": "boundary16-3", "checked": 0, "completed": false, "native_device_timeout": true, "pc_offsets": ["0x69c"]},
  {"label": "boundary15-1", "checked": 10, "completed": true, "native_device_timeout": false, "pc_offsets": []},
  {"label": "boundary15-2", "checked": 10, "completed": true, "native_device_timeout": false, "pc_offsets": []}
]
```

延迟基线的反汇编 `delay-baseline-disassembly.txt`：

```asm
698: XOR.b64                 X7, X20, X18
69c: WAIT_FLAG_DEV           #6
6a0: ADD.s64                 X18, X2, X12
```

注意：受控实验是从 IR 重编译得到的 ELF，增加延迟后等待指令偏移为 `0x69c`；未改写原生 ELF 的等待偏移为 `0x694`。两者均实际反汇编核对为 `WAIT_FLAG_DEV #6`，不能混用 PC。

该实验的解释是：在相同延迟下，16 次全部共用一个事件失败；只分流最后一次通知、保留 15 次后通过。它支持事件计数容量问题，而不是只靠关闭优化改变整体时序得到的相关性。

## 证据四：只改变事件编号，保留 MultiBuffer

另一个对照将四组数据的发送/等待分别配对为事件 7、8、9、10。实际修改只涉及八行事件编号。`events-split.diff` 的事件变更摘要如下，四组按数据依赖一一配对：

```text
Cube wait #1: flag 6 -> flag 7    Vector set #1: flag 6 -> flag 7
Cube wait #2: flag 6 -> flag 8    Vector set #2: flag 6 -> flag 8
Cube wait #3: flag 6 -> flag 9    Vector set #3: flag 6 -> flag 9
Cube wait #4: flag 6 -> flag 10   Vector set #4: flag 6 -> flag 10
```

`ir-intervention-audit.json` 的检查结果摘录：

```json
{
  "same_line_count": true,
  "changed_lines": 8,
  "all_changes_only_sync_event_ids": true
}
```

该变体不改变算术操作、workspace 布局或四路流水：

| 实验                         |         独立进程与调用数 | 结果                                 |
| ---------------------------- | -----------------------: | ------------------------------------ |
| 同样 Cube 延迟，拆分四组事件 |                   2 × 10 | 全部完成，输出逐次完全相等           |
| 无人为延迟，拆分四组事件     | 10,000 + 50,000 + 50,000 | 110,000 次全部完成，输出逐次完全相等 |

长循环的结果记录摘录：

```json
[
  {"label": "events-split-long-1", "checked": 50000, "completed": true, "native_device_timeout": false},
  {"label": "events-split-long-2", "checked": 50000, "completed": true, "native_device_timeout": false}
]
```

普通未加人为延迟的重编译基线也曾两轮各 10,000 次全部通过。因此，不能把原始版本的某轮通过当作问题已经消失；稳定的本机受控对照见上一节。

## 现有 overflow workaround 与源码位置

对应本机编译器提交的源码中，已经存在专门的 overflow workaround，但 pass 选项默认关闭。

文件：`bishengir/include/bishengir/Dialect/HIVM/Transforms/Passes.td`：

```cpp
Option<"enableFlagIdOverflowWorkaround",
       "enable-flag-id-overflow-workaround", "bool",
       /*default=*/"false",
       "Enable the flag-id overflow workaround for cross-core GSS.">
```

文件：`bishengir/lib/Dialect/HIVM/Transforms/GraphSyncSolver/CrossCoreGSS.cpp`，摘录：

```cpp
static constexpr llvm::StringLiteral FlagIdOverflowWorkaroundHint =
    "enable_flag_id_overflow_workaround";
```

同文件中的启用逻辑：

```cpp
if (options.isCrossCoreMode() &&
    (this->enableFlagIdOverflowWorkaround ||
     hasFlagIdOverflowWorkaroundHint(funcOp))) {
  options.enableFlagIdOverflowWorkaround = true;
}
```

文件：`bishengir/lib/Dialect/HIVM/Transforms/GraphSyncSolver/SyncSolver.cpp`，默认路径中的相关判断：

```cpp
if (!options.enableFlagIdOverflowWorkaround) {
  return false;
}
```

打开该选项后会引入额外冲突/复用约束，并影响事件分配。完整源码位置和提交均列于附件，不将以上短代码片段单独作为根因证明；根因分析同时依赖原生现场和临界干预结果。

上述源码对应的精确提交链接：

- [Passes.td：overflow workaround 默认值](https://github.com/Ascend/AscendNPU-IR/blob/042c923d02a22e5845cf10311cf2d192b17a5d77/bishengir/include/bishengir/Dialect/HIVM/Transforms/Passes.td#L282)
- [CrossCoreGSS.cpp：hint 与选项启用逻辑](https://github.com/Ascend/AscendNPU-IR/blob/042c923d02a22e5845cf10311cf2d192b17a5d77/bishengir/lib/Dialect/HIVM/Transforms/GraphSyncSolver/CrossCoreGSS.cpp#L150)
- [SyncSolver.cpp：相关冲突检查](https://github.com/Ascend/AscendNPU-IR/blob/042c923d02a22e5845cf10311cf2d192b17a5d77/bishengir/lib/Dialect/HIVM/Transforms/GraphSyncSolver/SyncSolver.cpp#L813)

## 已验证的业务侧 workaround

在图模式加载后的 `b_q` 张量上添加 hint：

```diff
 import triton.language as tl
+from triton.language.extra.cann import extension as al

 if USE_GRAPH:
     b_q = tl.load(p_q, padding_option='zero', boundary_check=(0, 1))
+    al.compile_hint(b_q, 'enable_flag_id_overflow_workaround', True)
```

验证期间保留默认 MultiBuffer，没有同时添加 `multibuffer=False`。

不要将该 hint 直接标到原始指针 `q` 上：在本机 Triton 版本中，这种先导写法导致前端转换失败；上面的加载后张量写法已经通过编译和回归。

在固定输入的 TTAdapter IR 上启用同一 hint 后，四组等待的实际生成结果摘录自 `overflow-hint-temps/module.hivm.opt.mlir`：

```mlir
hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 0
hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 13
hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 12
hivm.hir.sync_block_wait[<CUBE>, <PIPE_MTE3>, <PIPE_S>] flag = 11
```

对应固定输入的结果摘录：

```json
{"label": "hint-long-1", "checked": 50000, "completed": true, "native_device_timeout": false}
```

完整图模式回归从独立检出运行，未修改测试文件、参考实现或容差。外部观察插件在每轮断言图模式输出内核实际编译元数据中的 MultiBuffer 仍为 true。以下为 `hint-v2-regression-results.json` 与各轮 `kernels.jsonl` 的汇总：

```json
{
  "test_file": "tests/ops/test_gdn_graph.py",
  "fresh_pytest_processes": 10,
  "tests_per_round": 129,
  "total_passed": 1290,
  "total_failed": 0,
  "total_skipped": 0,
  "external_timeouts": 0,
  "all_process_exit_codes": 0,
  "recorded_graph_chunk_o_variants_per_round": 12,
  "all_recorded_multibuffer_values": true
}
```

单条实际内核观察记录示例：

```json
{"name": "chunk_o_fwd_kernel", "hash": "09ca37a9963b31ecc2fb9162a9b1fdbbeefac30af5ffa217609f02a7dc9dd3ce", "multibuffer": true, "workspace_size": 188416, "hint_in_source": true}
```

十轮均为独立 pytest 进程，后续轮次复用编译缓存。首轮包含冷编译，耗时约 678 秒；为了允许冷编译完成，外层控制进程曾暂停，但 pytest 及每用例 120 秒 watchdog 始终运行。首轮最终正常返回 0；后续各轮约 23–25 秒。完整监督记录也在附件中。

## 复现方法与附件

附件保留固定输入、参考输出、原生 ELF、优化后 IR、干预 IR、完整差异和运行记录。关键证据已经在正文中以代码块展示；无需仅根据附件中的结论文字判断。

附件内 `probe.py` 依赖 FLA 源码及上述 NPU 环境，尚不是完全脱离 FLA 的独立最小复现。它直接调用输出 JIT 内核，绕过上层 wrapper 对 MultiBuffer 的关闭措施。

使用随本 Issue 整理的可移植 probe 副本，设置 `FLA_REPO` 为对应 FLA 源码路径。每次使用新的 `--label`，避免覆盖结果：

```bash
source /usr/local/Ascend/cann-9.2.0/set_env.sh
export FLA_REPO=/path/to/flash-linear-attention

python probe.py \
  --allocator native --multibuffer on \
  --label native-repro-01 --iterations 20000 \
  --op-timeout-ms 5000
```

关键启动/检查逻辑来自 `probe.py`，以下为非连续代码摘录：

```python
jit = chunk_o_fwd_kernel.fn.fn
args = {**data, 'BK': 32, 'multibuffer': True}
grid = (data['num_core'],)
compiled = jit.warmup(**args, grid=grid)

for i in range(iterations):
    jit[grid](**args)
    torch.npu.synchronize()
    actual = data['o'].cpu()
    assert torch.equal(actual, expected)
```

上面按当前复现选项展开并简化了变量名；完整脚本还保存 manifest、事件时间线、实际 ELF、输出核对结果，并验证被启动的是同一编译对象。

编译受控 IR：

```bash
export PATH=/path/to/site-packages/triton/backends/ascend/bishengir/bin:$PATH

hivmc delay-baseline.mlir -o delay-baseline
hivmc delay-boundary15.mlir -o delay-boundary15
hivmc delay-split.mlir -o delay-split
```

分别启动原始计数和 15+1 对照。`--binary-file` 在编译对象加载到设备前替换待加载 ELF；每次启动都验证使用的是该对象，并保存实际 ELF SHA256：

```bash
python probe.py \
  --allocator native --multibuffer on \
  --label controlled-16-01 --iterations 1 --op-timeout-ms 5000 \
  --binary-file ./delay-baseline.o

python probe.py \
  --allocator native --multibuffer on \
  --label controlled-15-01 --iterations 10 --op-timeout-ms 5000 \
  --binary-file ./delay-boundary15.o
```

随 Issue 上传的材料已整理为 `issue-attachments.zip`。

## 结论范围与需要维护者确认的问题

1. 当前观察已将该固定复现定位到跨核事件计数容量超限：同一原生等待点、15/16 临界对照及事件拆分/现有防护的效果相互吻合。尚未直接读取溢出瞬间的事件计数寄存器，因此没有确认第 16 次的硬件内部行为究竟是回绕、饱和还是其他计数失效。
2. 之前 sanitizer 曾报告事件 14/15 的同步诊断，但插桩程序可继续完成。本文原生 PC 证据为事件 6，没有将 sanitizer 的报告等同于原生挂起现场。
3. 显式延长 workspace 生命周期的对照仍曾复现；仅替换两条 PIPE_S 发送指令的候选在扩大压力后也停滞。这些方案不作为本 Issue 的根因或正式修复。
4. 通过有限轮次不代表所有形状永不超时；本文不将该定位泛化为所有内核超时的唯一原因，也未验证更新编译器或其他芯片。

希望维护者协助确认：

- 默认 CrossCoreGSS 是否应约束同一事件在 CV pipeline 中的最大未消费计数，避免本例的 16 次累积？
- `enable_flag_id_overflow_workaround` 是否是该版本针对这一问题的推荐措施，其支持范围及潜在限制是什么？
- 是否已有正式修复或包含修复的编译器版本？若有，希望提供对应提交及推荐的 Triton Ascend / AscendNPU-IR 组合。


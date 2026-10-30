# PArray 内存模型与验证

`buffer_cells` 使用 `cell_storage`，其中 `cells_length` 记录逻辑长度，`cells_pages` 将页号映射到 `cell_page`。每页包含 4096 个 `memory_cell Value`，存放在 Rocq `PArray.array` 中。页内元素保留 `Uninitialized` 和 `Initialized value` 两种状态。

## 内存表示和地址检查

[Memory/Model.v](../rocq/Memory/Model.v) 定义分配、初始化、读取和写入。地址先按照 `0 <= address < cells_length` 检查，再计算页号和页内偏移。页号使用 `Z`，页内偏移位于 `[0, 4096)`，转换为 `Uint63.int` 后传入 `PArray`。`cell_page.page_length` 在 Rocq 中约束每页长度，提取时删除证明字段。

分页使逻辑 buffer 的长度不受单个 `PArray` 长度上限限制。分配未初始化 buffer 时建立空页表；首次写入某页时建立该页。读取尚未建立的页返回 `ReadUninitializedCell`。负数地址、长度位置及更大的地址返回 `ViewAddressOutOfBounds`。`allocate_buffer` 使用输入列表初始化各页，`allocate_memref` 保留全部单元未初始化的语义。

页表使用现有 stdpp `gmap`。页内读取和写入使用官方持久化数组，整体访问还包含页表查询以及地址运算的成本。`cells_to_list` 用于示例检查；执行内存读写时直接访问数组页。

## 提取和运行时

[Extract.v](../rocq/Extraction/Extract.v) 导入 `ExtrOCamlInt63` 和 `ExtrOCamlPArray`，通过 `Extraction NoInline PrimArray.array` 保留数组类型别名。空 map/set 构造器使用 extraction 的内联指令，使空内存提取为 OCaml 构造器值并保持多态。

[extracted/dune](../extracted/dune) 链接 `rocq-runtime.kernel`，使用官方 `Parray` 和 `Uint63`。页内更新由 `Parray.set` 修改底层数组，同时保存版本差异。读取历史版本时，运行时恢复相应版本的内容。连续访问当前版本时页内操作为常数时间；访问历史版本可能产生额外的版本恢复成本。元素使用装箱表示。

`empty_page` 接受 `unit` 参数，在需要建立页面时创建数组，符合 OCaml 的多态值限制。项目没有为 `PArray.get/set` 编写自定义提取替换。

## 状态、别名和 lens

描述符继续通过 allocation id 引用 buffer。[Memory/Handler.v](../rocq/Memory/Handler.v) 在写入后更新对应 allocation 的 buffer，其他描述符能够观察同一 allocation 的最新内容。已物化的 tensor 继续持有独立的元素列表。

[HIVM/Execution.v](../rocq/HIVM/Execution.v) 的 `local_memory`、`run_memory` 和 lens 组合保持原有实现。[attention/handlers.ml](../attention/handlers.ml) 继续在语义执行成功时提交返回状态。数组的持久化语义使调用前保存的状态继续表示原来的内存内容；计算期间产生写入后返回错误，也能继续读取调用前的状态。

## 证明和执行检查

[ArrayLaws.v](../rocq/Memory/ArrayLaws.v) 包含以下证明：

- `page_offset_in_bounds`、`page_coordinates_injective`：页内偏移有效，页号和偏移共同唯一确定地址。
- `cells_get_set_same`、`cells_get_set_other`：写入目标位置后能够读取新值，其他位置保持原值。
- `cells_of_list_represents`、`empty_cells_represents`：输入初始化和未初始化分配满足列表表示关系。
- `read_buffer_list_equivalence`：读取结果与列表模型相同，包括未初始化和越界错误。
- `write_buffer_list_equivalence`、`write_buffer_rejects_exactly`：成功写入保持列表表示关系与 buffer 元数据，错误条件恰好对应越界。

这些是内存操作层面的表示关系证明。官方数组原语及其规格、标准 extraction、OCaml 编译器与运行时继续属于可信基础。

[memory_array_test.ml](../attention_test/memory_array_test.ml) 使用提取后的接口检查跨页读写、1000 次分支版本更新、完整版本内容、500 万个单元的逻辑 buffer、输入列表初始化和实际写入后失败的状态保留。测试通过 effect handler 检查成功更新、历史状态以及独立的 marker 字段。

运行验证：

```sh
mkdir -p _build/task-tmp reports/parray-comparison
export TMPDIR="$PWD/_build/task-tmp"
opam exec --switch=unified-interpreter -- dune build @all
opam exec --switch=unified-interpreter -- dune runtest
```

## Attention 比较方法

在修改前构建并保存 attention 可执行文件，使用默认确定性输入运行 `--stage both`，同时保存完整结果 JSON、原语事件 JSONL 和 `/usr/bin/time -v` 的统计。修改完成并通过验证后，使用相同参数运行新可执行文件。计时包含两种 IR 的解释执行、参考结果计算、MLIR 前端处理和事件文件输出，不包含构建。

本次比较文件保存在被 Git 忽略的 `reports/parray-comparison/`。可以逐字节比较完整输出和事件记录：

```sh
cmp reports/parray-comparison/before.json reports/parray-comparison/after.json
cmp reports/parray-comparison/before.jsonl reports/parray-comparison/after.jsonl
```

完整构建后，保存修改后的可执行文件并计时：

```sh
cp _build/default/attention_cli/main.exe reports/parray-comparison/attention-after.exe
TMPDIR="$PWD/_build/task-tmp" /usr/bin/time -v \
  -o reports/parray-comparison/after.time \
  reports/parray-comparison/attention-after.exe --stage both \
  --output reports/parray-comparison/after.json \
  --trace reports/parray-comparison/after.jsonl
```

## 2026-10-30 实测结果

使用 Rocq 9.1.0、OCaml 5.3.0，修改前的代码基于 `b94fcd2b1e1e27a61130d79dbe9fc4917edae741`。两个版本均使用默认固定种子输入，依次运行 HFusion 和 HIVM，并输出完整原语事件。每个版本记录一次完整运行，均以退出码 0 结束。

| 指标 | 修改前 | PArray buffer |
| --- | ---: | ---: |
| 总耗时 | 431.95 秒 | 246.14 秒 |
| CPU 用户时间 | 431.53 秒 | 245.99 秒 |
| CPU 系统时间 | 0.20 秒 | 0.12 秒 |
| 峰值常驻内存 | 108,860 KiB | 96,592 KiB |

本次完整运行加速 **1.75 倍**，耗时减少 **43.0%**，峰值常驻内存从 **106.3 MiB** 降为 **94.3 MiB**。这些数据来自单次测量，耗时会受机器负载影响。tensor 元素继续使用列表表示，本次测量包含现有 tensor 计算的时间。

前后的完整结果 JSON 和事件 JSONL 均逐字节一致。Q/K/V 默认输入生成代码和两份 IR 的 SHA-256 在运行前后保持一致。

| 阶段 | 执行步数 | 原语调用数 | O 最大绝对误差 | LSE 最大绝对误差 |
| --- | ---: | ---: | ---: | ---: |
| HFusion | 66,076 | 33,286 | 0 | 0 |
| HIVM | 592 | 570 | 0 | 0 |

误差以现有独立数学参考实现为基准。阶段之间的结果比较也通过。

验证记录：

- `dune build @all` 和 `dune runtest` 均返回退出码 0，覆盖 Rocq 证明、默认随机输入、零 Q/K、常量输入、IR 修改后的输出变化、混合 attention、kernel 示例及 handler 检查。
- 新增 `memory_array_test.exe` 独立执行并返回退出码 0。
- `Print Assumptions` 输出保存在 `reports/parray-comparison/proof-assumptions.log`，记录内存表示关系证明和 lens 保持性质依赖的原语与规格。
- 原始计时记录为 `before.time`、`after.time`，输出比较记录为 `comparison.json`，均位于 `reports/parray-comparison/`。

完整结果 JSON 的 SHA-256：

```text
63401887b3e8429899ff23f3c38bc3b8f38a43f9841afde1019870744f6b640c
```

完整事件 JSONL 的 SHA-256：

```text
eae5e7e665ed2590792fafd8eb2c0870360478cfb0b2ff0212d3a7f0a341a5dc
```

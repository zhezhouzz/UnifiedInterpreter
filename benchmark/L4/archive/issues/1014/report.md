## 现象

Ascend 950 上运行 `large_4096`，pointwise cat 路径输出正确，但 N=257 时性能显著退化。初步发现 cat 第二个输入搬入 UB 的 load 可能走了逐元素 scalar fallback，想确认这是预期行为还是可以避免的性能问题。

环境：A5 / Ascend950PR；triton-ascend `3.6.0.dev20261120+git3cc90469`，AscendNPU-IR `6674d03a`，torch 2.10.0 + torch_npu 2.10.0.post5.dev20260901，CANN 9.3.0 weekly。使用 pointwise 与 concat 两路强制路由，路由检查通过，输出均 exact。

## Python workload 原文摘录

来自 `benchmark_cat_paths.py` 的 `large_4096`：

```python
CASE_ID = 'large_4096'


def make_inputs(device, generator):
    shapes = [(4096, 257), (4096, 257)]
    return tuple((torch.randn(shape, generator=generator) * 0.25).to(
        dtype=torch.float16, device=device) for shape in shapes)


def workload(first, second):
    return torch.cat([first, second], dim=-1) + 1
```

## 关键 IR

在 `IR Dump After InsertFreeLockVarBeforeReturn`（`--mlir-print-ir-after-all` dump）中，两路 load 的目的布局不同：第一路从 UB offset 0 开始；第二路从 UB offset 257 开始，并带 `left_padding_num = 1`。

```mlir
%subview_0 = memref.subview %23[0, 0] [%37, 257] [1, 1]
    : memref<15x1024xf16, #hivm.address_space<ub>>
      to memref<?x257xf16, strided<[1024, 1]>, #hivm.address_space<ub>>
hivm.hir.load ins(%subview : memref<?x257xf16, strided<[257, 1], offset: ?>, #hivm.address_space<gm>>)
    outs(%subview_0 : memref<?x257xf16, strided<[1024, 1]>, #hivm.address_space<ub>>)
    pad_mode = <PadValue> pad_value = %cst : f16
    eviction_policy = <EvictFirst> core_type = <VECTOR>

%subview_3 = memref.subview %22[0, 257] [%37, 257] [1, 1]
    : memref<15x1024xf16, #hivm.address_space<ub>>
      to memref<?x257xf16, strided<[1024, 1], offset: 257>, #hivm.address_space<ub>>
hivm.hir.load ins(%subview_2 : memref<?x257xf16, strided<[257, 1], offset: ?>, #hivm.address_space<gm>>)
    outs(%subview_3 : memref<?x257xf16, strided<[1024, 1], offset: 257>, #hivm.address_space<ub>>)
    pad_mode = <PadValue> pad_value = %cst : f16 left_padding_num = %c1 : index
    eviction_policy = <EvictFirst> core_type = <VECTOR>
```

完整的本次 pass dump 在 A5：`/home/h00905681/cat-large4096-20261120/bc-pointwise-a5/pass.log`。相关位置：`InsertFreeLockVarBeforeReturn` 后约第 60779 行开始，第一路 load 第 60979 行，第二路 load 第 60991 行；`ConvertHIVMToLLVM` 后约第 64990 行。

## 初步分析

`Copy2D.cpp` 的 `load_gm_to_ubuf_2d_core` 先检查 `dst->aligned + dst->offset` 是否 32B 对齐（约 206–209 行），未对齐时直接调用 `load_gm_to_ubuf_2d_by_scalar`。第二路目的 offset 是 257 个 fp16，即 514B，`514 % 32 = 2`；因此怀疑第二路 load 触发了逐元素 fallback。虽然 IR 带 `left_padding_num=1`，回退一格后的有效地址会对齐，但当前检查似乎在处理 left padding 前执行。

第一路的 GM 行跨度同样是 `257 * 2 = 514B`，但其 UB 目的地址从 offset 0 开始。`DMAUtils.h` 的 `load_gm_to_ubuf_intrin_core` 使用 `copy_gm_to_ubuf_align_v2`，因此 GM 行起始地址不对齐本身似乎仍可由 DMA 处理；当前疑点是第二路 UB 目的地址未对齐。

## 性能数据

NPU kernel duration per workload call，中位数；每模式 5 轮：

| 每输入行宽 N | pointwise | concat |
|---:|---:|---:|
| 256 | 7.228 us | 10.169 us |
| 257 | 150.196 us | 10.632 us |
| 272 | 8.773 us | 9.659 us |

N=257 两路输出均 exact；pointwise/concat = 14.126x。对齐宽度 A/B 是相同脚本与 profiler 口径，但 shape 会影响 Inductor 选用的 tile 配置，因此这些是端到端差异，不是单独隔离 load 的微基准。

## 希望后续分析

1. 在 `NormalizeLastDimUnalignedTensorOp`、`InsertFreeLockVarBeforeReturn` 之后，以及 `ConvertHIVMToLLVM` 之后检查 IR，确认 scalar fallback 是在哪一层引入、实际第二路是否逐元素 load/store。
2. 核实 `left_padding_num=1` 时对齐检查应针对 `dst + offset - left_padding_num` 还是当前未调整的目的地址；判断此处标量路径是否必要。
3. 对比 N=256/257/272 的 load lowering 与 kernel 配置，确认能否在保持语义的前提下避免 N=257 的性能断崖。

本 issue 是初步定位，请进一步确认后再定性/修复。
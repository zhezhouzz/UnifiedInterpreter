

## Overview of Examples:

### L1: working demos (7 groups, 12 variants)

- triton-add/910, with/without autosync
- missing-wait, wrong-event, mix-handoff
- triton-add/950
- kern3
- issue-920: reproduced error on my old compiler



### L2: bug diff suites (11 groups)
- issue-1022-attachment (frontend not supported `iter_arg` as `scf.for` loops)
- indirect-atomic (Merge request !3512, already fixed on my compiler)
- Other minimal protocol models.


### L3

| 分组（17 组） | 用例数 | 整函数翻译通过 | 静态良构通过 | 主要阻塞原因 / 现状说明 |
| --- | ---: | ---: | ---: | --- |
| `handwritten` | 14 | 14 / 14 | 14 / 14 | 全通过（核内同步正负单步变异基准） |
| `tutorial` | 12 | 12 / 12 | 0 | 全通过整函数翻译（12 个算子 32-lane 特化 + 实跑 GSS）；未填 `core_ratio` |
| `graph-sync` | 12 | 11 / 12 | 0 | 几乎全过（官方 GSS 测试）；仅 1 例卡在带返回值的 `scf.if` |
| `inject-sync` | 12 | 8 / 12 | 0 | 其余 4 例卡在标量 `memref.store`(5) / `memref.load`(4) / `annotation.mark`(3) |
| `buffer-alignment` | 12 | 8 / 12 | 0 | 其余 4 例卡在 `scope.scope`(2) / `hivm.hir.vtranspose`(2) |
| `memory-planning` | 28 | 17 / 28 | 0 | 其余 11 例卡在 `annotation.mark`(14) / `vector.transfer_read/write`(8/7) |
| `dma` | 10 | 6 / 10 | 0 | 其余 4 例卡在无空间标注 `memref.alloc`(13) / `tensor.empty`(4) / `mmadL1`(1) |
| `multibuffer` | 12 | 4 / 12 | 0 | 其余 8 例卡在 `scf.while`(6) / `annotation.mark`(3) / `test.before_guard`(1) |
| `unit-flag` | 12 | 4 / 12 | 0 | 其余 8 例卡在 `mmadL1`(12) / `memref.store`(10) / 无空间 `memref.alloca`(5) |
| `graph-control` | 10 | 1 / 10 | 0 | 卡在 `memref.store`(11) / 无空间 `memref.alloca`(7) / `scf.while`(5) |
| `vector-ops` | 12 | 1 / 12 | 0 | 卡在未 bufferize 的 tensor `vcast`(91) / 无空间 `memref.alloc`(26) / `tensor.empty`(9) |
| `issue-input` | 11 | 1 / 11 | 0 | 唯一整函数通过的是 `#1012`；其余卡在 `hivm.hir.l12l0`(17) / `tensor.empty`(9) / 无空间 `alloc`(7) |
| `repair-regression` | 16 | 1 / 16 | 0 | 多数处于未分核/未 bufferize 中层：`tensor.empty`(17) / `bufferization.to_tensor`(10) / `scope.scope`(6) |
| `mixed-core` | 15 | 0 / 15 | 0 | 集中卡在 `hivm.hir.anchor`(36) / 带内部同步的 `mmadL1`(11) / `set_ffts_base_addr`(9) |
| `attention` | 1 | 0 / 1 | 0 | 完整 `_attn_fwd` MIX 模块：卡在动态跨核 `sync_block_set`(9) / `set_ffts_base_addr`(2) / `mmadL1`(2) |
| `regbase-memory` | 14 | 0 / 14 | 0 | 卡在 outlined VF `func.call`(17) / `annotation.mark`(12) / `vector.transfer_write`(10) |
| `custom-macro` | 10 | 0 / 10 | 0 | 卡在自定义宏 `hivm.hir.custom_macro`(11) |
| 合计 | 213 | 88 / 213 | 14 / 88 | — |


> 纯核内同步核心测试组表现极强——handwritten 14/14、tutorial 12/12、graph-sync
> 11/12、inject-sync 8/12、memory-planning 17/28；未通过的组非常集中地指向 4 个
> 已知高层/专有缺口（未 bufferize 的 tensor 层、无空间标注 alloc、MIX 的
> anchor/FFTS/mmadL1、outlined VF func.call）。
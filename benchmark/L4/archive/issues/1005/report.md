## 现象与测量方法

在包含多个消费者共享 producer 的 attention 算子上，对同一份进入 AutoVectorizeV2 的 MLIR 切换 `enable-multiple-consumer-fusion`（MCF），开启后单次 pass 的编译时间增加。以 `3622af712` 为基线，在 macOS arm64 的 Debug 构建上关闭 MLIR 多线程，交错执行两种模式，各取 9 次。只读 MLIR timing 中 `AutoVectorizeV2` 的耗时，中位数从 608.2 ms 增至 768.6 ms，增加 160.4 ms，约 26.4%。

```sh
for mcf in false true; do
  bishengir-opt pass-input.mlir --mlir-disable-threading \
    "--hfusion-auto-vectorize-v2=enable-multiple-consumer-fusion=$mcf" \
    --mlir-timing --mlir-timing-display=list -o /dev/null
done
```

其中 `pass-input.mlir` 是从同一次编译中导出的 AV2 输入。以下数据描述编译器在主机上的耗时。

## MCF 改变了哪些融合

MCF 关闭时，transform 计划执行 2 次 `transform.structured.fuse_into_containing_op`。开启后保留这两次融合，另有 6 个 producer 进入两个 consumer loop。按实际融合顺序：

| 含有 consumer 的循环标签 | 新增 producer 标签 |
|---|---|
| `outlined-loop-target-4` | `hfusion-auto-vectorize-target-8`、`hfusion-auto-vectorize-target-9`、`hfusion-auto-vectorize-target-7` |
| `outlined-loop-target-12` | `hfusion-auto-vectorize-target-17`、`hfusion-auto-vectorize-target-18`、`hfusion-auto-vectorize-target-16` |

## 时间花在哪里

下表来自另一组插桩测量，每种模式各 6 次，列出每次 AV2 内各阶段的累计耗时均值。嵌套 PM 验证计入上一行 `apply_registered_pass`，两行不能相加。

| 阶段 | 调用次数，关 → 开 | MCF 关 | MCF 开 |
|---|---:|---:|---:|
| 全函数 `transform.apply_patterns`，含 CSE | 27 → 27 | 473.68 ms | 535.83 ms |
| `apply_registered_pass` 执行 `eliminate-single-iteration-scf-for` | 2 → 8 | 4.08 ms | 58.80 ms |
| 其中，嵌套 PassManager 验证整个 `func.func` | 2 → 8 | 1.60 ms | 49.39 ms |
| containing loop 局部 canonicalization | 4 → 16 | 8.51 ms | 38.48 ms |
| 规划期 `consolidateToTail` 递归验证父 `scf.for` | 4 → 8 | 12.80 ms | 24.94 ms |
| `structured.fuse_into_containing_op` 本身 | 2 → 8 | 0.84 ms | 4.61 ms |
| `structured.vectorize` | 39 → 39 | 13.01 ms | 12.54 ms |

在 `AutoVectorizeV2::fuseProducersIntoConsumers` 中，每个 producer 融合前对 containing loop 做 canonicalization，融合并重新 tiling 后再次做局部 canonicalization，再对整个函数执行单次迭代循环消除和清理。多出的 6 次融合因此增加了 12 次循环局部清理和 6 次嵌套 PM 验证。全函数 `apply_patterns` 总数在这个输入上都是 27，但 CSE 产生改写后需要再跑一轮 greedy 清理的调用从 11 次增至 15 次。全函数清理累计增加 62.15 ms。

规划阶段还存在一条独立路径。每次将 sibling 或 producer 并入融合组，`FusedNode::consolidateToTail` 在检查组内 op 连续性后递归验证父 op。同一 block 形成一个融合组的过程中，父 `scf.for` 可以被验证多次。

希望保留 MCF 新增的 producer 融合，并缩小逐次清理的范围、减少对同一父 op 的重复递归验证。可在两种模式下分别对比每次融合返回的 fused op、containing loop 以及 AV2 最终输出。
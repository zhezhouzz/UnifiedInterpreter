## 问题

`FoldRedundantCopy` 会把 `copy A -> B; copy B -> C` 折叠成 `copy A -> C`，但它只检查 copy 目标 `B`（及其 reshape 结果）的**直接 users**。当 `B` 是某个 allocation 上的 **view** 时，这个检查不完备：同一 allocation 的**兄弟 view** 不是 `B` 的 user，却读写同一块存储，于是中间更新被整体丢弃。

## 最小复现

```mlir
module {
  func.func @alias_copy(%a: memref<128xf32>, %c: memref<128xf32>) {
    %b = memref.alloc() : memref<256xf32>
    %b128 = memref.subview %b[0] [128] [1] : memref<256xf32> to memref<128xf32, strided<[1]>>
    memref.copy %a, %b128 : memref<128xf32> to memref<128xf32, strided<[1]>>
    %b64 = memref.subview %b[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
    %zero = arith.constant 0.0 : f32
    linalg.fill ins(%zero : f32) outs(%b64 : memref<64xf32, strided<[1]>>)
    memref.copy %b128, %c : memref<128xf32, strided<[1]>> to memref<128xf32>
    return
  }
}
```

```bash
bishengir-opt alias_copy_min.mlir --canonicalize-ext
```

实际输出（错误）：`%b128` 的初始化 copy 被删除，最后一条变成 `memref.copy %a, %c`，通过 `%b64` 写入的内容被旁路。按语义，`%c` 应为 `[64 个 0, a[64:128])`，折叠后变成 `a`。

## 严重程度

编译器在合法 IR 上生成错误结果，属于错误编译（miscompile），建议按正确性缺陷处理。建议同时保留“共享 allocation 兄弟 subview”的最小回归用例，避免后续优化重新引入。

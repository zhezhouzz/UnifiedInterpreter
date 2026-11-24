## 背景

TA（triton-ascend 3.6.0）为 GEN-0080 生成的 SIMD kernel，在 A5（Ascend950PR_9579）上编译后结果错误。现象为：kernel 中第一个 64-lane tile 被写成 `0`/`-0.0`，其余 lane 完全正确；`compile_mode="simt_only"` 时正常。

定位结论：TA 侧产出的 IR 是正确的，错误发生在 npuir（bishengir）流水线内部，具体是 **`canonicalize-ext`（ExtendedCanonicalizer）pass 中的 `FoldRedundantCopy` pattern** 删除了把真实数据写入临时 buffer 的 `memref.copy`。

环境：

- `bishengir-compile 2.0.0 (https://gitcode.com/Ascend/AscendNPU-IR.git 3c7f80bb4f7d 2026-11-10)`
- CANN 9.3.0-weekly，triton-ascend 3.6.0
- target：`Ascend950`（`hacc.target = #hacc.target<"Ascend950PR_9579">`）

---

## 1. 问题分析结论速览

1. **错误 pass**：`canonicalize-ext`（dump 头为 `IR Dump After ExtendedCanonicalizer (canonicalize-ext)`），发生在 bufferization 之后、作用在 `func.func @kern` 上的那次调用。它在相邻两次 IR dump（`12_12_memref-dse.mlir` → `12_13_canonicalize-ext.mlir`）之间把数据 copy 删掉了。
2. **错误 pattern**：`(anonymous namespace)::FoldRedundantCopy : 'memref.copy -> ()'`。用 `--debug-only=greedy-rewriter` 可以看到它处理 `memref.copy(%arg0, %subview)`（即“真实数据 → buffer[0:128]”）时，`Insert 1 条 copy`、`Erase 2 条 copy`，把这条写数据的 copy 一并删除。
3. **错误形态**：原本应为
   `copy(data -> b[0:128]); copy(b[0:64] -> c[0:64])`，
   被优化成
   `copy(b[0:64] -> c[0:64])`（此时 `b` 只剩 zero-template 的 `hivm.hir.copy`，内容是 0），并且 `b[0:128]` 上那条数据 copy 被整体删掉，`b[0:128]` 的 subview 也一并消失。
4. **触发条件**：同一个 buffer 上“先写 `[0:128]`、再取 `[0:64]` 转发到另一个 buffer、之后该 buffer 的 `[0:128]` 还会被读”。满足该形态时 `b[0:64]` 的消费者读到的是 0（或未初始化值）。
5. 该错误可以用一个 10 行的手写 IR 直接复现（见第 3、4 节），与 Triton 无关。

---

## 2. 定位证据

### 2.1 相邻两次 dump（`func @kern`）

**canonicalize-ext 之前**（`12_12_memref-dse.mlir`，第 86–95 行）：

```mlir
%subview_17 = memref.subview %alloc_16[0] [128] [1] : memref<256xf32> to memref<128xf32, strided<[1]>>
%alloc_18 = memref.alloc() {alignment = 64 : i64} : memref<256xf32>
hivm.hir.copy ins(%alloc_10 : memref<256xf32>) outs(%alloc_18 : memref<256xf32>)      // 零模板
%subview_19 = memref.subview %alloc_18[0] [128] [1] : memref<256xf32> to memref<128xf32, strided<[1]>>
memref.copy %subview_17, %subview_19 : memref<128xf32, strided<[1]>> to memref<128xf32, strided<[1]>>  // ← 真实数据
%subview_20 = memref.subview %alloc_18[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
%alloc_21 = memref.alloc() {alignment = 64 : i64} : memref<256xf32>
hivm.hir.copy ins(%alloc_10 : memref<256xf32>) outs(%alloc_21 : memref<256xf32>)
%subview_22 = memref.subview %alloc_21[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
memref.copy %subview_20, %subview_22 : memref<64xf32, strided<[1]>> to memref<64xf32, strided<[1]>>
```

**canonicalize-ext 之后**（`12_13_canonicalize-ext.mlir`，第 86–93 行）：

```mlir
%subview_17 = memref.subview %alloc_16[0] [128] [1] : memref<256xf32> to memref<128xf32, strided<[1]>>
%alloc_18 = memref.alloc() {alignment = 64 : i64} : memref<256xf32>
hivm.hir.copy ins(%alloc_10 : memref<256xf32>) outs(%alloc_18 : memref<256xf32>)      // 只剩零模板
%subview_19 = memref.subview %alloc_18[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>   // 128 被裁成 64
%alloc_20 = memref.alloc() {alignment = 64 : i64} : memref<256xf32>
hivm.hir.copy ins(%alloc_10 : memref<256xf32>) outs(%alloc_20 : memref<256xf32>)
%subview_21 = memref.subview %alloc_20[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
memref.copy %subview_19, %subview_21 : memref<64xf32, strided<[1]>> to memref<64xf32, strided<[1]>>          // 拷的是 0
```

即：写真实数据的 `memref.copy %subview_17, %subview_19` 被删除，`%alloc_18` 只保留 `hivm.hir.copy` 的零值；后续所有消费者都从零 buffer 读。

### 2.2 该错误可由 `bishengir-opt` 单独复现

```bash
bishengir-opt --canonicalize-ext 12_12_memref-dse.mlir
# 或
bishengir-opt --hivm-canonicalization-pipeline 12_12_memref-dse.mlir
```

两者输出的 `%alloc_18` 区域与上面的“之后”完全一致（数据 copy 消失）。

---

## 3. 内部线索

### 3.1 greedy rewriter trace

对 10 行最小 IR（见 3.2）执行：

```bash
bishengir-opt --canonicalize-ext repro_min.mlir --debug-only=greedy-rewriter
```

输出中唯一的 match 成功项如下（处理的对象就是“数据 → buffer[0:128]”这条 copy）：

```
Processing operation : 'memref.copy'(...) {
  "memref.copy"(%arg0, %1) : (memref<128xf32>, memref<128xf32, strided<[1]>>) -> ()
  * Pattern (anonymous namespace)::FoldRedundantCopy : 'memref.copy -> ()' {
    ** Insert  : 'memref.copy'(...)
    ** Erase   : 'memref.copy'(...)
    ** Erase   : 'memref.copy'(...)
  } -> success : pattern applied successfully
}
```

随后该 buffer 的 128-lane subview 被作为 “trivially dead” 删除，最终只留下 64-lane subview 与 `memref.copy`。

### 3.2 最小复现 IR（10 行）

输入 `repro_min.mlir`：

```mlir
func.func @repro(%data: memref<128xf32>, %out: memref<64xf32>, %out2: memref<128xf32>) {
  %b = memref.alloc() : memref<256xf32>
  %b128 = memref.subview %b[0] [128] [1] : memref<256xf32> to memref<128xf32, strided<[1]>>
  memref.copy %data, %b128 : memref<128xf32> to memref<128xf32, strided<[1]>>
  %b64 = memref.subview %b[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
  memref.copy %b64, %out : memref<64xf32, strided<[1]>> to memref<64xf32>
  memref.copy %b128, %out2 : memref<128xf32, strided<[1]>> to memref<128xf32>
  return
}
```

`bishengir-opt --canonicalize-ext repro_min.mlir` 输出：

```mlir
module {
  func.func @repro(%arg0: memref<128xf32>, %arg1: memref<64xf32>, %arg2: memref<128xf32>) {
    %alloc = memref.alloc() : memref<256xf32>
    %subview = memref.subview %alloc[0] [64] [1] : memref<256xf32> to memref<64xf32, strided<[1]>>
    memref.copy %subview, %arg1 : memref<64xf32, strided<[1]>> to memref<64xf32>
    memref.copy %arg0, %arg2 : memref<128xf32> to memref<128xf32>
    return
  }
}
```

→ `memref.copy %data, %b128` 被删除，`%out` 读到的是未初始化数据。该 IR 不含 Triton/hivm 任何特殊算子，纯 memref 即可复现。

### 3.3 怀疑点

`FoldRedundantCopy` 在合并 `copy(A -> B[0:128])` 与 `copy(B -> C)` 时，只删除了中间 copy，并把 B 的 128-lane subview 裁成 64-lane，但没有把 A 的数据转发到最终消费者；同时 B 上还有 zero-template/后续写入，导致 B 的消费者读到 0。建议检查该 pattern 中 `traceSingleReshapeUtilCopy` / `isUsersMemoryEffectFree` 的使用范围判断是否遗漏了“同一 buffer 的其它 subview 读取”。

---

## 4. 复现入口

### 4.1 Python 脚本

`repro_simd.py`（TA 侧，`compile_mode="simd"`，最小形状 `N1=2, SEG1=128, N2=2, SEG2=64`）：

```python
import torch
import torch_npu  # noqa: F401
import triton
import triton.language as tl

BLOCK = 256
SUB = 100.0
THRESH = -1e30


@triton.jit
def kern(x_ptr, out_ptr, n, sub_val, thresh,
         N1: tl.constexpr, SEG1: tl.constexpr,
         N2: tl.constexpr, SEG2: tl.constexpr,
         OPMODE: tl.constexpr, BLOCK: tl.constexpr):
    offs = tl.arange(0, BLOCK)
    v = tl.load(x_ptr + offs, mask=offs < n, other=0.0).to(tl.float32)
    z = tl.zeros([BLOCK], tl.float32)
    for t1 in tl.static_range(0, N1):
        l1 = t1 * SEG1
        in1 = (offs >= l1) & (offs < l1 + SEG1)
        seg1 = tl.where(in1, v, z)
        seg1 = seg1 - sub_val
        seg1 = tl.where(in1, seg1, z)
        for t2 in tl.static_range(0, N2):
            l2 = l1 + t2 * SEG2
            in2 = (offs >= l2) & (offs < l2 + SEG2)
            seg2 = tl.where(in2, seg1, z)
            if tl.max(seg2, axis=0) >= thresh:
                if OPMODE == 1:
                    seg2 = -seg2
                seg2 = tl.where(in2, seg2, z)
            seg1 = tl.where(in2, seg2, seg1)
        v = tl.where(in1, seg1, v)
    tl.store(out_ptr + offs, v, mask=offs < n)


def emulate(x):
    ar = torch.arange(256)
    z = torch.zeros(256)
    v = x.clone()
    for t1 in range(2):
        in1 = (ar >= t1 * 128) & (ar < t1 * 128 + 128)
        seg1 = torch.where(in1, v, z) - SUB
        seg1 = torch.where(in1, seg1, z)
        for t2 in range(2):
            in2 = (ar >= t1 * 128 + t2 * 64) & (ar < t1 * 128 + t2 * 64 + 64)
            seg2 = torch.where(in2, seg1, z)
            seg2 = -seg2
            seg2 = torch.where(in2, seg2, z)
            seg1 = torch.where(in2, seg2, seg1)
        v = torch.where(in1, seg1, v)
    return v


def main():
    dev = "npu"
    x = (torch.arange(256, device=dev, dtype=torch.float32) % 17 - 8)
    out = torch.zeros(256, device=dev, dtype=torch.float32)
    kern[(1,)](x, out, 256, SUB, THRESH,
               N1=2, SEG1=128, N2=2, SEG2=64,
               OPMODE=1, BLOCK=BLOCK, compile_mode="simd")
    torch.npu.synchronize()

    got = out.cpu()
    ref = emulate(x.cpu())
    bad = (got != ref).nonzero().flatten()
    print("bad =", len(bad), "range =", (int(bad[0]), int(bad[-1])) if len(bad) else None)
    print("got[0:4]   =", got[0:4].tolist())
    print("ref[0:4]   =", ref[0:4].tolist())
    print("got[64:68] =", got[64:68].tolist())
    print("ref[64:68] =", ref[64:68].tolist())


main()
```

实测输出：

```
bad = 64 range = (0, 63)
got[0:4]   = [-0.0, -0.0, -0.0, -0.0]
ref[0:4]   = [108.0, 107.0, 106.0, 105.0]
got[64:68] = [95.0, 94.0, 93.0, 92.0]
ref[64:68] = [95.0, 94.0, 93.0, 92.0]
```

### 4.2 两个 IR 的编译命令

#### (a) `bishengir-compile`（TA 实际使用的同一套参数）

```bash
LD=$HOME/.conda/envs/hujj/lib/python3.11/site-packages/triton/backends/ascend/lib/libdevice.10.bc
bishengir-compile min_kernel.mlir --target=Ascend950 \
  --enable-auto-multi-buffer=True --enable-auto-bind-sub-block=True \
  --enable-optimized-metaop=True --custom-aic-number=28 --custom-aiv-number=56 \
  --disable-ffts --limit-auto-multi-buffer-of-local-buffer=no-limit \
  --enable-auto-blockify-loop --enable-hfusion-compile=true \
  --enable-triton-kernel-compile=true \
  "--append-bisheng-options=-cce-link-aicore-ll-module $LD" \
  --enable-vf-merge-level=1 \
  --mlir-print-ir-after-all --mlir-print-ir-tree-dir=$PWD/tree \
  -o /tmp/kernel.o

# 然后对比：
diff -u tree/*/func_func_kern/12_12_memref-dse.mlir \
         tree/*/func_func_kern/12_13_canonicalize-ext.mlir
```

#### (b) `bishengir-opt`（最小复现，无需 device）

```bash
# 最小 IR 复现（第 3.2 节，10 行）
bishengir-opt --canonicalize-ext repro_min.mlir

# 用完整 kernel IR 复现
bishengir-opt --canonicalize-ext 12_12_memref-dse.mlir
bishengir-opt --hivm-canonicalization-pipeline 12_12_memref-dse.mlir

# 打印内部 pattern
bishengir-opt --canonicalize-ext repro_min.mlir --debug-only=greedy-rewriter
```

### 4.3 TA 产生的完整 IR（`min_kernel.mlir`，bishengir-compile 的输入）

该文件由 TA 的 `debug=True` dump 得到（`kernel.ttadapter.mlir`），对应 4.1 的 kernel。（完整内容见下方评论 1，因正文长度限制单独贴出。）

---

## 5. `--debug-only=greedy-rewriter` 且未禁用多线程时的崩溃

用 `bishengir-compile` 在**多线程**下打开 greedy rewriter 调试会 SIGSEGV（同一个 `min_kernel.mlir`、同一套参数）：

```bash
bishengir-compile min_kernel.mlir --target=Ascend950 \
  --enable-auto-multi-buffer=True --enable-auto-bind-sub-block=True \
  --enable-optimized-metaop=True --custom-aic-number=28 --custom-aiv-number=56 \
  --disable-ffts --limit-auto-multi-buffer-of-local-buffer=no-limit \
  --enable-auto-blockify-loop --enable-hfusion-compile=true \
  --enable-triton-kernel-compile=true \
  "--append-bisheng-options=-cce-link-aicore-ll-module $LD" \
  --enable-vf-merge-level=1 \
  --debug-only=greedy-rewriter -o /tmp/kernel_dbg.o
# Segmentation fault (core dumped)
```

崩溃栈（节选）：

```
PLEASE submit a bug report to https://github.com/llvm/llvm-project/issues/ and include the crash backtrace.
#11 0x... mlir::applyPatternsGreedily(...) GreedyPatternRewriteDriver.cpp:0:0
#12 0x... (anonymous namespace)::FuseTransposeIntoLoadPass::runOnOperation() FuseTransposeIntoLoad.cpp:0:0
#13 ... mlir::detail::OpToOpPassAdaptor::run(...)
```

加上 `--mlir-disable-threading` 后可以正常完成（本文所有 greedy-rewriter trace 均来自该模式）：

```bash
bishengir-compile min_kernel.mlir <同上参数> \
  --mlir-disable-threading --debug-only=greedy-rewriter -o /tmp/kernel_dbg.o
# exit=0，日志约 80 万行；FoldRedundantCopy 的 match 记录在第 417026 行附近
```

---

## 6. 完整 IR 附件（见下方评论）

- 评论 1：`min_kernel.mlir`（TA 产出的完整 IR）
- 评论 2：`12_12_memref-dse.mlir`（canonicalize-ext 之前）
- 评论 3：`12_13_canonicalize-ext.mlir`（canonicalize-ext 之后）

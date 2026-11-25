## 0. 结论

- **问题**：当 Triton 的 `tl.dot` 作用在 3 维张量（batched matmul），且左操作数 A 由同一 kernel 的向量计算产生（例如 `A = x2 + x0 * x1`）时，A5 后端生成的结果从 batch 1 开始全部错误；batch 0 正确。
- **根因**：npuir（BiShengIR，commit `f207976552fb`）的 batched matmul 路径缺失“向量缓冲（UB）→ Cube 输入缓冲（L1）”的布局转换。向量核按稠密 7×5 布局写 A（每 batch 35 个 float），Cube 核却按矩阵分形/补齐布局读 A（实测每 batch 前进 80 个 float）。两份 IR 在 `hivm-infer-data-layout` 之后失去一致性，`hivm-plan-memory` 又把它们分配到同一块 L1 地址，最终 Cube 读到错位数据或未初始化数据。
- **不是**：不是 Triton 前端错误（前端输出的 `linalg.batch_matmul` 正确）；不是测试标杆错误（2D、dot-only、逐 batch 2D 展开都能逐位对上）；不是精度问题（误差是整块矩阵取错，不是 1 ulp）。
- **影响面**：所有 A5 上“3 维 `tl.dot` + A 来自向量计算”的 Triton kernel。纯 2D dot 不受影响；A 直接从全局内存（GM）加载的 3D dot 也不受影响。
- **修复方向**：让 `hivm-insert-cv-tight-coupled-buffer` 和 `hivm-insert-load-store-for-mix-cv` 的“向量→L1 布局转换”模式覆盖 batched matmul 操作（`BatchMmadL1Op`），或在 `hivm-tile-batchmm-into-loop` 拆环之后再执行一次转换。

---

## 1. 复现环境与命令

| 项 | 值 |
|---|---|
| 机器 | A5 开发机 `ascend-a5`，NPU 为 Ascend950PR |
| Triton Ascend（TA） | wheel `triton_ascend 3.6.0.dev20261119+git54d85b57` |
| npuir | TA wheel 内置 `bishengir-compile 2.0.0`，对应 AscendNPU-IR commit `f207976552fb`（2026-11-19） |
| CANN | `/data/pri/Ascend/9.3.0-weekly/cann-9.3.0` |
| 设备 | `ASCEND_RT_VISIBLE_DEVICES=1` |

```bash
source /data/miniconda3/etc/profile.d/conda.sh
conda activate hujj
source /data/pri/Ascend/9.3.0-weekly/cann-9.3.0/set_env.sh
cd ~/sync-dot-20261119
PYTHONPATH=$HOME/sync-case-20261119/repo/cases/common \
ASCEND_RT_VISIBLE_DEVICES=1 \
~/sync-case-20261119/venv/bin/python -m pytest -sv work/test_case_mul_add_dot.py
```

测试用例文件：`~/sync-dot-20261119/work/test_case_mul_add_dot.py`。原用例调用了已删除的 `test_common.set_seed`，复现时在文件第 10-14 行加了等价的 `_set_seed`（`random/np/torch` 三方播种），不影响数值语义。

---

## 2. 测例与结果

### 2.1 kernel 片段（文件行号）

```python
# test_case_mul_add_dot.py
 18  op_chains = [["triton.language.mul", "triton.language.add", "triton.language.dot"]]
...
 56      idx0 = test_common.generate_multi_index(L0, M0, N0, K0, P0, Q0, R0, S0)
 57      idx1 = test_common.generate_multi_index(L1, M1, N1, K1, P1, Q1, R1, S1)
 58      idx2 = test_common.generate_multi_index(L2, M2, N2, K2, P2, Q2, R2, S2)
 59      in0 = tl.load(in0_ptr + idx0)
 60      in1 = tl.load(in1_ptr + idx0)
 61      in2 = tl.load(in2_ptr + idx0)
 62      in3 = tl.load(in3_ptr + idx1)
 63      t0 = in0 * in1
 64      t1 = in2 + t0
 65      ret = tl.dot(t1, in3)
 66      tl.store(out0_ptr + idx2, ret)
```

形状：

- 2D：`(21,12) @ (12,227) -> (21,227)`
- 3D：`(18,7,5) @ (18,5,10) -> (18,7,10)`（batch=18，M=7，K=5，N=10）

### 2.2 结果矩阵

| dtype | 2D `(21×12)·(12×227)` | 3D `(18×7×5)·(18×5×10)` |
|---|---|---|
| bfloat16 | PASS | FAIL（标杆先异常，见 2.3） |
| float16 | PASS | FAIL（标杆先异常，见 2.3） |
| float32 | PASS | **FAIL（数值错误）** |
| fp8e4m3 | PASS | **FAIL（数值错误）** |
| fp8e5m2 | PASS | **FAIL（数值错误）** |
| int8 | PASS | **FAIL（数值错误）** |

`6 passed / 6 failed`：**所有 2D 通过，所有 3D 失败**。

### 2.3 两个与 npuir 无关的干扰项

1. **float16/bfloat16 的 3D 用例在标杆阶段就异常**：`dot_golden` 对这两种类型调用 `torch_npu.npu_fused_matmul(..., '16cast32')`，该接口不支持 batched 的右操作数，报 `Batch-axis of y cannot be greater than 1`（aclnn 561103）。这是测试标杆限制，与编译器无关。
2. **默认输入含 ±FLT_MAX / ±inf / NaN**：`generate_tensor` 会注入 5% 特殊值和 10% 极值。3D dot 的输出被 inf/NaN 大面积污染，比较结果被淹没。因此本报告的全部数值证据改用 `data_range=[-0.5,0.5]`、`special_ratio=extreme_ratio=precision_ratio=zero_ratio=0` 的 benign 输入；**benign 下 3D 依然错**，证明这是独立于特殊值的真 bug。

### 2.4 具体结果示例（float32，benign 输入，batch 维）

期望的 A 操作数是 `t1[b]`（`t1 = x2 + x0*x1`，形状 18×7×5）。实测 Cube 实际使用的 A 是 `t1` 稠密展开后的 `[80b, 80b+35)` 窗口：

| batch | 期望 `A[0:2,0:3]` | Cube 实际使用 `A[0:2,0:3]` | `out[0,:3]` | `ref[0,:3]` | 该 batch 最大误差 |
|---|---|---|---|---|---|
| 0 | `[[-0.107771, 0.339631, -0.629065], [0.426317, 0.044944, 0.285515]]` | 与期望相同（偏移 0） | `[-0.014618, -0.138659, 0.117963]` | 同左 | **2.98e-8（正确）** |
| 1 | `[[0.220542, 0.109673, 0.480272], [0.079809, -0.094767, 0.085110]]` | `[[-0.221022, -0.038340, -0.119186], [0.180498, 0.448355, 0.298464]]` | `[0.101085, -0.070746, -0.194789]` | `[-0.233005, 0.178533, 0.146319]` | **0.5388** |
| 2 | `[[0.048715, -0.039724, -0.108434], …]` | `[[0.238618, -0.002462, -0.052829], …]` | `[0.034000, -0.101166, 0.092507]` | `[0.085510, 0.047681, -0.148036]` | 0.5663 |
| 7 | `[[0.323451, -0.624857, 0.159554], …]` | `[[0.326803, -0.173924, 0.338056], …]` | `[0.053022, 0.021575, -0.022840]` | `[0.239114, 0.158068, -0.068915]` | 0.8117 |
| 8 | `[[0.287279, -0.245073, -0.371324], …]` | 窗口起点 640，超出已写的 630 个 float（读取未初始化 L1） | `[0, 0, 0]` | `[-0.091029, -0.136490, 0.390529]` | 0.3905 |
| 17 | `[[-0.480852, 0.234731, -0.367706], …]` | 窗口起点 1360，越界 | `[0, 0, 0]` | `[0.265858, -0.154643, 0.292862]` | 0.7099 |

整体：`maxdiff = 0.8117`，`close_frac = 0.0556`（只有 batch 0 的 70/1260 个元素正确）。

> 上表的“A 实际值”不是从 IR 猜的，而是用 `out[b] = A_b @ x3[b]` 最小二乘反解出来的（拟合残差 3e-8），并对每个 batch 验证 `A_b == t1.reshape(-1)[80b : 80b+35].reshape(7,5)` 精确成立（b=0..7）。

### 2.5 隔离实验（同一组输入）

| 实验 | 结果 |
|---|---|
| 3D dot，A 直接从 GM 加载（单独的 dot-only kernel） | 全 batch 正确，`maxdiff = 3.7e-8` |
| 3D dot，A = `x2 + x0*x1`（本用例） | batch 0 正确，batch 1..17 全错 |
| 同一计算展开成 18 次 per-batch 2D dot | **全对，`maxdiff = 3.0e-8`，`close_frac = 1.0`** |
| 2D dot，A = `x2 + x0*x1`（原用例 2D 形状） | 6/6 dtype 通过 |

结论：**触发条件是“batched matmul + A 由向量产生”，而不是“向量产生 A”本身**。

---

## 3. IR 证据（全部带行号）

行号说明：`ir_all.log` 是 3D 用例的逐 pass IR 日志（`bishengir-compile --mlir-print-ir-after-all`）；`ir_2d_all.log` 是 2D 对照。

### 3.1 前端输出是正确的（ttadapter 文件行号）

```mlir
 22      %6 = arith.mulf %2, %3 : tensor<18x7x5xf32>
 23      %7 = arith.addf %4, %6 : tensor<18x7x5xf32>
 24      %8 = linalg.batch_matmul {input_precision = "ieee"}
               ins(%7, %5 : tensor<18x7x5xf32>, tensor<18x5x10xf32>)
               outs(%1 : tensor<18x7x10xf32>) -> tensor<18x7x10xf32>
```

前端把 `tl.dot` 正确表达成 `linalg.batch_matmul`，没有任何布局问题。

### 3.2 缺失的转换：`hivm-insert-load-store-for-mix-cv`（3D 对照 2D）

**3D 用例，该 pass 之后的 IR**（`ir_all.log:2629-2631`）——只插入了**稠密**的 UB→L1 copy，A 仍是 18×7×5：

```mlir
2629    %10 = hivm.hir.copy ins(%8 : tensor<18x7x5xf32>) outs(%9 : tensor<18x7x5xf32>)
                {"hivm.inserted-copy"} -> tensor<18x7x5xf32>
2631    %12 = hivm.hir.batchMmadL1 {already_set_real_mkn, fixpipe_for_result_already_inserted = true, normalized_in_L0C}
                ins(%10, %5, %true, %c7, %c5, %c10
                    : tensor<18x7x5xf32>, tensor<18x5x10xf32>, i1, index, index, index)
                outs(%11 : tensor<18x7x10xf32>) -> tensor<18x7x10xf32>
```

**2D 用例，同一个 pass 之后的 IR**（`ir_2d_all.log:2739-2747`）——插入了完整的补齐 + 转置 + ND→NZ 转换：

```mlir
2739    %11 = hivm.hir.vbrc {hivm.tcore_type = #hivm.tcore_type<VECTOR>}
                ins(%cst : f32) outs(%10 : tensor<32x16xf32>) -> tensor<32x16xf32>
2740    %inserted_slice = tensor.insert_slice %8 into %11[0, 0] [21, 12] [1, 1]
                : tensor<21x12xf32> into tensor<32x16xf32>
2741    %expanded = tensor.expand_shape %inserted_slice [[0], [1, 2]] output_shape [32, 2, 8]
                : tensor<32x16xf32> into tensor<32x2x8xf32>
2743    %13 = hivm.hir.vtranspose ins(%expanded : tensor<32x2x8xf32>)
                outs(%12 : tensor<2x32x8xf32>) permutation = [1, 0, 2] -> tensor<2x32x8xf32>
2744    %expanded_6 = tensor.expand_shape %13 [[0], [1, 2], [3]] output_shape [2, 2, 16, 8]
                : tensor<2x32x8xf32> into tensor<2x2x16x8xf32>
2746    %15 = hivm.hir.copy ins(%expanded_6 : tensor<2x2x16x8xf32>)
                outs(%14 : tensor<2x2x16x8xf32>) {"hivm.inserted-copy"} -> tensor<2x2x16x8xf32>
2747    %16 = hivm.hir.mmadL1 {already_set_real_mkn, …}
                ins(%15, %5, … : tensor<2x2x16x8xf32>, tensor<12x227xf32>, …)
                outs(%9 : tensor<21x227xf32>) -> tensor<21x227xf32>
```

**全 pipeline 统计**：3D 日志中 `vtranspose` 出现 **0** 次；2D 日志出现 **314** 次。这说明 3D 路径上“向量核写 L1 前先转成 Cube 布局”这一步完全没有发生。

### 3.3 拆环之后，A 的来源仍是稠密缓冲

`hivm-tile-batchmm-into-loop` 之后（`ir_all.log:2752-2760`）：

```mlir
2752    %alloc_6 = memref.alloc() : memref<18x7x5xf32, #hivm.address_space<cbuf>>
2754    hivm.hir.copy ins(%8 : tensor<18x7x5xf32>)
                outs(%alloc_6 : memref<18x7x5xf32, #hivm.address_space<cbuf>>) {"hivm.inserted-copy"}
2756    scf.for %arg11 = %c0 to %c18 step %c1 {
2757      %extracted_slice = tensor.extract_slice %9[%arg11, 0, 0] [1, 7, 5] [1, 1, 1]
                  : tensor<18x7x5xf32> to tensor<7x5xf32>
2760      %11 = hivm.hir.mmadL1 {batch_matmul, fixpipe_for_result_already_inserted = true}
                  ins(%extracted_slice, %extracted_slice_8, … : tensor<7x5xf32>, tensor<5x10xf32>, …)
                  outs(%10 : tensor<7x10xf32>) -> tensor<7x10xf32>
```

到这里 A 仍是 `18×7×5` 稠密缓冲（每 batch 35 个 float），符合向量核的写布局。

### 3.4 出错点：`hivm-infer-data-layout` 把 Cube 侧 A 改成 16×8 分形视图

**pass 前**（`ir_all.log:39886-39899`，AIC 函数，A 是稠密 18×7×5，与生产者一致）：

```mlir
39886    %alloc_0 = memref.alloc() : memref<18x7x5xf32, #hivm.address_space<cbuf>>
39887    annotation.mark %alloc_0 {effects = ["write", "read"],
                hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>}
...
39894      %subview = memref.subview %alloc_0[%arg11, 0, 0] [1, 7, 5] [1, 1, 1]
                  : memref<18x7x5xf32, cbuf> to memref<7x5xf32, strided<[5, 1], offset: ?>>
39896      %subview_2 = memref.subview %alloc[%arg11, 0, 0] [1, 5, 10] [1, 1, 1]   // B 操作数
39899      hivm.hir.mmadL1 {already_set_real_mkn, batch_matmul, …}
                  ins(%subview, %subview_2, %true, %c7, %c5, %c10
                      : memref<7x5xf32, strided<[5, 1]>>, memref<5x10xf32, strided<[10, 1]>>, …)
                  outs(%alloc_3 : memref<7x10xf32, #hivm.address_space<cc>>)
```

**pass 后**（`ir_all.log:40340-40411`，A 变成 16×8 分形的 L1 视图，且这个 alloc 在 AIC 内没有任何写入者；B 得到 GM→L1 的 `nd2nz`）：

```mlir
40340  %alloc = memref.alloc(%c18_0, %3, %2, %c16, %c8) : memref<?x?x?x?x?xf32, #hivm.address_space<cbuf>>
...
40353    hivm.hir.nd2nz {dst_continuous} ins(%collapse_shape : memref<?x?xf32, strided<[10, 1]>, gm>)
                outs(%collapse_shape_17 : memref<?x?x?x?xf32, strided<[?, ?, ?, 1]>, cbuf>)
...
40366  %alloc_11 = memref.alloc(%c18_6, %5, %4, %c16_9, %c8_10) : memref<?x?x?x?x?xf32, #hivm.address_space<cbuf>>
40367  annotation.mark %alloc_11 {effects = ["write", "read"],
              hivm.tightly_coupled_buffer = #hivm.tightly_coupled_buffer<0>}
...
40387    %subview = memref.subview %alloc_11[%arg11, %10, %8, %9, %11] [1, %7, %6, %c16_16, %c8_17]
                : memref<?x?x?x?x?xf32, cbuf> to memref<?x?x?x?xf32, strided<[?, ?, ?, 1]>>
40411    hivm.hir.mmadL1 {already_set_real_mkn, batch_matmul, …}
                ins(%subview, %subview_27, … : memref<?x?x?x?xf32, strided<[?, ?, ?, 1]>>, …)
                outs(%alloc_32 : memref<?x?x?x?xf32, #hivm.address_space<cc>>)
```

`%alloc_11` 的维度是 `(18, ceil(K/8)=1, ceil(M/16)=1, 16, 8)`——即每个 batch 预留 16×8 = 128 个 float 的分形块；而生产侧从未写过这个布局。

### 3.5 地址别名：`hivm-plan-memory` 把两份不兼容视图放到同一块 L1

PlanMemory 之后（`ir_all.log:46094`、`46192`、`46199-46201`）：

```mlir
// AIC（Cube 侧）：A 按 16×8 分形视图解释
46094  %3 = hivm.hir.pointer_cast(%c18432_i64) : memref<18x1x1x16x8xf32, #hivm.address_space<cbuf>>

// AIV（Vector 侧）：A 按稠密 18×7×5 写入
46192  %6 = hivm.hir.pointer_cast(%c18432_i64) : memref<18x7x5xf32, #hivm.address_space<cbuf>>
46199      %collapse_shape_7 = memref.collapse_shape %subview
                  : memref<18x7x5xf32, strided<[56, 8, 1]>, ub> -> memref<126x5xf32, strided<[8, 1]>, ub>
46200      %collapse_shape_8 = memref.collapse_shape %6
                  : memref<18x7x5xf32, cbuf> -> memref<126x5xf32, cbuf>
46201      hivm.hir.copy ins(%collapse_shape_7) outs(%collapse_shape_8) {"hivm.inserted-copy"}
```

两块 buffer 都从 L1 偏移 **18432 字节**（0x4800）开始：Cube 侧按 18×1×1×16×8 解释，Vector 侧按 18×7×5 稠密写入。这就是错误结果落地的地方。

---

## 4. 前后 IR 对比：为什么错、为什么结果错

### 4.1 布局对比

| | 生产者（AIV，向量核） | 消费者（AIC，Cube 核） |
|---|---|---|
| A 的类型 | `memref<18x7x5xf32>` 稠密 | `memref<18x1x1x16x8xf32>`，16×8 分形块 |
| 每 batch 占用 | 35 个 float（7 行 × 5 列） | 128 个 float（16×8）；实测寻址等价于每 batch 前进 **80** 个 float（16 行 × 5 列） |
| 写入总量 | 630 个 float（2520 字节） | 按 18 × 128 = 2304 个 float 的范围寻址 |

`hivm-infer-data-layout` 之前，两份 IR 都使用 `18x7x5` 稠密类型，语义一致；该 pass 只在 AIC 函数内把操作数改成 16×8 分形视图（并且对 AIV 函数直接提前返回，见 5.6），生产侧没有跟着改，IR 从此自相矛盾。

### 4.2 为什么 batch 0 正确、其余错误

设 `t1` 的稠密展开为 `dense[0..629]`，正确的 A 是 `dense[35b : 35b+35]`。

- **b = 0**：读者偏移 0，与写者偏移 0 重合 → 结果正确（实测 2.98e-8）。
- **b = 1..7**：读者取 `dense[80b : 80b+35]`，写者对应的是 `dense[35b : 35b+35]`，每个 batch 错位 `45b` 个 float（跨到后面 batch 的行）→ mmad 本身执行正确，但乘的是错误的 A。反解残差 3e-8 证明 `out[b] == A_wrong @ x3[b]` 精确成立。
- **b ≥ 8**：`80b ≥ 640 > 630`，超出写者写入的 630 个 float，读到未初始化的 L1（本次运行表现为全 0）→ `out[8..17]` 全 0。

### 4.3 为什么 M=16 时连 batch 0 都错

把 3D 形状换成 `(18,16,5) @ (18,5,10)` 后，Cube 侧按完整的 16×8 分形布局读（每个 batch 128 个 float，行内步长 8），而向量侧仍按 16×5 = 80 个 float 的稠密布局写。两者在 batch 0 就不一致，`close_frac` 只有 0.0035。这进一步说明问题是“生产者/消费者布局约定不一致”，与某个固定偏移无关。

---

## 5. 具体错误链路（按 pipeline 顺序）

1. **前端正确**：`tl.dot` → ttadapter 的 `linalg.batch_matmul`（ttadapter 行 24）。
2. **`inferLayoutOptimization` 关闭备用转换流水线**：`bishengir-compile` 的 regbase 驱动在模块中看到 `linalg.batch_matmul` 就把 `enableLayoutOptimization` 置为 false（`bishengir/lib/Tools/bishengir-compile/regbase/Utility.cpp:100-104`）。因此 3D 编译完全跳过了 `hivm-insert-convert-layout`、`hivm-propagate-convert-layout`、`hivm-combine-optimized-convert-layout`、`hivm-convert-layout-to-transpose` 这一组 pass；2D 编译则会执行它们。
3. **`hivm-insert-load-store-for-mix-cv` 漏掉 batched 操作**：负责“向量结果 → L1 并转成 Cube 布局”的 `AddConvertLayoutUBToL1` 只声明匹配非 batched 的 `hivm::MmadL1Op`（`bishengir/lib/Dialect/HIVM/Transforms/InsertLoadStoreForMixCV.cpp:1277`）。此时 3D 的 op 是 `hivm.hir.batchMmadL1`，模式不匹配，于是只插入稠密 copy（`ir_all.log:2629`），没有 `vbrc`+`vtranspose`。
4. **`hivm-insert-cv-tight-coupled-buffer` 同样漏掉**：`InsertMoveL1BetweenVectorAndCube` 与 `InsertDataMovementFixpipeToL1` 也只匹配 `hivm::MmadL1Op`（`InsertCVTightCoupledBuffer.cpp:452、576`）；该 pass 的入口虽然识别 `BatchMmadL1Op`（同文件 `:794`），但具体的搬运/转换模式没有覆盖它。并且这两趟都跑在拆环之前（pipeline 顺序：`HIVMRegbasePipelines.cpp:480` 的 buffer 标记 → `:494` 的 `hivm-tile-batchmm-into-loop`）。
5. **`hivm-tile-batchmm-into-loop` 拆环**：`batchMmadL1` 被拆成 `scf.for { mmadL1 {batch_matmul} }`（`ir_all.log:2756-2760`）。拆环之后，第 3、4 步负责插转换的 pass 已经运行完毕，再没有 pass 补做布局转换。默认 `enable_hivm_batch_matmul=false`；本次环境尝试置 true 会直接触发设备错误 507015，因此默认路径就是拆环路径。
6. **`hivm-infer-data-layout` 改写 Cube 侧布局**：该 pass 只处理非 AIV 函数（`InferHIVMDataLayout.cpp:1672-1680`，AIV 直接 `return`），于是 AIC 的 A 操作数变成 16×8 分形视图（`ir_all.log:40366-40411`），生产侧 AIV 保持稠密。
7. **`hivm-plan-memory` 别名**：AIC 的分形 buffer 与 AIV 的稠密 copy 目标被分到同一个 L1 偏移 18432（`ir_all.log:46094、46192`），两份不兼容视图共享内存。
8. **运行期**：Cube 按分形/补齐布局取 A → batch 0 偏移重合；batch 1..7 取错位数据；batch ≥8 读未初始化 L1。

### 一个关键对照

把同一计算写成 18 次 per-batch 的 2D `tl.dot` 后结果**完全正确**（2.5 节）。2D 情况下 op 是非 batched 的 `mmadL1`，第 3 步的 `AddConvertLayoutUBToL1` 能匹配，插入了 `vbrc` + `vtranspose`（`ir_2d_all.log:2739-2747`）。这直接证明缺失的就是 batched 操作上的这一步转换。

---

## 6. 修复建议

1. **补齐 batched 操作的模式覆盖**：给 `InsertCVTightCoupledBuffer` 的 `InsertMoveL1BetweenVectorAndCube` / `InsertDataMovementFixpipeToL1` 以及 `InsertLoadStoreForMixCV` 的 `AddConvertLayoutUBToL1` 增加 `hivm::BatchMmadL1Op`（或在 `hivm-tile-batchmm-into-loop` 之后补跑一次这些模式）。
2. **复核 `inferLayoutOptimization` 的禁用策略**：不要因为模块里存在 `linalg.BatchMatmulOp` 就整体关闭 convert-layout 子流水线；至少保证 batch matmul 操作数仍有等价的布局转换。
3. **加回归测试**：一个 3D `tl.dot`（A 由向量计算产生）的端到端用例，以及一个 `batchMmadL1` 的 lit 测试，检查在 A 来自 UB 时 `vbrc/vtranspose` 或等价的 ND→NZ 转换被插入。
4. 在修复前，使用侧规避方式：把 3D dot 改写成“逐 batch 的 2D dot”循环（已知可正确编译）。

---

## 7. 复现材料

`ascend-a5:~/sync-dot-20261119/`：

| 文件 | 内容 |
|---|---|
| `work/test_case_mul_add_dot.py` | 复现用例（含 `_set_seed` shim） |
| `work/diag3_mul_add_dot.py` | 分阶段隔离（load / `t1` / dot-only / 全链路） |
| `work/check_per_batch.py` | 逐 batch 2D dot 对照实验 |
| `work/analyze_layout.py`、`work/make_example.py` | A 操作数反解与数值示例 |
| `ir_all.log` | 3D 用例逐 pass IR（本报告 3.2、3.3、3.4、3.5 的行号来源） |
| `ir_2d_all.log` | 2D 对照逐 pass IR（3.2 的 2D 行号来源） |
| `dump/…/triton_kernel.ttadapter` | 前端输出（3.1 的行号来源） |

手工复现编译（与 TA 调用的 `bishengir-compile` 相同）：

```bash
B=~/sync-case-20261119/venv/lib/python3.11/site-packages/triton/backends/ascend/bishengir/bin/bishengir-compile
T=dump/FCBRH4LVHY6F73PCGTBBMZQO3XHFX3ZXE5RI3FMXWZEWNM7MF67Q/triton_kernel.ttadapter
$B $T --target=Ascend950 \
   --enable-hfusion-compile=true --enable-triton-kernel-compile=true \
   --custom-aic-number=28 --custom-aiv-number=56 \
   -o ./out.o --mlir-print-ir-after-all > ir_all.log 2>&1
```

---

*Assisted-by: AI*
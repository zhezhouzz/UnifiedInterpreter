### 环境信息
            
```
- 操作系统        : Ubuntu 24.04.5 LTS (Noble Numbat)，内核 6.8.0-149-generic，x86_64
- 昇腾硬件        : Ascend950PR（Chip Version V100；Product/Model A310-50-C00MM304A1；NPU Name 9579；hacc.target = Ascend950PR_9579）
- NPU 驱动        : 25.7.rc1（ascendhal 7.35.23，Innerversion V100R001C10SPC102B224），npu-smi 25.7.rc1
- CANN 软件版本   : Ascend-cann-toolkit 9.1.0（innerversion V100R001C11B106；compiler version.info Version=9.1.0，timestamp 20260612_141800522）
- 编译器(取证用)  : bishengir，自源码构建，revision 0cafbb815133d67e4910110627ca5ab50c5b9c13（2026-11-18 构建）
```
# 🐛 问题描述
            
## 一句话总结
一个 rank-1、静态带步长的 `vector.transfer_write`（语义是「沿某一列、每隔 8192 个元素写一个值」）在 `ConvertVectorToHIVMAVE` 这个 Pass 里被**误降**成一条**连续写**指令 `ave.hir.masked_store <NORM_B32>`，lane 之间的步长 8192 被静默丢弃，结果把 4 个值**挤在一起连续写**到起始地址，而不是分散到正确的列地址。编译成功、不报错——属**静默错误代码生成（silent wrong-codegen）**。

- **Failure class**：Compile（编译成功，但生成的访存指令地址错误）
- **First bad pass**：`ConvertVectorToHIVMAVE`（`lib/Conversion/VectorToHIVMAVE/`）
- **对应修复PR**：MR https://gitcode.com/Ascend/AscendNPU-IR/merge_requests/5314
  - `17e584cb9bfb385f5bb67732c2331fcc55f42836` [Vector] fix: lower rank-1 static-strided transfer_write to a scatter
  - `983899456a91079c2de2b6221ff1fcd1536ef947` [HIVMAVE] feat: add a lightweight verifier for VFScatterOp


## 复现场景与最小可复现示例

**场景**：一张 `4 行 × 8192 列` 的 f32 临时表，命中全局第 0 列的 tile 需要把 4 个 `-inf`（IEEE-754 位模式 `0xFF800000`）写入**同一列的 4 行**。

- 原始输入：`triton_poi_fused_copy_expand_scalar_tensor_sele_0.ttadapter`（`hacc.target = Ascend950PR_9579`）。
- 写一列：`tensor.insert_slice %1 into %37[0, %38] [4, 1] [1, 1]`（偏移 `[0,%38]`、范围 `[4,1]`=4 行 1 列、步长 `[1,1]`，三组方括号都是行列号不是字节）。
- rank-reduce 后在 VF 内部落成 rank-1 的 `memref<4xf32, strided<[8192], offset: ?>, ub>`：写第 i 行 = 在一维视图里跳 `i × 8192` 个元素。此处 stride=8192 来自 UB 临时 buffer 的行距（写的是 UB 上那张连续 `4×8192` 表的一列），不是 GM 视图的行距 686624。

**最小可复现输入**（`stride-store-minimal.mlir`，两个函数仅 stride 不同，其余完全相同）：

```mlir
// 函数 A：带步长 stride=8192（本 bug 场景）
func.func @store_strided(%arg0: memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>) {
  %cst  = arith.constant dense<0xFF800000> : vector<64xf32>   // 4 个 -inf 在前 4 lane
  %mask = vector.constant_mask [4] : vector<64xi1>            // 仅前 4 lane 有效
  vector.transfer_write %cst, %arg0[...], %mask { in_bounds = [true] }
      : vector<64xf32>, memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
  return
}

// 函数 B：单位步长 stride=1（对照）—— 其余与 A 完全相同
func.func @store_unit(%arg0: memref<4xf32, strided<[1], offset: ?>, #hivm.address_space<ub>>) { ... }
```

**判别器**：经 `ConvertVectorToHIVMAVE` 后，函数 A 与函数 B **都生成同一条 `ave.hir.masked_store <NORM_B32>` 连续存储**。若 stride 被正确消费，A（`strided<[8192]>`）本应生成 scatter/带步长存储，不该和单位步长收敛到同一形态——这直接证明 stride 在转换中被静默丢弃。


## 根因主线（起因 → 经过 → 结果 → 解决）

**起因（语义正确）**：要「沿一列、每隔 8192 元素写一个值」，上层正确生成了带 `strided<[8192]>` 的 rank-1 `vector.transfer_write` + `constant_mask [4]`。

**经过（stride 被静默丢弃）**：在 `ConvertVectorToHIVMAVE` 里——
- 带步长存储入口判定 helper `Util.cpp::isTransferWriteSuitForStoreWithStride`（旧 `Util.cpp:1941-2010`）在 `1961-1963` 处 `if (shape.size() < 2) return false`，只为**特定多维 block-stride** 设计，直接拒绝 rank-1；
- 走不进带步长存储分支（旧 `VectorToHIVMAVE.cpp:494-515`）；
- 回退分支（旧 `VectorToHIVMAVE.cpp:578-625`）在 `611-613` 处**无任何连续性保护**地构造普通 `VFMaskedStoreOp`；
- 布局选择器定成 `<NORM_B32>`（连续）；
- intrinsic 下降（旧 `HIVMAVEToAVEIntrin.cpp:1336-1376`）里 `getStridedElementPtr` 只算**单一起点**，`vstus/vstas` 连续写——stride 从未参与寻址。

**对称性缺口**：读一侧 `NormalizeVector.cpp:1010-1035` 早有 rank-1 read→gather 规整，**但写一侧没有对应保护**。read/write 是两个不同 Op，修 read 不会自动覆盖 write——这是本 bug 的结构性成因。

**结果（连续写列地址丢失）**：生成的指令把 4 个值连续写到 `0/4/8/12` 字节，而非 `0/32768/65536/98304` 字节，下游数据错误；编译不报错。


## 证明根因的 IR 片段

**转换前**（语义正确，stride 与 mask 都在）：

```mlir
func.func @..._outlined_vf_1(%arg0: memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>) {
  %cst  = arith.constant dense<0xFF800000> : vector<64xf32>
  %mask = vector.constant_mask [4] : vector<64xi1>
  vector.transfer_write %cst, %arg0[...], %mask { in_bounds = [true] }
      : vector<64xf32>, memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
}
```

**转换后**（退化为连续存储，`<NORM_B32>` 不消费 stride；注意 memref 类型里 `strided<[8192]>` 仍在，但指令已不再使用它）：

```mlir
%pge = ave.hir.pge <VL4> ...
ave.hir.masked_store <NORM_B32> %val, %arg0[...], %pge
    : ..., memref<4xf32, strided<[8192], offset: ?>, #hivm.address_space<ub>>
//              ^^^^^^^^^^^^^^^^ 类型里还带着 stride，但 NORM_B32 按连续地址落地，stride 被忽略
```

**LLVM 层佐证**（`llvm.mul` 只用 `0 × 8192` 算一个起点，`vstus` 连续写 16 字节、`vstas` 提交，无任何按 lane 的跨步寻址；`vstus`=连续 store，`vstas`=提交地址，二者都不接受逐 lane 地址向量）：

```mlir
%start = llvm.mul %0, %c8192 : i64        // 只算起点（此处为 0），没有逐 lane 的 stride 寻址
hivm.vstus.post.f32 %vec, %ptr, 16, %addr // 连续写 16 字节 = 4 × f32，4 个值被挤在一起
hivm.vstas %addr, %ptr, 0, 0              // 提交
```

∴ `vstus` 落地地址仅来自单一 `llvm.mul` 起点、无 index 向量参与，确认 stride 在 LLVM 层同样未参与寻址——与转换后 `NORM_B32` 丢弃 stride 一脉相承，是同一个丢失沿下降链路一路贯穿到底。对比锚点：调用点 rank-reduce 时 stride 仍被保留，证明信息直到 `ConvertVectorToHIVMAVE` 之前都对，丢失点就在这个 Pass。


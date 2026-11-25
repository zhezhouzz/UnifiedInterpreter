## 背景

A5 上 sync_cases `maximum + div` 全 dtype 用例（12 dtype × 8 shape = 96）出现 88 failed / 8 passed，仅 float32 通过。对照 TA 20261119 wheel（triton_ascend 3.6.0.dev20261119+git54d85b57）与 AscendNPU-IR master 后，失败来自**测试标杆与 Triton 语义不一致**，以及 **tl.store 的隐式类型转换**；编译器 IR 中未发现数学表达式替换。

本文把两处 div 实现和 store 行为分别列出，并附仓库源码链接，作为后续用例修正与归因的依据。

## 一、标杆 `div_golden` 的实现

源码：https://gitcode.com/ultrayay/sync/blob/sync_cases/cases/common/golden/triton_api/math_ops/div_golden.py

| 输入 dtype | 标杆做法 | 结果 dtype |
|---|---|---|
| float16 / bfloat16 | 显式 `.to(torch.float32)` 后 `torch.div` | f32（不回舍入） |
| fp8e4m3 / fp8e5m2 | 显式转 f32 后除 | f32 |
| uint16 / uint32 | 转 int64 后 `torch.div` | f32 |
| uint64 | numpy 真除法（f64）→ f32 | f32 |
| int8/16/32/64、uint8、bool | 直接 `torch.div` | f32（实测 7/2→3.5，bool→1.0） |
| float32 | 直接除 | f32 |

要点：**标杆结果始终是 f32**，不向输出 dtype 舍入，也不对整型截断。

## 二、Triton `truediv` 的实现

源码（wheel 对应 commit）：https://github.com/triton-lang/triton-ascend/blob/54d85b57b864ace347eef87421e935b5e2fb1a7d/python/triton/language/semantic.py#L286-L306

| 运算 | 行为 | 结果 dtype |
|---|---|---|
| int / int | 双方 cast 到 `tl.float32` 再 fdiv | f32 |
| float / int、int / float | 转成 float 一方类型 | 该浮点类型 |
| float / float | 取 mantissa 更宽的一方 | f16/f16 保持 f16；bf16/bf16 保持 bf16；f16+bf16→f16；带 f32 才是 f32 |

对比结论：
- 整型：两边的**除法本身一致**（都是 f32 真除法，7/2=3.5），差异出现在写回阶段（见下）。
- f16/bf16/fp8：标杆统一升到 f32 并保持 f32，Triton 语义保持原浮点类型，两者不同；golden 注释里的「triton 语义要求先类型提升」只对 int/int 成立。
- uint64：标杆走 f64 再转 f32，Triton 走 f32，大数商不同。

## 三、`tl.store` 的隐式转换

源码：https://github.com/triton-lang/triton-ascend/blob/54d85b57b864ace347eef87421e935b5e2fb1a7d/python/triton/language/semantic.py#L1232-L1233

`store` 在写回前执行 `val = self.cast(val, elt_ty)`，即把结果隐式转换到输出指针元素类型：

- f32 → 整型：向零截断。`int/int` 先得到 f32 商 3.5，store 后变成 3。
- f32 → f16/bf16/fp8：舍入到输出 dtype。

这就是整型用例必然失配的直接原因：kernel 按 Triton 语义截断存储（3），标杆保留真除法结果（3.5）。对浮点 dtype，kernel 输出被舍入到输出 dtype，而标杆不做舍入。

## 四、比较环节进一步放大差异

源码：https://gitcode.com/ultrayay/sync/blob/sync_cases/cases/common/test_common.py

用例中 `ref` 为 f32，与 kernel 输出 promote 后两者都变为 f32，随后才读取 `out_dtype`，于是非 f32 精度的数据按 float32 的容差判定；整型则直接比较 3.5 与 3。

此前定界已验证：把标杆先转换到输出 dtype、并按输出 dtype 选择容差后，40/40 浮点用例通过。

## 五、编译器侧核对（BiShengIR）

- `arith.divf/divsi/divui → ave.hir.vdiv`，不改变 dtype：
  https://gitcode.com/Ascend/AscendNPU-IR/blob/master/bishengir/lib/Conversion/ArithToHIVMAVE/ArithToHIVMAVE.cpp
- `ave.hir.vdiv` 的 F16 与 F32 映射到同一条 `hivm.vdiv.s.x` 指令，转换处没有插入 f16→f32 扩展：
  https://gitcode.com/Ascend/AscendNPU-IR/blob/master/bishengir/lib/Conversion/HIVMAVEToAVEIntrin/HIVMAVEToAVEIntrin.cpp
- 指令定义：
  https://gitcode.com/Ascend/AscendNPU-IR/blob/master/bishengir/include/bishengir/Dialect/HIVMRegbaseIntrins/IR/HIVMRegbaseIntrins.td

IR 中未见 max/div 的数学替换或重排；数值残差可定位到 vdiv 指令路径（f32 ≤1 ulp、subnormal FTZ），与标杆/比较语义问题分开记录。

## 六、建议

1. 标杆先按输出 dtype 舍入再比较；整型期望值显式按「f32 除 + 向零截断」构造，或标注例外。
2. harness 的容差按 kernel 输出 dtype 选取，不要 promote 后仍用 f32 门限。
3. float/float 的期望值按 Triton 的 mantissa 规则生成（f16 保持 f16），不要统一升 f32。
4. 若维持现状，请在用例层注明这是期望语义差异，避免被当作编译器回归。

---
Assisted-by: AI
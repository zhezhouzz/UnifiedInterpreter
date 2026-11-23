## 问题背景

`normalize-to-tensor` 已支持 memory space 隔离，以及将 `to_tensor` 之前的部分 memref 级 DPS 写暴露给 tensor 层分析。本 issue 的主要问题是：原有 memref 别名追踪不支持 `arith.select`，需要补齐这一支持，并增强相关写识别和合法性检查。

## 问题表现

当 `bufferization.to_tensor` 的输入来自 `arith.select`，或其底层 memref 经 `arith.select` 选中后被写入时，原 pass 无法完整追踪这条别名链：

- 向上追踪定义链遇到 `arith.select` 时，会将其视为不支持的定义并触发 fatal error。
- 向下检查 memref 用户时，不会沿 `arith.select` 的结果继续查找，可能漏掉通过该结果发生的写，导致未按需插入 tensor 层 copy。

例如，以下输入需要同时检查 select 的两个候选 memref，并识别 `%a` 上已有的写：

```mlir
func.func @select_before_to_tensor(%cond: i1, %value: f32) -> tensor<16xf32> {
  %a = memref.alloc() : memref<16xf32>
  %b = memref.alloc() : memref<16xf32>
  hivm.hir.vbrc ins(%value : f32) outs(%a : memref<16xf32>)
  %selected = arith.select %cond, %a, %b : memref<16xf32>
  %t = bufferization.to_tensor %selected restrict writable : memref<16xf32>
  return %t : tensor<16xf32>
}
```

原实现不能正确处理这里的 select 定义链。另一类场景是先向 select 结果写入，再对其中一个候选 memref 执行 `to_tensor`，同样需要纳入别名写追踪。

## 预期行为与改进范围

### 主要修复：支持 `arith.select`

- 向上追踪 select 的 true / false 两个候选值，继续检查其定义与相关写。
- 向下追踪 select 结果的用户，识别通过该别名发生的写。
- 对 writable `to_tensor`，若追踪到其之前的相关写，沿用已有机制插入 `bufferization.alloc_tensor() copy(...) {to_be_replaced}`，使写在 tensor 层分析中可见；只读使用本身不触发 copy。

### 配套增强

- 写识别由 DPS init 扩展到 `CopyOpInterface` 的 target 和 `memref.store` 的目标 memref。
- 使用 `isBeforeInMemoryView` 判断写与 `to_tensor` 的顺序，替代原有支配关系判断及 preload scope 特判；将该工具下沉到通用 `Dialect/Utils`。
- 检查追踪到的 memref / 别名是否还被其他 `to_tensor` 使用，对违反 `restrict` 使用约定的情况输出诊断。
- 明确定义链支持范围；对追踪到的 SCF 用户及不支持的定义显式报错。
- 将 memory space 隔离与写暴露分阶段执行，移除用于标记已处理操作的 `write_exposed` 属性。

## 验证关注点

对应测试文件：`bishengir/test/Dialect/Bufferization/normailze-toTensorOp.mlir`。

- select 候选 memref 上已有写，以及通过 select 结果写入的场景。
- 只读 select 用户不应仅因出现 select 而插入 copy。
- 保持 memory space 隔离、动态 shape 和 preload scope 场景的行为。
- 遍历多个独立 `to_tensor` 时不遗漏处理，并正确替换各自的 tensor 用户。
- 结合 `hivm-decompose-alloc-tensor-copy` 和 One-Shot Bufferization 检查后续处理。

## 当前边界

- 本次不提供跨函数写分析，`func.call` 不被当作已识别的写。
- 本次不实现 SCF 控制流中的通用别名分析，也不支持任意 memref 定义来源。
- `to_tensor` 之后的 memref 写与后续 tensor 读之间的冲突检查仍需额外分析，不属于本次修复范围。

关联 PR：!5315（`fix-normalize-to-tensor`）。

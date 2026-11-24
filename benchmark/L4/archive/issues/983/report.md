### 🐛 问题描述

`analyze-vector-layout` 布局无解时的失败诊断（`Vector Layout Analysis Failure`）使用默认
Value/Operation 打印：未指定 local scope 时 `Value::print` 会**上溯父 module** 解析 SSA 名字，
并触发 `verifyIsIsolatedFromAbove`。函数 pass 在多个函数上并行执行时，诊断会读取**正被其他
线程修改的兄弟函数**，违反函数 pass 的访问隔离。同一输入在并发时序下表现为：

- 热线程异常遍历不退出
- SIGSEGV
- 断言失败（assertions 构建，落在诊断打印的 IR 遍历路径上）

### 根因

- 失败分支 `os << *failedOp` / `os << result` / `os << operand` 走默认打印，隐式上溯顶层
  module；
- 仅 `assumeVerified` 不能根治：跳过 verify 后，SSA 编号仍会遍历
  兄弟函数，必须同时约束打印根与作用域。

### ✅ 修复（随 MR 提交）

仅失败分支（`solves.empty()` 路径）改为：

- 构造根为**当前 FuncOp** 的 `AsmState`（`useLocalScope` + `printGenericOpForm`）；
- `failedOp` 经该显式状态打印（generic 形式同时跳过对可能非法 IR 的隐式 verify）；
- Vector Result/Operand 用 `printAsOperand`，共用同一函数内 SSA 编号。
- 成功路径不受影响。

# 在 HFusion 和 HIVM 模块 AST 上按 trace 执行

## 1. scheduler 的输入

使用 `Hivm_trace.Execution.run_module` 时，解释器在每次执行前向 scheduler 请求一条 trace。需要同时取得 trace 和执行结果时，调用 `Ir_scheduler.run_module ~stage ~launch ast`。`ast` 是 parser 返回的 OCaml 模块，`stage` 取 `HFusion` 或 `HIVM`。`launch` 指定入口、实参、初始内存和执行流。多个实参通过相同的 `storage` 引用同一块内存。[调用接口](../lib/scheduler/ir_scheduler.mli) · [解释器入口](../lib/hivm/module_execution.ml) · [模块 AST](../lib/hivm/hivm_module.mli) · [启动参数](mlir-to-core.md#启动参数)

命令行 `run FILE --stage hivm --launch launch.json` 从文件解析 AST。相同模块、IR 层和具体启动配置共享跨进程的 trace 历史。默认数据库位于 `$XDG_STATE_HOME/unified-interpreter/traces.sqlite3`，未设置该变量时使用 `~/.local/state/unified-interpreter/traces.sqlite3`。可以通过 `--trace-db FILE` 指定数据库。[命令行入口](../bin/source_run.ml)

## 2. scheduler 返回的 trace 结构

命令行输出的 `schedule` 字段与 OCaml 的 `Delivery.encode trace` 相同。[trace 接口](../lib/scheduler/ir_scheduler.mli)

| 字段 | 含义 |
| --- | --- |
| `events` | 按执行顺序排列的事件。每项依次为执行流编号、源操作位置、管线、动态出现序号、阶段。 |
| `extent` | `race_prefix` 在第二个竞争端点结束。`terminal` 覆盖本次执行直至终止。 |
| `targets` | 竞争前缀包含按执行顺序排列的两个端点。`event` 是可与 `events` 直接比较的事件，`source` 包含原始 AST 位置和循环轮次。终止 trace 的值为 `null`。 |
| `terminal` | 终止状态为 `returned`、`deadlock` 或 `invalid-memory`。竞争前缀的值为 `null`。 |
| `hash`、`reused` | `hash` 是紧凑 JSON 事件数组的 SHA-256。`reused` 表示本次是否复用已交付的 trace。只有耗尽当前输入的可选调度后才允许复用。 |

例如，`[0,"@stream_0/10 func.call","V",0,"complete"]` 表示执行流 0 中，函数 `@stream_0` 的路径 `[10]` 上，第一次提交至 V 管线的调用完成。动态序号在同一执行流、源操作位置和管线内从零开始计数。同一任务的提交和完成共用序号。[事件定义](../lib/dispatch.ml)

## 3. interpreter 如何利用 trace

使用现有执行器时，`Ir_scheduler.run_module` 完成请求、执行和消费检查。已通过 `next_trace` 取得 trace 时，可以直接调用 `Hivm_trace.Execution.execute_trace ~stage ~launch ast schedule`。需要自行驱动解释器时，用 `Delivery.replay` 取得 `choose` 和 `verify`。解释器自行计算标量、分支、循环条件和地址。每当有可执行的调度动作时，将这些动作传给 `choose`，执行它选出的事件。提交阶段保存任务和实参，完成阶段执行该任务的读写，原子阶段执行对应操作。[执行接口](../lib/hivm/module_execution.ml) · [事件选择与检查](../lib/scheduler/trace_delivery.ml)

竞争前缀消费完以后，可以使用任意合法的调度策略继续执行。现有 `choose` 在此时选择执行器给出的第一个可执行动作。终止后调用 `verify result.status`。scheduler 优先交付已发现竞争的两个顺序。单次调度请求的默认超时为 120 秒（120000 毫秒），可通过 `--scheduler-timeout-ms` 调整。请求超时时，接口抛出 `Delivery.Incomplete`，命令行以状态码 3 退出。[OCaml 调用实现](../lib/hivm/module_execution.ml)

## 4. fifo-copy 例子

`fixture/fifo-copy` 的 HIVM 入口 `@stream_0` 两次调用 `@copy`。路径 `[10]` 将 `x[0]` 复制到 `x[1]`，路径 `[19]` 将 `x[1]` 复制到 `x[2]`。初始值为 `[7, 0, 0]`。使用同一份新的数据库连续启动解释器，可以观察到以下结果。[HIVM 源程序](../benchmarks/ir-pairs/fixture/fifo-copy/hivm.mlir) · [跨进程回归测试](../test/test_trace_delivery.py)

| 请求 | 调度顺序 | 最终内存 | `reused` |
| --- | --- | --- | --- |
| 第一次 | 提交 10，提交 19，完成 10，完成 19 | `[7, 7, 7]` | `false` |
| 第二次 | 提交 10，提交 19，完成 19，完成 10 | `[7, 7, 0]` | `false` |
| 第三次 | 提交 10，完成 10，提交 19，完成 19 | `[7, 7, 7]` | `false` |
| 第四次 | 复用第一次的 trace | `[7, 7, 7]` | `true` |

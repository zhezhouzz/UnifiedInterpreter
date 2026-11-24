# Core Language 的公理化轨迹语义

源语言对应 `core_language_litao` 提交 `ee071f0` 的 `docs/core-language-opsem.tex` 中的基础配置。一个 AI Core 的活动指令流分别发射命令，每条数据管道独立完成队列项。语法与 #316 的程序见[语法文档](../../../docs/core-language-syntax.pdf)，轨迹公理和定理见[语义文档](../../../docs/core-language-trace-semantics.pdf)。

## 定义

- [Syntax.v](Syntax.v) 定义命令、五种操作数类别、硬件签名、活动流与良构条件。`hardware` 指定可用管道和同步边，并解释标量求值、分配、读写足迹以及算子完成时的内存更新。
- [Events.v](Events.v) 的 `stream_plan` 计算每条流的控制动作，处理局部绑定、带正负步长的循环和提前返回。`candidate` 要求轨迹中每条流的发射投影是其控制序列的前缀。
- [TraceSemantics.v](TraceSemantics.v) 的 `trace_semantics` 对每个事件之前的轨迹前缀施加 `queue_law`、`flag_law` 和 `memory_law`。`program_semantics` 还检查程序和入口参数，并量化动态分配见证。`terminated`、`deadlocked` 和 `race` 分别描述正常终止、死锁和在途操作的足迹冲突。
- [SerializedTrace.v](SerializedTrace.v) 的 `checked_iff_laws` 给出逐事件检查与全部前缀公理的双向蕴含。`fragment_append` 用于拼接具有给定发射投影和最终性质的见证片段。

局部 flag 和块通知都使用二值令牌。块通知按接收者分别记录，发向标量端的等待阻塞该流的后续发射。该配置的范围见参考分支的操作语义；benchmark 中的 `local-scalar-memory` 和 `bounded-counter` 是独立的执行器扩展。

## 证明

[ResourceExamples.v](ResourceExamples.v) 验证数据管道等待可以先于匹配通知发射，事件编号错误会造成死锁，两个足迹冲突的管道复制按不同顺序完成会产生不同的可见结果。广播例子验证两个接收流独立消费，以及首个接收流消费后再次广播仍须等待。

[#316 的 HIVM 示例](../../../examples/kernels/issue316_vexp_hivm.mlir) 每轮从 GM 搬入一块数据，再从选中的 UB 缓冲区计算结果。[Issue316.v](Issue316.v) 在显式循环内发射 `Load(input[i], buffer[i % 2])` 和 `VExp(buffer[i % 2], output)`。两个输入缓冲区由程序分配，所有迭代使用调用方提供的同一个 UB 输出视图。每个 tile 含 1024 个 f16 元素，单元素指数由参数 `exp_f16` 给出。

- [Issue316Safety.v](Issue316Safety.v) 的 `issue316_program_buffer_selection` 证明，对程序语义允许的任意轨迹，已经发射的装载目的地址和计算源地址各自按轮次交替选择实际分配的 A、B。`issue316_buffer_selection` 和 `issue316_iteration_address` 给出指定布局下的地址序列与逐轮结论。`freeA_second_consumption` 还证明两次消费 A 的可用令牌之间，V 必须至少完成一次相应通知。
- `issue316_data_path` 证明每轮两条数据操作的发射顺序、源视图和目的视图。[Issue316Execution.v](Issue316Execution.v) 的 `issue316_load_compute_overlap` 给出第 1 轮装载先于第 0 轮计算完成的合法前缀，并验证第 0 轮计算写入 `output` 的值。
- `issue316_complete_trace_exists` 为任意轮数、单射布局和满足初始分配条件的内存构造一条终止轨迹。MTE2 和 V 全部排空，所有令牌都已消费，两个地址序列都覆盖整个循环。`issue316_complete_trace_for_all_counts` 为任意输入 tile 序列给出具体布局和初始内存。

在仓库根目录执行以下命令可编译证明并检查证明项。

```sh
opam exec --switch=unified-interpreter -- make -C rocq CoreLanguage/Axiomatic/ResourceExamples.vo CoreLanguage/Axiomatic/Issue316Execution.vo
opam exec --switch=unified-interpreter -- rocq check -silent -Q rocq UnifiedInterpreter UnifiedInterpreter.CoreLanguage.Axiomatic.ResourceExamples UnifiedInterpreter.CoreLanguage.Axiomatic.Issue316Execution
```

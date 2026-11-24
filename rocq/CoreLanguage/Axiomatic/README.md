# Core Language 的公理化轨迹语义

源语言对应 `core_language_litao` 提交 `ee071f0` 的 `docs/core-language-opsem.tex` 中的基础配置。一个 AI Core 的活动指令流分别发射命令，每条数据管道独立完成队列项。语法与 #316 的程序见[语法文档](../../../docs/core-language-syntax.pdf)，轨迹公理和定理见[语义文档](../../../docs/core-language-trace-semantics.pdf)。

## 定义

- [Syntax.v](Syntax.v) 定义命令、五种操作数类别、硬件签名、活动流与良构条件。`hardware` 指定可用管道和同步边，并解释标量求值、分配、读写足迹以及算子完成时的内存更新。
- [Events.v](Events.v) 的 `stream_plan` 计算每条流的控制动作，处理局部绑定、带正负步长的循环和提前返回。`candidate` 要求轨迹中每条流的发射投影是其控制序列的前缀。
- [TraceSemantics.v](TraceSemantics.v) 的 `trace_semantics` 对每个事件之前的轨迹前缀施加 `queue_law`、`flag_law` 和 `memory_law`。`program_semantics` 还检查程序和入口参数，并量化动态分配见证。`terminated`、`deadlocked` 和 `race` 分别描述正常终止、死锁和在途操作的足迹冲突。
- [SerializedTrace.v](SerializedTrace.v) 的 `checked_iff_laws` 给出逐事件检查与全部前缀公理的双向蕴含。`fragment_append` 用于拼接具有给定发射投影和最终性质的见证片段。

局部 flag 和块通知都使用二值令牌。块通知按接收者分别记录，发向标量端的等待阻塞该流的后续发射。该配置的范围见参考分支的操作语义；benchmark 中的 `local-scalar-memory` 和 `bounded-counter` 是独立的执行器扩展。

## 从 OCaml AST 生成 data race 见证

`Unified_interpreter.Bug_traces.generate_bug_traces` 接受固定入口实参的 Core Lang 程序。调用者通过纯函数提供标量计算、操作的读写地址和块通知的接收关系。`Input` 表示入口处已有的存储，访问 `Allocated` 地址的操作必须在对应的分配事件之后完成，且偏移量须在分配范围内。读写足迹相交且至少有一方写入，并且两个动态操作能够以两种顺序完成时，函数返回两条合法前缀。每个方向各取一条最短前缀。该判定使用地址和事件顺序抽象。

```ocaml
open Unified_interpreter
open Core_lang

let view i = Literal (VView [Input 0, i])
let copy a b next = Issue (0, 0, [view a; view b], next)
let program = {
  streams = [{ id = 0; pipes = [0]; params = [];
               body = copy 0 1 (copy 1 2 End) }];
  scalar_eval = (fun _ _ _ -> invalid_arg "unknown scalar operation");
  footprint = (fun _ _ op args -> match op, args with
    | 0, [VView src; VView dst] -> { reads = src; writes = dst }
    | _ -> invalid_arg "unknown operation");
  block_edge = (fun _ _ _ _ -> false);
}

let search = Bug_traces.generate_bug_traces ~loop_bound:0 program
let solve = Bug_traces.generate_bug_traces ~backend:Solve program
```

两个结果各含一对竞争，冲突地址为 `(Input 0, 1)`。见证的 `first_then_second` 和 `second_then_first` 字段可传入 `Bug_traces.replay program` 重放。动态操作标识包含流编号、AST 中的命令位置和从零开始的各层循环迭代编号。

`Solve` 省略 `loop_bound` 时，根据具体入口实参、循环步长和控制流生成所有迭代的候选事件，再由 Z3 求解两种完成顺序。正常返回时 `truncated = false`，竞争集合覆盖这组入口实参。求解规模随实际展开的事件数和冲突访问对数增长。

`Search` 需要显式传入 `loop_bound`，`Solve` 也接受此参数。上界分别限制每次进入循环后可执行的轮数。若某个可达前缀仍有下一轮且已经达到上界，结果的 `truncated` 为真，此时竞争集合覆盖界内前缀。

### 求解存在竞争的循环次数

`Bug_traces.find_symbolic_race` 接受同一个 Core Lang AST，以及标量原语和读写足迹的表达式定义。`parameter` 列出的入口变量绑定到同一个符号整数 `N ≥ 0`。例如，下列程序每轮向同一地址写入一次。

```ocaml
open Unified_interpreter
open Core_lang
open Bug_traces

let integer n = Literal (VInt (Z.of_int n))
let destination = Literal (VView [Input 0, 7])
let body = Issue (0, 1, [destination], End)
let family : Symbolic.family = {
  streams = [{ id = 0; params = []; pipes = [0];
               body = For (1, integer 0, Var 0, integer 1, body, End) }];
  parameter = [0, 0];
  scalar = (fun _ _ -> invalid_arg "unknown scalar operation");
  access = (fun _ _ -> function
    | 1 -> [], [Symbolic.Arg 0]
    | _ -> invalid_arg "unknown memory operation");
  block_edge = (fun _ _ _ _ -> false);
}

let result = Bug_traces.find_symbolic_race family
```

- `Race { n; witness }` 给出同一个具体 `n` 下的两条合法前缀。可用 `let p = Symbolic.instantiate family n` 得到具体程序，将 `witness.first_then_second` 和 `witness.second_then_first` 分别传给 `Bug_traces.replay p`。上例在 `N = 2` 时两次写入已经可以交换完成顺序。
- `No_race` 表示在地址与完成顺序语义下，对所有非负 `N` 都没有竞争。`Unknown reason` 表示求解未完成，并返回原因。可用 `~timeout_ms` 指定每次 Z3 查询的时间预算，默认为 5000 毫秒，0 表示不限时。

求解按源指令建立事件模板，用整数变量表示各层循环的迭代编号。查询要求同一 `N` 下的同一对动态访问具有冲突地址，并允许两种相反的完成顺序。对顺序确定的 flag 发送和消费，求解器可利用它们在同一令牌上的序号排除竞争。其余同步约束通过两个独立前缀的完成时钟和令牌交替条件求解。只有在取得候选模型后才实例化具体 `N` 并生成见证。

原语定义可使用 `Arg`、`Const`、整数加减乘、正整数取模、比较、条件选择、`Event` 和 `Input_slice (storage, offset, length)`。`access` 返回读取视图和写入视图的表达式列表。同一套定义用于符号查询与具体重放。输入须满足 Core Lang 的类型和原语调用约定。

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

open Unified_interpreter
module Ast = Attention_runtime.Parser
module Module_ast = Hivm_module
module Mlir = Mlir_lowering
module Mlir_device = Mlir_device

type pipe = Core_lang.Device.pipe = S | V | M | MTE1 | MTE2 | MTE3 | FIX
type origin = { path : int list; opcode : string; part : string option }

(** iterations 从外到内记录从零开始的轮次。 *)
type location = { stream : int; entry : string; origin : origin; iterations : int list }

(** 同一报告内，同一动态任务的提交和完成使用相同的 id。 *)
type task = { id : int; pipe : pipe }
type signal = { receiver : int; source : pipe; target : pipe; flag : int; cross : bool }
type action = Compute | Allocate | Set of signal list | Wait of signal
            | Wait_all of int list * signal | Barrier
type phase = Submit of task list | Complete of task | Execute of pipe option
type event = { location : location; action : action; phase : phase }

(** 两条前缀分别以 second 和 first 的访问结束，均可能保留待完成任务。 *)
type race = { first : event; second : event; forward : event list; reverse : event list }
type status = Complete_search | Race_found | No_race | Unknown of string
type report = {
  benchmark : string;
  streams : (int * string) list;
  n : Z.t option;
  inputs : Yojson.Safe.t;
  status : status;
  races : race list;
}

(** 按函数体和各层 region 中从零开始的下标定位指令。 *)
val resolve : Ast.program -> int list -> Ast.operation

(** 从 HIVM 前端的 AST JSON 读入同一个 OCaml 类型。 *)
val read_ast : string -> Ast.program

(** 每个可观察的 Core 指令位置都需要登记。多阶段指令的各个位置可以指向
    同一个 HIVM 节点，part 标识该节点内的动作。 *)
type binding = { core_site : int list; origin : origin }
type stream_pair = { stream_id : int; program : Ast.program; bindings : binding list }
type pairing
val pair :
  name:string -> launch:Race_benchmarks.launch -> pipes:(int * pipe) list ->
  streams:stream_pair list -> pairing

(** 内置配对会核对原始 HIVM 程序。没有配对或配对不完整时抛出 Invalid_argument。 *)
val registered : ?root:string -> (string * (unit -> Race_benchmarks.benchmark)) list ->
  string -> Ast.program -> pairing
val registered_file : ?root:string -> (string * (unit -> Race_benchmarks.benchmark)) list ->
  string -> string -> pairing

val registered_module : ?root:string -> (string * (unit -> Race_benchmarks.benchmark)) list ->
  string -> Module_ast.t -> pairing
val ast_file : ?root:string -> string -> string
val fixture_source : (string * (unit -> Race_benchmarks.benchmark)) list -> string -> string
val generate : ?n:int -> ?kv_heads:int -> ?timeout_ms:int -> Benchmark_traces.method_ -> pairing -> report
val core_inputs : ?n:int -> pairing -> (int * string) list * Z.t option * Yojson.Safe.t
val to_json : report -> Yojson.Safe.t

type lowered_mlir = Core_mlir of Mlir.t | Device_mlir of Mlir_device.t
val lower_mlir : ?entry:string -> ?configuration:Yojson.Safe.t -> Module_ast.t -> lowered_mlir
val analyze_mlir : backend:Bug_traces.backend -> ?hivm:bool -> lowered_mlir -> Yojson.Safe.t
val replay_mlir : lowered_mlir -> Yojson.Safe.t -> int

(** 解释器传入解析所得的 HIVM 或 HFusion 模块 AST 和具体启动参数。 *)
module Source = Source_scheduler
module Ast = Source.Ast
module Delivery : sig
  type extent = Hivm_trace.Execution.Delivery.extent = Race_prefix | Terminal of string
  type trace = Hivm_trace.Execution.Delivery.trace = {events:Unified_interpreter.Dispatch.event list; hash:string; extent:extent;
                targets:Yojson.Safe.t; reused:bool}
  exception Incomplete of string
  val encode : trace -> Yojson.Safe.t
  val replay : trace -> Unified_interpreter.Dispatch.choose * (Hivm_trace.Execution.status -> unit)
end
type stage = Source.stage = HFusion | HIVM
val next_trace : ?db_path:string -> ?timeout_ms:int -> ?max_steps:int -> stage:stage ->
  launch:Yojson.Safe.t -> Ast.t -> Delivery.trace
val run_module : ?db_path:string -> ?timeout_ms:int -> ?max_steps:int ->
  ?trace:(int -> string -> unit) -> ?on_read:(int -> string -> Hivm_trace.Execution_value.view -> unit) ->
  stage:stage -> launch:Yojson.Safe.t -> Ast.t -> Delivery.trace * Hivm_trace.Execution.result
val generate_mlir : ?entry:string -> ?configuration:Yojson.Safe.t -> ?timeout_ms:int -> stage ->
  Unified_interpreter.Precedence.backend -> Ast.t -> Yojson.Safe.t

(** 按名称加载已登记模型和归档的 benchmark。 *)
module Catalog = Catalog_scheduler

(** 兼容原有的目录调用接口，新调用使用 Catalog。 *)
type program = Catalog.program =
  | Tensor of Hfusion_trace.t
  | Device of Hivm_trace.pairing
  | Module of stage * Ast.t * Yojson.Safe.t
val explicit : Yojson.Safe.t -> Yojson.Safe.t
val generate : ?n:int -> ?kv_heads:int -> ?timeout_ms:int -> name:string ->
  Unified_interpreter.Precedence.backend -> program -> Yojson.Safe.t
val replay_module : Ast.t -> Yojson.Safe.t -> int

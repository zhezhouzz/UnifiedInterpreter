module Ast = Hivm_trace.Module_ast
type stage = Source_scheduler.stage = HFusion | HIVM
type program =
  | Tensor of Hfusion_trace.t
  | Device of Hivm_trace.pairing
  | Module of stage * Ast.t * Yojson.Safe.t

(** 按名称运行 benchmark 时，使用 explicit 提供已经确定的启动参数。 *)
val explicit : Yojson.Safe.t -> Yojson.Safe.t
val generate : ?n:int -> ?kv_heads:int -> ?timeout_ms:int -> name:string ->
  Unified_interpreter.Precedence.backend -> program -> Yojson.Safe.t
val replay_module : Ast.t -> Yojson.Safe.t -> int

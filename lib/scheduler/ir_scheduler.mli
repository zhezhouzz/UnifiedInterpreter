module Ast = Hivm_trace.Module_ast
type stage = HFusion | HIVM
type program =
  | Tensor of Hfusion_trace.t
  | Device of Hivm_trace.pairing
  | Module of stage * Ast.t * Yojson.Safe.t

(** Module 的第三个参数描述启动方式。直接使用解释器输入时调用 explicit。
    所有输入均通过内存传递，两个方向共享同一个输入。 *)
val explicit : Yojson.Safe.t -> Yojson.Safe.t
val generate : ?n:int -> ?kv_heads:int -> ?timeout_ms:int -> name:string ->
  Unified_interpreter.Precedence.backend -> program -> Yojson.Safe.t
val replay_module : Ast.t -> Yojson.Safe.t -> int

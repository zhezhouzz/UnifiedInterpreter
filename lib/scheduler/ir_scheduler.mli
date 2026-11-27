(** 解释器传入解析所得的 HIVM 或 HFusion 模块 AST 和具体启动参数。 *)
module Source = Source_scheduler
module Ast = Source.Ast
type stage = Source.stage = HFusion | HIVM
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

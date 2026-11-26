module Ast = Attention_runtime.Parser
type buffer = {
  allocation : string; elements : int; initialized : bool;
  offset : int; shape : int list; strides : int list;
}
type argument = Buffer of buffer | Integer of int | Parameter | Float of float
type launch = (string * argument) list list
type event = { stream : int; entry : string; path : int list; opcode : string;
               iterations : int list }
type race = { first : event; second : event; forward : event list; reverse : event list }
type status = Complete | Race | No_race | Unknown of string
type report = { entry : string; launch : launch; n : Z.t option; status : status; races : race list }
type backend = Bfs | Smt | Symbolic
type t
val prepare : Ast.program -> launch -> t
val generate : ?n:Z.t -> ?timeout_ms:int -> backend -> t -> report
val resolve : Ast.program -> int list -> Ast.operation
val scheduling_point : t -> stream:int -> path:int list -> bool
val replay : ?n:Z.t -> t -> event list -> unit
val verify_race : ?n:Z.t -> t -> race -> unit
val to_json : report -> Yojson.Safe.t
val launch_of_json : Yojson.Safe.t -> launch
val read_ast : string -> Ast.program
val replay_report : Ast.program -> Yojson.Safe.t -> int

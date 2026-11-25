type value = int * string
type operation = {
  opcode : string; operands : int list; results : value list;
  attributes : (string * string) list; properties : (string * string) list;
  regions : block list list;
}
and block = {arguments : value list; body : operation list}
type catalog_origin = {benchmark:string; model_digest:string;
                       sites:(string * (int list * int list) list) list}
type t = private {digest : string; attributes : (string * string) list; functions : (string * operation) list;
                  catalog_origin:catalog_origin option}
val read : string -> t
val entry : t -> string -> block
val resolve : t -> entry:string -> int list -> operation

(** 使用解释器已有的 HIVM 节点类型，按操作、region、block 下标定位。 *)
val resolve_in : body:'op list -> region_block:('op -> int -> int -> 'op list) ->
  int list -> 'op

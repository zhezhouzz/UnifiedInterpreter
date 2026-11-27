type value = int * string
type shaped_kind = Tensor | Memref | Vector
type layout = Identity | Strided of int option * int option list | Opaque_layout
type shaped_type = {
  kind : shaped_kind; shape : int option list; element : string;
  layout : layout; space : string option;
}
type typ = Integer of int | Float of int | Shaped of shaped_type | Opaque
type operation = {
  opcode : string; operands : int list; results : value list;
  attributes : (string * string) list; properties : (string * string) list;
  regions : block list list;
  literals : (string * Yojson.Safe.t) list;
  decoded : (string * Yojson.Safe.t) list;
  generic : bool;
  span : Attention_runtime.Source.span option;
  location : string option;
}
and block = {arguments : value list; body : operation list}
type catalog_origin = {benchmark:string; model_digest:string;
                       sites:(string * (int list * int list) list) list}
type t = private {digest : string; format : string; attributes : (string * string) list; functions : (string * operation) list;
                  catalog_origin : catalog_origin option; types : (string * Yojson.Safe.t) list;
                  mlir_types : (string * typ) list; source_sha256 : string option}
type syntax = Custom | Generic | BiSheng of string | Auto of string
val parse : ?syntax:syntax -> file:string -> string -> t
val read : string -> t
val of_json : Yojson.Safe.t -> t
val scheduling_json : t -> Yojson.Safe.t
val execution_json : t -> Yojson.Safe.t
val entry : t -> string -> block
val resolve : t -> entry:string -> int list -> operation

(** 使用解释器已有的 HIVM 节点类型，按操作、region、block 下标定位。 *)
val resolve_in : body:'op list -> region_block:('op -> int -> int -> 'op list) ->
  int list -> 'op

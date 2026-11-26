type dtype = I1 | I8 | I16 | I32 | I64 | F16 | F32
type space = GM of int | UB | Vector_ub of int | L1 | L0A | L0B | L0C
type pipe = S | V | M | MTE1 | MTE2 | MTE3 | FIX
type core = Cube | Vector of int
type location = { block : int; core : core }
type packing = Norm | Pk | Pk4
type layout = { element : dtype; lane_bits : int }
type binary = Add | Sub | Mul | Div | Rem | Min | Max | And | Or | Xor | Shr
type comparison = Eq | Ne | Lt | Le | Ge | Gt

type expr =
  | Var of string
  | Int of dtype * int64
  | Float of dtype * float
  | Block | Subblock
  | Range of expr * int
  | Broadcast of expr * int
  | Binary of binary * expr * expr
  | Compare of comparison * expr * expr
  | Select of expr * expr * expr
  | Cast of dtype * expr | Bitcast of dtype * expr
  | Layout_cast of layout * expr
  | Register_group of int * expr
  | Pge of int | Plt of int * expr
  | Splat_lane of expr * int * int
  | Reduce_max of expr
  | Buffer of space * dtype * expr * expr list * expr list
  | Strided_view of expr * expr * expr list * expr list
  | Reinterpret_view of expr * expr * expr list * expr list
  | Slice of expr * expr list * expr list * expr list
  | Reshape of expr * expr list
  | Read of expr * expr list * int
  | Empty_tensor of dtype * expr list
  | Tensor_fill of expr * expr
  | Tensor_range of expr * expr list * expr
  | Tensor_compare of comparison * expr * expr * expr
  | Tensor_get of expr * expr list
  | Tensor_insert of expr * expr list * expr
  | Gather_tensor of expr * expr * expr * expr * expr
  | Counter of string

type channel = Local | Cross
type instruction =
  | Let of string * expr
  | Interleave of string * string * expr * expr
  | Let_plt of string * string * int * expr
  | Advance_counter of string
  | If of expr * instruction list * instruction list
  | For of loop
  | Issue of pipe * string * instruction list
  | Set of channel * pipe * pipe * expr
  | Wait of channel * pipe * pipe * expr
  | Barrier of pipe list
  | Control of int * bool
  | Debug of string * expr
  | Store of expr * expr list * expr
  | Masked_store of expr * expr list * expr * expr * packing
  | Copy of expr * expr
  | Copy_tensor of expr * expr
  | Fill of expr * expr
  | Indirect_load of expr * expr * expr * expr * expr
  | Indirect_store of expr * expr * expr * expr
  | Scatter_tensor of expr * expr * expr * expr
  | Nd2nz of expr * expr
  | Mmad of expr * expr * expr * expr * int * int * int * bool
  | Fixpipe_row_split of expr * expr * expr
and loop = {
  index : string; index_type : dtype; lo : expr; hi : expr; step : expr;
  carried : (string * expr) list; body : instruction list; yield : expr list;
}

type stream = { location : location; body : instruction list }
type program = { name : string; register_bytes : int; streams : stream list }

let bits = function I1 -> 1 | I8 -> 8 | I16 | F16 -> 16 | I32 | F32 -> 32 | I64 -> 64
let pipe_name = function S -> "S" | V -> "V" | M -> "M" | MTE1 -> "MTE1"
  | MTE2 -> "MTE2" | MTE3 -> "MTE3" | FIX -> "FIX"
let core_name = function Cube -> "cube" | Vector i -> "vector" ^ string_of_int i
let dtype_name = function I1 -> "i1" | I8 -> "i8" | I16 -> "i16" | I32 -> "i32"
  | I64 -> "i64" | F16 -> "f16" | F32 -> "f32"
let pack_name = function Norm -> "norm" | Pk -> "pk" | Pk4 -> "pk4"

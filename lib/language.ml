(* Unified shallow-embedded language shared by all handlers. *)

type dtype = F32 | F16ish | BF16ish

let pp_dtype = function F32 -> "f32" | F16ish -> "f16ish" | BF16ish -> "bf16ish"

type int_binary = IAdd | IMul

type int_cmp = ILt

type float_binary = FAdd | FSub | FMul | FDiv

type reduction = Max | Sum

type elementwise = Exp | Sqrt | Relu

type source = {
  title : string;
  url : string;
  note : string;
}

type program = unit -> unit

type case = {
  id : string;
  title : string;
  source : source;
  source_text : string;
  grid : int;
  inputs : (string * Tensor.t) list;
  output : string;
  output_dims : int list;
  program : program;
}

let ceil_div x y = (x + y - 1) / y

let pp_int_binary = function IAdd -> "iadd" | IMul -> "imul"

let pp_int_cmp = function ILt -> "ilt"

let pp_float_binary = function
  | FAdd -> "fadd"
  | FSub -> "fsub"
  | FMul -> "fmul"
  | FDiv -> "fdiv"

let pp_reduction = function Max -> "max" | Sum -> "sum"

let pp_elementwise = function Exp -> "exp" | Sqrt -> "sqrt" | Relu -> "relu"

let ibroadcast width value = Array.make width value

let fbroadcast width value = Array.make width value

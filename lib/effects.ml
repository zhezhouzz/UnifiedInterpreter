(* Unified effect vocabulary. Programs are shallow OCaml terms that perform
   these operations; H1-H4 decide how each operation is executed or lowered. *)

open Effect
open Language

type load = {
  ptr : string;
  offsets : int array;
  mask : bool array option;
  other : float;
}

type store = {
  ptr : string;
  offsets : int array;
  values : float array;
  mask : bool array option;
}

type async_copy = {
  core : int;
  global : string;
  local : string;
  offsets : int array;
  mask : bool array option;
}

type _ Effect.t += Trace : string -> unit Effect.t
type _ Effect.t += Program_id : int -> int Effect.t
type _ Effect.t += Arange : int * int -> int array Effect.t
type _ Effect.t += Int_binop : int_binary * int array * int array -> int array Effect.t
type _ Effect.t += Int_cmp : int_cmp * int array * int array -> bool array Effect.t
type _ Effect.t += Load : load -> float array Effect.t
type _ Effect.t += Store : store -> unit Effect.t
type _ Effect.t += Float_binop : float_binary * float array * float array * dtype -> float array Effect.t
type _ Effect.t += Float_map : elementwise * float array * dtype -> float array Effect.t
type _ Effect.t += Reduce : reduction * float array * bool array option * dtype -> float Effect.t
type _ Effect.t += Alloc_local : int * string * int -> unit Effect.t
type _ Effect.t += Async_copy_in : async_copy -> unit Effect.t
type _ Effect.t += Async_copy_out : async_copy -> unit Effect.t
type _ Effect.t += Wait : int * string -> unit Effect.t
type _ Effect.t += Barrier : int * string -> unit Effect.t

let trace msg = perform (Trace msg)

let program_id axis = perform (Program_id axis)

let arange start stop = perform (Arange (start, stop))

let int_binop op lhs rhs = perform (Int_binop (op, lhs, rhs))

let iadd lhs rhs = int_binop IAdd lhs rhs

let imul lhs rhs = int_binop IMul lhs rhs

let int_cmp op lhs rhs = perform (Int_cmp (op, lhs, rhs))

let ilt lhs rhs = int_cmp ILt lhs rhs

let load ~ptr ~offsets ?mask ~other () =
  perform (Load { ptr; offsets; mask; other })

let store ~ptr ~offsets ~values ?mask () =
  perform (Store { ptr; offsets; values; mask })

let float_binop ?(dtype = F32) op lhs rhs =
  perform (Float_binop (op, lhs, rhs, dtype))

let fadd ?dtype lhs rhs = float_binop ?dtype FAdd lhs rhs

let fsub ?dtype lhs rhs = float_binop ?dtype FSub lhs rhs

let fmul ?dtype lhs rhs = float_binop ?dtype FMul lhs rhs

let fdiv ?dtype lhs rhs = float_binop ?dtype FDiv lhs rhs

let float_map ?(dtype = F32) op values = perform (Float_map (op, values, dtype))

let exp ?dtype values = float_map ?dtype Exp values

let sqrt ?dtype values = float_map ?dtype Sqrt values

let relu ?dtype values = float_map ?dtype Relu values

let reduce ?(dtype = F32) op values ?mask () =
  perform (Reduce (op, values, mask, dtype))

let reduce_max ?dtype values ?mask () = reduce ?dtype Max values ?mask ()

let reduce_sum ?dtype values ?mask () = reduce ?dtype Sum values ?mask ()

let alloc_local core name cells = perform (Alloc_local (core, name, cells))

let async_copy_in copy = perform (Async_copy_in copy)

let async_copy_out copy = perform (Async_copy_out copy)

let wait core token = perform (Wait (core, token))

let barrier core scope = perform (Barrier (core, scope))

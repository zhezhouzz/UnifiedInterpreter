(* Effect vocabulary: the observable actions an interpreter can handle. *)

open Effect

type dtype = Language.dtype = F32 | F16ish | BF16ish
type binary = Language.binary = Add | Mul
type reduction = Language.reduction = Max | Sum
type elementwise = Language.elementwise = Exp | Sqrt | Relu

let pp_dtype = Language.pp_dtype

  type vector_binop = {
    core : int option;
    op : binary;
    lhs : float array;
    rhs : float array;
    mask : bool array option;
    dtype : dtype;
  }

  type vector_fma = {
    core : int option;
    acc : float array;
    a : float array;
    b : float array;
    mask : bool array option;
    dtype : dtype;
  }

  type vector_reduce = {
    core : int option;
    op : reduction;
    values : float array;
    mask : bool array option;
    dtype : dtype;
  }

  type vector_map = {
    core : int option;
    op : elementwise;
    values : float array;
    dtype : dtype;
  }

  type copy_plan = {
    core : int;
    local : string;
    global : string;
    pairs : (int list * int list) list;
  }

  type _ Effect.t += Trace : string -> unit Effect.t
  type _ Effect.t += Read_tensor : string * int list -> float Effect.t
  type _ Effect.t += Write_tensor : string * int list * float -> unit Effect.t
  type _ Effect.t += Launch_core : int * (unit -> unit) -> unit Effect.t
  type _ Effect.t += Masked_load : string * int list array * bool array * float -> float array Effect.t
  type _ Effect.t += Masked_store : string * int list array * bool array * float array -> unit Effect.t
  type _ Effect.t += Vector_binop : vector_binop -> float array Effect.t
  type _ Effect.t += Vector_fma : vector_fma -> float array Effect.t
  type _ Effect.t += Vector_reduce : vector_reduce -> float Effect.t
  type _ Effect.t += Vector_map : vector_map -> float array Effect.t
  type _ Effect.t += Cast : dtype * dtype * float -> float Effect.t
  type _ Effect.t += Alloc_local : int * string * int list -> unit Effect.t
  type _ Effect.t += Read_local : int * string * int list -> float Effect.t
  type _ Effect.t += Write_local : int * string * int list * float -> unit Effect.t
  type _ Effect.t += Async_copy_in : copy_plan -> unit Effect.t
  type _ Effect.t += Async_copy_out : copy_plan -> unit Effect.t
  type _ Effect.t += Wait : int * string -> unit Effect.t
  type _ Effect.t += Barrier : int * string -> unit Effect.t

  let trace msg = perform (Trace msg)

  let read_tensor name idx = perform (Read_tensor (name, idx))

  let write_tensor name idx value = perform (Write_tensor (name, idx, value))

  let launch_core core body = perform (Launch_core (core, body))

  let masked_load name indices mask other = perform (Masked_load (name, indices, mask, other))

  let masked_store name indices mask values = perform (Masked_store (name, indices, mask, values))

  let vector_binop core op lhs rhs mask dtype =
    perform (Vector_binop { core; op; lhs; rhs; mask; dtype })

  let vector_fma core acc a b mask dtype = perform (Vector_fma { core; acc; a; b; mask; dtype })

  let vector_reduce core op values mask dtype = perform (Vector_reduce { core; op; values; mask; dtype })

  let vector_map core op values dtype = perform (Vector_map { core; op; values; dtype })

  let cast from_dtype to_dtype value = perform (Cast (from_dtype, to_dtype, value))

  let alloc_local core name dims = perform (Alloc_local (core, name, dims))

  let read_local core name idx = perform (Read_local (core, name, idx))

  let write_local core name idx value = perform (Write_local (core, name, idx, value))

  let async_copy_in plan = perform (Async_copy_in plan)

  let async_copy_out plan = perform (Async_copy_out plan)

  let wait core token = perform (Wait (core, token))

  let barrier core scope = perform (Barrier (core, scope))

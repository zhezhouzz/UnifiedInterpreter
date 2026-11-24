(* Target B (Refunctionalization): Core Language AST, refocusing, and native
   OCaml 5 Effect.t signature mirroring rocq/CoreLanguage/Derived/{Refocusing,CoreEffects}.v. *)

type positive =
  | XI of positive
  | XO of positive
  | XH

let rec pos_succ = function
  | XI p -> XO (pos_succ p)
  | XO p -> XI p
  | XH -> XO XH

let rec pos_of_succ_nat n =
  if n <= 0 then XH else pos_succ (pos_of_succ_nat (n - 1))

let rec pos_to_nat = function
  | XH -> 1
  | XO p -> 2 * pos_to_nat p
  | XI p -> (2 * pos_to_nat p) + 1

let rec pos_eq a b =
  match (a, b) with
  | XH, XH -> true
  | XO x, XO y | XI x, XI y -> pos_eq x y
  | _ -> false

let pp_positive p = string_of_int (pos_to_nat p)

type var = int
type op_id = positive * positive

let op_id_eq (t1, p1) (t2, p2) = pos_eq t1 t2 && pos_eq p1 p2

let pp_op_id (t, p) = Printf.sprintf "(%s,%s)" (pp_positive t) (pp_positive p)

type memory_resource = int

type allocation_site =
  | Before_run of int
  | In_branch of op_id

type allocation_layout = allocation_site -> memory_resource

let cantor_to_nat (x, y) =
  let s = x + y in
  y + (s * (s + 1) / 2)

let odd_address = function
  | Before_run k -> (4 * k) + 1
  | In_branch (j, path) ->
      (4 * cantor_to_nat (pos_to_nat j, pos_to_nat path)) + 3

let odd_allocation_layout : allocation_layout = odd_address

type atomic_op =
  | Int_add
  | Int_sub
  | Int_mul
  | Int_mod
  | Int_eq
  | Int_lt
  | Bool_not
  | Bool_and
  | Bool_or
  | Memory_at of memory_resource list

type ('unit_res, 'queue) execution = {
  resource : 'unit_res;
  queue : 'queue option;
}

let dispatch resource queue = { resource; queue }

type step_error =
  | Err_out_of_fuel
  | Err_refocus_stuck of int
  | Err_invalid_branch of int
  | Err_branch_not_runnable of int
  | Err_unbound_var of op_id * var
  | Err_type_mismatch of op_id
  | Err_invalid_atomic of op_id
  | Err_permission_denied of op_id
  | Err_alloc_already_written of op_id * memory_resource
  | Err_early_async_use of op_id * op_id
  | Err_uninit_memory_read of op_id * memory_resource
  | Err_compute_undefined of op_id
  | Err_pipe_blocked of op_id
  | Err_inflight_not_found of op_id
  | Err_set_flag_deps_pending of op_id
  | Err_flag_not_ready of op_id
  | Err_deadlocked

let pp_step_error = function
  | Err_out_of_fuel -> "ErrOutOfFuel"
  | Err_refocus_stuck j -> Printf.sprintf "ErrRefocusStuck(%d)" j
  | Err_invalid_branch j -> Printf.sprintf "ErrInvalidBranch(%d)" j
  | Err_branch_not_runnable j -> Printf.sprintf "ErrBranchNotRunnable(%d)" j
  | Err_unbound_var (o, x) ->
      Printf.sprintf "ErrUnboundVar(%s,%d)" (pp_op_id o) x
  | Err_type_mismatch o -> Printf.sprintf "ErrTypeMismatch(%s)" (pp_op_id o)
  | Err_invalid_atomic o -> Printf.sprintf "ErrInvalidAtomic(%s)" (pp_op_id o)
  | Err_permission_denied o ->
      Printf.sprintf "ErrPermissionDenied(%s)" (pp_op_id o)
  | Err_alloc_already_written (o, a) ->
      Printf.sprintf "ErrAllocAlreadyWritten(%s,%d)" (pp_op_id o) a
  | Err_early_async_use (c, p) ->
      Printf.sprintf "ErrEarlyAsyncUse(%s,%s)" (pp_op_id c) (pp_op_id p)
  | Err_uninit_memory_read (o, a) ->
      Printf.sprintf "ErrUninitMemoryRead(%s,%d)" (pp_op_id o) a
  | Err_compute_undefined o ->
      Printf.sprintf "ErrComputeUndefined(%s)" (pp_op_id o)
  | Err_pipe_blocked o -> Printf.sprintf "ErrPipeBlocked(%s)" (pp_op_id o)
  | Err_inflight_not_found o ->
      Printf.sprintf "ErrInflightNotFound(%s)" (pp_op_id o)
  | Err_set_flag_deps_pending o ->
      Printf.sprintf "ErrSetFlagDepsPending(%s)" (pp_op_id o)
  | Err_flag_not_ready o -> Printf.sprintf "ErrFlagNotReady(%s)" (pp_op_id o)
  | Err_deadlocked -> "ErrDeadlocked"

let z_mod a b =
  let r = a mod b in
  if b > 0 then if r < 0 then r + b else r
  else if r > 0 then r + b
  else r

module type TYPES = sig
  type float_val
  type event_id
  type pipe
  type unit_res

  val pipe_eq : pipe -> pipe -> bool
  val event_eq : event_id -> event_id -> bool
end

module Make (T : TYPES) = struct
  type value =
    | V_int of int
    | V_float of T.float_val
    | V_bool of bool
    | V_event of T.event_id
    | V_pipe of T.pipe
    | V_memory of memory_resource

  type operand =
    | Literal of value
    | O_var of var

  type command =
    | Return of operand list
    | C_alias of var * operand * command
    | Alloc of var * command
    | Let_atomic of var * atomic_op * operand list * command
    | Select of var * operand * operand * operand * command
    | Assign_pipe of var * operand * command
    | C_compute of var * (T.unit_res, operand) execution * operand list * command
    | Read of var * (T.unit_res, operand) execution * operand * command
    | Write of (T.unit_res, operand) execution * operand * operand * command
    | Set_flag of operand * operand * operand * command
    | Wait_flag of operand * operand * operand * command
    | For of var * int * int * command * command
    | Loop_end
    | If of operand * command * command

  type program = command list

  type shared_program =
    | Run of program
    | Shared_alloc of var * shared_program

  let rec instantiate_shared (layout : allocation_layout) (index : int) =
    function
    | Run branches -> branches
    | Shared_alloc (x, body) ->
        let addr = layout (Before_run index) in
        List.map
          (fun c -> C_alias (x, Literal (V_memory addr), c))
          (instantiate_shared layout (index + 1) body)

  type label =
    | L_read_start of (T.unit_res, T.pipe) execution * memory_resource
    | L_read_end of value
    | L_write_start of (T.unit_res, T.pipe) execution * memory_resource * value
    | L_write_end
    | L_compute_start of (T.unit_res, T.pipe) execution * value list
    | L_compute_end of value
    | L_atomic of atomic_op * value list * value
    | L_alloc of memory_resource
    | L_set_flag_start of T.pipe * T.pipe * T.event_id
    | L_set_flag_end
    | L_wait_flag_start of T.pipe * T.pipe * T.event_id
    | L_wait_flag_end
    | L_branch of bool
    | L_return of value list
    | L_pipe_assignment of var * T.pipe

  type event_record = {
    owner : op_id;
    payload : label;
  }

  type binding =
    | Known of value
    | Async of op_id

  type env = var -> binding option

  let empty_env : env = fun _ -> None

  let bind (rho : env) (x : var) (b : binding) : env =
   fun y -> if y = x then Some b else rho y

  let resolve (rho : env) = function
    | Literal v -> Some (Known v)
    | O_var x -> rho x

  type use_record = {
    consumer : op_id;
    operand_index : int;
    producer : op_id;
    used_value : value;
  }

  let eval_atomic (f : atomic_op) (args : value list) : value option =
    match (f, args) with
    | Int_add, [ V_int a; V_int b ] -> Some (V_int (a + b))
    | Int_sub, [ V_int a; V_int b ] -> Some (V_int (a - b))
    | Int_mul, [ V_int a; V_int b ] -> Some (V_int (a * b))
    | Int_mod, [ V_int a; V_int b ] ->
        if b = 0 then None else Some (V_int (z_mod a b))
    | Int_eq, [ V_int a; V_int b ] -> Some (V_bool (a = b))
    | Int_lt, [ V_int a; V_int b ] -> Some (V_bool (a < b))
    | Bool_not, [ V_bool b ] -> Some (V_bool (not b))
    | Bool_and, [ V_bool a; V_bool b ] -> Some (V_bool (a && b))
    | Bool_or, [ V_bool a; V_bool b ] -> Some (V_bool (a || b))
    | Memory_at inputs, [ V_int i ] ->
        if i < 0 then None
        else Option.map (fun a -> V_memory a) (List.nth_opt inputs i)
    | _ -> None

  type loop_frame = K_loop of var * int * int * command * command

  type thread_cursor = {
    cursor_tid : positive;
    cursor_path : positive;
    cursor_env : env;
    cursor_cmd : command;
    cursor_stack : loop_frame list;
  }

  let is_event_head = function
    | Return _ | Alloc _ | Let_atomic _ | Assign_pipe _ | C_compute _ | Read _
    | Write _ | Set_flag _ | Wait_flag _ | If _ ->
        true
    | C_alias _ | Select _ | For _ | Loop_end -> false

  let rec refocus (budget : int) (cur : thread_cursor) : thread_cursor option =
    if budget <= 0 then None
    else
      let budget' = budget - 1 in
      let tid = cur.cursor_tid in
      let path = cur.cursor_path in
      let rho = cur.cursor_env in
      let stk = cur.cursor_stack in
      match cur.cursor_cmd with
      | C_alias (x, v, n) -> (
          match resolve rho v with
          | Some b ->
              refocus budget'
                {
                  cursor_tid = tid;
                  cursor_path = XO path;
                  cursor_env = bind rho x b;
                  cursor_cmd = n;
                  cursor_stack = stk;
                }
          | None -> None)
      | Select (x, cond, yes, no, n) -> (
          match resolve rho cond with
          | Some (Known (V_bool b)) -> (
              match resolve rho (if b then yes else no) with
              | Some sel ->
                  refocus budget'
                    {
                      cursor_tid = tid;
                      cursor_path = XO path;
                      cursor_env = bind rho x sel;
                      cursor_cmd = n;
                      cursor_stack = stk;
                    }
              | None -> None)
          | _ -> None)
      | For (x, lo, hi, body, after) ->
          if hi <= lo then
            refocus budget'
              {
                cursor_tid = tid;
                cursor_path = path;
                cursor_env = rho;
                cursor_cmd = after;
                cursor_stack = stk;
              }
          else
            refocus budget'
              {
                cursor_tid = tid;
                cursor_path = XO path;
                cursor_env = bind rho x (Known (V_int lo));
                cursor_cmd = body;
                cursor_stack = K_loop (x, lo + 1, hi, body, after) :: stk;
              }
      | Loop_end -> (
          match stk with
          | K_loop (x, next_i, hi, body, after) :: rest ->
              refocus budget'
                {
                  cursor_tid = tid;
                  cursor_path = path;
                  cursor_env = rho;
                  cursor_cmd = For (x, next_i, hi, body, after);
                  cursor_stack = rest;
                }
          | [] -> None)
      | _ -> Some cur

  (* Refunctionalized OCaml 5 algebraic effects (1-to-1 with CoreEffects.v). *)
  type _ Effect.t +=
    | E_alloc : op_id -> memory_resource Effect.t
    | E_atomic : op_id * env * atomic_op * operand list -> value Effect.t
    | E_assign_pipe : op_id * env * var * operand -> T.pipe Effect.t
    | E_issue_read :
        op_id * env * (T.unit_res, operand) execution * operand
        -> unit Effect.t
    | E_issue_write :
        op_id * env * (T.unit_res, operand) execution * operand * operand
        -> unit Effect.t
    | E_issue_compute :
        op_id * env * (T.unit_res, operand) execution * operand list
        -> unit Effect.t
    | E_issue_set_flag :
        op_id * env * operand * operand * operand
        -> unit Effect.t
    | E_await_flag :
        op_id * env * operand * operand * operand
        -> unit Effect.t
    | E_branch : op_id * env * operand -> bool Effect.t
    | E_return : op_id * env * operand list -> value list Effect.t

  (* Direct-style branch evaluator running natively on an OCaml 5 fiber stack.
     Every Free.Trigger from CoreEffects.v becomes an Effect.perform. *)
  let rec eval_branch ~refocus_budget ~branch_idx (cur : thread_cursor) :
      (value list, step_error) result =
    match refocus refocus_budget cur with
    | None -> Error (Err_refocus_stuck branch_idx)
    | Some cur' -> (
        let tid = cur'.cursor_tid in
        let path = cur'.cursor_path in
        let rho = cur'.cursor_env in
        let stk = cur'.cursor_stack in
        let o = (tid, path) in
        match cur'.cursor_cmd with
        | Alloc (x, n) ->
            let addr = Effect.perform (E_alloc o) in
            eval_branch ~refocus_budget ~branch_idx
              {
                cursor_tid = tid;
                cursor_path = XO path;
                cursor_env = bind rho x (Known (V_memory addr));
                cursor_cmd = n;
                cursor_stack = stk;
              }
        | Let_atomic (x, f, vs, n) ->
            let res = Effect.perform (E_atomic (o, rho, f, vs)) in
            eval_branch ~refocus_budget ~branch_idx
              {
                cursor_tid = tid;
                cursor_path = XO path;
                cursor_env = bind rho x (Known res);
                cursor_cmd = n;
                cursor_stack = stk;
              }
        | Assign_pipe (x, v, n) ->
            let p = Effect.perform (E_assign_pipe (o, rho, x, v)) in
            eval_branch ~refocus_budget ~branch_idx
              {
                cursor_tid = tid;
                cursor_path = XO path;
                cursor_env = bind rho x (Known (V_pipe p));
                cursor_cmd = n;
                cursor_stack = stk;
              }
        | Read (x, d, v, n) ->
            Effect.perform (E_issue_read (o, rho, d, v));
            eval_branch ~refocus_budget ~branch_idx
              {
                cursor_tid = tid;
                cursor_path = XO path;
                cursor_env = bind rho x (Async o);
                cursor_cmd = n;
                cursor_stack = stk;
              }
        | Write (d, v1, v2, n) ->
            Effect.perform (E_issue_write (o, rho, d, v1, v2));
            eval_branch ~refocus_budget ~branch_idx
              {
                cursor_tid = tid;
                cursor_path = XO path;
                cursor_env = rho;
                cursor_cmd = n;
                cursor_stack = stk;
              }
        | C_compute (x, d, vs, n) ->
            Effect.perform (E_issue_compute (o, rho, d, vs));
            eval_branch ~refocus_budget ~branch_idx
              {
                cursor_tid = tid;
                cursor_path = XO path;
                cursor_env = bind rho x (Async o);
                cursor_cmd = n;
                cursor_stack = stk;
              }
        | Set_flag (src, dst, v, n) ->
            Effect.perform (E_issue_set_flag (o, rho, src, dst, v));
            eval_branch ~refocus_budget ~branch_idx
              {
                cursor_tid = tid;
                cursor_path = XO path;
                cursor_env = rho;
                cursor_cmd = n;
                cursor_stack = stk;
              }
        | Wait_flag (src, dst, v, n) ->
            Effect.perform (E_await_flag (o, rho, src, dst, v));
            eval_branch ~refocus_budget ~branch_idx
              {
                cursor_tid = tid;
                cursor_path = XO path;
                cursor_env = rho;
                cursor_cmd = n;
                cursor_stack = stk;
              }
        | If (cond, y, n) ->
            let b = Effect.perform (E_branch (o, rho, cond)) in
            eval_branch ~refocus_budget ~branch_idx
              {
                cursor_tid = tid;
                cursor_path = (if b then XO path else XI path);
                cursor_env = rho;
                cursor_cmd = (if b then y else n);
                cursor_stack = stk;
              }
        | Return vs ->
            let args = Effect.perform (E_return (o, rho, vs)) in
            Ok args
        | C_alias _ | Select _ | For _ | Loop_end ->
            Error (Err_refocus_stuck branch_idx))
end

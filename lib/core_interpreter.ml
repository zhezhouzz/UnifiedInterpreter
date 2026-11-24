(* Target B (Refunctionalization): OCaml 5 Effect.Deep layered handlers and
   cooperative fiber scheduler mirroring rocq/CoreLanguage/Derived/Handlers.v. *)

open Core_effects

type thread_status =
  | St_running
  | St_waiting of op_id
  | St_done

type schedule_action =
  | Act_issue of int
  | Act_finish of op_id

type 's policy_decision =
  | Pol_step of schedule_action * 's
  | Pol_stop
  | Pol_stuck

type schedule_policy =
  | Policy : {
      init : 's;
      next :
        's ->
        thread_status list ->
        (op_id * bool) list ->
        (int * bool) list ->
        's policy_decision;
    }
      -> schedule_policy

let is_status_done = function St_done -> true | _ -> false

let rec find_first_enabled_op = function
  | [] -> None
  | (o, true) :: _ -> Some o
  | (_, false) :: rest -> find_first_enabled_op rest

let rec find_first_enabled_branch = function
  | [] -> None
  | (j, true) :: _ -> Some j
  | (_, false) :: rest -> find_first_enabled_branch rest

let rec take n xs =
  if n <= 0 then []
  else match xs with [] -> [] | x :: rest -> x :: take (n - 1) rest

let rec drop n xs =
  if n <= 0 then xs else match xs with [] -> [] | _ :: rest -> drop (n - 1) rest

let find_enabled_branch_from start xs =
  let n = List.length xs in
  if n = 0 then None
  else
    let k = start mod n in
    find_first_enabled_branch (drop k xs @ take k xs)

let serialized_policy : schedule_policy =
  Policy
    {
      init = ();
      next =
        (fun () statuses inflight_info branch_info ->
          if List.for_all is_status_done statuses && inflight_info = [] then
            Pol_stop
          else
            match find_first_enabled_op inflight_info with
            | Some o -> Pol_step (Act_finish o, ())
            | None -> (
                match find_first_enabled_branch branch_info with
                | Some j -> Pol_step (Act_issue j, ())
                | None -> Pol_stuck));
    }

let overlapped_round_robin_policy (max_inflight : int) : schedule_policy =
  Policy
    {
      init = 0;
      next =
        (fun cursor statuses inflight_info branch_info ->
          if List.for_all is_status_done statuses && inflight_info = [] then
            Pol_stop
          else if List.length inflight_info < max_inflight then
            match find_enabled_branch_from cursor branch_info with
            | Some j -> Pol_step (Act_issue j, j + 1)
            | None -> (
                match find_first_enabled_op inflight_info with
                | Some o -> Pol_step (Act_finish o, cursor)
                | None -> Pol_stuck)
          else
            match find_first_enabled_op inflight_info with
            | Some o -> Pol_step (Act_finish o, cursor)
            | None -> (
                match find_enabled_branch_from cursor branch_info with
                | Some j -> Pol_step (Act_issue j, j + 1)
                | None -> Pol_stuck));
    }

let scripted_policy (script : schedule_action list) : schedule_policy =
  Policy
    {
      init = script;
      next =
        (fun remaining _ _ _ ->
          match remaining with
          | [] -> Pol_stop
          | act :: rest -> Pol_step (act, rest));
    }

let rec lookup_assoc eq k = function
  | [] -> None
  | (k', v) :: rest -> if eq k k' then Some v else lookup_assoc eq k rest

let rec remove_assoc eq k = function
  | [] -> []
  | (k', v) :: rest ->
      if eq k k' then remove_assoc eq k rest else (k', v) :: remove_assoc eq k rest

let rec update_nth idx x = function
  | [] -> []
  | hd :: tl -> if idx = 0 then x :: tl else hd :: update_nth (idx - 1) x tl

let ( let* ) r f = match r with Ok x -> f x | Error e -> Error e

module Make (T : TYPES) = struct
  module E = Core_effects.Make (T)

  type executable_target = {
    check_declared_pipe : T.pipe -> bool;
    check_declared_resource : T.unit_res -> bool;
    check_can_read : T.unit_res -> memory_resource -> bool;
    check_can_write : T.unit_res -> memory_resource -> bool;
  }

  type executable_model = T.unit_res -> E.value list -> E.value option

  type choice_policy = {
    pick_early_async : op_id -> int -> op_id -> E.value option;
    pick_uninit_mem : memory_resource -> E.value option;
  }

  let strict_choice_policy (init_mem : memory_resource -> E.value option) :
      choice_policy =
    { pick_early_async = (fun _ _ _ -> None); pick_uninit_mem = init_mem }

  let permissive_choice_policy (init_mem : memory_resource -> E.value option)
      (early_oracle : op_id -> int -> op_id -> E.value)
      (uninit_default : E.value) : choice_policy =
    {
      pick_early_async = (fun c idx p -> Some (early_oracle c idx p));
      pick_uninit_mem =
        (fun a ->
          match init_mem a with Some v -> Some v | None -> Some uninit_default);
    }

  type pending_kind =
    | P_read of (T.unit_res, T.pipe) execution * memory_resource
    | P_write of (T.unit_res, T.pipe) execution * memory_resource * E.value
    | P_compute of (T.unit_res, T.pipe) execution * E.value list
    | P_set_flag of T.pipe * T.pipe * T.event_id * op_id list
    | P_wait_flag of T.pipe * T.pipe * T.event_id * int

  type flag_key = (T.pipe * T.pipe) * T.event_id

  let flag_key_eq ((p1, q1), e1) ((p2, q2), e2) =
    T.pipe_eq p1 p2 && T.pipe_eq q1 q2 && T.event_eq e1 e2

  type sync_state = {
    sync_inflight : (op_id * pending_kind) list;
    sync_flags : flag_key list;
    sync_active_wait : (T.pipe * op_id) list;
  }

  let empty_sync_state =
    { sync_inflight = []; sync_flags = []; sync_active_wait = [] }

  type mem_state = {
    mem_writes : (memory_resource * E.value) list;
    mem_done_val : (op_id * E.value) list;
  }

  let empty_mem_state = { mem_writes = []; mem_done_val = [] }

  type suspend_mode =
    | Mode_continue
    | Mode_wait_flag of op_id
    | Mode_return

  type 'a effect_outcome = {
    eo_value : 'a;
    eo_event : E.event_record;
    eo_uses : E.use_record list;
    eo_sync : sync_state;
    eo_mem : mem_state;
    eo_mode : suspend_mode;
  }

  type run_result = {
    rr_events : E.event_record list;
    rr_uses : E.use_record list;
    rr_outputs : E.value list option list;
    rr_inflight_count : int;
  }

  (* --- Layer 1: Memory & Allocation Handler --- *)
  module Memory_handler = struct
    let mem_lookup a mem = lookup_assoc Int.equal a mem.mem_writes

    let resolve_operand (cpol : choice_policy) (dv : (op_id * E.value) list)
        (rho : E.env) (o : op_id) (idx : int) (v : E.operand) :
        (E.value * E.use_record list, step_error) result =
      match E.resolve rho v with
      | None -> (
          match v with
          | O_var x -> Error (Err_unbound_var (o, x))
          | Literal _ -> Error (Err_type_mismatch o))
      | Some (Known a) -> Ok (a, [])
      | Some (Async r) -> (
          match lookup_assoc op_id_eq r dv with
          | Some res ->
              Ok
                ( res,
                  [
                    {
                      consumer = o;
                      operand_index = idx;
                      producer = r;
                      used_value = res;
                    };
                  ] )
          | None -> (
              match cpol.pick_early_async o idx r with
              | Some res ->
                  Ok
                    ( res,
                      [
                        {
                          consumer = o;
                          operand_index = idx;
                          producer = r;
                          used_value = res;
                        };
                      ] )
              | None -> Error (Err_early_async_use (o, r))))

    let rec resolve_operands cpol dv rho o idx = function
      | [] -> Ok ([], [])
      | v :: rest ->
          let* a, u1 = resolve_operand cpol dv rho o idx v in
          let* args, u2 = resolve_operands cpol dv rho o (idx + 1) rest in
          Ok (a :: args, u1 @ u2)

    let resolve_exec cpol dv rho o vs = function
      | None ->
          let* args, uses = resolve_operands cpol dv rho o 0 vs in
          Ok (None, args, uses)
      | Some qop -> (
          let* all, uses = resolve_operands cpol dv rho o 0 (qop :: vs) in
          match all with
          | V_pipe p :: args -> Ok (Some p, args, uses)
          | _ -> Error (Err_type_mismatch o))

    let handle_alloc (layout : allocation_layout) (o : op_id)
        (sync : sync_state) (mem : mem_state) :
        (memory_resource effect_outcome, step_error) result =
      let addr = layout (In_branch o) in
      match mem_lookup addr mem with
      | Some _ -> Error (Err_alloc_already_written (o, addr))
      | None ->
          Ok
            {
              eo_value = addr;
              eo_event = { owner = o; payload = L_alloc addr };
              eo_uses = [];
              eo_sync = sync;
              eo_mem = mem;
              eo_mode = Mode_continue;
            }

    let finish_read (cpol : choice_policy) (o : op_id) (a : memory_resource)
        (inflight' : (op_id * pending_kind) list) (sync : sync_state)
        (mem : mem_state) =
      let ov =
        match mem_lookup a mem with
        | Some v -> Some v
        | None -> cpol.pick_uninit_mem a
      in
      match ov with
      | None -> Error (Err_uninit_memory_read (o, a))
      | Some res ->
          let ev : E.event_record = { owner = o; payload = L_read_end res } in
          let sync' = { sync with sync_inflight = inflight' } in
          let mem' = { mem with mem_done_val = (o, res) :: mem.mem_done_val } in
          Ok (ev, sync', mem', None)

    let finish_write (o : op_id) (a : memory_resource) (data : E.value)
        (inflight' : (op_id * pending_kind) list) (sync : sync_state)
        (mem : mem_state) =
      let ev : E.event_record = { owner = o; payload = L_write_end } in
      let sync' = { sync with sync_inflight = inflight' } in
      let mem' = { mem with mem_writes = (a, data) :: mem.mem_writes } in
      Ok (ev, sync', mem', None)
  end

  (* --- Layer 2: Scalar Compute & Branch Control Handler --- *)
  module Compute_and_val_handler = struct
    let handle_atomic cpol o rho f vs sync mem =
      let* args, uses =
        Memory_handler.resolve_operands cpol mem.mem_done_val rho o 0 vs
      in
      match E.eval_atomic f args with
      | None -> Error (Err_invalid_atomic o)
      | Some res ->
          Ok
            {
              eo_value = res;
              eo_event = { owner = o; payload = L_atomic (f, args, res) };
              eo_uses = uses;
              eo_sync = sync;
              eo_mem = mem;
              eo_mode = Mode_continue;
            }

    let handle_assign_pipe tgt cpol o rho x v sync mem =
      let* val_, uses =
        Memory_handler.resolve_operand cpol mem.mem_done_val rho o 0 v
      in
      match val_ with
      | V_pipe p ->
          if tgt.check_declared_pipe p then
            Ok
              {
                eo_value = p;
                eo_event = { owner = o; payload = L_pipe_assignment (x, p) };
                eo_uses = uses;
                eo_sync = sync;
                eo_mem = mem;
                eo_mode = Mode_continue;
              }
          else Error (Err_permission_denied o)
      | _ -> Error (Err_type_mismatch o)

    let handle_branch cpol o rho cond sync mem =
      let* val_, uses =
        Memory_handler.resolve_operand cpol mem.mem_done_val rho o 0 cond
      in
      match val_ with
      | V_bool b ->
          Ok
            {
              eo_value = b;
              eo_event = { owner = o; payload = L_branch b };
              eo_uses = uses;
              eo_sync = sync;
              eo_mem = mem;
              eo_mode = Mode_continue;
            }
      | _ -> Error (Err_type_mismatch o)

    let handle_return cpol o rho vs sync mem =
      let* args, uses =
        Memory_handler.resolve_operands cpol mem.mem_done_val rho o 0 vs
      in
      Ok
        {
          eo_value = args;
          eo_event = { owner = o; payload = L_return args };
          eo_uses = uses;
          eo_sync = sync;
          eo_mem = mem;
          eo_mode = Mode_return;
        }

    let finish_compute (emodel : executable_model) (o : op_id)
        (d : (T.unit_res, T.pipe) execution) (args : E.value list)
        (inflight' : (op_id * pending_kind) list) (sync : sync_state)
        (mem : mem_state) =
      match emodel d.resource args with
      | None -> Error (Err_compute_undefined o)
      | Some res ->
          let ev : E.event_record = { owner = o; payload = L_compute_end res } in
          let sync' = { sync with sync_inflight = inflight' } in
          let mem' = { mem with mem_done_val = (o, res) :: mem.mem_done_val } in
          Ok (ev, sync', mem', None)
  end

  (* --- Layer 3: Async Pipeline & Flag Synchronization Handler --- *)
  module Sync_handler = struct
    let pending_pipe = function
      | P_read (d, _) | P_write (d, _, _) | P_compute (d, _) -> d.queue
      | P_set_flag (p, _, _, _) -> Some p
      | P_wait_flag (_, q, _, _) -> Some q

    let inflight_on_pipe p inf =
      List.filter_map
        (fun (o, pk) ->
          match pending_pipe pk with
          | Some q when T.pipe_eq p q -> Some o
          | _ -> None)
        inf

    let deps_drained deps inf =
      List.for_all
        (fun d -> Option.is_none (lookup_assoc op_id_eq d inf))
        deps

    let flag_is_set p q fl flags =
      List.exists (fun k -> flag_key_eq ((p, q), fl) k) flags

    let flag_set_true p q fl flags = ((p, q), fl) :: flags

    let flag_set_false p q fl flags =
      List.filter (fun k -> not (flag_key_eq ((p, q), fl) k)) flags

    let active_wait_of q aw = lookup_assoc T.pipe_eq q aw
    let active_wait_set q w aw = (q, w) :: aw
    let active_wait_clear q aw = remove_assoc T.pipe_eq q aw

    let check_pipe_ready tgt aw o = function
      | None -> Ok ()
      | Some q ->
          if tgt.check_declared_pipe q then
            match active_wait_of q aw with
            | None -> Ok ()
            | Some _ -> Error (Err_pipe_blocked o)
          else Error (Err_permission_denied o)

    let handle_issue_read tgt cpol o rho (d : (T.unit_res, E.operand) execution)
        v sync mem =
      let* p, args, uses =
        Memory_handler.resolve_exec cpol mem.mem_done_val rho o [ v ] d.queue
      in
      match args with
      | [ V_memory a ] ->
          if tgt.check_declared_resource d.resource && tgt.check_can_read d.resource a
          then
            let* () = check_pipe_ready tgt sync.sync_active_wait o p in
            let disp = dispatch d.resource p in
            let sync' =
              { sync with sync_inflight = (o, P_read (disp, a)) :: sync.sync_inflight }
            in
            Ok
              {
                eo_value = ();
                eo_event = { owner = o; payload = L_read_start (disp, a) };
                eo_uses = uses;
                eo_sync = sync';
                eo_mem = mem;
                eo_mode = Mode_continue;
              }
          else Error (Err_permission_denied o)
      | _ -> Error (Err_type_mismatch o)

    let handle_issue_write tgt cpol o rho
        (d : (T.unit_res, E.operand) execution) v1 v2 sync mem =
      let* p, args, uses =
        Memory_handler.resolve_exec cpol mem.mem_done_val rho o [ v1; v2 ] d.queue
      in
      match args with
      | [ V_memory a; data ] ->
          if tgt.check_declared_resource d.resource && tgt.check_can_write d.resource a
          then
            let* () = check_pipe_ready tgt sync.sync_active_wait o p in
            let disp = dispatch d.resource p in
            let sync' =
              {
                sync with
                sync_inflight = (o, P_write (disp, a, data)) :: sync.sync_inflight;
              }
            in
            Ok
              {
                eo_value = ();
                eo_event = { owner = o; payload = L_write_start (disp, a, data) };
                eo_uses = uses;
                eo_sync = sync';
                eo_mem = mem;
                eo_mode = Mode_continue;
              }
          else Error (Err_permission_denied o)
      | _ -> Error (Err_type_mismatch o)

    let handle_issue_compute tgt cpol o rho
        (d : (T.unit_res, E.operand) execution) vs sync mem =
      let* p, args, uses =
        Memory_handler.resolve_exec cpol mem.mem_done_val rho o vs d.queue
      in
      if tgt.check_declared_resource d.resource then
        let* () = check_pipe_ready tgt sync.sync_active_wait o p in
        let disp = dispatch d.resource p in
        let sync' =
          {
            sync with
            sync_inflight = (o, P_compute (disp, args)) :: sync.sync_inflight;
          }
        in
        Ok
          {
            eo_value = ();
            eo_event = { owner = o; payload = L_compute_start (disp, args) };
            eo_uses = uses;
            eo_sync = sync';
            eo_mem = mem;
            eo_mode = Mode_continue;
          }
      else Error (Err_permission_denied o)

    let handle_set_flag tgt cpol o rho src dst v sync mem =
      let* args, uses =
        Memory_handler.resolve_operands cpol mem.mem_done_val rho o 0 [ src; dst; v ]
      in
      match args with
      | [ V_pipe p; V_pipe q; V_event fl ] ->
          if tgt.check_declared_pipe p && tgt.check_declared_pipe q then
            let* () = check_pipe_ready tgt sync.sync_active_wait o (Some p) in
            let deps = inflight_on_pipe p sync.sync_inflight in
            let sync' =
              {
                sync with
                sync_inflight =
                  (o, P_set_flag (p, q, fl, deps)) :: sync.sync_inflight;
              }
            in
            Ok
              {
                eo_value = ();
                eo_event = { owner = o; payload = L_set_flag_start (p, q, fl) };
                eo_uses = uses;
                eo_sync = sync';
                eo_mem = mem;
                eo_mode = Mode_continue;
              }
          else Error (Err_permission_denied o)
      | _ -> Error (Err_type_mismatch o)

    let handle_await_flag tgt cpol j o rho src dst v sync mem =
      let* args, uses =
        Memory_handler.resolve_operands cpol mem.mem_done_val rho o 0 [ src; dst; v ]
      in
      match args with
      | [ V_pipe p; V_pipe q; V_event fl ] ->
          if tgt.check_declared_pipe p && tgt.check_declared_pipe q then
            let* () = check_pipe_ready tgt sync.sync_active_wait o (Some q) in
            let sync' =
              {
                sync_inflight =
                  (o, P_wait_flag (p, q, fl, j)) :: sync.sync_inflight;
                sync_flags = sync.sync_flags;
                sync_active_wait = active_wait_set q o sync.sync_active_wait;
              }
            in
            Ok
              {
                eo_value = ();
                eo_event = { owner = o; payload = L_wait_flag_start (p, q, fl) };
                eo_uses = uses;
                eo_sync = sync';
                eo_mem = mem;
                eo_mode = Mode_wait_flag o;
              }
          else Error (Err_permission_denied o)
      | _ -> Error (Err_type_mismatch o)

    let finish_set_flag o p q fl deps inflight' sync mem =
      if deps_drained deps sync.sync_inflight then
        if not (flag_is_set p q fl sync.sync_flags) then
          let ev : E.event_record = { owner = o; payload = L_set_flag_end } in
          let sync' =
            {
              sync_inflight = inflight';
              sync_flags = flag_set_true p q fl sync.sync_flags;
              sync_active_wait = sync.sync_active_wait;
            }
          in
          Ok (ev, sync', mem, None)
        else Error (Err_flag_not_ready o)
      else Error (Err_set_flag_deps_pending o)

    let finish_wait_flag o p q fl j inflight' sync mem =
      if flag_is_set p q fl sync.sync_flags then
        let ev : E.event_record = { owner = o; payload = L_wait_flag_end } in
        let sync' =
          {
            sync_inflight = inflight';
            sync_flags = flag_set_false p q fl sync.sync_flags;
            sync_active_wait = active_wait_clear q sync.sync_active_wait;
          }
        in
        Ok (ev, sync', mem, Some j)
      else Error (Err_flag_not_ready o)
  end

  (* --- Layer 4: OCaml 5 Effect.Deep Cooperative Fiber Scheduler --- *)
  module Scheduler_handler = struct
    type _ effect_req =
      | Req_alloc : op_id -> memory_resource effect_req
      | Req_atomic : op_id * E.env * atomic_op * E.operand list -> E.value effect_req
      | Req_assign_pipe : op_id * E.env * var * E.operand -> T.pipe effect_req
      | Req_issue_read :
          op_id * E.env * (T.unit_res, E.operand) execution * E.operand
          -> unit effect_req
      | Req_issue_write :
          op_id * E.env * (T.unit_res, E.operand) execution * E.operand * E.operand
          -> unit effect_req
      | Req_issue_compute :
          op_id * E.env * (T.unit_res, E.operand) execution * E.operand list
          -> unit effect_req
      | Req_issue_set_flag :
          op_id * E.env * E.operand * E.operand * E.operand
          -> unit effect_req
      | Req_await_flag :
          op_id * E.env * E.operand * E.operand * E.operand
          -> unit effect_req
      | Req_branch : op_id * E.env * E.operand -> bool effect_req
      | Req_return : op_id * E.env * E.operand list -> E.value list effect_req

    type paused_effect =
      | Paused :
          'a effect_req * ('a, fiber_step) Effect.Deep.continuation
          -> paused_effect

    and fiber_step =
      | Fiber_suspended of paused_effect
      | Fiber_done of E.value list
      | Fiber_error of step_error

    type fiber_state =
      | Fiber_running of paused_effect
      | Fiber_waiting of op_id * paused_effect
      | Fiber_finished of E.value list

    type machine_state = {
      threads : fiber_state list;
      sync : sync_state;
      mem : mem_state;
      rev_trace : E.event_record list;
      rev_uses : E.use_record list;
    }

    let handle_core_req (type a) layout tgt cpol j (req : a effect_req) sync mem
        : (a effect_outcome, step_error) result =
      match req with
      | Req_alloc o -> Memory_handler.handle_alloc layout o sync mem
      | Req_atomic (o, rho, f, vs) ->
          Compute_and_val_handler.handle_atomic cpol o rho f vs sync mem
      | Req_assign_pipe (o, rho, x, v) ->
          Compute_and_val_handler.handle_assign_pipe tgt cpol o rho x v sync mem
      | Req_issue_read (o, rho, d, v) ->
          Sync_handler.handle_issue_read tgt cpol o rho d v sync mem
      | Req_issue_write (o, rho, d, v1, v2) ->
          Sync_handler.handle_issue_write tgt cpol o rho d v1 v2 sync mem
      | Req_issue_compute (o, rho, d, vs) ->
          Sync_handler.handle_issue_compute tgt cpol o rho d vs sync mem
      | Req_issue_set_flag (o, rho, s, d, v) ->
          Sync_handler.handle_set_flag tgt cpol o rho s d v sync mem
      | Req_await_flag (o, rho, s, d, v) ->
          Sync_handler.handle_await_flag tgt cpol j o rho s d v sync mem
      | Req_branch (o, rho, cond) ->
          Compute_and_val_handler.handle_branch cpol o rho cond sync mem
      | Req_return (o, rho, vs) ->
          Compute_and_val_handler.handle_return cpol o rho vs sync mem

    let handle_finish_req emodel cpol o sync mem =
      match lookup_assoc op_id_eq o sync.sync_inflight with
      | None -> Error (Err_inflight_not_found o)
      | Some pk -> (
          let inflight' = remove_assoc op_id_eq o sync.sync_inflight in
          match pk with
          | P_read (_, a) ->
              Memory_handler.finish_read cpol o a inflight' sync mem
          | P_write (_, a, data) ->
              Memory_handler.finish_write o a data inflight' sync mem
          | P_compute (d, args) ->
              Compute_and_val_handler.finish_compute emodel o d args inflight'
                sync mem
          | P_set_flag (p, q, fl, deps) ->
              Sync_handler.finish_set_flag o p q fl deps inflight' sync mem
          | P_wait_flag (p, q, fl, j) ->
              Sync_handler.finish_wait_flag o p q fl j inflight' sync mem)

    (* Capture each direct-style branch as an OCaml 5 Effect.Deep fiber. *)
    let spawn_fiber ~refocus_budget ~branch_idx (cur : E.thread_cursor) :
        fiber_step =
      Effect.Deep.match_with
        (fun () -> E.eval_branch ~refocus_budget ~branch_idx cur)
        ()
        {
          retc =
            (function
            | Ok args -> Fiber_done args | Error err -> Fiber_error err);
          exnc = raise;
          effc =
            (fun (type a) (eff : a Effect.t) ->
              match eff with
              | E.E_alloc o ->
                  Some
                    (fun (k : (a, fiber_step) Effect.Deep.continuation) ->
                      Fiber_suspended (Paused (Req_alloc o, k)))
              | E.E_atomic (o, rho, f, vs) ->
                  Some
                    (fun (k : (a, fiber_step) Effect.Deep.continuation) ->
                      Fiber_suspended (Paused (Req_atomic (o, rho, f, vs), k)))
              | E.E_assign_pipe (o, rho, x, v) ->
                  Some
                    (fun (k : (a, fiber_step) Effect.Deep.continuation) ->
                      Fiber_suspended
                        (Paused (Req_assign_pipe (o, rho, x, v), k)))
              | E.E_issue_read (o, rho, d, v) ->
                  Some
                    (fun (k : (a, fiber_step) Effect.Deep.continuation) ->
                      Fiber_suspended
                        (Paused (Req_issue_read (o, rho, d, v), k)))
              | E.E_issue_write (o, rho, d, v1, v2) ->
                  Some
                    (fun (k : (a, fiber_step) Effect.Deep.continuation) ->
                      Fiber_suspended
                        (Paused (Req_issue_write (o, rho, d, v1, v2), k)))
              | E.E_issue_compute (o, rho, d, vs) ->
                  Some
                    (fun (k : (a, fiber_step) Effect.Deep.continuation) ->
                      Fiber_suspended
                        (Paused (Req_issue_compute (o, rho, d, vs), k)))
              | E.E_issue_set_flag (o, rho, s, d, v) ->
                  Some
                    (fun (k : (a, fiber_step) Effect.Deep.continuation) ->
                      Fiber_suspended
                        (Paused (Req_issue_set_flag (o, rho, s, d, v), k)))
              | E.E_await_flag (o, rho, s, d, v) ->
                  Some
                    (fun (k : (a, fiber_step) Effect.Deep.continuation) ->
                      Fiber_suspended
                        (Paused (Req_await_flag (o, rho, s, d, v), k)))
              | E.E_branch (o, rho, cond) ->
                  Some
                    (fun (k : (a, fiber_step) Effect.Deep.continuation) ->
                      Fiber_suspended (Paused (Req_branch (o, rho, cond), k)))
              | E.E_return (o, rho, vs) ->
                  Some
                    (fun (k : (a, fiber_step) Effect.Deep.continuation) ->
                      Fiber_suspended (Paused (Req_return (o, rho, vs), k)))
              | _ -> None);
        }

    let init_fibers ~refocus_budget (branches : E.program) :
        (machine_state, step_error) result =
      let rec go idx = function
        | [] -> Ok []
        | c :: rest -> (
            let cur0 : E.thread_cursor =
              {
                cursor_tid = pos_of_succ_nat idx;
                cursor_path = XH;
                cursor_env = E.empty_env;
                cursor_cmd = c;
                cursor_stack = [];
              }
            in
            match spawn_fiber ~refocus_budget ~branch_idx:idx cur0 with
            | Fiber_error err -> Error err
            | Fiber_done args ->
                let* ts = go (idx + 1) rest in
                Ok (Fiber_finished args :: ts)
            | Fiber_suspended paused ->
                let* ts = go (idx + 1) rest in
                Ok (Fiber_running paused :: ts))
      in
      let* threads = go 0 branches in
      Ok
        {
          threads;
          sync = empty_sync_state;
          mem = empty_mem_state;
          rev_trace = [];
          rev_uses = [];
        }

    let fiber_status = function
      | Fiber_running _ -> St_running
      | Fiber_waiting (w, _) -> St_waiting w
      | Fiber_finished _ -> St_done

    let fiber_output = function Fiber_finished args -> Some args | _ -> None

    (* Pure probe: checks whether branch j can issue WITHOUT consuming the
       one-shot OCaml 5 continuation stored in Fiber_running. *)
    let probe_issue layout tgt cpol j st : bool =
      match List.nth_opt st.threads j with
      | Some (Fiber_running (Paused (req, _))) ->
          Result.is_ok (handle_core_req layout tgt cpol j req st.sync st.mem)
      | _ -> false

    let probe_finish emodel cpol o st : bool =
      match handle_finish_req emodel cpol o st.sync st.mem with
      | Error _ -> false
      | Ok (_, _, _, None) -> true
      | Ok (_, _, _, Some j) -> (
          match List.nth_opt st.threads j with
          | Some (Fiber_waiting (w, _)) -> op_id_eq w o
          | _ -> false)

    (* Commit Act_issue j: handle the suspended effect and resume the one-shot
       OCaml 5 Effect.Deep continuation exactly once. *)
    let step_issue layout tgt cpol j st :
        (E.event_record * machine_state, step_error) result =
      match List.nth_opt st.threads j with
      | None -> Error (Err_invalid_branch j)
      | Some (Fiber_finished _) | Some (Fiber_waiting _) ->
          Error (Err_branch_not_runnable j)
      | Some (Fiber_running (Paused (req, k))) ->
          let* out = handle_core_req layout tgt cpol j req st.sync st.mem in
          let next_step = Effect.Deep.continue k out.eo_value in
          let* next_ts =
            match (out.eo_mode, next_step) with
            | Mode_continue, Fiber_suspended paused' -> Ok (Fiber_running paused')
            | Mode_continue, Fiber_error err -> Error err
            | Mode_continue, Fiber_done args -> Ok (Fiber_finished args)
            | Mode_wait_flag w, Fiber_suspended paused' ->
                Ok (Fiber_waiting (w, paused'))
            | Mode_wait_flag _, Fiber_error err -> Error err
            | Mode_wait_flag _, Fiber_done _ -> Error (Err_refocus_stuck j)
            | Mode_return, Fiber_done args -> Ok (Fiber_finished args)
            | Mode_return, Fiber_error err -> Error err
            | Mode_return, Fiber_suspended _ -> Error (Err_refocus_stuck j)
          in
          let ev = out.eo_event in
          Ok
            ( ev,
              {
                threads = update_nth j next_ts st.threads;
                sync = out.eo_sync;
                mem = out.eo_mem;
                rev_trace = ev :: st.rev_trace;
                rev_uses = List.rev_append out.eo_uses st.rev_uses;
              } )

    let step_finish emodel cpol o st :
        (E.event_record * machine_state, step_error) result =
      let* ev, sync', mem', wake =
        handle_finish_req emodel cpol o st.sync st.mem
      in
      match wake with
      | None ->
          Ok
            ( ev,
              {
                st with
                sync = sync';
                mem = mem';
                rev_trace = ev :: st.rev_trace;
              } )
      | Some j -> (
          match List.nth_opt st.threads j with
          | Some (Fiber_waiting (w, paused)) when op_id_eq w o ->
              Ok
                ( ev,
                  {
                    st with
                    threads = update_nth j (Fiber_running paused) st.threads;
                    sync = sync';
                    mem = mem';
                    rev_trace = ev :: st.rev_trace;
                  } )
          | _ -> Error (Err_branch_not_runnable j))

    let run ~layout ~tgt ~emodel ~cpol ~policy ~step_fuel ~refocus_budget
        (prog : E.shared_program) : (run_result, step_error) result =
      let (Policy pol) = policy in
      let branches = E.instantiate_shared layout 0 prog in
      let* st0 = init_fibers ~refocus_budget branches in
      let rec loop fuel ps st =
        if fuel <= 0 then Error Err_out_of_fuel
        else
          let statuses = List.map fiber_status st.threads in
          let inflight_info =
            List.map
              (fun (o, _) -> (o, probe_finish emodel cpol o st))
              (List.rev st.sync.sync_inflight)
          in
          let branch_info =
            List.init (List.length st.threads) (fun j ->
                (j, probe_issue layout tgt cpol j st))
          in
          match pol.next ps statuses inflight_info branch_info with
          | Pol_stop ->
              Ok
                {
                  rr_events = List.rev st.rev_trace;
                  rr_uses = List.rev st.rev_uses;
                  rr_outputs = List.map fiber_output st.threads;
                  rr_inflight_count = List.length st.sync.sync_inflight;
                }
          | Pol_stuck -> Error Err_deadlocked
          | Pol_step (Act_issue j, ps') ->
              let* _, st' = step_issue layout tgt cpol j st in
              loop (fuel - 1) ps' st'
          | Pol_step (Act_finish o, ps') ->
              let* _, st' = step_finish emodel cpol o st in
              loop (fuel - 1) ps' st'
      in
      loop step_fuel pol.init st0
  end

  let run_effect_interpreter = Scheduler_handler.run
end

(* ========================================================================== *)
(* Built-in Verification Scenarios matching DerivedExamples.v                 *)
(* ========================================================================== *)

module Issue316 = struct
  type issue_pipe =
    | MTE2
    | Vector

  type issue_resource =
    | Transfer_engine
    | Vector_unit

  type 'f16 tile = 'f16 list

  let map_tile f xs = List.map f xs

  let pp_pipe = function MTE2 -> "MTE2" | Vector -> "Vector"

  let pp_resource = function
    | Transfer_engine -> "TransferEngine"
    | Vector_unit -> "VectorUnit"

  let input_addresses count = List.init count (fun i -> 2 * (i + 1))
  let output : memory_resource = 0
  let buffer_a (layout : allocation_layout) = layout (Before_run 0)
  let buffer_b (layout : allocation_layout) = layout (Before_run 1)

  let is_buffer layout a = a = buffer_a layout || a = buffer_b layout

  module Types_int = struct
    type float_val = int tile
    type event_id = int
    type pipe = issue_pipe
    type unit_res = issue_resource

    let pipe_eq a b = a = b
    let event_eq = Int.equal
  end

  module Interp = Make (Types_int)
  open Interp.E

  let pipe_arg p = Literal (V_pipe p)
  let flag id = Literal (V_event id)
  let integer v = Literal (V_int v)

  let bufA = 0
  let bufB = 1
  let active = 2
  let i = 3
  let slot = 4
  let first = 5
  let buf = 6
  let ready = 7
  let free = 8
  let src = 9
  let x = 10
  let y = 11
  let s = 12
  let initialFirst = 13
  let initial = 14
  let current = O_var active

  let fence p next =
    Set_flag (p, p, flag 4, Wait_flag (p, p, flag 4, next))

  let choose_slot body =
    Let_atomic
      ( slot,
        Int_mod,
        [ O_var i; integer 2 ],
        Let_atomic
          ( first,
            Int_eq,
            [ O_var slot; integer 0 ],
            Select
              ( buf,
                O_var first,
                O_var bufA,
                O_var bufB,
                Select
                  ( ready,
                    O_var first,
                    flag 0,
                    flag 1,
                    Select (free, O_var first, flag 2, flag 3, body) ) ) ) )

  let load_iteration count =
    choose_slot
      (Let_atomic
         ( src,
           Memory_at (input_addresses count),
           [ O_var i ],
           Wait_flag
             ( pipe_arg Vector,
               current,
               O_var free,
               Read
                 ( x,
                   dispatch Transfer_engine (Some current),
                   O_var src,
                   fence current
                     (Write
                        ( dispatch Transfer_engine (Some current),
                          O_var buf,
                          O_var x,
                          Set_flag (current, pipe_arg Vector, O_var ready, Loop_end)
                        )) ) ) ))

  let vector_iteration =
    choose_slot
      (Wait_flag
         ( pipe_arg MTE2,
           current,
           O_var ready,
           Read
             ( x,
               dispatch Vector_unit (Some current),
               O_var buf,
               fence current
                 (C_compute
                    ( y,
                      dispatch Vector_unit (Some current),
                      [ O_var x ],
                      fence current
                        (Write
                           ( dispatch Vector_unit (Some current),
                             Literal (V_memory output),
                             O_var y,
                             fence current
                               (Set_flag
                                  (current, pipe_arg MTE2, O_var free, Loop_end))
                           )) )) ) ))

  let initially_free =
    Let_atomic
      ( initialFirst,
        Int_eq,
        [ O_var s; integer 0 ],
        Select
          ( initial,
            O_var initialFirst,
            flag 2,
            flag 3,
            Set_flag (current, pipe_arg MTE2, O_var initial, Loop_end) ) )

  let issue316 count : shared_program =
    Shared_alloc
      ( bufA,
        Shared_alloc
          ( bufB,
            Run
              [
                C_alias
                  ( active,
                    pipe_arg MTE2,
                    For (i, 0, count, load_iteration count, Return []) );
                C_alias
                  ( active,
                    pipe_arg Vector,
                    For
                      ( s,
                        0,
                        min 2 count,
                        initially_free,
                        For (i, 0, count, vector_iteration, Return []) ) );
              ] ) )

  let issue316_exec_target (layout : allocation_layout) (count : int) :
      Interp.executable_target =
    let inputs = input_addresses count in
    {
      check_declared_pipe = (fun _ -> true);
      check_declared_resource = (fun _ -> true);
      check_can_read =
        (fun r a ->
          match r with
          | Transfer_engine -> List.mem a inputs
          | Vector_unit -> is_buffer layout a);
      check_can_write =
        (fun r a ->
          match r with
          | Transfer_engine -> is_buffer layout a
          | Vector_unit -> a = output);
    }

  let issue316_exec_model (exp_fn : int -> int) : Interp.executable_model =
   fun r args ->
    match (r, args) with
    | Vector_unit, [ V_float xs ] -> Some (V_float (map_tile exp_fn xs))
    | _ -> None

  let vector_output_writes (evs : event_record list) : value list =
    List.concat_map
      (fun r ->
        match r.payload with
        | L_write_start ({ resource = Vector_unit; queue = Some Vector }, a, v)
          when a = output ->
            [ v ]
        | _ -> [])
      evs

  let max_inflight (evs : event_record list) : int =
    let rec go cur best = function
      | [] -> best
      | r :: rest ->
          let cur' =
            match r.payload with
            | L_read_start _ | L_write_start _ | L_compute_start _
            | L_set_flag_start _ | L_wait_flag_start _ ->
                cur + 1
            | L_read_end _ | L_write_end | L_compute_end _ | L_set_flag_end
            | L_wait_flag_end ->
                max 0 (cur - 1)
            | _ -> cur
          in
          go cur' (max best cur') rest
    in
    go 0 0 evs

  let nth_index_of n p xs =
    let rec go idx rem = function
      | [] -> None
      | x :: rest ->
          if p x then if rem = 0 then Some idx else go (idx + 1) (rem - 1) rest
          else go (idx + 1) rem rest
    in
    go 0 n xs

  let first_index_of p xs = nth_index_of 0 p xs

  let check_double_buffer_overlap (evs : event_record list) : bool =
    let bufA_addr = buffer_a odd_allocation_layout in
    let bufB_addr = buffer_b odd_allocation_layout in
    let is_mte2_read_from addr r =
      match r.payload with
      | L_read_start ({ resource = Transfer_engine; queue = Some MTE2 }, a) ->
          a = addr
      | _ -> false
    in
    let is_mte2_write_to addr r =
      match r.payload with
      | L_write_start ({ resource = Transfer_engine; queue = Some MTE2 }, a, _)
        ->
          a = addr
      | _ -> false
    in
    let is_vec_write_output r =
      match r.payload with
      | L_write_start ({ resource = Vector_unit; queue = Some Vector }, a, _) ->
          a = output
      | _ -> false
    in
    let is_set_flag_start src dst fl r =
      match r.payload with
      | L_set_flag_start (p, q, f) -> p = src && q = dst && f = fl
      | _ -> false
    in
    match
      ( first_index_of (is_mte2_read_from 4) evs,
        first_index_of (is_mte2_write_to bufB_addr) evs,
        first_index_of is_vec_write_output evs,
        nth_index_of 1 (is_set_flag_start Vector MTE2 2) evs,
        nth_index_of 1 (is_mte2_write_to bufA_addr) evs )
    with
    | ( Some idx_mte2_read1,
        Some idx_mte2_write_bufB,
        Some idx_vec_write0,
        Some idx_vec_release_bufA,
        Some idx_mte2_write_bufA_2 ) ->
        idx_mte2_read1 < idx_vec_write0
        && idx_mte2_write_bufB < idx_vec_release_bufA
        && idx_vec_release_bufA < idx_mte2_write_bufA_2
        && 2 <= max_inflight evs
    | _ -> false

  let demo_tile v : int tile = List.init 1024 (fun _ -> v)

  let demo_init_mem tile0 tile1 tile2 = function
    | 2 -> Some (V_float tile0)
    | 4 -> Some (V_float tile1)
    | 6 -> Some (V_float tile2)
    | _ -> None

  let run_demo ~policy =
    let cpol =
      Interp.strict_choice_policy
        (demo_init_mem (demo_tile 1) (demo_tile 2) (demo_tile 3))
    in
    Interp.run_effect_interpreter ~layout:odd_allocation_layout
      ~tgt:(issue316_exec_target odd_allocation_layout 3)
      ~emodel:(issue316_exec_model (fun x -> x + 100))
      ~cpol ~policy ~step_fuel:300 ~refocus_budget:32 (issue316 3)

  let pp_event (r : event_record) : string =
    let tag =
      match r.payload with
      | L_read_start (d, a) ->
          Printf.sprintf "ReadStart(%s,%s,addr=%d)" (pp_resource d.resource)
            (Option.fold ~none:"Direct" ~some:pp_pipe d.queue)
            a
      | L_read_end _ -> "ReadEnd"
      | L_write_start (d, a, _) ->
          Printf.sprintf "WriteStart(%s,%s,addr=%d)" (pp_resource d.resource)
            (Option.fold ~none:"Direct" ~some:pp_pipe d.queue)
            a
      | L_write_end -> "WriteEnd"
      | L_compute_start (d, _) ->
          Printf.sprintf "ComputeStart(%s,%s)" (pp_resource d.resource)
            (Option.fold ~none:"Direct" ~some:pp_pipe d.queue)
      | L_compute_end _ -> "ComputeEnd"
      | L_atomic _ -> "Atomic"
      | L_alloc a -> Printf.sprintf "Alloc(addr=%d)" a
      | L_set_flag_start (p, q, fl) ->
          Printf.sprintf "SetFlagStart(%s->%s,f=%d)" (pp_pipe p) (pp_pipe q) fl
      | L_set_flag_end -> "SetFlagEnd"
      | L_wait_flag_start (p, q, fl) ->
          Printf.sprintf "WaitFlagStart(%s->%s,f=%d)" (pp_pipe p) (pp_pipe q) fl
      | L_wait_flag_end -> "WaitFlagEnd"
      | L_branch b -> Printf.sprintf "Branch(%b)" b
      | L_return _ -> "Return"
      | L_pipe_assignment (x, p) ->
          Printf.sprintf "AssignPipe(v%d=%s)" x (pp_pipe p)
    in
    Printf.sprintf "%s:%s" (pp_op_id r.owner) tag
end

module Shared_resource = struct
  type empty_pipe = |

  module Types = struct
    type float_val = unit
    type event_id = int
    type pipe = empty_pipe
    type unit_res = unit

    let pipe_eq (a : empty_pipe) _ = match a with _ -> .
    let event_eq = Int.equal
  end

  module Interp = Make (Types)
  open Interp.E

  let branch : command =
    C_compute (0, dispatch () None, [], Return [])

  let shared_res_prog : shared_program = Run [ branch; branch ]

  let tgt : Interp.executable_target =
    {
      check_declared_pipe = (fun _ -> false);
      check_declared_resource = (fun _ -> true);
      check_can_read = (fun _ _ -> false);
      check_can_write = (fun _ _ -> false);
    }

  let emodel : Interp.executable_model = fun _ _ -> Some (V_float ())
  let cpol = Interp.strict_choice_policy (fun _ -> None)

  let run_order_01 () =
    Interp.run_effect_interpreter ~layout:odd_allocation_layout ~tgt ~emodel
      ~cpol ~policy:(scripted_policy [ Act_issue 0; Act_issue 1 ]) ~step_fuel:10
      ~refocus_budget:8 shared_res_prog

  let run_order_10 () =
    Interp.run_effect_interpreter ~layout:odd_allocation_layout ~tgt ~emodel
      ~cpol ~policy:(scripted_policy [ Act_issue 1; Act_issue 0 ]) ~step_fuel:10
      ~refocus_budget:8 shared_res_prog
end

module Memory_and_choice = struct
  module Types = struct
    type float_val = unit
    type event_id = int
    type pipe = bool
    type unit_res = unit

    let pipe_eq = Bool.equal
    let event_eq = Int.equal
  end

  module Interp = Make (Types)
  open Interp.E

  let open_tgt : Interp.executable_target =
    {
      check_declared_pipe = (fun _ -> true);
      check_declared_resource = (fun _ -> true);
      check_can_read = (fun _ _ -> true);
      check_can_write = (fun _ _ -> true);
    }

  let open_emodel : Interp.executable_model = fun _ _ -> Some (V_int 0)

  let overwrite_prog : shared_program =
    Shared_alloc
      ( 0,
        Run
          [
            Write
              ( dispatch () (Some (Literal (V_pipe true))),
                O_var 0,
                Literal (V_int 10),
                Write
                  ( dispatch () (Some (Literal (V_pipe true))),
                    O_var 0,
                    Literal (V_int 20),
                    Write
                      ( dispatch () (Some (Literal (V_pipe true))),
                        O_var 0,
                        Literal (V_int 40),
                        Return [] ) ) );
            Read (1, dispatch () None, O_var 0, Return [ O_var 1 ]);
          ] )

  let overwrite_script =
    [
      Act_issue 0;
      Act_finish (XH, XO XH);
      Act_issue 1;
      Act_issue 0;
      Act_finish (XH, XO (XO XH));
      Act_issue 0;
      Act_finish (XO XH, XO XH);
      Act_issue 1;
    ]

  let run_overwrite () =
    Interp.run_effect_interpreter ~layout:odd_allocation_layout ~tgt:open_tgt
      ~emodel:open_emodel
      ~cpol:(Interp.strict_choice_policy (fun _ -> None))
      ~policy:(scripted_policy overwrite_script) ~step_fuel:20 ~refocus_budget:8
      overwrite_prog

  let uninit_read_prog : shared_program =
    Run [ Read (0, dispatch () None, Literal (V_memory 42), Return [ O_var 0 ]) ]

  let run_uninit_strict_scripted () =
    Interp.run_effect_interpreter ~layout:odd_allocation_layout ~tgt:open_tgt
      ~emodel:open_emodel
      ~cpol:(Interp.strict_choice_policy (fun _ -> None))
      ~policy:(scripted_policy [ Act_issue 0; Act_finish (XH, XH) ])
      ~step_fuel:20 ~refocus_budget:8 uninit_read_prog

  let run_uninit_strict_deadlock () =
    Interp.run_effect_interpreter ~layout:odd_allocation_layout ~tgt:open_tgt
      ~emodel:open_emodel
      ~cpol:(Interp.strict_choice_policy (fun _ -> None))
      ~policy:serialized_policy ~step_fuel:20 ~refocus_budget:8 uninit_read_prog

  let run_uninit_permissive () =
    Interp.run_effect_interpreter ~layout:odd_allocation_layout ~tgt:open_tgt
      ~emodel:open_emodel
      ~cpol:
        (Interp.permissive_choice_policy (fun _ -> None)
           (fun _ _ _ -> V_int 0)
           (V_int 99))
      ~policy:serialized_policy ~step_fuel:20 ~refocus_budget:8 uninit_read_prog

  let early_async_prog : shared_program =
    Run [ Read (0, dispatch () None, Literal (V_memory 10), Return [ O_var 0 ]) ]

  let early_async_init_mem = function 10 -> Some (V_int 7) | _ -> None

  let run_early_async_strict () =
    Interp.run_effect_interpreter ~layout:odd_allocation_layout ~tgt:open_tgt
      ~emodel:open_emodel
      ~cpol:(Interp.strict_choice_policy early_async_init_mem)
      ~policy:(scripted_policy [ Act_issue 0; Act_issue 0 ]) ~step_fuel:20
      ~refocus_budget:8 early_async_prog

  let run_early_async_permissive () =
    Interp.run_effect_interpreter ~layout:odd_allocation_layout ~tgt:open_tgt
      ~emodel:open_emodel
      ~cpol:
        (Interp.permissive_choice_policy early_async_init_mem
           (fun _ _ _ -> V_int 777)
           (V_int 0))
      ~policy:(scripted_policy [ Act_issue 0; Act_issue 0; Act_finish (XH, XH) ])
      ~step_fuel:20 ~refocus_budget:8 early_async_prog

  let loop_alloc_prog : shared_program =
    Run [ For (0, 0, 2, Alloc (1, Loop_end), Return []) ]

  let run_loop_alloc () =
    Interp.run_effect_interpreter ~layout:odd_allocation_layout ~tgt:open_tgt
      ~emodel:open_emodel
      ~cpol:(Interp.strict_choice_policy (fun _ -> None))
      ~policy:serialized_policy ~step_fuel:20 ~refocus_budget:16 loop_alloc_prog
end

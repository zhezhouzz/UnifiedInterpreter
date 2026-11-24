(* Cross-validation test suite (Verification Ladder Step 3):
   Verifies bit-for-bit trace, use-record, output, and error agreement between
   Target A (Rocq-extracted Extracted_semantics.Derived_core_interpreter) and
   Target B (OCaml 5 Effect.Deep refunctionalized Unified_interpreter.Core_interpreter),
   plus the H1-H5 shallow interpreter bridge. *)

module Ext = Extracted_semantics.Derived_core_interpreter
module CE = Unified_interpreter.Core_effects
module CI = Unified_interpreter.Core_interpreter

(* --- Structural equality bridges between Target A (Ext) and Target B (CE/CI) --- *)

let rec ext_pos_to_int = function
  | Ext.XH -> 1
  | Ext.XO p -> 2 * ext_pos_to_int p
  | Ext.XI p -> (2 * ext_pos_to_int p) + 1

let ext_z_to_int = function
  | Ext.Z0 -> 0
  | Ext.Zpos p -> ext_pos_to_int p
  | Ext.Zneg p -> -(ext_pos_to_int p)

let ext_op_id (t, p) = (ext_pos_to_int t, ext_pos_to_int p)
let oc_op_id (t, p) = (CE.pos_to_nat t, CE.pos_to_nat p)

let atomic_op_eq (a : Ext.atomic_op) (b : CE.atomic_op) =
  match (a, b) with
  | Ext.IntAdd, CE.Int_add
  | Ext.IntSub, CE.Int_sub
  | Ext.IntMul, CE.Int_mul
  | Ext.IntMod, CE.Int_mod
  | Ext.IntEq, CE.Int_eq
  | Ext.IntLt, CE.Int_lt
  | Ext.BoolNot, CE.Bool_not
  | Ext.BoolAnd, CE.Bool_and
  | Ext.BoolOr, CE.Bool_or ->
      true
  | Ext.MemoryAt xs, CE.Memory_at ys -> xs = ys
  | _ -> false

let step_error_eq (a : Ext.step_error) (b : CE.step_error) =
  match (a, b) with
  | Ext.ErrOutOfFuel, CE.Err_out_of_fuel -> true
  | Ext.ErrDeadlocked, CE.Err_deadlocked -> true
  | Ext.ErrRefocusStuck i, CE.Err_refocus_stuck j -> i = j
  | Ext.ErrInvalidBranch i, CE.Err_invalid_branch j -> i = j
  | Ext.ErrBranchNotRunnable i, CE.Err_branch_not_runnable j -> i = j
  | Ext.ErrUnboundOperand o1, CE.Err_unbound_var (o2, _) ->
      ext_op_id o1 = oc_op_id o2
  | Ext.ErrEarlyAsyncUse (c1, p1), CE.Err_early_async_use (c2, p2) ->
      ext_op_id c1 = oc_op_id c2 && ext_op_id p1 = oc_op_id p2
  | Ext.ErrTypeMismatch o1, CE.Err_type_mismatch o2 ->
      ext_op_id o1 = oc_op_id o2
  | Ext.ErrInvalidAtomic o1, CE.Err_invalid_atomic o2 ->
      ext_op_id o1 = oc_op_id o2
  | Ext.ErrAllocAlreadyWritten (o1, a1), CE.Err_alloc_already_written (o2, a2) ->
      ext_op_id o1 = oc_op_id o2 && a1 = a2
  | Ext.ErrPermissionDenied o1, CE.Err_permission_denied o2 ->
      ext_op_id o1 = oc_op_id o2
  | Ext.ErrPipeBlockedByWait o1, CE.Err_pipe_blocked o2 ->
      ext_op_id o1 = oc_op_id o2
  | Ext.ErrInflightNotFound o1, CE.Err_inflight_not_found o2 ->
      ext_op_id o1 = oc_op_id o2
  | Ext.ErrSetFlagDepsPending o1, CE.Err_set_flag_deps_pending o2 ->
      ext_op_id o1 = oc_op_id o2
  | Ext.ErrFlagNotReady o1, CE.Err_flag_not_ready o2 ->
      ext_op_id o1 = oc_op_id o2
  | Ext.ErrUninitMemoryRead (o1, a1), CE.Err_uninit_memory_read (o2, a2) ->
      ext_op_id o1 = oc_op_id o2 && a1 = a2
  | Ext.ErrComputeUndefined o1, CE.Err_compute_undefined o2 ->
      ext_op_id o1 = oc_op_id o2
  | _ -> false

let list_eq eq xs ys =
  List.length xs = List.length ys && List.for_all2 eq xs ys

let option_eq eq a b =
  match (a, b) with
  | None, None -> true
  | Some x, Some y -> eq x y
  | _ -> false

let exec_eq unit_eq pipe_eq (a : ('u1, 'p1) Ext.execution)
    (b : ('u2, 'p2) CE.execution) =
  unit_eq a.resource b.resource && option_eq pipe_eq a.queue b.queue

module Compare (M : sig
  module T : CE.TYPES
  module Interp : module type of CI.Make (T)

  type ext_float
  type ext_event
  type ext_pipe
  type ext_unit

  val float_eq : ext_float -> T.float_val -> bool
  val event_eq : ext_event -> T.event_id -> bool
  val pipe_eq : ext_pipe -> T.pipe -> bool
  val unit_eq : ext_unit -> T.unit_res -> bool
end) =
struct
  module E = M.Interp.E

  let value_eq (a : (M.ext_float, M.ext_event, M.ext_pipe) Ext.value)
      (b : E.value) =
    match (a, b) with
    | Ext.VInt z, E.V_int n -> ext_z_to_int z = n
    | Ext.VFloat f1, E.V_float f2 -> M.float_eq f1 f2
    | Ext.VBool b1, E.V_bool b2 -> b1 = b2
    | Ext.VEvent e1, E.V_event e2 -> M.event_eq e1 e2
    | Ext.VPipe p1, E.V_pipe p2 -> M.pipe_eq p1 p2
    | Ext.VMemory m1, E.V_memory m2 -> m1 = m2
    | _ -> false

  let label_eq (a : (M.ext_float, M.ext_event, M.ext_pipe, M.ext_unit) Ext.label)
      (b : E.label) =
    match (a, b) with
    | Ext.LReadStart (d1, m1), E.L_read_start (d2, m2) ->
        exec_eq M.unit_eq M.pipe_eq d1 d2 && m1 = m2
    | Ext.LReadEnd v1, E.L_read_end v2 -> value_eq v1 v2
    | Ext.LWriteStart (d1, m1, v1), E.L_write_start (d2, m2, v2) ->
        exec_eq M.unit_eq M.pipe_eq d1 d2 && m1 = m2 && value_eq v1 v2
    | Ext.LWriteEnd, E.L_write_end -> true
    | Ext.LComputeStart (d1, vs1), E.L_compute_start (d2, vs2) ->
        exec_eq M.unit_eq M.pipe_eq d1 d2 && list_eq value_eq vs1 vs2
    | Ext.LComputeEnd v1, E.L_compute_end v2 -> value_eq v1 v2
    | Ext.LAtomic (f1, vs1, r1), E.L_atomic (f2, vs2, r2) ->
        atomic_op_eq f1 f2 && list_eq value_eq vs1 vs2 && value_eq r1 r2
    | Ext.LAlloc m1, E.L_alloc m2 -> m1 = m2
    | Ext.LSetFlagStart (p1, q1, e1), E.L_set_flag_start (p2, q2, e2) ->
        M.pipe_eq p1 p2 && M.pipe_eq q1 q2 && M.event_eq e1 e2
    | Ext.LSetFlagEnd, E.L_set_flag_end -> true
    | Ext.LWaitFlagStart (p1, q1, e1), E.L_wait_flag_start (p2, q2, e2) ->
        M.pipe_eq p1 p2 && M.pipe_eq q1 q2 && M.event_eq e1 e2
    | Ext.LWaitFlagEnd, E.L_wait_flag_end -> true
    | Ext.LBranch b1, E.L_branch b2 -> b1 = b2
    | Ext.LReturn vs1, E.L_return vs2 -> list_eq value_eq vs1 vs2
    | Ext.LPipeAssignment (x1, p1), E.L_pipe_assignment (x2, p2) ->
        x1 = x2 && M.pipe_eq p1 p2
    | _ -> false

  let event_eq (a : (M.ext_float, M.ext_event, M.ext_pipe, M.ext_unit) Ext.event_record)
      (b : E.event_record) =
    ext_op_id a.owner = oc_op_id b.owner && label_eq a.payload b.payload

  let use_eq (a : (M.ext_float, M.ext_event, M.ext_pipe) Ext.use_record)
      (b : E.use_record) =
    ext_op_id a.consumer = oc_op_id b.consumer
    && a.operand_index = b.operand_index
    && ext_op_id a.producer = oc_op_id b.producer
    && value_eq a.used_value b.used_value

  let assert_results_identical name
      (ext_res :
        ( Ext.step_error,
          (M.ext_float, M.ext_event, M.ext_pipe, M.ext_unit) Ext.run_result )
        Ext.result) (oc_res : (M.Interp.run_result, CE.step_error) result) =
    match (ext_res, oc_res) with
    | Ext.Error e1, Error e2 ->
        if not (step_error_eq e1 e2) then
          failwith (name ^ ": error mismatch between Target A and Target B")
    | Ext.Ok r1, Ok r2 ->
        if r1.rr_inflight_count <> r2.rr_inflight_count then
          failwith
            (Printf.sprintf "%s: inflight mismatch (%d vs %d)" name
               r1.rr_inflight_count r2.rr_inflight_count);
        if not (list_eq event_eq r1.rr_events r2.rr_events) then
          failwith
            (Printf.sprintf "%s: event trace mismatch (len %d vs %d)" name
               (List.length r1.rr_events) (List.length r2.rr_events));
        if not (list_eq use_eq r1.rr_uses r2.rr_uses) then
          failwith
            (Printf.sprintf "%s: use records mismatch (len %d vs %d)" name
               (List.length r1.rr_uses) (List.length r2.rr_uses));
        if not (list_eq (option_eq (list_eq value_eq)) r1.rr_outputs r2.rr_outputs)
        then failwith (name ^ ": outputs mismatch between Target A and Target B")
    | Ext.Ok _, Error e ->
        failwith
          (Printf.sprintf "%s: Target A Ok but Target B Error (%s)" name
             (CE.pp_step_error e))
    | Ext.Error _, Ok _ ->
        failwith (name ^ ": Target A Error but Target B Ok")
end

module Cmp_issue316 = Compare (struct
  module T = CI.Issue316.Types_int
  module Interp = CI.Issue316.Interp

  type ext_float = Ext.z Ext.tile
  type ext_event = int
  type ext_pipe = Ext.issue_pipe
  type ext_unit = Ext.issue_resource

  let float_eq (xs : Ext.z Ext.tile) (ys : int list) =
    list_eq (fun z n -> ext_z_to_int z = n) xs ys

  let event_eq = Int.equal

  let pipe_eq a b =
    match (a, b) with
    | Ext.MTE2, CI.Issue316.MTE2 | Ext.Vector, CI.Issue316.Vector -> true
    | _ -> false

  let unit_eq a b =
    match (a, b) with
    | Ext.TransferEngine, CI.Issue316.Transfer_engine
    | Ext.VectorUnit, CI.Issue316.Vector_unit ->
        true
    | _ -> false
end)

module Cmp_shared = Compare (struct
  module T = CI.Shared_resource.Types
  module Interp = CI.Shared_resource.Interp

  type ext_float = unit
  type ext_event = int
  type ext_pipe = Ext.empty_set
  type ext_unit = unit

  let float_eq () () = true
  let event_eq = Int.equal
  let pipe_eq (p : Ext.empty_set) _ = match p with _ -> .
  let unit_eq () () = true
end)

module Cmp_mem = Compare (struct
  module T = CI.Memory_and_choice.Types
  module Interp = CI.Memory_and_choice.Interp

  type ext_float = unit
  type ext_event = int
  type ext_pipe = bool
  type ext_unit = unit

  let float_eq () () = true
  let event_eq = Int.equal
  let pipe_eq = Bool.equal
  let unit_eq () () = true
end)

let () =
  (* 1. Issue #316 Serialized: Target A vs Target B (125 events bit-for-bit) *)
  let oc_ser = CI.Issue316.run_demo ~policy:CI.serialized_policy in
  Cmp_issue316.assert_results_identical "issue316_serialized"
    Ext.DerivedExtractionDemo.demo_issue316_serialized oc_ser;
  (match oc_ser with
  | Ok res ->
      assert (List.length res.rr_events = 125);
      assert (res.rr_inflight_count = 0);
      assert (CI.Issue316.max_inflight res.rr_events = 2);
      let outs =
        CI.Issue316.vector_output_writes res.rr_events
        |> List.map (function
             | CI.Issue316.Interp.E.V_float (x :: _) -> x
             | _ -> assert false)
      in
      assert (outs = [ 101; 102; 103 ])
  | Error e -> failwith (CE.pp_step_error e));

  (* 2. Issue #316 Overlapped: Target A (Derived & Free) vs Target B (Effect.Deep) *)
  let oc_ov =
    CI.Issue316.run_demo ~policy:(CI.overlapped_round_robin_policy 8)
  in
  Cmp_issue316.assert_results_identical "issue316_overlapped_derived"
    Ext.DerivedExtractionDemo.demo_issue316_overlapped oc_ov;
  Cmp_issue316.assert_results_identical "issue316_overlapped_free"
    Ext.DerivedExtractionDemo.demo_issue316_free_overlapped oc_ov;
  (match oc_ov with
  | Ok res ->
      assert (List.length res.rr_events = 125);
      assert (res.rr_inflight_count = 0);
      assert (CI.Issue316.max_inflight res.rr_events = 6);
      assert (CI.Issue316.check_double_buffer_overlap res.rr_events);
      let outs =
        CI.Issue316.vector_output_writes res.rr_events
        |> List.map (function
             | CI.Issue316.Interp.E.V_float (x :: _) -> x
             | _ -> assert false)
      in
      assert (outs = [ 101; 102; 103 ])
  | Error e -> failwith (CE.pp_step_error e));

  (* 3. SharedResource both issue orders *)
  Cmp_shared.assert_results_identical "shared_order_01"
    Ext.DerivedExtractionDemo.demo_shared_order_01
    (CI.Shared_resource.run_order_01 ());
  Cmp_shared.assert_results_identical "shared_order_10"
    Ext.DerivedExtractionDemo.demo_shared_order_10
    (CI.Shared_resource.run_order_10 ());

  (* 4. Memory visibility: overwrite observes latest completed write (20) *)
  Cmp_mem.assert_results_identical "overwrite"
    Ext.DerivedExtractionDemo.demo_overwrite
    (CI.Memory_and_choice.run_overwrite ());

  (* 5. Uninitialized memory read: strict scripted, strict deadlock, permissive *)
  Cmp_mem.assert_results_identical "uninit_strict_scripted"
    Ext.DerivedExtractionDemo.demo_uninit_strict_scripted
    (CI.Memory_and_choice.run_uninit_strict_scripted ());
  Cmp_mem.assert_results_identical "uninit_strict_deadlock"
    Ext.DerivedExtractionDemo.demo_uninit_strict_deadlock
    (CI.Memory_and_choice.run_uninit_strict_deadlock ());
  Cmp_mem.assert_results_identical "uninit_permissive"
    Ext.DerivedExtractionDemo.demo_uninit_permissive
    (CI.Memory_and_choice.run_uninit_permissive ());

  (* 6. Early Async Use (Issue #920 style): strict rejects, permissive sound *)
  Cmp_mem.assert_results_identical "early_async_strict"
    Ext.DerivedExtractionDemo.demo_early_async_strict
    (CI.Memory_and_choice.run_early_async_strict ());
  Cmp_mem.assert_results_identical "early_async_permissive"
    Ext.DerivedExtractionDemo.demo_early_async_permissive
    (CI.Memory_and_choice.run_early_async_permissive ());

  (* 7. Loop-local dynamic Alloc *)
  Cmp_mem.assert_results_identical "loop_alloc"
    Ext.DerivedExtractionDemo.demo_loop_alloc
    (CI.Memory_and_choice.run_loop_alloc ());

  (* 8. H1-H5 shallow interpreter bridge: emit Target B Issue #316 trace in H5 *)
  let open Unified_interpreter in
  let h5_state =
    Interpreter.run_program (fun () ->
        Effects.with_sync_ops (fun () ->
            match
              CI.Issue316.run_demo ~policy:(CI.overlapped_round_robin_policy 8)
            with
            | Ok res ->
                let lines = List.map CI.Issue316.pp_event res.rr_events in
                Effects.emit_core_async_events "issue316-overlapped" lines
            | Error e -> failwith (CE.pp_step_error e)))
  in
  assert (
    Report.trace_contains h5_state
      "H5 core.async.begin issue316-overlapped count=125");
  assert (
    Report.trace_contains h5_state
      "ReadStart(TransferEngine,MTE2,addr=2)");
  assert (
    Report.trace_contains h5_state
      "WriteStart(VectorUnit,Vector,addr=0)");
  assert (
    Report.trace_contains h5_state "H5 core.async.end issue316-overlapped");

  print_endline
    "Cross-validation PASSED: Target A (Rocq extracted) == Target B (OCaml 5 Effect.Deep) bit-for-bit across all 10 scenarios + H5 bridge."

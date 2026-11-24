From Stdlib Require Import List ZArith Bool Lia.
From UnifiedInterpreter.Base Require Import Free Result.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics.
From UnifiedInterpreter.CoreLanguage.Derived Require Import Refocusing Automaton CoreEffects.
Import ListNotations.
Set Implicit Arguments.

(* ========================================================================== *)
(* 1. 通用调度策略接口（同时驱动 Free Monad 解释器与一阶去函数化自动机）         *)
(* ========================================================================== *)

Inductive thread_status : Type :=
| StRunning
| StWaiting (wait_op : op_id)
| StDone.

Inductive schedule_action : Type :=
| ActIssue (branch_idx : nat)
| ActFinish (op : op_id).

Inductive policy_decision (S : Type) : Type :=
| PolStep (act : schedule_action) (next_state : S)
| PolStop
| PolStuck.

Arguments PolStop {S}.
Arguments PolStuck {S}.

Record schedule_policy : Type := SchedulePolicy {
  pol_state : Type;
  pol_init : pol_state;
  pol_next :
    pol_state ->
    list thread_status ->
    list (op_id * bool) ->
    list (nat * bool) ->
    policy_decision pol_state
}.

Definition is_status_done (s : thread_status) : bool :=
  match s with StDone => true | _ => false end.

Fixpoint find_first_enabled_op (xs : list (op_id * bool)) : option op_id :=
  match xs with
  | [] => None
  | (o, true) :: _ => Some o
  | (_, false) :: rest => find_first_enabled_op rest
  end.

Fixpoint find_first_enabled_branch (xs : list (nat * bool)) : option nat :=
  match xs with
  | [] => None
  | (j, true) :: _ => Some j
  | (_, false) :: rest => find_first_enabled_branch rest
  end.

Definition find_enabled_branch_from (start : nat) (xs : list (nat * bool)) : option nat :=
  let n := length xs in
  match n with
  | 0 => None
  | S _ =>
      let k := Nat.modulo start n in
      find_first_enabled_branch (skipn k xs ++ firstn k xs)
  end.

(* 策略 1：串行优先完成（只要有可完成的在途操作就立即完成，否则发起首个可运行分支）。 *)
Definition serialized_policy : schedule_policy :=
  {| pol_state := unit;
     pol_init := tt;
     pol_next := fun _ statuses inflight_info branch_info =>
       if forallb is_status_done statuses && Nat.eqb (length inflight_info) 0 then
         PolStop
       else
         match find_first_enabled_op inflight_info with
         | Some o => PolStep (ActFinish o) tt
         | None =>
             match find_first_enabled_branch branch_info with
             | Some j => PolStep (ActIssue j) tt
             | None => PolStuck
             end
         end |}.

(* 策略 2：重叠轮转调度（在途操作数小于 max_inflight 时优先轮转发起不同分支，实现流水线重叠）。 *)
Definition overlapped_round_robin_policy (max_inflight : nat) : schedule_policy :=
  {| pol_state := nat;
     pol_init := 0%nat;
     pol_next := fun cursor statuses inflight_info branch_info =>
       if forallb is_status_done statuses && Nat.eqb (length inflight_info) 0 then
         PolStop
       else if Nat.ltb (length inflight_info) max_inflight then
         match find_enabled_branch_from cursor branch_info with
         | Some j => PolStep (ActIssue j) (S j)
         | None =>
             match find_first_enabled_op inflight_info with
             | Some o => PolStep (ActFinish o) cursor
             | None => PolStuck
             end
         end
       else
         match find_first_enabled_op inflight_info with
         | Some o => PolStep (ActFinish o) cursor
         | None =>
             match find_enabled_branch_from cursor branch_info with
             | Some j => PolStep (ActIssue j) (S j)
             | None => PolStuck
             end
         end |}.

(* 策略 3：显式脚本调度（按给定动作序列逐步推进并在脚本耗尽时以有效前缀轨迹停止）。 *)
Definition scripted_policy (script : list schedule_action) : schedule_policy :=
  {| pol_state := list schedule_action;
     pol_init := script;
     pol_next := fun remaining _ _ _ =>
       match remaining with
       | [] => PolStop
       | act :: rest => PolStep act rest
       end |}.

(* ========================================================================== *)
(* 2. 运行结果与模块化 Algebraic Effect Handlers                              *)
(* ========================================================================== *)

Record run_result {Float EventId Pipe Unit : Type} : Type := RunResult {
  rr_events : list (@event_record Float EventId Pipe Unit);
  rr_uses : list (@use_record Float EventId Pipe);
  rr_outputs : list (option (list (@value Float EventId Pipe)));
  rr_inflight_count : nat
}.

Section Handlers.
Context {Float EventId Pipe Unit : Type}.
Context (layout : allocation_layout).
Context (tgt : @executable_target Float EventId Pipe Unit).
Context (model : @computation_model Float EventId Pipe Unit).
Context (emodel : executable_model model).
Context (cpol : @choice_policy Float EventId Pipe).

Local Notation Val := (@value Float EventId Pipe).
Local Notation Op := (@operand Float EventId Pipe).
Local Notation Env := (@environment Float EventId Pipe).
Local Notation RawCmd := (@command Float EventId Pipe Unit unit).
Local Notation Rec := (@event_record Float EventId Pipe Unit).
Local Notation Use := (@use_record Float EventId Pipe).
Local Notation Cursor := (@thread_cursor Float EventId Pipe Unit).
Local Notation Sync := (@sync_state Float EventId Pipe Unit).
Local Notation Mem := (@mem_state Float EventId Pipe).
Local Notation MState := (@machine_state Float EventId Pipe Unit).
Local Notation BComp := (@branch_comp Float EventId Pipe Unit).

Let peq := eqb (pipe_eq tgt).
Let eeq := eqb (event_eq tgt).

Inductive suspend_mode : Type :=
| ModeContinue
| ModeWaitFlag (wait_op : op_id)
| ModeReturn.

Record effect_outcome (X : Type) : Type := EffectOutcome {
  eo_value : X;
  eo_event : Rec;
  eo_uses : list Use;
  eo_sync : Sync;
  eo_mem : Mem;
  eo_mode : suspend_mode
}.

(* --- 子处理器 1：内存与分配处理器 --- *)
Definition handle_alloc_effect (o : op_id) (sync : Sync) (mem : Mem)
    : result step_error (effect_outcome memory_resource) :=
  let addr := address_at layout (InBranch o) in
  match mem_lookup addr mem with
  | Some _ => Error (ErrAllocAlreadyWritten o addr)
  | None =>
      Ok (EffectOutcome addr (EventRecord o (LAlloc addr)) [] sync mem ModeContinue)
  end.

(* --- 子处理器 2：标量求值与分支控制处理器 --- *)
Definition handle_atomic_effect (o : op_id) (rho : Env) (f : atomic_op) (vs : list Op)
    (sync : Sync) (mem : Mem) : result step_error (effect_outcome Val) :=
  r <-? exec_resolve_operands cpol (mem_done_val mem) rho o 0 vs ;;
  let '(args, uses) := r in
  match eval_atomic f args with
  | None => Error (ErrInvalidAtomic o)
  | Some res =>
      Ok (EffectOutcome res (EventRecord o (LAtomic f args res)) uses sync mem ModeContinue)
  end.

Definition handle_assign_pipe_effect (o : op_id) (rho : Env) (x : var) (v : Op)
    (sync : Sync) (mem : Mem) : result step_error (effect_outcome Pipe) :=
  r <-? exec_resolve_operand cpol (mem_done_val mem) rho o 0 v ;;
  let '(val, uses) := r in
  match val with
  | VPipe p =>
      if check_declared_pipe tgt p then
        Ok (EffectOutcome p (EventRecord o (LPipeAssignment x p)) uses sync mem ModeContinue)
      else Error (ErrPermissionDenied o)
  | _ => Error (ErrTypeMismatch o)
  end.

Definition handle_branch_effect (o : op_id) (rho : Env) (cond : Op)
    (sync : Sync) (mem : Mem) : result step_error (effect_outcome bool) :=
  r <-? exec_resolve_operand cpol (mem_done_val mem) rho o 0 cond ;;
  let '(val, uses) := r in
  match val with
  | VBool b =>
      Ok (EffectOutcome b (EventRecord o (LBranch b)) uses sync mem ModeContinue)
  | _ => Error (ErrTypeMismatch o)
  end.

Definition handle_return_effect (o : op_id) (rho : Env) (vs : list Op)
    (sync : Sync) (mem : Mem) : result step_error (effect_outcome (list Val)) :=
  r <-? exec_resolve_operands cpol (mem_done_val mem) rho o 0 vs ;;
  let '(args, uses) := r in
  Ok (EffectOutcome args (EventRecord o (LReturn args)) uses sync mem ModeReturn).

(* --- 子处理器 3：异步操作发起与同步处理器 --- *)
Definition handle_issue_read_effect (o : op_id) (rho : Env)
    (d : execution Unit Op) (v : Op) (sync : Sync) (mem : Mem)
    : result step_error (effect_outcome unit) :=
  r <-? exec_resolve_exec cpol (mem_done_val mem) rho o [v] (queue d) ;;
  let '(p, args, uses) := r in
  match args with
  | [VMemory a] =>
      if check_declared_resource tgt (resource d) && check_can_read tgt (resource d) a then
        _ <-? check_pipe_ready tgt (sync_active_wait sync) o p ;;
        let disp := Dispatch (resource d) p in
        let sync' := SyncState ((o, PRead disp a) :: sync_inflight sync)
                               (sync_flags sync) (sync_active_wait sync) in
        Ok (EffectOutcome tt (EventRecord o (LReadStart disp a)) uses sync' mem ModeContinue)
      else Error (ErrPermissionDenied o)
  | _ => Error (ErrTypeMismatch o)
  end.

Definition handle_issue_write_effect (o : op_id) (rho : Env)
    (d : execution Unit Op) (v1 v2 : Op) (sync : Sync) (mem : Mem)
    : result step_error (effect_outcome unit) :=
  r <-? exec_resolve_exec cpol (mem_done_val mem) rho o [v1; v2] (queue d) ;;
  let '(p, args, uses) := r in
  match args with
  | [VMemory a; data] =>
      if check_declared_resource tgt (resource d) && check_can_write tgt (resource d) a then
        _ <-? check_pipe_ready tgt (sync_active_wait sync) o p ;;
        let disp := Dispatch (resource d) p in
        let sync' := SyncState ((o, PWrite disp a data) :: sync_inflight sync)
                               (sync_flags sync) (sync_active_wait sync) in
        Ok (EffectOutcome tt (EventRecord o (LWriteStart disp a data)) uses sync' mem ModeContinue)
      else Error (ErrPermissionDenied o)
  | _ => Error (ErrTypeMismatch o)
  end.

Definition handle_issue_compute_effect (o : op_id) (rho : Env)
    (d : execution Unit Op) (vs : list Op) (sync : Sync) (mem : Mem)
    : result step_error (effect_outcome unit) :=
  r <-? exec_resolve_exec cpol (mem_done_val mem) rho o vs (queue d) ;;
  let '(p, args, uses) := r in
  if check_declared_resource tgt (resource d) then
    _ <-? check_pipe_ready tgt (sync_active_wait sync) o p ;;
    let disp := Dispatch (resource d) p in
    let sync' := SyncState ((o, PCompute disp args) :: sync_inflight sync)
                           (sync_flags sync) (sync_active_wait sync) in
    Ok (EffectOutcome tt (EventRecord o (LComputeStart disp args)) uses sync' mem ModeContinue)
  else Error (ErrPermissionDenied o).

Definition handle_set_flag_effect (o : op_id) (rho : Env) (src dst v : Op)
    (sync : Sync) (mem : Mem) : result step_error (effect_outcome unit) :=
  r <-? exec_resolve_operands cpol (mem_done_val mem) rho o 0 [src; dst; v] ;;
  let '(args, uses) := r in
  match args with
  | [VPipe p; VPipe q; VEvent fl] =>
      if check_declared_pipe tgt p && check_declared_pipe tgt q then
        _ <-? check_pipe_ready tgt (sync_active_wait sync) o (Some p) ;;
        let deps := inflight_on_pipe peq p (sync_inflight sync) in
        let sync' := SyncState ((o, PSetFlag p q fl deps) :: sync_inflight sync)
                               (sync_flags sync) (sync_active_wait sync) in
        Ok (EffectOutcome tt (EventRecord o (LSetFlagStart p q fl)) uses sync' mem ModeContinue)
      else Error (ErrPermissionDenied o)
  | _ => Error (ErrTypeMismatch o)
  end.

Definition handle_await_flag_effect (j : nat) (o : op_id) (rho : Env) (src dst v : Op)
    (sync : Sync) (mem : Mem) : result step_error (effect_outcome unit) :=
  r <-? exec_resolve_operands cpol (mem_done_val mem) rho o 0 [src; dst; v] ;;
  let '(args, uses) := r in
  match args with
  | [VPipe p; VPipe q; VEvent fl] =>
      if check_declared_pipe tgt p && check_declared_pipe tgt q then
        _ <-? check_pipe_ready tgt (sync_active_wait sync) o (Some q) ;;
        let sync' := SyncState ((o, PWaitFlag p q fl j) :: sync_inflight sync)
                               (sync_flags sync) (active_wait_set q o (sync_active_wait sync)) in
        Ok (EffectOutcome tt (EventRecord o (LWaitFlagStart p q fl)) uses sync' mem (ModeWaitFlag o))
      else Error (ErrPermissionDenied o)
  | _ => Error (ErrTypeMismatch o)
  end.

(* 组合效应分派器 *)
Definition handle_core_effect {X : Type} (j : nat)
    (eff : @core_effect Float EventId Pipe Unit X) (sync : Sync) (mem : Mem)
    : result step_error (effect_outcome X) :=
  match eff in core_effect X return result step_error (effect_outcome X) with
  | EAlloc o => handle_alloc_effect o sync mem
  | EAtomic o rho f vs => handle_atomic_effect o rho f vs sync mem
  | EAssignPipe o rho x v => handle_assign_pipe_effect o rho x v sync mem
  | EIssueRead o rho d v => handle_issue_read_effect o rho d v sync mem
  | EIssueWrite o rho d v1 v2 => handle_issue_write_effect o rho d v1 v2 sync mem
  | EIssueCompute o rho d vs => handle_issue_compute_effect o rho d vs sync mem
  | EIssueSetFlag o rho src dst v => handle_set_flag_effect o rho src dst v sync mem
  | EAwaitFlag o rho src dst v => handle_await_flag_effect j o rho src dst v sync mem
  | EBranch o rho cond => handle_branch_effect o rho cond sync mem
  | EReturn o rho vs => handle_return_effect o rho vs sync mem
  end.

(* --- 子处理器 4：在途异步事件完成处理器 --- *)
Definition handle_finish_effect (o : op_id) (sync : Sync) (mem : Mem)
    : result step_error (Rec * Sync * Mem * option nat) :=
  match lookup_inflight o sync with
  | None => Error (ErrInflightNotFound o)
  | Some pk =>
      let inflight' := remove_assoc op_id_eqb o (sync_inflight sync) in
      let flags := sync_flags sync in
      let aw := sync_active_wait sync in
      match pk with
      | PRead _ a =>
          let ov := match mem_lookup a mem with
                    | Some v => Some v
                    | None => pick_uninit_mem cpol a
                    end in
          match ov with
          | None => Error (ErrUninitMemoryRead o a)
          | Some res =>
              let ev := EventRecord o (LReadEnd res) in
              let sync' := SyncState inflight' flags aw in
              let mem' := MemState (mem_writes mem) ((o, res) :: mem_done_val mem) in
              Ok (ev, sync', mem', None)
          end
      | PWrite _ a data =>
          let ev := EventRecord o LWriteEnd in
          let sync' := SyncState inflight' flags aw in
          let mem' := MemState ((a, data) :: mem_writes mem) (mem_done_val mem) in
          Ok (ev, sync', mem', None)
      | PCompute d args =>
          match exec_comp emodel (resource d) args with
          | None => Error (ErrComputeUndefined o)
          | Some res =>
              let ev := EventRecord o (LComputeEnd res) in
              let sync' := SyncState inflight' flags aw in
              let mem' := MemState (mem_writes mem) ((o, res) :: mem_done_val mem) in
              Ok (ev, sync', mem', None)
          end
      | PSetFlag p q fl deps =>
          if deps_drained deps (sync_inflight sync) then
            if negb (flag_is_set peq eeq p q fl flags) then
              let ev := EventRecord o LSetFlagEnd in
              let sync' := SyncState inflight' (flag_set_true p q fl flags) aw in
              Ok (ev, sync', mem, None)
            else Error (ErrFlagNotReady o)
          else Error (ErrSetFlagDepsPending o)
      | PWaitFlag p q fl j =>
          if flag_is_set peq eeq p q fl flags then
            let ev := EventRecord o LWaitFlagEnd in
            let sync' := SyncState inflight' (flag_set_false peq eeq p q fl flags)
                                   (active_wait_clear peq q aw) in
            Ok (ev, sync', mem, Some j)
          else Error (ErrFlagNotReady o)
      end
  end.

(* ========================================================================== *)
(* 3. 高阶 Free Monad 解释器（基于 Base/Free.v 续体）                          *)
(* ========================================================================== *)

Inductive free_thread_state : Type :=
| FRunning (comp : BComp)
| FWaiting (wait_op : op_id) (k : unit -> BComp)
| FDone (results : list Val).

Record free_machine_state : Type := FreeMachineState {
  fms_threads : list free_thread_state;
  fms_sync : Sync;
  fms_mem : Mem;
  fms_rev_trace : list Rec;
  fms_rev_uses : list Use
}.

Definition free_thread_status (fts : free_thread_state) : thread_status :=
  match fts with
  | FRunning _ => StRunning
  | FWaiting w _ => StWaiting w
  | FDone _ => StDone
  end.

Definition free_thread_output (fts : free_thread_state) : option (list Val) :=
  match fts with
  | FDone args => Some args
  | _ => None
  end.

Definition machine_thread_status (ts : @thread_state Float EventId Pipe Unit) : thread_status :=
  match ts with
  | TRunning _ => StRunning
  | TWaitingFlag w _ => StWaiting w
  | TDone _ => StDone
  end.

Definition machine_thread_output (ts : @thread_state Float EventId Pipe Unit) : option (list Val) :=
  match ts with
  | TDone args => Some args
  | _ => None
  end.

Fixpoint init_free_threads_aux (branch_fuel refocus_budget idx : nat) (branches : list RawCmd)
    : result step_error (list free_thread_state) :=
  match branches with
  | [] => Ok []
  | c :: rest =>
      let cur0 := ThreadCursor (Pos.of_succ_nat idx) 1%positive empty_environment c [] in
      match denote_branch (S branch_fuel) refocus_budget idx cur0 with
      | Free.Return (Error err) => Error err
      | Free.Return (Ok args) =>
          ts <-? init_free_threads_aux branch_fuel refocus_budget (S idx) rest ;;
          Ok (FDone args :: ts)
      | Trigger req k =>
          ts <-? init_free_threads_aux branch_fuel refocus_budget (S idx) rest ;;
          Ok (FRunning (Trigger req k) :: ts)
      end
  end.

Definition init_free_machine (branch_fuel refocus_budget : nat) (branches : list RawCmd)
    : result step_error free_machine_state :=
  ts <-? init_free_threads_aux branch_fuel refocus_budget 0 branches ;;
  Ok (FreeMachineState ts empty_sync_state empty_mem_state [] []).

Definition step_free_issue (j : nat) (fst : free_machine_state)
    : result step_error (Rec * free_machine_state) :=
  match nth_error (fms_threads fst) j with
  | None => Error (ErrInvalidBranch j)
  | Some (FDone _) | Some (FWaiting _ _) => Error (ErrBranchNotRunnable j)
  | Some (FRunning (Free.Return (Error err))) => Error err
  | Some (FRunning (Free.Return (Ok _))) => Error (ErrBranchNotRunnable j)
  | Some (FRunning (Trigger eff k)) =>
      out <-? handle_core_effect j eff (fms_sync fst) (fms_mem fst) ;;
      let next_comp := k (eo_value out) in
      next_ts <-? match eo_mode out, next_comp with
                  | ModeContinue, Trigger req' k' => Ok (FRunning (Trigger req' k'))
                  | ModeContinue, Free.Return (Error err) => Error err
                  | ModeContinue, Free.Return (Ok args) => Ok (FDone args)
                  | ModeWaitFlag w, Trigger req' k' => Ok (FWaiting w (fun _ => Trigger req' k'))
                  | ModeWaitFlag _, Free.Return (Error err) => Error err
                  | ModeWaitFlag _, Free.Return (Ok _) => Error (ErrRefocusStuck j)
                  | ModeReturn, Free.Return (Ok args) => Ok (FDone args)
                  | ModeReturn, Free.Return (Error err) => Error err
                  | ModeReturn, Trigger _ _ => Error (ErrRefocusStuck j)
                  end ;;
      let ev := eo_event out in
      Ok (ev, FreeMachineState
                (update_nth j next_ts (fms_threads fst))
                (eo_sync out) (eo_mem out)
                (ev :: fms_rev_trace fst)
                (rev_append (eo_uses out) (fms_rev_uses fst)))
  end.

Definition step_free_finish (o : op_id) (fst : free_machine_state)
    : result step_error (Rec * free_machine_state) :=
  r <-? handle_finish_effect o (fms_sync fst) (fms_mem fst) ;;
  let '(ev, sync', mem', wake) := r in
  match wake with
  | None =>
      Ok (ev, FreeMachineState (fms_threads fst) sync' mem'
                (ev :: fms_rev_trace fst) (fms_rev_uses fst))
  | Some j =>
      match nth_error (fms_threads fst) j with
      | Some (FWaiting w k) =>
          if op_id_eqb w o then
            Ok (ev, FreeMachineState (update_nth j (FRunning (k tt)) (fms_threads fst))
                      sync' mem' (ev :: fms_rev_trace fst) (fms_rev_uses fst))
          else Error (ErrBranchNotRunnable j)
      | _ => Error (ErrBranchNotRunnable j)
      end
  end.

(* ========================================================================== *)
(* 4. 统一调度驱动：高阶 Free 解释器与一阶去函数化解释器                       *)
(* ========================================================================== *)

Definition is_ok {E A} (r : result E A) : bool :=
  match r with Ok _ => true | Error _ => false end.

Fixpoint run_free_loop (pol : schedule_policy) (step_fuel : nat)
    (ps : pol_state pol) (fst : free_machine_state)
    : result step_error free_machine_state :=
  match step_fuel with
  | 0 => Error ErrOutOfFuel
  | S fuel' =>
      let statuses := map free_thread_status (fms_threads fst) in
      let inflight_info :=
        map (fun '(o, _) => (o, is_ok (step_free_finish o fst)))
            (rev (sync_inflight (fms_sync fst))) in
      let branch_info :=
        map (fun j => (j, is_ok (step_free_issue j fst)))
            (seq 0 (length (fms_threads fst))) in
      match pol_next pol ps statuses inflight_info branch_info with
      | PolStop => Ok fst
      | PolStuck => Error ErrDeadlocked
      | PolStep (ActIssue j) ps' =>
          r <-? step_free_issue j fst ;;
          run_free_loop pol fuel' ps' (snd r)
      | PolStep (ActFinish o) ps' =>
          r <-? step_free_finish o fst ;;
          run_free_loop pol fuel' ps' (snd r)
      end
  end.

Definition run_free_state (pol : schedule_policy) (step_fuel branch_fuel refocus_budget : nat)
    (prog : @shared_program Float EventId Pipe Unit)
    : result step_error free_machine_state :=
  let branches := instantiate_shared layout 0 prog in
  fst0 <-? init_free_machine branch_fuel refocus_budget branches ;;
  run_free_loop pol step_fuel (pol_init pol) fst0.

Definition free_state_to_result (fst : free_machine_state)
    : @run_result Float EventId Pipe Unit :=
  RunResult
    (rev (fms_rev_trace fst))
    (rev (fms_rev_uses fst))
    (map free_thread_output (fms_threads fst))
    (length (sync_inflight (fms_sync fst))).

Definition run_free_interpreter (pol : schedule_policy) (step_fuel branch_fuel refocus_budget : nat)
    (prog : @shared_program Float EventId Pipe Unit)
    : result step_error (@run_result Float EventId Pipe Unit) :=
  fst <-? run_free_state pol step_fuel branch_fuel refocus_budget prog ;;
  Ok (free_state_to_result fst).

Fixpoint run_derived_loop (pol : schedule_policy) (step_fuel refocus_budget : nat)
    (ps : pol_state pol) (st : MState)
    : result step_error MState :=
  match step_fuel with
  | 0 => Error ErrOutOfFuel
  | S fuel' =>
      let statuses := map machine_thread_status (ms_threads st) in
      let inflight_info :=
        map (fun '(o, _) => (o, is_ok (exec_finish_op tgt emodel cpol o st)))
            (rev (sync_inflight (ms_sync st))) in
      let branch_info :=
        map (fun j => (j, is_ok (exec_issue_branch layout tgt cpol refocus_budget j st)))
            (seq 0 (length (ms_threads st))) in
      match pol_next pol ps statuses inflight_info branch_info with
      | PolStop => Ok st
      | PolStuck => Error ErrDeadlocked
      | PolStep (ActIssue j) ps' =>
          r <-? exec_issue_branch layout tgt cpol refocus_budget j st ;;
          run_derived_loop pol fuel' refocus_budget ps' (snd r)
      | PolStep (ActFinish o) ps' =>
          r <-? exec_finish_op tgt emodel cpol o st ;;
          run_derived_loop pol fuel' refocus_budget ps' (snd r)
      end
  end.

Definition run_derived_state (pol : schedule_policy) (step_fuel refocus_budget : nat)
    (prog : @shared_program Float EventId Pipe Unit)
    : result step_error MState :=
  let branches := instantiate_shared layout 0 prog in
  st0 <-? init_machine refocus_budget branches ;;
  run_derived_loop pol step_fuel refocus_budget (pol_init pol) st0.

Definition machine_state_to_result (st : MState)
    : @run_result Float EventId Pipe Unit :=
  RunResult
    (rev (ms_rev_trace st))
    (rev (ms_rev_uses st))
    (map machine_thread_output (ms_threads st))
    (length (sync_inflight (ms_sync st))).

Definition run_derived_interpreter (pol : schedule_policy) (step_fuel refocus_budget : nat)
    (prog : @shared_program Float EventId Pipe Unit)
    : result step_error (@run_result Float EventId Pipe Unit) :=
  st <-? run_derived_state pol step_fuel refocus_budget prog ;;
  Ok (machine_state_to_result st).

(* ========================================================================== *)
(* 5. 函数式对应定理（Functional Correspondence：Free 处理器 ↔ 一阶自动机）     *)
(* ========================================================================== *)

Lemma denote_branch_refocus fuel budget j (cur0 cur : Cursor) :
  (1 <= budget)%nat ->
  refocus budget cur0 = Some cur ->
  denote_branch (S fuel) budget j cur0 = denote_branch (S fuel) budget j cur.
Proof.
  intros Hge Href.
  pose proof (refocus_event_head _ _ Href) as Hhead.
  pose proof (refocus_idempotent cur Hge Hhead) as Hid.
  cbn [denote_branch]. rewrite Href, Hid. reflexivity.
Qed.
Arguments denote_branch_refocus _ _ _ _ _ _ _ : clear implicits.

Lemma denote_branch_is_trigger fuel budget j (cur : Cursor) :
  (1 <= budget)%nat ->
  is_event_head (cursor_cmd cur) = true ->
  exists X (req : @core_effect Float EventId Pipe Unit X) k,
    denote_branch (S fuel) budget j cur = Trigger req k.
Proof.
  intros Hge Hhead.
  pose proof (refocus_idempotent cur Hge Hhead) as Hid.
  cbn [denote_branch]. rewrite Hid.
  destruct cur as [tid path rho cmd stk]. cbn in *.
  destruct cmd as [o vs | x v n | o x n | o x f vs n | x b y z n | o x v n
                  | o x d vs n | o x d v n | o d v1 v2 n | o src dst v n | o src dst v n
                  | x lo hi body after | | o cond y n]; try discriminate;
    try destruct o; repeat eexists.
Qed.
Arguments denote_branch_is_trigger _ _ _ _ _ _ : clear implicits.

Lemma denote_branch_trigger_inv fuel budget j (cur0 : Cursor) X
    (req : @core_effect Float EventId Pipe Unit X) k :
  denote_branch fuel budget j cur0 = Trigger req k ->
  exists fuel' cur,
    fuel = S fuel' /\
    refocus budget cur0 = Some cur /\
    is_event_head (cursor_cmd cur) = true /\
    denote_branch (S fuel') budget j cur = Trigger req k.
Proof.
  intros H. destruct fuel as [|fuel']; [cbn in H; discriminate |].
  cbn [denote_branch] in H.
  destruct (refocus budget cur0) as [cur|] eqn:Href; [| discriminate].
  pose proof (refocus_event_head _ _ Href) as Hhead.
  destruct budget as [|budget'].
  - cbn in Href; discriminate.
  - exists fuel', cur. repeat split; auto.
    rewrite <- (denote_branch_refocus fuel' (S budget') j cur0 cur) by (lia || exact Href).
    cbn [denote_branch]. rewrite Href. exact H.
Qed.

(* 单线程高阶续体与一阶游标之间的精确去函数化对应关系 *)
Inductive corresponds_thread (budget j : nat) :
    @thread_state Float EventId Pipe Unit -> free_thread_state -> Prop :=
| CorrRunning : forall fuel cur,
    is_event_head (cursor_cmd cur) = true ->
    corresponds_thread budget j (TRunning cur) (FRunning (denote_branch (S fuel) budget j cur))
| CorrWaiting : forall fuel w cur k,
    is_event_head (cursor_cmd cur) = true ->
    (forall u, k u = denote_branch (S fuel) budget j cur) ->
    corresponds_thread budget j (TWaitingFlag w cur) (FWaiting w k)
| CorrDone : forall args,
    corresponds_thread budget j (TDone args) (FDone args).

(* 带最低剩余燃料下界的对应关系，用于反方向（一阶自动机 -> Free 解释器）同步模拟。 *)
Inductive corresponds_thread_ge (min_fuel budget j : nat) :
    @thread_state Float EventId Pipe Unit -> free_thread_state -> Prop :=
| CorrRunningGe : forall fuel cur,
    (min_fuel <= fuel)%nat ->
    is_event_head (cursor_cmd cur) = true ->
    corresponds_thread_ge min_fuel budget j (TRunning cur) (FRunning (denote_branch (S fuel) budget j cur))
| CorrWaitingGe : forall fuel w cur k,
    (min_fuel <= fuel)%nat ->
    is_event_head (cursor_cmd cur) = true ->
    (forall u, k u = denote_branch (S fuel) budget j cur) ->
    corresponds_thread_ge min_fuel budget j (TWaitingFlag w cur) (FWaiting w k)
| CorrDoneGe : forall args,
    corresponds_thread_ge min_fuel budget j (TDone args) (FDone args).

Lemma corresponds_thread_ge_mono m1 m2 budget j ts fts :
  (m1 <= m2)%nat ->
  corresponds_thread_ge m2 budget j ts fts ->
  corresponds_thread_ge m1 budget j ts fts.
Proof.
  intros Hle H. inversion H; subst.
  - apply CorrRunningGe; [lia | assumption].
  - eapply CorrWaitingGe; [| assumption | eassumption]; lia.
  - apply CorrDoneGe.
Qed.

Lemma corresponds_thread_ge_forget m budget j ts fts :
  corresponds_thread_ge m budget j ts fts ->
  corresponds_thread budget j ts fts.
Proof.
  intros H. inversion H; subst; econstructor; eauto.
Qed.

Definition corresponds_threads (budget : nat)
    (ts : list (@thread_state Float EventId Pipe Unit)) (fts : list free_thread_state) : Prop :=
  length ts = length fts /\
  forall j t ft,
    nth_error ts j = Some t ->
    nth_error fts j = Some ft ->
    corresponds_thread budget j t ft.

Definition corresponds_threads_ge (min_fuel budget : nat)
    (ts : list (@thread_state Float EventId Pipe Unit)) (fts : list free_thread_state) : Prop :=
  length ts = length fts /\
  forall j t ft,
    nth_error ts j = Some t ->
    nth_error fts j = Some ft ->
    corresponds_thread_ge min_fuel budget j t ft.

Record corresponds_state (budget : nat) (st : MState) (fst : free_machine_state) : Prop := {
  cs_threads : corresponds_threads budget (ms_threads st) (fms_threads fst);
  cs_sync : ms_sync st = fms_sync fst;
  cs_mem : ms_mem st = fms_mem fst;
  cs_trace : ms_rev_trace st = fms_rev_trace fst;
  cs_uses : ms_rev_uses st = fms_rev_uses fst
}.

Record corresponds_state_ge (min_fuel budget : nat) (st : MState) (fst : free_machine_state) : Prop := {
  csg_threads : corresponds_threads_ge min_fuel budget (ms_threads st) (fms_threads fst);
  csg_sync : ms_sync st = fms_sync fst;
  csg_mem : ms_mem st = fms_mem fst;
  csg_trace : ms_rev_trace st = fms_rev_trace fst;
  csg_uses : ms_rev_uses st = fms_rev_uses fst
}.

Lemma corresponds_threads_update budget j t ft ts fts :
  corresponds_threads budget ts fts ->
  corresponds_thread budget j t ft ->
  corresponds_threads budget (update_nth j t ts) (update_nth j ft fts).
Proof.
  intros [Hlen Hall] Ht. split.
  - rewrite !length_update_nth. exact Hlen.
  - intros k t' ft' H1 H2.
    destruct (Nat.eq_dec j k) as [-> | Hneq].
    + assert (Hk : (k < length ts)%nat).
      { rewrite <- (length_update_nth k t ts). apply nth_error_Some. rewrite H1. discriminate. }
      rewrite nth_error_update_nth_eq in H1 by exact Hk.
      rewrite nth_error_update_nth_eq in H2 by lia.
      inversion H1; inversion H2; subst. exact Ht.
    + rewrite nth_error_update_nth_neq in H1 by exact Hneq.
      rewrite nth_error_update_nth_neq in H2 by exact Hneq.
      eapply Hall; eassumption.
Qed.

Lemma corresponds_threads_ge_update m budget j t ft ts fts :
  corresponds_threads_ge m budget ts fts ->
  corresponds_thread_ge m budget j t ft ->
  corresponds_threads_ge m budget (update_nth j t ts) (update_nth j ft fts).
Proof.
  intros [Hlen Hall] Ht. split.
  - rewrite !length_update_nth. exact Hlen.
  - intros k t' ft' H1 H2.
    destruct (Nat.eq_dec j k) as [-> | Hneq].
    + assert (Hk : (k < length ts)%nat).
      { rewrite <- (length_update_nth k t ts). apply nth_error_Some. rewrite H1. discriminate. }
      rewrite nth_error_update_nth_eq in H1 by exact Hk.
      rewrite nth_error_update_nth_eq in H2 by lia.
      inversion H1; inversion H2; subst. exact Ht.
    + rewrite nth_error_update_nth_neq in H1 by exact Hneq.
      rewrite nth_error_update_nth_neq in H2 by exact Hneq.
      eapply Hall; eassumption.
Qed.

Lemma corresponds_threads_ge_mono m1 m2 budget ts fts :
  (m1 <= m2)%nat ->
  corresponds_threads_ge m2 budget ts fts ->
  corresponds_threads_ge m1 budget ts fts.
Proof.
  intros Hle [Hlen Hall]. split; [exact Hlen |].
  intros j t ft H1 H2. eapply corresponds_thread_ge_mono; [exact Hle | eapply Hall; eassumption].
Qed.

Lemma corresponds_state_status budget st fst :
  corresponds_state budget st fst ->
  map machine_thread_status (ms_threads st) = map free_thread_status (fms_threads fst).
Proof.
  intros Hcs. destruct (cs_threads Hcs) as [Hlen Hall].
  apply nth_error_ext. intros j. rewrite !nth_error_map.
  destruct (nth_error (ms_threads st) j) as [t|] eqn:H1;
  destruct (nth_error (fms_threads fst) j) as [ft|] eqn:H2.
  - cbn. f_equal. pose proof (Hall j t ft H1 H2) as Hc. inversion Hc; reflexivity.
  - exfalso. apply nth_error_None in H2. assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence). lia.
  - exfalso. apply nth_error_None in H1. assert (j < length (fms_threads fst))%nat by (apply nth_error_Some; congruence). lia.
  - reflexivity.
Qed.

Lemma corresponds_state_result budget st fst :
  corresponds_state budget st fst ->
  machine_state_to_result st = free_state_to_result fst.
Proof.
  intros Hcs. unfold machine_state_to_result, free_state_to_result.
  rewrite (cs_trace Hcs), (cs_uses Hcs), (cs_sync Hcs). f_equal.
  destruct (cs_threads Hcs) as [Hlen Hall].
  apply nth_error_ext. intros j. rewrite !nth_error_map.
  destruct (nth_error (ms_threads st) j) as [t|] eqn:H1;
  destruct (nth_error (fms_threads fst) j) as [ft|] eqn:H2.
  - cbn. f_equal. pose proof (Hall j t ft H1 H2) as Hc. inversion Hc; reflexivity.
  - exfalso. apply nth_error_None in H2. assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence). lia.
  - exfalso. apply nth_error_None in H1. assert (j < length (fms_threads fst))%nat by (apply nth_error_Some; congruence). lia.
  - reflexivity.
Qed.

(* 初始化对应引理：init_free_machine 与 init_machine 在任意分支燃料下精确一致 *)
Lemma init_free_threads_corresponds_aux branch_fuel budget idx branches :
  (1 <= budget)%nat ->
  (forall fts,
     init_free_threads_aux branch_fuel budget idx branches = Ok fts ->
     exists ts,
       init_threads_aux budget idx branches = Ok ts /\
       length ts = length fts /\
       forall k t ft,
         nth_error ts k = Some t ->
         nth_error fts k = Some ft ->
         corresponds_thread_ge branch_fuel budget (idx + k) t ft) /\
  (forall ts,
     init_threads_aux budget idx branches = Ok ts ->
     exists fts,
       init_free_threads_aux branch_fuel budget idx branches = Ok fts /\
       length ts = length fts /\
       forall k t ft,
         nth_error ts k = Some t ->
         nth_error fts k = Some ft ->
         corresponds_thread_ge branch_fuel budget (idx + k) t ft) /\
  (forall err,
     init_threads_aux budget idx branches = Error err ->
     init_free_threads_aux branch_fuel budget idx branches = Error err).
Proof.
  intros Hge. revert idx. induction branches as [|c rest IH]; intros idx.
  - repeat split; cbn; intros.
    + inversion H; subst. exists []. repeat split; intros k; destruct k; discriminate.
    + inversion H; subst. exists []. repeat split; intros k; destruct k; discriminate.
    + discriminate.
  - specialize (IH (S idx)) as [IH1 [IH2 IH3]].
    set (cur0 := ThreadCursor (Pos.of_succ_nat idx) 1%positive empty_environment c []).
    cbn [init_free_threads_aux init_threads_aux].
    fold cur0.
    destruct (refocus budget cur0) as [cur|] eqn:Href.
    + pose proof (refocus_event_head _ _ Href) as Hhead.
      pose proof (denote_branch_refocus branch_fuel budget idx cur0 cur Hge Href) as Hden.
      destruct (denote_branch_is_trigger branch_fuel budget idx cur Hge Hhead) as [X [req [k Htrig]]].
      rewrite Hden, Htrig.
      repeat split.
      * intros fts H.
        destruct (init_free_threads_aux branch_fuel budget (S idx) rest) as [fts'|err] eqn:Hrest;
          cbn [result_bind] in H; [| discriminate].
        inversion H; subst.
        destruct (IH1 fts' eq_refl) as [ts' [Hts' [Hlen Hall]]].
        rewrite Hts'; cbn [result_bind].
        exists (TRunning cur :: ts'). repeat split; [cbn; lia |].
        intros [|m] t ft H1 H2; cbn in H1, H2.
        -- inversion H1; inversion H2; subst.
           rewrite Nat.add_0_r, <- Htrig. constructor; [lia | exact Hhead].
        -- replace (idx + S m)%nat with (S idx + m)%nat by lia. eapply Hall; eassumption.
      * intros ts H.
        destruct (init_threads_aux budget (S idx) rest) as [ts'|err] eqn:Hrest;
          cbn [result_bind] in H; [| discriminate].
        inversion H; subst.
        destruct (IH2 ts' eq_refl) as [fts' [Hfts' [Hlen Hall]]].
        rewrite Hfts'; cbn [result_bind].
        exists (FRunning (Trigger req k) :: fts'). repeat split; [cbn; lia |].
        intros [|m] t ft H1 H2; cbn in H1, H2.
        -- inversion H1; inversion H2; subst.
           rewrite Nat.add_0_r, <- Htrig. constructor; [lia | exact Hhead].
        -- replace (idx + S m)%nat with (S idx + m)%nat by lia. eapply Hall; eassumption.
      * intros err H.
        destruct (init_threads_aux budget (S idx) rest) as [ts'|err'] eqn:Hrest;
          cbn [result_bind] in H; [discriminate |].
        inversion H; subst. rewrite (IH3 err eq_refl). reflexivity.
    + assert (Herr : denote_branch (S branch_fuel) budget idx cur0 = Free.Return (Error (ErrRefocusStuck idx))).
      { cbn [denote_branch]. rewrite Href. reflexivity. }
      rewrite Herr. repeat split; intros ? H; try discriminate; inversion H; reflexivity.
Qed.
Arguments init_free_threads_corresponds_aux _ _ _ _ _ : clear implicits.

Lemma init_free_machine_corresponds branch_fuel budget branches fst :
  (1 <= budget)%nat ->
  init_free_machine branch_fuel budget branches = Ok fst ->
  exists st,
    init_machine budget branches = Ok st /\
    corresponds_state_ge branch_fuel budget st fst.
Proof.
  intros Hge H. unfold init_free_machine in H.
  destruct (init_free_threads_aux branch_fuel budget 0 branches) as [fts|err] eqn:Hf;
    cbn [result_bind] in H; [| discriminate].
  inversion H; subst.
  destruct (proj1 (init_free_threads_corresponds_aux branch_fuel budget 0 branches Hge) fts Hf)
    as [ts [Hts [Hlen Hall]]].
  unfold init_machine. rewrite Hts; cbn [result_bind].
  eexists; split; [reflexivity |].
  constructor; cbn; auto. split; [exact Hlen | exact Hall].
Qed.

Lemma init_machine_corresponds_free branch_fuel budget branches st :
  (1 <= budget)%nat ->
  init_machine budget branches = Ok st ->
  exists fst,
    init_free_machine branch_fuel budget branches = Ok fst /\
    corresponds_state_ge branch_fuel budget st fst.
Proof.
  intros Hge H. unfold init_machine in H.
  destruct (init_threads_aux budget 0 branches) as [ts|err] eqn:Ht;
    cbn [result_bind] in H; [| discriminate].
  inversion H; subst.
  destruct (proj1 (proj2 (init_free_threads_corresponds_aux branch_fuel budget 0 branches Hge)) ts Ht)
    as [fts [Hfts [Hlen Hall]]].
  unfold init_free_machine. rewrite Hfts; cbn [result_bind].
  eexists; split; [reflexivity |].
  constructor; cbn; auto. split; [exact Hlen | exact Hall].
Qed.

Lemma init_machine_error_corresponds_free branch_fuel budget branches err :
  (1 <= budget)%nat ->
  init_machine budget branches = Error err ->
  init_free_machine branch_fuel budget branches = Error err.
Proof.
  intros Hge H. unfold init_machine in H.
  destruct (init_threads_aux budget 0 branches) as [ts|err'] eqn:Ht;
    cbn [result_bind] in H; [discriminate |].
  inversion H; subst.
  unfold init_free_machine.
  rewrite (proj2 (proj2 (init_free_threads_corresponds_aux branch_fuel budget 0 branches Hge)) err Ht).
  reflexivity.
Qed.

(* 辅助引理：解析单步续体结果 *)
Local Lemma cont_trigger_case fuel budget j (next_cur : Cursor) next_ts :
  (1 <= budget)%nat ->
  match denote_branch fuel budget j next_cur with
  | Free.Return (Ok args) => Ok (FDone args)
  | Free.Return (Error err) => Error err
  | Trigger req' k' => Ok (FRunning (Trigger req' k'))
  end = Ok next_ts ->
  exists fuel' cur',
    fuel = S fuel' /\
    refocus budget next_cur = Some cur' /\
    is_event_head (cursor_cmd cur') = true /\
    next_ts = FRunning (denote_branch (S fuel') budget j cur').
Proof.
  intros Hge H. destruct fuel as [|fuel']; [cbn in H; discriminate |].
  cbn [denote_branch] in H.
  destruct (refocus budget next_cur) as [cur'|] eqn:Href; [| discriminate].
  pose proof (refocus_event_head _ _ Href) as Hhead.
  pose proof (denote_branch_refocus fuel' budget j next_cur cur' Hge Href) as Hden.
  destruct (denote_branch_is_trigger fuel' budget j cur' Hge Hhead) as [X [req' [k' Htrig]]].
  assert (Horig : denote_branch (S fuel') budget j next_cur = Trigger req' k')
    by (rewrite Hden; exact Htrig).
  cbn [denote_branch] in Horig. rewrite Href in Horig.
  rewrite Horig in H. inversion H; subst.
  exists fuel', cur'. repeat split; auto. rewrite Htrig. reflexivity.
Qed.
Arguments cont_trigger_case {fuel budget j next_cur next_ts} _ _.

Local Lemma cont_wait_case fuel budget j w (next_cur : Cursor) next_ts :
  (1 <= budget)%nat ->
  match denote_branch fuel budget j next_cur with
  | Free.Return (Ok _) => Error (ErrRefocusStuck j)
  | Free.Return (Error err) => Error err
  | Trigger req' k' => Ok (FWaiting w (fun _ => Trigger req' k'))
  end = Ok next_ts ->
  exists fuel' cur' k_wait,
    fuel = S fuel' /\
    refocus budget next_cur = Some cur' /\
    is_event_head (cursor_cmd cur') = true /\
    next_ts = FWaiting w k_wait /\
    (forall u, k_wait u = denote_branch (S fuel') budget j cur').
Proof.
  intros Hge H. destruct fuel as [|fuel']; [cbn in H; discriminate |].
  cbn [denote_branch] in H.
  destruct (refocus budget next_cur) as [cur'|] eqn:Href; [| discriminate].
  pose proof (refocus_event_head _ _ Href) as Hhead.
  pose proof (denote_branch_refocus fuel' budget j next_cur cur' Hge Href) as Hden.
  destruct (denote_branch_is_trigger fuel' budget j cur' Hge Hhead) as [X [req' [k' Htrig]]].
  assert (Horig : denote_branch (S fuel') budget j next_cur = Trigger req' k')
    by (rewrite Hden; exact Htrig).
  cbn [denote_branch] in Horig. rewrite Href in Horig.
  rewrite Horig in H. inversion H; subst.
  exists fuel', cur', (fun _ => Trigger req' k').
  repeat split; auto.
Qed.
Arguments cont_wait_case {fuel budget j w next_cur next_ts} _ _.

(* 方向 1：Free Monad 解释器的每一步发起精确对应一阶去函数化自动机的 exec_issue_branch *)
Theorem free_issue_refines_exec_issue budget j st fst ev fst' :
  (1 <= budget)%nat ->
  corresponds_state budget st fst ->
  step_free_issue j fst = Ok (ev, fst') ->
  exists st',
    exec_issue_branch layout tgt cpol budget j st = Ok (ev, st') /\
    corresponds_state budget st' fst'.
Proof.
  intros Hge Hcs Hstep.
  destruct Hcs as [[Hlen Hall] Hsync Hmem Htr Huses].
  unfold step_free_issue in Hstep.
  destruct (nth_error (fms_threads fst) j) as [ft|] eqn:Hft; [| discriminate].
  assert (Hjlt : (j < length (ms_threads st))%nat).
  { rewrite Hlen. apply nth_error_Some. rewrite Hft. discriminate. }
  destruct (nth_error (ms_threads st) j) as [t|] eqn:Ht;
    [| exfalso; apply nth_error_None in Ht; lia].
  pose proof (Hall j t ft Ht Hft) as Hct.
  inversion Hct as [fuel cur Hhead Hteq Hfteq | fuel w cur k Hhead Hk Hteq Hfteq | args Hteq Hfteq];
    subst t ft; try discriminate.
  pose proof (refocus_idempotent cur Hge Hhead) as Hid.
  unfold exec_issue_branch. rewrite Ht.
  rewrite <- Hsync, <- Hmem, <- Htr, <- Huses in Hstep.
  destruct cur as [tid path rho cmd stk]. cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack] in *.
  cbn [denote_branch] in Hstep. rewrite Hid in Hstep.
  cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack] in Hstep.
  destruct cmd as [o vs | x v n | o x n | o x f vs n | x b y z n | o x v n
                  | o x d vs n | o x d v n | o d v1 v2 n | o src dst v n | o src dst v n
                  | x lo hi body after | | o cond y n]; try discriminate;
    try destruct o;
    cbn [handle_core_effect] in Hstep;
    unfold handle_alloc_effect, handle_atomic_effect, handle_assign_pipe_effect,
           handle_issue_read_effect, handle_issue_write_effect, handle_issue_compute_effect,
           handle_set_flag_effect, handle_await_flag_effect, handle_branch_effect,
           handle_return_effect in Hstep;
    cbv zeta in Hstep; cbv zeta; revert Hstep.
  - (* Return *)
    destruct (exec_resolve_operands cpol _ _ _ _ vs) as [[args uses]|] eqn:Hr;
      cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses]; [| intro; discriminate].
    intros Hstep; inversion Hstep; subst.
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption | constructor].
  - (* Alloc *)
    destruct (mem_lookup (address_at layout (InBranch (tid, path))) (ms_mem st)) eqn:Hm;
      cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses]; [intro; discriminate |].
    destruct (match denote_branch fuel budget j _ with
              | Free.Return (Ok args) => Ok (FDone args)
              | Free.Return (Error err) => Error err
              | Trigger req' k' => Ok (FRunning (Trigger req' k'))
              end) as [next_ts|] eqn:Hcont; cbn [result_bind]; [| intro; discriminate].
    destruct (cont_trigger_case Hge Hcont) as [fuel' [cur' [_ [Href [Hhead' ->]]]]].
    intros Hstep; inversion Hstep; subst.
    unfold exec_advance; rewrite Href; cbn [result_bind].
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption | econstructor; exact Hhead'].
  - (* LetAtomic *)
    destruct (exec_resolve_operands cpol _ _ _ _ vs) as [[args uses]|] eqn:Hr;
      cbn [result_bind]; [| intro; discriminate].
    destruct (eval_atomic f args) as [res|] eqn:Ha;
      cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses]; [| intro; discriminate].
    destruct (match denote_branch fuel budget j _ with
              | Free.Return (Ok args0) => Ok (FDone args0)
              | Free.Return (Error err) => Error err
              | Trigger req' k' => Ok (FRunning (Trigger req' k'))
              end) as [next_ts|] eqn:Hcont; cbn [result_bind]; [| intro; discriminate].
    destruct (cont_trigger_case Hge Hcont) as [fuel' [cur' [_ [Href [Hhead' ->]]]]].
    intros Hstep; inversion Hstep; subst.
    unfold exec_advance; rewrite Href; cbn [result_bind].
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption | econstructor; exact Hhead'].
  - (* AssignPipe *)
    destruct (exec_resolve_operand cpol _ _ _ _ v) as [[val uses]|] eqn:Hr;
      cbn [result_bind]; [| intro; discriminate].
    destruct val; try (intro; discriminate).
    destruct (check_declared_pipe tgt p) eqn:Hp;
      cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses]; [| intro; discriminate].
    destruct (match denote_branch fuel budget j _ with
              | Free.Return (Ok args0) => Ok (FDone args0)
              | Free.Return (Error err) => Error err
              | Trigger req' k' => Ok (FRunning (Trigger req' k'))
              end) as [next_ts|] eqn:Hcont; cbn [result_bind]; [| intro; discriminate].
    destruct (cont_trigger_case Hge Hcont) as [fuel' [cur' [_ [Href [Hhead' ->]]]]].
    intros Hstep; inversion Hstep; subst.
    unfold exec_advance; rewrite Href; cbn [result_bind].
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption | econstructor; exact Hhead'].
  - (* CCompute *)
    destruct (exec_resolve_exec cpol _ _ _ vs (queue d)) as [[[p args] uses]|] eqn:Hr;
      cbn [result_bind]; [| intro; discriminate].
    destruct (check_declared_resource tgt (resource d)) eqn:Hd; [| intro; discriminate].
    destruct (check_pipe_ready tgt _ _ p) as [[]|] eqn:Hpr;
      cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses]; [| intro; discriminate].
    destruct (match denote_branch fuel budget j _ with
              | Free.Return (Ok args0) => Ok (FDone args0)
              | Free.Return (Error err) => Error err
              | Trigger req' k' => Ok (FRunning (Trigger req' k'))
              end) as [next_ts|] eqn:Hcont; cbn [result_bind]; [| intro; discriminate].
    destruct (cont_trigger_case Hge Hcont) as [fuel' [cur' [_ [Href [Hhead' ->]]]]].
    intros Hstep; inversion Hstep; subst.
    unfold exec_advance; rewrite Href; cbn [result_bind].
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption | econstructor; exact Hhead'].
  - (* Read *)
    destruct (exec_resolve_exec cpol _ _ _ [v] (queue d)) as [[[p args] uses]|] eqn:Hr;
      cbn [result_bind]; [| intro; discriminate].
    destruct args as [|val rest]; try (intro; discriminate). destruct val; try (intro; discriminate).
    destruct rest; try (intro; discriminate).
    destruct (check_declared_resource tgt (resource d) && check_can_read tgt (resource d) address) eqn:Hd;
      [| intro; discriminate].
    destruct (check_pipe_ready tgt _ _ p) as [[]|] eqn:Hpr;
      cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses]; [| intro; discriminate].
    destruct (match denote_branch fuel budget j _ with
              | Free.Return (Ok args0) => Ok (FDone args0)
              | Free.Return (Error err) => Error err
              | Trigger req' k' => Ok (FRunning (Trigger req' k'))
              end) as [next_ts|] eqn:Hcont; cbn [result_bind]; [| intro; discriminate].
    destruct (cont_trigger_case Hge Hcont) as [fuel' [cur' [_ [Href [Hhead' ->]]]]].
    intros Hstep; inversion Hstep; subst.
    unfold exec_advance; rewrite Href; cbn [result_bind].
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption | econstructor; exact Hhead'].
  - (* Write *)
    destruct (exec_resolve_exec cpol _ _ _ [v1; v2] (queue d)) as [[[p args] uses]|] eqn:Hr;
      cbn [result_bind]; [| intro; discriminate].
    destruct args as [|val1 rest1]; try (intro; discriminate). destruct val1; try (intro; discriminate).
    destruct rest1 as [|val2 rest2]; try (intro; discriminate). destruct rest2; try (intro; discriminate).
    destruct (check_declared_resource tgt (resource d) && check_can_write tgt (resource d) address) eqn:Hd;
      [| intro; discriminate].
    destruct (check_pipe_ready tgt _ _ p) as [[]|] eqn:Hpr;
      cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses]; [| intro; discriminate].
    destruct (match denote_branch fuel budget j _ with
              | Free.Return (Ok args0) => Ok (FDone args0)
              | Free.Return (Error err) => Error err
              | Trigger req' k' => Ok (FRunning (Trigger req' k'))
              end) as [next_ts|] eqn:Hcont; cbn [result_bind]; [| intro; discriminate].
    destruct (cont_trigger_case Hge Hcont) as [fuel' [cur' [_ [Href [Hhead' ->]]]]].
    intros Hstep; inversion Hstep; subst.
    unfold exec_advance; rewrite Href; cbn [result_bind].
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption | econstructor; exact Hhead'].
  - (* SetFlag *)
    destruct (exec_resolve_operands cpol _ _ _ _ [src; dst; v]) as [[args uses]|] eqn:Hr;
      cbn [result_bind]; [| intro; discriminate].
    destruct args as [|v1 r1]; try (intro; discriminate). destruct v1; try (intro; discriminate).
    destruct r1 as [|v2 r2]; try (intro; discriminate). destruct v2; try (intro; discriminate).
    destruct r2 as [|v3 r3]; try (intro; discriminate). destruct v3; try (intro; discriminate).
    destruct r3; try (intro; discriminate).
    destruct (check_declared_pipe tgt p && check_declared_pipe tgt p0) eqn:Hp; [| intro; discriminate].
    destruct (check_pipe_ready tgt _ _ (Some p)) as [[]|] eqn:Hpr;
      cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses]; [| intro; discriminate].
    destruct (match denote_branch fuel budget j _ with
              | Free.Return (Ok args0) => Ok (FDone args0)
              | Free.Return (Error err) => Error err
              | Trigger req' k' => Ok (FRunning (Trigger req' k'))
              end) as [next_ts|] eqn:Hcont; cbn [result_bind]; [| intro; discriminate].
    destruct (cont_trigger_case Hge Hcont) as [fuel' [cur' [_ [Href [Hhead' ->]]]]].
    intros Hstep; inversion Hstep; subst.
    unfold exec_advance; rewrite Href; cbn [result_bind].
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption | econstructor; exact Hhead'].
  - (* WaitFlag *)
    destruct (exec_resolve_operands cpol _ _ _ _ [src; dst; v]) as [[args uses]|] eqn:Hr;
      cbn [result_bind]; [| intro; discriminate].
    destruct args as [|v1 r1]; try (intro; discriminate). destruct v1; try (intro; discriminate).
    destruct r1 as [|v2 r2]; try (intro; discriminate). destruct v2; try (intro; discriminate).
    destruct r2 as [|v3 r3]; try (intro; discriminate). destruct v3; try (intro; discriminate).
    destruct r3; try (intro; discriminate).
    destruct (check_declared_pipe tgt p && check_declared_pipe tgt p0) eqn:Hp; [| intro; discriminate].
    destruct (check_pipe_ready tgt _ _ (Some p0)) as [[]|] eqn:Hpr;
      cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses]; [| intro; discriminate].
    destruct (match denote_branch fuel budget j _ with
              | Free.Return (Ok _) => Error (ErrRefocusStuck j)
              | Free.Return (Error err) => Error err
              | Trigger req' k' => Ok (FWaiting (tid, path) (fun _ => Trigger req' k'))
              end) as [next_ts|] eqn:Hcont; cbn [result_bind]; [| intro; discriminate].
    destruct (cont_wait_case Hge Hcont) as [fuel' [cur' [kw [_ [Href [Hhead' [-> Hkw]]]]]]].
    intros Hstep; inversion Hstep; subst.
    unfold exec_advance; rewrite Href; cbn [result_bind].
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption | econstructor; [exact Hhead' | exact Hkw]].
  - (* If *)
    destruct (exec_resolve_operand cpol _ _ _ _ cond) as [[val uses]|] eqn:Hr;
      cbn [result_bind]; [| intro; discriminate].
    destruct val; try (intro; discriminate).
    cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses].
    destruct (match denote_branch fuel budget j _ with
              | Free.Return (Ok args0) => Ok (FDone args0)
              | Free.Return (Error err) => Error err
              | Trigger req' k' => Ok (FRunning (Trigger req' k'))
              end) as [next_ts|] eqn:Hcont; cbn [result_bind]; [| intro; discriminate].
    destruct (cont_trigger_case Hge Hcont) as [fuel' [cur' [_ [Href [Hhead' ->]]]]].
    intros Hstep; inversion Hstep; subst.
    unfold exec_advance; rewrite Href; cbn [result_bind].
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption | econstructor; exact Hhead'].
Qed.

(* 方向 1 完成步：step_free_finish 精确对应 exec_finish_op *)
Theorem free_finish_refines_exec_finish budget o st fst ev fst' :
  corresponds_state budget st fst ->
  step_free_finish o fst = Ok (ev, fst') ->
  exists st',
    exec_finish_op tgt emodel cpol o st = Ok (ev, st') /\
    corresponds_state budget st' fst'.
Proof.
  intros Hcs Hstep.
  destruct Hcs as [[Hlen Hall] Hsync Hmem Htr Huses].
  unfold step_free_finish, handle_finish_effect in Hstep.
  unfold exec_finish_op.
  unfold peq, eeq in *.
  rewrite <- Hsync, <- Hmem, <- Htr, <- Huses in Hstep.
  cbv zeta in Hstep; cbv zeta; revert Hstep.
  destruct (lookup_inflight o (ms_sync st)) as [pk|] eqn:Hinf; [| intro; discriminate].
  destruct pk as [d a | d a data | d args | p q fl deps | p q fl j];
    cbn [result_bind].
  - destruct (mem_lookup a (ms_mem st)) as [v0|] eqn:Hm.
    + cbn [result_bind]; intros Hstep; inversion Hstep; subst.
      eexists; split; [reflexivity | constructor; cbn; auto; split; assumption].
    + destruct (pick_uninit_mem cpol a) as [res|] eqn:Hp; [| intro; discriminate].
      cbn [result_bind]; intros Hstep; inversion Hstep; subst.
      eexists; split; [reflexivity | constructor; cbn; auto; split; assumption].
  - intros Hstep; inversion Hstep; subst.
    eexists; split; [reflexivity | constructor; cbn; auto; split; assumption].
  - destruct (exec_comp emodel (resource d) args) as [res|] eqn:Hc;
      cbn [result_bind]; [| intro; discriminate].
    intros Hstep; inversion Hstep; subst.
    eexists; split; [reflexivity | constructor; cbn; auto; split; assumption].
  - destruct (deps_drained deps (sync_inflight (ms_sync st))) eqn:Hdd; [| intro; discriminate].
    destruct (flag_is_set _ _ p q fl (sync_flags (ms_sync st))) eqn:Hf;
      cbn [negb result_bind]; [intro; discriminate |].
    intros Hstep; inversion Hstep; subst.
    eexists; split; [reflexivity | constructor; cbn; auto; split; assumption].
  - destruct (flag_is_set _ _ p q fl (sync_flags (ms_sync st))) eqn:Hf;
      cbn [result_bind]; [| intro; discriminate].
    destruct (nth_error (fms_threads fst) j) as [ft|] eqn:Hft; [| intro; discriminate].
    assert (Hjlt : (j < length (ms_threads st))%nat).
    { rewrite Hlen. apply nth_error_Some. rewrite Hft. discriminate. }
    destruct (nth_error (ms_threads st) j) as [t|] eqn:Ht;
      [| exfalso; apply nth_error_None in Ht; lia].
    pose proof (Hall j t ft Ht Hft) as Hct.
    inversion Hct as [fuel cur Hhead Hteq Hfteq | fuel w cur k Hhead Hk Hteq Hfteq | args Hteq Hfteq];
      subst t ft; try (intro; discriminate).
    destruct (op_id_eqb w o) eqn:Heq; [| intro; discriminate].
    intros Hstep; inversion Hstep; subst.
    eexists; split; [reflexivity |].
    constructor; cbn; auto.
    apply corresponds_threads_update; [split; assumption |].
    rewrite Hk. constructor; exact Hhead.
Qed.

(* 方向 2：在燃料充足（>= S m）条件下，exec_issue_branch 与 step_free_issue 完全同步（连错误码也一致） *)
Theorem exec_issue_sync_free m budget j st fst :
  (1 <= budget)%nat ->
  corresponds_state_ge (S m) budget st fst ->
  (forall ev st',
     exec_issue_branch layout tgt cpol budget j st = Ok (ev, st') ->
     exists fst',
       step_free_issue j fst = Ok (ev, fst') /\
       corresponds_state_ge m budget st' fst') /\
  (forall err,
     exec_issue_branch layout tgt cpol budget j st = Error err ->
     step_free_issue j fst = Error err).
Proof.
  intros Hge Hcs.
  destruct Hcs as [[Hlen Hall] Hsync Hmem Htr Huses].
  unfold exec_issue_branch, step_free_issue.
  rewrite <- Hsync, <- Hmem, <- Htr, <- Huses.
  destruct (nth_error (ms_threads st) j) as [t|] eqn:Ht.
  - assert (Hjlt : (j < length (fms_threads fst))%nat).
    { rewrite <- Hlen. apply nth_error_Some. rewrite Ht. discriminate. }
    destruct (nth_error (fms_threads fst) j) as [ft|] eqn:Hft;
      [| exfalso; apply nth_error_None in Hft; lia].
    pose proof (Hall j t ft Ht Hft) as Hct.
    inversion Hct as [fuel cur Hfm Hhead Hteq Hfteq | fuel w cur k Hfm Hhead Hk Hteq Hfteq | args Hteq Hfteq];
      subst t ft.
    + pose proof (refocus_idempotent cur Hge Hhead) as Hid.
      destruct cur as [tid path rho cmd stk]. cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack] in *.
      cbn [denote_branch]. rewrite Hid.
      cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
      destruct fuel as [|fuel']; [lia |].
      assert (Hcont_ok : forall (nc cur' : Cursor),
        refocus budget nc = Some cur' ->
        match denote_branch (S fuel') budget j nc with
        | Free.Return (Ok args) => Ok (FDone args)
        | Free.Return (Error err) => Error err
        | Trigger req' k' => Ok (FRunning (Trigger req' k'))
        end = Ok (FRunning (denote_branch (S fuel') budget j cur')) /\
        is_event_head (cursor_cmd cur') = true).
      { intros nc cur' Href.
        pose proof (refocus_event_head _ _ Href) as Hh'.
        rewrite (denote_branch_refocus fuel' budget j nc cur' Hge Href).
        destruct (denote_branch_is_trigger fuel' budget j cur' Hge Hh') as [X [req' [k' Htrig]]].
        rewrite Htrig. split; reflexivity || exact Hh'. }
      assert (Hcont_err : forall (nc : Cursor),
        refocus budget nc = None ->
        match denote_branch (S fuel') budget j nc with
        | Free.Return (Ok args) => Ok (FDone args)
        | Free.Return (Error err) => Error err
        | Trigger req' k' => Ok (FRunning (Trigger req' k'))
        end = Error (ErrRefocusStuck j)).
      { intros nc Hnone. cbn [denote_branch]. rewrite Hnone. reflexivity. }
      assert (Hwait_ok : forall w (nc cur' : Cursor),
        refocus budget nc = Some cur' ->
        exists kw,
          match denote_branch (S fuel') budget j nc with
          | Free.Return (Ok _) => Error (ErrRefocusStuck j)
          | Free.Return (Error err) => Error err
          | Trigger req' k' => Ok (FWaiting w (fun _ => Trigger req' k'))
          end = Ok (FWaiting w kw) /\
          is_event_head (cursor_cmd cur') = true /\
          (forall u, kw u = denote_branch (S fuel') budget j cur')).
      { intros w nc cur' Href.
        pose proof (refocus_event_head _ _ Href) as Hh'.
        rewrite (denote_branch_refocus fuel' budget j nc cur' Hge Href).
        destruct (denote_branch_is_trigger fuel' budget j cur' Hge Hh') as [X [req' [k' Htrig]]].
        rewrite Htrig. exists (fun _ => Trigger req' k'). repeat split; auto. }
      assert (Hwait_err : forall w (nc : Cursor),
        refocus budget nc = None ->
        match denote_branch (S fuel') budget j nc with
        | Free.Return (Ok _) => Error (ErrRefocusStuck j)
        | Free.Return (Error err) => Error err
        | Trigger req' k' => Ok (FWaiting w (fun _ => Trigger req' k'))
        end = Error (ErrRefocusStuck j)).
      { intros w nc Hnone. cbn [denote_branch]. rewrite Hnone. reflexivity. }
      assert (Hmono : corresponds_threads_ge m budget (ms_threads st) (fms_threads fst)).
      { eapply corresponds_threads_ge_mono; [| split; [exact Hlen | exact Hall]]; lia. }
      destruct cmd as [o vs | x v n | o x n | o x f vs n | x b y z n | o x v n
                      | o x d vs n | o x d v n | o d v1 v2 n | o src dst v n | o src dst v n
                      | x lo hi body after | | o cond y n]; try discriminate;
        try destruct o;
        cbn [handle_core_effect];
        unfold handle_alloc_effect, handle_atomic_effect, handle_assign_pipe_effect,
               handle_issue_read_effect, handle_issue_write_effect, handle_issue_compute_effect,
               handle_set_flag_effect, handle_await_flag_effect, handle_branch_effect,
               handle_return_effect, exec_advance; cbv zeta.
      * (* Return *)
        destruct (exec_resolve_operands cpol _ _ _ _ vs) as [[args uses]|err];
          cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses];
          (split; intros; try discriminate; try (inversion H; subst; eexists; split; [reflexivity | constructor; cbn; auto; apply corresponds_threads_ge_update; [exact Hmono | constructor]]); inversion H; reflexivity).
      * (* Alloc *)
        destruct (mem_lookup (address_at layout (InBranch (tid, path))) (ms_mem st));
          cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses];
          [split; intros; try discriminate; inversion H; reflexivity |].
        match goal with |- context [refocus budget ?nc] => destruct (refocus budget nc) as [cur'|] eqn:Href end; cbn [result_bind].
        -- destruct (Hcont_ok _ _ Href) as [-> Hh']. cbn [result_bind].
           split; intros; try discriminate. inversion H; subst.
           eexists; split; [reflexivity |]. constructor; cbn; auto.
           apply corresponds_threads_ge_update; [exact Hmono | econstructor; [lia | exact Hh']].
        -- rewrite (Hcont_err _ Href); cbn [result_bind].
           split; intros; try discriminate; inversion H; reflexivity.
      * (* LetAtomic *)
        destruct (exec_resolve_operands cpol _ _ _ _ vs) as [[args uses]|err];
          cbn [result_bind]; [| split; intros; try discriminate; inversion H; reflexivity].
        destruct (eval_atomic f args) as [res|];
          cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses];
          [| split; intros; try discriminate; inversion H; reflexivity].
        match goal with |- context [refocus budget ?nc] => destruct (refocus budget nc) as [cur'|] eqn:Href end; cbn [result_bind].
        -- destruct (Hcont_ok _ _ Href) as [-> Hh']. cbn [result_bind].
           split; intros; try discriminate. inversion H; subst.
           eexists; split; [reflexivity |]. constructor; cbn; auto.
           apply corresponds_threads_ge_update; [exact Hmono | econstructor; [lia | exact Hh']].
        -- rewrite (Hcont_err _ Href); cbn [result_bind].
           split; intros; try discriminate; inversion H; reflexivity.
      * (* AssignPipe *)
        destruct (exec_resolve_operand cpol _ _ _ _ v) as [[val uses]|err];
          cbn [result_bind]; [| split; intros; try discriminate; inversion H; reflexivity].
        destruct val; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct (check_declared_pipe tgt p);
          cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses];
          [| split; intros; try discriminate; inversion H; reflexivity].
        match goal with |- context [refocus budget ?nc] => destruct (refocus budget nc) as [cur'|] eqn:Href end; cbn [result_bind].
        -- destruct (Hcont_ok _ _ Href) as [-> Hh']. cbn [result_bind].
           split; intros; try discriminate. inversion H; subst.
           eexists; split; [reflexivity |]. constructor; cbn; auto.
           apply corresponds_threads_ge_update; [exact Hmono | econstructor; [lia | exact Hh']].
        -- rewrite (Hcont_err _ Href); cbn [result_bind].
           split; intros; try discriminate; inversion H; reflexivity.
      * (* CCompute *)
        destruct (exec_resolve_exec cpol _ _ _ vs (queue d)) as [[[p args] uses]|err];
          cbn [result_bind]; [| split; intros; try discriminate; inversion H; reflexivity].
        destruct (check_declared_resource tgt (resource d));
          [| split; intros; try discriminate; inversion H; reflexivity].
        destruct (check_pipe_ready tgt _ _ p) as [[]|err];
          cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses];
          [| split; intros; try discriminate; inversion H; reflexivity].
        match goal with |- context [refocus budget ?nc] => destruct (refocus budget nc) as [cur'|] eqn:Href end; cbn [result_bind].
        -- destruct (Hcont_ok _ _ Href) as [-> Hh']. cbn [result_bind].
           split; intros; try discriminate. inversion H; subst.
           eexists; split; [reflexivity |]. constructor; cbn; auto.
           apply corresponds_threads_ge_update; [exact Hmono | econstructor; [lia | exact Hh']].
        -- rewrite (Hcont_err _ Href); cbn [result_bind].
           split; intros; try discriminate; inversion H; reflexivity.
      * (* Read *)
        destruct (exec_resolve_exec cpol _ _ _ [v] (queue d)) as [[[p args] uses]|err];
          cbn [result_bind]; [| split; intros; try discriminate; inversion H; reflexivity].
        destruct args as [|val rest]; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct val; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct rest; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct (check_declared_resource tgt (resource d) && check_can_read tgt (resource d) address);
          [| split; intros; try discriminate; inversion H; reflexivity].
        destruct (check_pipe_ready tgt _ _ p) as [[]|err];
          cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses];
          [| split; intros; try discriminate; inversion H; reflexivity].
        match goal with |- context [refocus budget ?nc] => destruct (refocus budget nc) as [cur'|] eqn:Href end; cbn [result_bind].
        -- destruct (Hcont_ok _ _ Href) as [-> Hh']. cbn [result_bind].
           split; intros; try discriminate. inversion H; subst.
           eexists; split; [reflexivity |]. constructor; cbn; auto.
           apply corresponds_threads_ge_update; [exact Hmono | econstructor; [lia | exact Hh']].
        -- rewrite (Hcont_err _ Href); cbn [result_bind].
           split; intros; try discriminate; inversion H; reflexivity.
      * (* Write *)
        destruct (exec_resolve_exec cpol _ _ _ [v1; v2] (queue d)) as [[[p args] uses]|err];
          cbn [result_bind]; [| split; intros; try discriminate; inversion H; reflexivity].
        destruct args as [|val1 rest1]; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct val1; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct rest1 as [|val2 rest2]; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct rest2; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct (check_declared_resource tgt (resource d) && check_can_write tgt (resource d) address);
          [| split; intros; try discriminate; inversion H; reflexivity].
        destruct (check_pipe_ready tgt _ _ p) as [[]|err];
          cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses];
          [| split; intros; try discriminate; inversion H; reflexivity].
        match goal with |- context [refocus budget ?nc] => destruct (refocus budget nc) as [cur'|] eqn:Href end; cbn [result_bind].
        -- destruct (Hcont_ok _ _ Href) as [-> Hh']. cbn [result_bind].
           split; intros; try discriminate. inversion H; subst.
           eexists; split; [reflexivity |]. constructor; cbn; auto.
           apply corresponds_threads_ge_update; [exact Hmono | econstructor; [lia | exact Hh']].
        -- rewrite (Hcont_err _ Href); cbn [result_bind].
           split; intros; try discriminate; inversion H; reflexivity.
      * (* SetFlag *)
        destruct (exec_resolve_operands cpol _ _ _ _ [src; dst; v]) as [[args uses]|err];
          cbn [result_bind]; [| split; intros; try discriminate; inversion H; reflexivity].
        destruct args as [|v1 r1]; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct v1; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct r1 as [|v2 r2]; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct v2; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct r2 as [|v3 r3]; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct v3; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct r3; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct (check_declared_pipe tgt p && check_declared_pipe tgt p0);
          [| split; intros; try discriminate; inversion H; reflexivity].
        destruct (check_pipe_ready tgt _ _ (Some p)) as [[]|err];
          cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses];
          [| split; intros; try discriminate; inversion H; reflexivity].
        match goal with |- context [refocus budget ?nc] => destruct (refocus budget nc) as [cur'|] eqn:Href end; cbn [result_bind].
        -- destruct (Hcont_ok _ _ Href) as [-> Hh']. cbn [result_bind].
           split; intros; try discriminate. inversion H; subst.
           eexists; split; [reflexivity |]. constructor; cbn; auto.
           apply corresponds_threads_ge_update; [exact Hmono | econstructor; [lia | exact Hh']].
        -- rewrite (Hcont_err _ Href); cbn [result_bind].
           split; intros; try discriminate; inversion H; reflexivity.
      * (* WaitFlag *)
        destruct (exec_resolve_operands cpol _ _ _ _ [src; dst; v]) as [[args uses]|err];
          cbn [result_bind]; [| split; intros; try discriminate; inversion H; reflexivity].
        destruct args as [|v1 r1]; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct v1; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct r1 as [|v2 r2]; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct v2; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct r2 as [|v3 r3]; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct v3; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct r3; try (split; intros; try discriminate; inversion H; reflexivity).
        destruct (check_declared_pipe tgt p && check_declared_pipe tgt p0);
          [| split; intros; try discriminate; inversion H; reflexivity].
        destruct (check_pipe_ready tgt _ _ (Some p0)) as [[]|err];
          cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses];
          [| split; intros; try discriminate; inversion H; reflexivity].
        match goal with |- context [refocus budget ?nc] => destruct (refocus budget nc) as [cur'|] eqn:Href end; cbn [result_bind].
        -- destruct (Hwait_ok (tid, path) _ _ Href) as [kw [-> [Hh' Hkw]]]. cbn [result_bind].
           split; intros; try discriminate. inversion H; subst.
           eexists; split; [reflexivity |]. constructor; cbn; auto.
           apply corresponds_threads_ge_update; [exact Hmono | apply CorrWaitingGe with (fuel := fuel'); [lia | exact Hh' | exact Hkw]].
        -- rewrite (Hwait_err (tid, path) _ Href); cbn [result_bind].
           split; intros; try discriminate; inversion H; reflexivity.
      * (* If *)
        destruct (exec_resolve_operand cpol _ _ _ _ cond) as [[val uses]|err];
          cbn [result_bind]; [| split; intros; try discriminate; inversion H; reflexivity].
        destruct val; try (split; intros; try discriminate; inversion H; reflexivity).
        cbn [result_bind eo_value eo_mode eo_event eo_sync eo_mem eo_uses].
        match goal with |- context [refocus budget ?nc] => destruct (refocus budget nc) as [cur'|] eqn:Href end; cbn [result_bind].
        -- destruct (Hcont_ok _ _ Href) as [-> Hh']. cbn [result_bind].
           split; intros; try discriminate. inversion H; subst.
           eexists; split; [reflexivity |]. constructor; cbn; auto.
           apply corresponds_threads_ge_update; [exact Hmono | econstructor; [lia | exact Hh']].
        -- rewrite (Hcont_err _ Href); cbn [result_bind].
           split; intros; try discriminate; inversion H; reflexivity.
    + split; intros; try discriminate; inversion H; reflexivity.
    + split; intros; try discriminate; inversion H; reflexivity.
  - assert (Hft : nth_error (fms_threads fst) j = None).
    { apply nth_error_None. rewrite <- Hlen. apply nth_error_None. exact Ht. }
    rewrite Hft. split; intros; try discriminate; inversion H; reflexivity.
Qed.

Theorem exec_finish_sync_free m budget o st fst :
  corresponds_state_ge m budget st fst ->
  (forall ev st',
     exec_finish_op tgt emodel cpol o st = Ok (ev, st') ->
     exists fst',
       step_free_finish o fst = Ok (ev, fst') /\
       corresponds_state_ge m budget st' fst') /\
  (forall err,
     exec_finish_op tgt emodel cpol o st = Error err ->
     step_free_finish o fst = Error err).
Proof.
  intros Hcs. destruct Hcs as [[Hlen Hall] Hsync Hmem Htr Huses].
  unfold exec_finish_op, step_free_finish, handle_finish_effect.
  unfold peq, eeq in *.
  rewrite <- Hsync, <- Hmem, <- Htr, <- Huses.
  destruct (lookup_inflight o (ms_sync st)) as [pk|] eqn:Hinf;
    [| split; intros; try discriminate; inversion H; reflexivity].
  destruct pk as [d a | d a data | d args | p q fl deps | p q fl j];
    cbn [result_bind].
  - destruct (mem_lookup a (ms_mem st)) as [v0|];
      [| destruct (pick_uninit_mem cpol a) as [res|]]; cbn [result_bind];
      (split; intros; try discriminate; try (inversion H; subst; eexists; split; [reflexivity | constructor; cbn; auto; split; assumption]); inversion H; reflexivity).
  - split; intros; try discriminate. inversion H; subst.
    eexists; split; [reflexivity | constructor; cbn; auto; split; assumption].
  - destruct (exec_comp emodel (resource d) args) as [res|]; cbn [result_bind];
      (split; intros; try discriminate; try (inversion H; subst; eexists; split; [reflexivity | constructor; cbn; auto; split; assumption]); inversion H; reflexivity).
  - destruct (deps_drained deps (sync_inflight (ms_sync st)));
      [destruct (flag_is_set _ _ p q fl (sync_flags (ms_sync st))) |];
      cbn [negb result_bind];
      (split; intros; try discriminate; try (inversion H; subst; eexists; split; [reflexivity | constructor; cbn; auto; split; assumption]); inversion H; reflexivity).
  - destruct (flag_is_set _ _ p q fl (sync_flags (ms_sync st)));
      cbn [result_bind]; [| split; intros; try discriminate; inversion H; reflexivity].
    destruct (nth_error (ms_threads st) j) as [t|] eqn:Ht.
    + assert (Hjlt : (j < length (fms_threads fst))%nat).
      { rewrite <- Hlen. apply nth_error_Some. rewrite Ht. discriminate. }
      destruct (nth_error (fms_threads fst) j) as [ft|] eqn:Hft;
        [| exfalso; apply nth_error_None in Hft; lia].
      pose proof (Hall j t ft Ht Hft) as Hct.
      inversion Hct as [fuel cur Hfm Hhead Hteq Hfteq | fuel w cur k Hfm Hhead Hk Hteq Hfteq | args Hteq Hfteq];
        subst t ft; try (split; intros; try discriminate; inversion H; reflexivity).
      destruct (op_id_eqb w o); [| split; intros; try discriminate; inversion H; reflexivity].
      split; intros; try discriminate. inversion H; subst.
      eexists; split; [reflexivity |]. constructor; cbn; auto.
      apply corresponds_threads_ge_update; [split; assumption | rewrite Hk; econstructor; assumption].
    + assert (Hft : nth_error (fms_threads fst) j = None).
      { apply nth_error_None. rewrite <- Hlen. apply nth_error_None. exact Ht. }
      rewrite Hft. split; intros; try discriminate; inversion H; reflexivity.
Qed.

(* 顶层定理 1：一阶派生解释器的执行轨迹满足关系型在线自动机 auto_steps *)
Lemma run_derived_loop_steps pol step_fuel budget ps st st' :
  run_derived_loop pol step_fuel budget ps st = Ok st' ->
  auto_steps layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st st'.
Proof.
  revert ps st st'. induction step_fuel as [|fuel' IH]; intros ps st st' H; cbn in H; [discriminate |].
  destruct (pol_next pol ps _ _ _) as [[j|o] ps' | | ]; try discriminate.
  - destruct (exec_issue_branch layout tgt cpol budget j st) as [[ev st1]|] eqn:Hs;
      cbn [result_bind] in H; [| discriminate].
    eapply StepsTrans; [eapply exec_issue_sound; exact Hs | eapply IH; exact H].
  - destruct (exec_finish_op tgt emodel cpol o st) as [[ev st1]|] eqn:Hs;
      cbn [result_bind] in H; [| discriminate].
    eapply StepsTrans; [eapply exec_finish_sound; exact Hs | eapply IH; exact H].
  - inversion H; subst. constructor.
Qed.

Theorem run_derived_state_steps pol step_fuel budget prog st' :
  run_derived_state pol step_fuel budget prog = Ok st' ->
  exists st0,
    init_machine budget (instantiate_shared layout 0 prog) = Ok st0 /\
    auto_steps layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st0 st'.
Proof.
  unfold run_derived_state. intros H.
  destruct (init_machine budget (instantiate_shared layout 0 prog)) as [st0|] eqn:Hi;
    cbn [result_bind] in H; [| discriminate].
  exists st0; split; [reflexivity | eapply run_derived_loop_steps; exact H].
Qed.

(* 顶层定理 2：高阶 Free Monad 解释器通过去函数化模拟同样满足 auto_steps *)
Lemma run_free_loop_steps pol step_fuel budget ps st fst fst' :
  (1 <= budget)%nat ->
  corresponds_state budget st fst ->
  run_free_loop pol step_fuel ps fst = Ok fst' ->
  exists st',
    auto_steps layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st st' /\
    corresponds_state budget st' fst'.
Proof.
  intros Hge. revert ps st fst fst'.
  induction step_fuel as [|fuel' IH]; intros ps st fst fst' Hcs H; cbn in H; [discriminate |].
  destruct (pol_next pol ps _ _ _) as [[j|o] ps' | | ]; try discriminate.
  - destruct (step_free_issue j fst) as [[ev fst1]|] eqn:Hs;
      cbn [result_bind] in H; [| discriminate].
    destruct (free_issue_refines_exec_issue j Hge Hcs Hs) as [st1 [Hexec Hcs1]].
    destruct (IH ps' st1 fst1 fst' Hcs1 H) as [st' [Hsteps Hcs']].
    exists st'; split; [eapply StepsTrans; [eapply exec_issue_sound; exact Hexec | exact Hsteps] | exact Hcs'].
  - destruct (step_free_finish o fst) as [[ev fst1]|] eqn:Hs;
      cbn [result_bind] in H; [| discriminate].
    destruct (free_finish_refines_exec_finish o Hcs Hs) as [st1 [Hexec Hcs1]].
    destruct (IH ps' st1 fst1 fst' Hcs1 H) as [st' [Hsteps Hcs']].
    exists st'; split; [eapply StepsTrans; [eapply exec_finish_sound; exact Hexec | exact Hsteps] | exact Hcs'].
  - inversion H; subst. exists st; split; [constructor | exact Hcs].
Qed.

Theorem run_free_state_steps pol step_fuel branch_fuel budget prog fst' :
  (1 <= budget)%nat ->
  run_free_state pol step_fuel branch_fuel budget prog = Ok fst' ->
  exists st0 st',
    init_machine budget (instantiate_shared layout 0 prog) = Ok st0 /\
    auto_steps layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st0 st' /\
    corresponds_state budget st' fst'.
Proof.
  intros Hge H. unfold run_free_state in H.
  destruct (init_free_machine branch_fuel budget (instantiate_shared layout 0 prog)) as [fst0|] eqn:Hi;
    cbn [result_bind] in H; [| discriminate].
  destruct (init_free_machine_corresponds branch_fuel _ Hge Hi) as [st0 [Hinit Hcsg]].
  assert (Hcs0 : corresponds_state budget st0 fst0).
  { destruct Hcsg as [[Hlen Hall] ? ? ? ?]. constructor; auto. split; [exact Hlen |].
    intros j t ft H1 H2. eapply corresponds_thread_ge_forget; eapply Hall; eassumption. }
  destruct (run_free_loop_steps pol step_fuel (pol_init pol) Hge Hcs0 H) as [st' [Hsteps Hcs']].
  exists st0, st'; auto.
Qed.

(* 顶层定理 3（双向锁步对应）：当每条分支燃料 >= 步数燃料时，Free Monad 解释器与一阶派生解释器产生完全相同的输出与错误！ *)
Lemma run_loops_lockstep pol step_fuel budget ps st fst :
  (1 <= budget)%nat ->
  corresponds_state_ge step_fuel budget st fst ->
  match run_derived_loop pol step_fuel budget ps st, run_free_loop pol step_fuel ps fst with
  | Ok st', Ok fst' => corresponds_state budget st' fst'
  | Error e1, Error e2 => e1 = e2
  | _, _ => False
  end.
Proof.
  intros Hge. revert ps st fst.
  induction step_fuel as [|fuel' IH]; intros ps st fst Hcsg; cbn; [reflexivity |].
  assert (Hcs : corresponds_state budget st fst).
  { destruct Hcsg as [[Hlen Hall] ? ? ? ?]. constructor; auto. split; [exact Hlen |].
    intros j t ft H1 H2. eapply corresponds_thread_ge_forget; eapply Hall; eassumption. }
  assert (Hst : map machine_thread_status (ms_threads st) = map free_thread_status (fms_threads fst))
    by (eapply corresponds_state_status; exact Hcs).
  assert (Hinf :
    map (fun '(o, _) => (o, is_ok (exec_finish_op tgt emodel cpol o st))) (rev (sync_inflight (ms_sync st))) =
    map (fun '(o, _) => (o, is_ok (step_free_finish o fst))) (rev (sync_inflight (fms_sync fst)))).
  { rewrite (cs_sync Hcs). apply map_ext. intros [o pk]. f_equal.
    destruct (exec_finish_sync_free o Hcsg) as [Hok Herr].
    destruct (exec_finish_op tgt emodel cpol o st) as [[ev st1]|err] eqn:He.
    - destruct (Hok ev st1 eq_refl) as [fst1 [-> _]]. reflexivity.
    - rewrite (Herr err eq_refl). reflexivity. }
  assert (Hbr :
    map (fun j => (j, is_ok (exec_issue_branch layout tgt cpol budget j st))) (seq 0 (length (ms_threads st))) =
    map (fun j => (j, is_ok (step_free_issue j fst))) (seq 0 (length (fms_threads fst)))).
  { rewrite (proj1 (cs_threads Hcs)). apply map_ext. intros j. f_equal.
    destruct (exec_issue_sync_free j Hge Hcsg) as [Hok Herr].
    destruct (exec_issue_branch layout tgt cpol budget j st) as [[ev st1]|err] eqn:He.
    - destruct (Hok ev st1 eq_refl) as [fst1 [-> _]]. reflexivity.
    - rewrite (Herr err eq_refl). reflexivity. }
  rewrite Hst, Hinf, Hbr.
  destruct (pol_next pol ps _ _ _) as [[j|o] ps' | | ].
  - destruct (exec_issue_sync_free j Hge Hcsg) as [Hok Herr].
    destruct (exec_issue_branch layout tgt cpol budget j st) as [[ev st1]|err] eqn:He.
    + destruct (Hok ev st1 eq_refl) as [fst1 [-> Hcsg1]]. cbn [result_bind snd].
      apply IH; exact Hcsg1.
    + rewrite (Herr err eq_refl). cbn [result_bind]. reflexivity.
  - destruct (exec_finish_sync_free o Hcsg) as [Hok Herr].
    destruct (exec_finish_op tgt emodel cpol o st) as [[ev st1]|err] eqn:He.
    + destruct (Hok ev st1 eq_refl) as [fst1 [-> Hcsg1]]. cbn [result_bind snd].
      assert (Hcsg1' : corresponds_state_ge fuel' budget st1 fst1).
      { destruct Hcsg1 as [Ht ? ? ? ?]. constructor; auto.
        eapply corresponds_threads_ge_mono; [| exact Ht]; lia. }
      apply IH; exact Hcsg1'.
    + rewrite (Herr err eq_refl). cbn [result_bind]. reflexivity.
  - exact Hcs.
  - reflexivity.
Qed.

Theorem free_and_derived_equivalent pol step_fuel branch_fuel budget prog :
  (1 <= budget)%nat ->
  (step_fuel <= branch_fuel)%nat ->
  run_free_interpreter pol step_fuel branch_fuel budget prog =
  run_derived_interpreter pol step_fuel budget prog.
Proof.
  intros Hge Hfuel. unfold run_free_interpreter, run_derived_interpreter, run_free_state, run_derived_state.
  destruct (init_machine budget (instantiate_shared layout 0 prog)) as [st0|err] eqn:Hi.
  - destruct (init_machine_corresponds_free branch_fuel _ Hge Hi) as [fst0 [Hfi Hcsg]].
    rewrite Hfi. cbn [result_bind].
    assert (Hcsg' : corresponds_state_ge step_fuel budget st0 fst0).
    { destruct Hcsg as [Ht ? ? ? ?]. constructor; auto.
      eapply corresponds_threads_ge_mono; [exact Hfuel | exact Ht]. }
    pose proof (run_loops_lockstep pol (pol_init pol) Hge Hcsg') as Hlock.
    destruct (run_derived_loop pol step_fuel budget (pol_init pol) st0) as [st'|e1];
    destruct (run_free_loop pol step_fuel (pol_init pol) fst0) as [fst'|e2];
      cbn [result_bind] in *; try contradiction.
    + f_equal. symmetry. eapply corresponds_state_result; exact Hlock.
    + subst; reflexivity.
  - rewrite (init_machine_error_corresponds_free branch_fuel _ Hge Hi). reflexivity.
Qed.

End Handlers.

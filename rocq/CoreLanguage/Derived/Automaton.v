From Stdlib Require Import List ZArith Bool Lia.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics.
From UnifiedInterpreter.CoreLanguage.Derived Require Import Refocusing.
Import ListNotations.
Set Implicit Arguments.

(* ========================================================================== *)
(* 1. 可判定相等性与可执行目标/模型/策略接口（不修改原有 TraceSemantics.v）       *)
(* ========================================================================== *)

Record eq_dec_ops (A : Type) := EqDecOps {
  eqb : A -> A -> bool;
  eqb_spec : forall x y, eqb x y = true <-> x = y
}.

Lemma eqb_refl {A} (D : eq_dec_ops A) (x : A) : eqb D x x = true.
Proof. apply (proj2 (eqb_spec D x x)). reflexivity. Qed.

Lemma eqb_neq {A} (D : eq_dec_ops A) (x y : A) : eqb D x y = false <-> x <> y.
Proof.
  split.
  - intros Hf Heq. subst. rewrite eqb_refl in Hf. discriminate.
  - intros Hneq. destruct (eqb D x y) eqn:E; [| reflexivity].
    apply (proj1 (eqb_spec D x y)) in E. contradiction.
Qed.

Definition op_id_eqb (x y : op_id) : bool :=
  Pos.eqb (fst x) (fst y) && Pos.eqb (snd x) (snd y).

Lemma op_id_eqb_spec x y : op_id_eqb x y = true <-> x = y.
Proof.
  destruct x as [x1 x2], y as [y1 y2]. unfold op_id_eqb; cbn.
  rewrite andb_true_iff, !Pos.eqb_eq.
  split; [intros [-> ->]; reflexivity | intros H; inversion H; auto].
Qed.

Definition op_id_eq_ops : eq_dec_ops op_id :=
  EqDecOps op_id_eqb op_id_eqb_spec.

Definition nat_eq_ops : eq_dec_ops nat :=
  EqDecOps Nat.eqb Nat.eqb_eq.

Record executable_target {Float EventId Pipe Unit : Type} := ExecTarget {
  exec_cfg : @configuration Pipe Unit;
  pipe_eq : eq_dec_ops Pipe;
  event_eq : eq_dec_ops EventId;
  check_declared_pipe : Pipe -> bool;
  check_declared_pipe_sound :
    forall p, check_declared_pipe p = true -> declared_pipeline exec_cfg p;
  check_declared_resource : Unit -> bool;
  check_declared_resource_sound :
    forall r, check_declared_resource r = true -> declared_resource exec_cfg r;
  check_can_read : Unit -> memory_resource -> bool;
  check_can_read_sound :
    forall r a, check_can_read r a = true -> can_read exec_cfg r a;
  check_can_write : Unit -> memory_resource -> bool;
  check_can_write_sound :
    forall r a, check_can_write r a = true -> can_write exec_cfg r a
}.

Record executable_model {Float EventId Pipe Unit : Type}
    (model : @computation_model Float EventId Pipe Unit) := ExecModel {
  exec_comp : Unit -> list (@value Float EventId Pipe) -> option (@value Float EventId Pipe);
  exec_comp_sound : forall r args res, exec_comp r args = Some res -> comp model r args res
}.

Definition model_of {Float EventId Pipe Unit : Type}
    (f : Unit -> list (@value Float EventId Pipe) -> @value Float EventId Pipe)
    : @computation_model Float EventId Pipe Unit :=
  {| comp := fun r args res => res = f r args;
     comp_total := fun r args => ex_intro _ (f r args) eq_refl |}.

Definition exec_model_of {Float EventId Pipe Unit : Type}
    (f : Unit -> list (@value Float EventId Pipe) -> @value Float EventId Pipe)
    : executable_model (model_of f).
Proof.
  refine {| exec_comp := fun r args => Some (f r args) |}.
  intros r args res H. inversion H; reflexivity.
Defined.

(* 两类合法非确定性（提前使用异步结果、读未写入内存）的策略参数。 *)
Record choice_policy {Float EventId Pipe : Type} := ChoicePolicy {
  pick_early_async : op_id -> nat -> op_id -> option (@value Float EventId Pipe);
  pick_uninit_mem : memory_resource -> option (@value Float EventId Pipe)
}.

Definition strict_choice_policy {Float EventId Pipe : Type}
    (init_mem : memory_resource -> option (@value Float EventId Pipe))
    : @choice_policy Float EventId Pipe :=
  {| pick_early_async := fun _ _ _ => None;
     pick_uninit_mem := init_mem |}.

Definition permissive_choice_policy {Float EventId Pipe : Type}
    (init_mem : memory_resource -> option (@value Float EventId Pipe))
    (early_oracle : op_id -> nat -> op_id -> @value Float EventId Pipe)
    (uninit_default : @value Float EventId Pipe)
    : @choice_policy Float EventId Pipe :=
  {| pick_early_async := fun c i p => Some (early_oracle c i p);
     pick_uninit_mem := fun a =>
       match init_mem a with Some v => Some v | None => Some uninit_default end |}.

Inductive step_error :=
| ErrRefocusStuck (branch : nat)
| ErrInvalidBranch (branch : nat)
| ErrBranchNotRunnable (branch : nat)
| ErrUnboundOperand (op : op_id)
| ErrEarlyAsyncUse (consumer producer : op_id)
| ErrTypeMismatch (op : op_id)
| ErrInvalidAtomic (op : op_id)
| ErrAllocAlreadyWritten (op : op_id) (addr : memory_resource)
| ErrPermissionDenied (op : op_id)
| ErrPipeBlockedByWait (op : op_id)
| ErrInflightNotFound (op : op_id)
| ErrSetFlagDepsPending (op : op_id)
| ErrFlagNotReady (op : op_id)
| ErrUninitMemoryRead (op : op_id) (addr : memory_resource)
| ErrComputeUndefined (op : op_id)
| ErrOutOfFuel
| ErrDeadlocked.

(* ========================================================================== *)
(* 2. 在线前缀自动机状态定义与基础操作                                           *)
(* ========================================================================== *)

Section Automaton.
Context {Float EventId Pipe Unit : Type}.
Local Notation Val := (@value Float EventId Pipe).
Local Notation RawCmd := (@command Float EventId Pipe Unit unit).
Local Notation Rec := (@event_record Float EventId Pipe Unit).
Local Notation Use := (@use_record Float EventId Pipe).
Local Notation Cursor := (@thread_cursor Float EventId Pipe Unit).
Local Notation Model := (@computation_model Float EventId Pipe Unit).

(* 去函数化后的一阶线程状态（同时是 Free Monad 续体去函数化结果）。 *)
Inductive thread_state : Type :=
| TRunning (cur : Cursor)
| TWaitingFlag (wait_op : op_id) (next_cur : Cursor)
| TDone (results : list Val).

Inductive pending_kind : Type :=
| PRead (d : execution Unit Pipe) (addr : memory_resource)
| PWrite (d : execution Unit Pipe) (addr : memory_resource) (data : Val)
| PCompute (d : execution Unit Pipe) (args : list Val)
| PSetFlag (src dst : Pipe) (flag : EventId) (deps : list op_id)
| PWaitFlag (src dst : Pipe) (flag : EventId) (branch_idx : nat).

Definition pending_pipe (pk : pending_kind) : option Pipe :=
  match pk with
  | PRead d _ | PWrite d _ _ | PCompute d _ => queue d
  | PSetFlag src _ _ _ => Some src
  | PWaitFlag _ dst _ _ => Some dst
  end.

Record sync_state : Type := SyncState {
  sync_inflight : list (op_id * pending_kind);
  sync_flags : list (Pipe * Pipe * EventId);
  sync_active_wait : list (Pipe * op_id)
}.

Record mem_state : Type := MemState {
  mem_writes : list (memory_resource * Val);
  mem_done_val : list (op_id * Val)
}.

Record machine_state : Type := MachineState {
  ms_threads : list thread_state;
  ms_sync : sync_state;
  ms_mem : mem_state;
  ms_rev_trace : list Rec;
  ms_rev_uses : list Use
}.

Definition empty_sync_state : sync_state := SyncState [] [] [].
Definition empty_mem_state : mem_state := MemState [] [].

(* 辅助列表查询/更新函数 *)

Fixpoint update_nth {A} (idx : nat) (v : A) (xs : list A) : list A :=
  match idx, xs with
  | 0, _ :: rest => v :: rest
  | S k, x :: rest => x :: update_nth k v rest
  | _, [] => []
  end.

Lemma length_update_nth {A} idx (v : A) xs :
  length (update_nth idx v xs) = length xs.
Proof.
  revert idx. induction xs as [|x xs IH]; intros [|k]; cbn; auto.
Qed.

Lemma nth_error_update_nth_eq {A} idx (v : A) xs :
  (idx < length xs)%nat ->
  nth_error (update_nth idx v xs) idx = Some v.
Proof.
  revert idx. induction xs as [|x xs IH]; intros [|k] Hlt; cbn in *; try lia; auto.
  apply IH; lia.
Qed.

Lemma nth_error_update_nth_neq {A} i j (v : A) xs :
  i <> j ->
  nth_error (update_nth i v xs) j = nth_error xs j.
Proof.
  revert i j. induction xs as [|x xs IH]; intros [|i] [|j] Hneq; cbn; auto; try lia.
Qed.

Fixpoint lookup_assoc {K V} (eqk : K -> K -> bool) (k : K) (xs : list (K * V)) : option V :=
  match xs with
  | [] => None
  | (k', v) :: rest => if eqk k k' then Some v else lookup_assoc eqk k rest
  end.

Fixpoint remove_assoc {K V} (eqk : K -> K -> bool) (k : K) (xs : list (K * V)) : list (K * V) :=
  match xs with
  | [] => []
  | (k', v) :: rest =>
      if eqk k k' then remove_assoc eqk k rest else (k', v) :: remove_assoc eqk k rest
  end.

Lemma lookup_assoc_remove_eq {K V} (D : eq_dec_ops K) k (xs : list (K * V)) :
  lookup_assoc (eqb D) k (remove_assoc (eqb D) k xs) = None.
Proof.
  induction xs as [|[k' v] xs IH]; cbn; [reflexivity |].
  destruct (eqb D k k') eqn:E; cbn; [exact IH | rewrite E; exact IH].
Qed.

Lemma lookup_assoc_remove_neq {K V} (D : eq_dec_ops K) k1 k2 (xs : list (K * V)) :
  k1 <> k2 ->
  lookup_assoc (eqb D) k1 (remove_assoc (eqb D) k2 xs) = lookup_assoc (eqb D) k1 xs.
Proof.
  intros Hneq. induction xs as [|[k' v] xs IH]; cbn; [reflexivity |].
  destruct (eqb D k2 k') eqn:E2.
  - apply (proj1 (eqb_spec D _ _)) in E2; subst k'.
    rewrite (proj2 (eqb_neq D k1 k2) Hneq). exact IH.
  - cbn. destruct (eqb D k1 k'); [reflexivity | exact IH].
Qed.

Lemma lookup_assoc_in {K V} (D : eq_dec_ops K) k v (xs : list (K * V)) :
  lookup_assoc (eqb D) k xs = Some v -> In (k, v) xs.
Proof.
  induction xs as [|[k' v'] xs IH]; cbn; [discriminate |].
  destruct (eqb D k k') eqn:E.
  - intros H; inversion H; subst. apply (proj1 (eqb_spec D _ _)) in E; subst. now left.
  - intros H; right; auto.
Qed.

Definition lookup_inflight (o : op_id) (s : sync_state) : option pending_kind :=
  lookup_assoc op_id_eqb o (sync_inflight s).

Definition inflight_on_pipe (peq : Pipe -> Pipe -> bool) (p : Pipe)
    (inflight : list (op_id * pending_kind)) : list op_id :=
  flat_map (fun '(o, pk) =>
    match pending_pipe pk with
    | Some q => if peq p q then [o] else []
    | None => []
    end) inflight.

Definition deps_drained (deps : list op_id) (inflight : list (op_id * pending_kind)) : bool :=
  forallb (fun d => match lookup_assoc op_id_eqb d inflight with None => true | Some _ => false end) deps.

Definition flag_key_eqb (peq : Pipe -> Pipe -> bool) (eeq : EventId -> EventId -> bool)
    (h1 h2 : Pipe * Pipe * EventId) : bool :=
  let '(p1, q1, e1) := h1 in
  let '(p2, q2, e2) := h2 in
  peq p1 p2 && peq q1 q2 && eeq e1 e2.

Definition flag_is_set (peq : Pipe -> Pipe -> bool) (eeq : EventId -> EventId -> bool)
    (p q : Pipe) (e : EventId) (flags : list (Pipe * Pipe * EventId)) : bool :=
  existsb (flag_key_eqb peq eeq (p, q, e)) flags.

Definition flag_set_true (p q : Pipe) (e : EventId)
    (flags : list (Pipe * Pipe * EventId)) : list (Pipe * Pipe * EventId) :=
  (p, q, e) :: flags.

Definition flag_set_false (peq : Pipe -> Pipe -> bool) (eeq : EventId -> EventId -> bool)
    (p q : Pipe) (e : EventId) (flags : list (Pipe * Pipe * EventId))
    : list (Pipe * Pipe * EventId) :=
  filter (fun h => negb (flag_key_eqb peq eeq (p, q, e) h)) flags.

Definition active_wait_of (peq : Pipe -> Pipe -> bool) (q : Pipe)
    (aw : list (Pipe * op_id)) : option op_id :=
  lookup_assoc peq q aw.

Definition active_wait_set (q : Pipe) (w : op_id) (aw : list (Pipe * op_id))
    : list (Pipe * op_id) :=
  (q, w) :: aw.

Definition active_wait_clear (peq : Pipe -> Pipe -> bool) (q : Pipe)
    (aw : list (Pipe * op_id)) : list (Pipe * op_id) :=
  remove_assoc peq q aw.

Definition mem_lookup (a : memory_resource) (m : mem_state) : option Val :=
  lookup_assoc Nat.eqb a (mem_writes m).

Definition done_val_lookup (o : op_id) (m : mem_state) : option Val :=
  lookup_assoc op_id_eqb o (mem_done_val m).

Lemma flag_key_eqb_spec (Pe : eq_dec_ops Pipe) (Ee : eq_dec_ops EventId) h1 h2 :
  flag_key_eqb (eqb Pe) (eqb Ee) h1 h2 = true <-> h1 = h2.
Proof.
  destruct h1 as [[p1 q1] e1], h2 as [[p2 q2] e2].
  unfold flag_key_eqb. rewrite !andb_true_iff, !(eqb_spec Pe), (eqb_spec Ee).
  split; [intros [[-> ->] ->]; reflexivity | intros H; inversion H; auto].
Qed.

Lemma flag_is_set_true_eq (Pe : eq_dec_ops Pipe) (Ee : eq_dec_ops EventId) p q e flags :
  flag_is_set (eqb Pe) (eqb Ee) p q e (flag_set_true p q e flags) = true.
Proof.
  unfold flag_is_set, flag_set_true; cbn [existsb].
  rewrite (proj2 (flag_key_eqb_spec Pe Ee _ _) eq_refl). reflexivity.
Qed.

Lemma flag_is_set_true_neq (Pe : eq_dec_ops Pipe) (Ee : eq_dec_ops EventId) p q e p' q' e' flags :
  (p', q', e') <> (p, q, e) ->
  flag_is_set (eqb Pe) (eqb Ee) p' q' e' (flag_set_true p q e flags) =
  flag_is_set (eqb Pe) (eqb Ee) p' q' e' flags.
Proof.
  intros Hneq. unfold flag_is_set, flag_set_true; cbn [existsb].
  destruct (flag_key_eqb (eqb Pe) (eqb Ee) (p', q', e') (p, q, e)) eqn:E; [| reflexivity].
  apply (proj1 (flag_key_eqb_spec Pe Ee _ _)) in E. contradiction.
Qed.

Lemma flag_is_set_false_eq (Pe : eq_dec_ops Pipe) (Ee : eq_dec_ops EventId) p q e flags :
  flag_is_set (eqb Pe) (eqb Ee) p q e (flag_set_false (eqb Pe) (eqb Ee) p q e flags) = false.
Proof.
  unfold flag_is_set, flag_set_false.
  induction flags as [|h flags IH]; cbn [filter existsb]; [reflexivity |].
  destruct (flag_key_eqb (eqb Pe) (eqb Ee) (p, q, e) h) eqn:E; cbn [negb existsb]; [exact IH | rewrite E; exact IH].
Qed.

Lemma flag_is_set_false_neq (Pe : eq_dec_ops Pipe) (Ee : eq_dec_ops EventId) p q e p' q' e' flags :
  (p', q', e') <> (p, q, e) ->
  flag_is_set (eqb Pe) (eqb Ee) p' q' e' (flag_set_false (eqb Pe) (eqb Ee) p q e flags) =
  flag_is_set (eqb Pe) (eqb Ee) p' q' e' flags.
Proof.
  intros Hneq. unfold flag_is_set, flag_set_false.
  induction flags as [|h flags IH]; cbn [filter existsb]; [reflexivity |].
  destruct (flag_key_eqb (eqb Pe) (eqb Ee) (p, q, e) h) eqn:E1; cbn [negb existsb].
  - apply (proj1 (flag_key_eqb_spec Pe Ee _ _)) in E1; subst h.
    destruct (flag_key_eqb (eqb Pe) (eqb Ee) (p', q', e') (p, q, e)) eqn:E2; [| exact IH].
    apply (proj1 (flag_key_eqb_spec Pe Ee _ _)) in E2. contradiction.
  - destruct (flag_key_eqb (eqb Pe) (eqb Ee) (p', q', e') h); [reflexivity | exact IH].
Qed.

(* 初始化多分支自动机：将每条原始分支做首次 refocus，保证全部处于可观测头命令。 *)
Fixpoint init_threads_aux (budget idx : nat) (branches : list RawCmd)
    : result step_error (list thread_state) :=
  match branches with
  | [] => Ok []
  | c :: rest =>
      let cur0 := ThreadCursor (Pos.of_succ_nat idx) 1%positive empty_environment c [] in
      match refocus budget cur0 with
      | None => Error (ErrRefocusStuck idx)
      | Some cur =>
          ts <-? init_threads_aux budget (S idx) rest ;;
          Ok (TRunning cur :: ts)
      end
  end.

Definition init_machine (budget : nat) (branches : list RawCmd)
    : result step_error machine_state :=
  ts <-? init_threads_aux budget 0 branches ;;
  Ok (MachineState ts empty_sync_state empty_mem_state [] []).

(* ========================================================================== *)
(* 3. 关系型在线自动机迁移关系 auto_step（精确对应 TraceSemantics 公理）         *)
(* ========================================================================== *)

Section RelationalAutomaton.
Context (layout : allocation_layout).
Context (cfg : @configuration Pipe Unit).
Context (model : Model).
Context (Pe : eq_dec_ops Pipe) (Ee : eq_dec_ops EventId).

(* 单个操作数按完成结果表 done_val 因果求值 *)
Inductive resolve_operand_rel (done_val : list (op_id * Val))
    (rho : @environment Float EventId Pipe) (o : op_id) (idx : nat)
    : @operand Float EventId Pipe -> Val -> list Use -> Prop :=
| ResKnown : forall v a,
    resolve rho v = Some (Known a) ->
    resolve_operand_rel done_val rho o idx v a []
| ResAsync : forall v r a,
    resolve rho v = Some (Async r) ->
    (forall res, lookup_assoc op_id_eqb r done_val = Some res -> a = res) ->
    resolve_operand_rel done_val rho o idx v a [UseRecord o idx r a].

Inductive resolve_operands_rel (done_val : list (op_id * Val))
    (rho : @environment Float EventId Pipe) (o : op_id)
    : nat -> list (@operand Float EventId Pipe) -> list Val -> list Use -> Prop :=
| ResNil : forall i, resolve_operands_rel done_val rho o i [] [] []
| ResCons : forall i v vs a args u1 u2,
    resolve_operand_rel done_val rho o i v a u1 ->
    resolve_operands_rel done_val rho o (S i) vs args u2 ->
    resolve_operands_rel done_val rho o i (v :: vs) (a :: args) (u1 ++ u2).

Inductive resolve_exec_rel (done_val : list (op_id * Val))
    (rho : @environment Float EventId Pipe) (o : op_id)
    (vs : list (@operand Float EventId Pipe))
    : option (@operand Float EventId Pipe) -> option Pipe -> list Val -> list Use -> Prop :=
| ResDirect : forall args uses,
    resolve_operands_rel done_val rho o 0 vs args uses ->
    resolve_exec_rel done_val rho o vs None None args uses
| ResQueued : forall v p args uses,
    resolve_operands_rel done_val rho o 0 (v :: vs) (VPipe p :: args) uses ->
    resolve_exec_rel done_val rho o vs (Some v) (Some p) args uses.

Definition pipe_ready (aw : list (Pipe * op_id)) (p : option Pipe) : Prop :=
  match p with
  | None => True
  | Some q => declared_pipeline cfg q /\ active_wait_of (eqb Pe) q aw = None
  end.

Definition advance_cursor (budget : nat) (tid path : positive)
    (rho : @environment Float EventId Pipe) (cmd : RawCmd) (stk : list (@loop_frame Float EventId Pipe Unit))
    (cur' : Cursor) : Prop :=
  refocus budget (ThreadCursor tid path rho cmd stk) = Some cur'.

Inductive auto_step (budget : nat) : machine_state -> Rec -> machine_state -> Prop :=
| StepAlloc : forall st j cur tid path rho x n cur' addr,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho (Alloc tt x n) (cursor_stack cur) ->
    let o := (tid, path) in
    addr = address_at layout (InBranch o) ->
    mem_lookup addr (ms_mem st) = None ->
    advance_cursor budget tid (xO path) (bind rho x (Known (VMemory addr))) n (cursor_stack cur) cur' ->
    let ev := EventRecord o (LAlloc addr) in
    auto_step budget st ev
      (MachineState (update_nth j (TRunning cur') (ms_threads st))
                    (ms_sync st) (ms_mem st)
                    (ev :: ms_rev_trace st) (ms_rev_uses st))

| StepAtomic : forall st j cur tid path rho x f vs n cur' args res uses,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho (LetAtomic tt x f vs n) (cursor_stack cur) ->
    let o := (tid, path) in
    resolve_operands_rel (mem_done_val (ms_mem st)) rho o 0 vs args uses ->
    eval_atomic f args = Some res ->
    advance_cursor budget tid (xO path) (bind rho x (Known res)) n (cursor_stack cur) cur' ->
    let ev := EventRecord o (LAtomic f args res) in
    auto_step budget st ev
      (MachineState (update_nth j (TRunning cur') (ms_threads st))
                    (ms_sync st) (ms_mem st)
                    (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))

| StepAssignPipe : forall st j cur tid path rho x v n cur' p uses,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho (AssignPipe tt x v n) (cursor_stack cur) ->
    let o := (tid, path) in
    resolve_operand_rel (mem_done_val (ms_mem st)) rho o 0 v (VPipe p) uses ->
    declared_pipeline cfg p ->
    advance_cursor budget tid (xO path) (bind rho x (Known (VPipe p))) n (cursor_stack cur) cur' ->
    let ev := EventRecord o (LPipeAssignment x p) in
    auto_step budget st ev
      (MachineState (update_nth j (TRunning cur') (ms_threads st))
                    (ms_sync st) (ms_mem st)
                    (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))

| StepReadStart : forall st j cur tid path rho x d v n cur' p a uses,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho (Read tt x d v n) (cursor_stack cur) ->
    let o := (tid, path) in
    resolve_exec_rel (mem_done_val (ms_mem st)) rho o [v] (queue d) p [VMemory a] uses ->
    declared_resource cfg (resource d) ->
    can_read cfg (resource d) a ->
    pipe_ready (sync_active_wait (ms_sync st)) p ->
    advance_cursor budget tid (xO path) (bind rho x (Async o)) n (cursor_stack cur) cur' ->
    let disp := Dispatch (resource d) p in
    let ev := EventRecord o (LReadStart disp a) in
    let sync' := SyncState ((o, PRead disp a) :: sync_inflight (ms_sync st))
                           (sync_flags (ms_sync st))
                           (sync_active_wait (ms_sync st)) in
    auto_step budget st ev
      (MachineState (update_nth j (TRunning cur') (ms_threads st))
                    sync' (ms_mem st)
                    (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))

| StepWriteStart : forall st j cur tid path rho d v1 v2 n cur' p a data uses,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho (Write tt d v1 v2 n) (cursor_stack cur) ->
    let o := (tid, path) in
    resolve_exec_rel (mem_done_val (ms_mem st)) rho o [v1; v2] (queue d) p [VMemory a; data] uses ->
    declared_resource cfg (resource d) ->
    can_write cfg (resource d) a ->
    pipe_ready (sync_active_wait (ms_sync st)) p ->
    advance_cursor budget tid (xO path) rho n (cursor_stack cur) cur' ->
    let disp := Dispatch (resource d) p in
    let ev := EventRecord o (LWriteStart disp a data) in
    let sync' := SyncState ((o, PWrite disp a data) :: sync_inflight (ms_sync st))
                           (sync_flags (ms_sync st))
                           (sync_active_wait (ms_sync st)) in
    auto_step budget st ev
      (MachineState (update_nth j (TRunning cur') (ms_threads st))
                    sync' (ms_mem st)
                    (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))

| StepComputeStart : forall st j cur tid path rho x d vs n cur' p args uses,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho (CCompute tt x d vs n) (cursor_stack cur) ->
    let o := (tid, path) in
    resolve_exec_rel (mem_done_val (ms_mem st)) rho o vs (queue d) p args uses ->
    declared_resource cfg (resource d) ->
    pipe_ready (sync_active_wait (ms_sync st)) p ->
    advance_cursor budget tid (xO path) (bind rho x (Async o)) n (cursor_stack cur) cur' ->
    let disp := Dispatch (resource d) p in
    let ev := EventRecord o (LComputeStart disp args) in
    let sync' := SyncState ((o, PCompute disp args) :: sync_inflight (ms_sync st))
                           (sync_flags (ms_sync st))
                           (sync_active_wait (ms_sync st)) in
    auto_step budget st ev
      (MachineState (update_nth j (TRunning cur') (ms_threads st))
                    sync' (ms_mem st)
                    (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))

| StepSetFlagStart : forall st j cur tid path rho src dst v n cur' p q fl uses,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho (SetFlag tt src dst v n) (cursor_stack cur) ->
    let o := (tid, path) in
    resolve_operands_rel (mem_done_val (ms_mem st)) rho o 0 [src; dst; v] [VPipe p; VPipe q; VEvent fl] uses ->
    declared_pipeline cfg p ->
    declared_pipeline cfg q ->
    pipe_ready (sync_active_wait (ms_sync st)) (Some p) ->
    advance_cursor budget tid (xO path) rho n (cursor_stack cur) cur' ->
    let deps := inflight_on_pipe (eqb Pe) p (sync_inflight (ms_sync st)) in
    let ev := EventRecord o (LSetFlagStart p q fl) in
    let sync' := SyncState ((o, PSetFlag p q fl deps) :: sync_inflight (ms_sync st))
                           (sync_flags (ms_sync st))
                           (sync_active_wait (ms_sync st)) in
    auto_step budget st ev
      (MachineState (update_nth j (TRunning cur') (ms_threads st))
                    sync' (ms_mem st)
                    (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))

| StepWaitFlagStart : forall st j cur tid path rho src dst v n cur' p q fl uses,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho (WaitFlag tt src dst v n) (cursor_stack cur) ->
    let o := (tid, path) in
    resolve_operands_rel (mem_done_val (ms_mem st)) rho o 0 [src; dst; v] [VPipe p; VPipe q; VEvent fl] uses ->
    declared_pipeline cfg p ->
    declared_pipeline cfg q ->
    pipe_ready (sync_active_wait (ms_sync st)) (Some q) ->
    advance_cursor budget tid (xO path) rho n (cursor_stack cur) cur' ->
    let ev := EventRecord o (LWaitFlagStart p q fl) in
    let sync' := SyncState ((o, PWaitFlag p q fl j) :: sync_inflight (ms_sync st))
                           (sync_flags (ms_sync st))
                           (active_wait_set q o (sync_active_wait (ms_sync st))) in
    auto_step budget st ev
      (MachineState (update_nth j (TWaitingFlag o cur') (ms_threads st))
                    sync' (ms_mem st)
                    (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))

| StepIf : forall st j cur tid path rho cond y n cur' b uses,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho (If tt cond y n) (cursor_stack cur) ->
    let o := (tid, path) in
    resolve_operand_rel (mem_done_val (ms_mem st)) rho o 0 cond (VBool b) uses ->
    advance_cursor budget tid (if b then xO path else xI path) rho (if b then y else n) (cursor_stack cur) cur' ->
    let ev := EventRecord o (LBranch b) in
    auto_step budget st ev
      (MachineState (update_nth j (TRunning cur') (ms_threads st))
                    (ms_sync st) (ms_mem st)
                    (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))

| StepReturn : forall st j cur tid path rho vs args uses,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho (Return tt vs) (cursor_stack cur) ->
    let o := (tid, path) in
    resolve_operands_rel (mem_done_val (ms_mem st)) rho o 0 vs args uses ->
    let ev := EventRecord o (LReturn args) in
    auto_step budget st ev
      (MachineState (update_nth j (TDone args) (ms_threads st))
                    (ms_sync st) (ms_mem st)
                    (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))

| StepReadEnd : forall st o d a res,
    lookup_inflight o (ms_sync st) = Some (PRead d a) ->
    (forall v0, mem_lookup a (ms_mem st) = Some v0 -> res = v0) ->
    let ev := EventRecord o (LReadEnd res) in
    let sync' := SyncState (remove_assoc op_id_eqb o (sync_inflight (ms_sync st)))
                           (sync_flags (ms_sync st))
                           (sync_active_wait (ms_sync st)) in
    let mem' := MemState (mem_writes (ms_mem st)) ((o, res) :: mem_done_val (ms_mem st)) in
    auto_step budget st ev
      (MachineState (ms_threads st) sync' mem' (ev :: ms_rev_trace st) (ms_rev_uses st))

| StepWriteEnd : forall st o d a data,
    lookup_inflight o (ms_sync st) = Some (PWrite d a data) ->
    let ev := EventRecord o LWriteEnd in
    let sync' := SyncState (remove_assoc op_id_eqb o (sync_inflight (ms_sync st)))
                           (sync_flags (ms_sync st))
                           (sync_active_wait (ms_sync st)) in
    let mem' := MemState ((a, data) :: mem_writes (ms_mem st)) (mem_done_val (ms_mem st)) in
    auto_step budget st ev
      (MachineState (ms_threads st) sync' mem' (ev :: ms_rev_trace st) (ms_rev_uses st))

| StepComputeEnd : forall st o d args res,
    lookup_inflight o (ms_sync st) = Some (PCompute d args) ->
    comp model (resource d) args res ->
    let ev := EventRecord o (LComputeEnd res) in
    let sync' := SyncState (remove_assoc op_id_eqb o (sync_inflight (ms_sync st)))
                           (sync_flags (ms_sync st))
                           (sync_active_wait (ms_sync st)) in
    let mem' := MemState (mem_writes (ms_mem st)) ((o, res) :: mem_done_val (ms_mem st)) in
    auto_step budget st ev
      (MachineState (ms_threads st) sync' mem' (ev :: ms_rev_trace st) (ms_rev_uses st))

| StepSetFlagEnd : forall st f p q fl deps,
    lookup_inflight f (ms_sync st) = Some (PSetFlag p q fl deps) ->
    deps_drained deps (sync_inflight (ms_sync st)) = true ->
    flag_is_set (eqb Pe) (eqb Ee) p q fl (sync_flags (ms_sync st)) = false ->
    let ev := EventRecord f LSetFlagEnd in
    let sync' := SyncState (remove_assoc op_id_eqb f (sync_inflight (ms_sync st)))
                           (flag_set_true p q fl (sync_flags (ms_sync st)))
                           (sync_active_wait (ms_sync st)) in
    auto_step budget st ev
      (MachineState (ms_threads st) sync' (ms_mem st) (ev :: ms_rev_trace st) (ms_rev_uses st))

| StepWaitFlagEnd : forall st w p q fl j next_cur,
    lookup_inflight w (ms_sync st) = Some (PWaitFlag p q fl j) ->
    flag_is_set (eqb Pe) (eqb Ee) p q fl (sync_flags (ms_sync st)) = true ->
    nth_error (ms_threads st) j = Some (TWaitingFlag w next_cur) ->
    let ev := EventRecord w LWaitFlagEnd in
    let sync' := SyncState (remove_assoc op_id_eqb w (sync_inflight (ms_sync st)))
                           (flag_set_false (eqb Pe) (eqb Ee) p q fl (sync_flags (ms_sync st)))
                           (active_wait_clear (eqb Pe) q (sync_active_wait (ms_sync st))) in
    auto_step budget st ev
      (MachineState (update_nth j (TRunning next_cur) (ms_threads st))
                    sync' (ms_mem st) (ev :: ms_rev_trace st) (ms_rev_uses st)).

Inductive auto_steps (budget : nat) : machine_state -> machine_state -> Prop :=
| StepsRefl : forall st, auto_steps budget st st
| StepsTrans : forall st1 ev st2 st3,
    auto_step budget st1 ev st2 ->
    auto_steps budget st2 st3 ->
    auto_steps budget st1 st3.

Lemma auto_steps_snoc budget st1 st2 ev st3 :
  auto_steps budget st1 st2 ->
  auto_step budget st2 ev st3 ->
  auto_steps budget st1 st3.
Proof.
  intros H12 H23. induction H12; eauto using auto_steps.
Qed.

End RelationalAutomaton.

(* ========================================================================== *)
(* 4. 可执行去函数化单步转移函数及对 auto_step 的精细化证明                       *)
(* ========================================================================== *)

Section ExecutableStep.
Context (layout : allocation_layout).
Context (tgt : @executable_target Float EventId Pipe Unit).
Context (model : Model) (emodel : executable_model model).
Context (cpol : @choice_policy Float EventId Pipe).

Let peq := eqb (pipe_eq tgt).
Let eeq := eqb (event_eq tgt).

Definition exec_resolve_operand (done_val : list (op_id * Val))
    (rho : @environment Float EventId Pipe) (o : op_id) (idx : nat)
    (v : @operand Float EventId Pipe) : result step_error (Val * list Use) :=
  match resolve rho v with
  | None => Error (ErrUnboundOperand o)
  | Some (Known a) => Ok (a, [])
  | Some (Async r) =>
      match lookup_assoc op_id_eqb r done_val with
      | Some a => Ok (a, [UseRecord o idx r a])
      | None =>
          match pick_early_async cpol o idx r with
          | Some a => Ok (a, [UseRecord o idx r a])
          | None => Error (ErrEarlyAsyncUse o r)
          end
      end
  end.

Fixpoint exec_resolve_operands (done_val : list (op_id * Val))
    (rho : @environment Float EventId Pipe) (o : op_id) (idx : nat)
    (vs : list (@operand Float EventId Pipe)) : result step_error (list Val * list Use) :=
  match vs with
  | [] => Ok ([], [])
  | v :: rest =>
      r1 <-? exec_resolve_operand done_val rho o idx v ;;
      let '(a, u1) := r1 in
      r2 <-? exec_resolve_operands done_val rho o (S idx) rest ;;
      let '(args, u2) := r2 in
      Ok (a :: args, u1 ++ u2)
  end.

Definition exec_resolve_exec (done_val : list (op_id * Val))
    (rho : @environment Float EventId Pipe) (o : op_id)
    (vs : list (@operand Float EventId Pipe))
    (q : option (@operand Float EventId Pipe))
    : result step_error (option Pipe * list Val * list Use) :=
  match q with
  | None =>
      r <-? exec_resolve_operands done_val rho o 0 vs ;;
      let '(args, uses) := r in
      Ok (None, args, uses)
  | Some vq =>
      r <-? exec_resolve_operands done_val rho o 0 (vq :: vs) ;;
      let '(vals, uses) := r in
      match vals with
      | VPipe p :: args => Ok (Some p, args, uses)
      | _ => Error (ErrTypeMismatch o)
      end
  end.

Definition check_pipe_ready (aw : list (Pipe * op_id)) (o : op_id) (p : option Pipe)
    : result step_error unit :=
  match p with
  | None => Ok tt
  | Some q =>
      if check_declared_pipe tgt q then
        match active_wait_of peq q aw with
        | None => Ok tt
        | Some _ => Error (ErrPipeBlockedByWait o)
        end
      else Error (ErrPermissionDenied o)
  end.

Definition exec_advance (budget j : nat) (tid path : positive)
    (rho : @environment Float EventId Pipe) (n : RawCmd) (stk : list (@loop_frame Float EventId Pipe Unit))
    : result step_error Cursor :=
  match refocus budget (ThreadCursor tid path rho n stk) with
  | Some cur' => Ok cur'
  | None => Error (ErrRefocusStuck j)
  end.

Definition exec_issue_branch (budget j : nat) (st : machine_state)
    : result step_error (Rec * machine_state) :=
  match nth_error (ms_threads st) j with
  | None => Error (ErrInvalidBranch j)
  | Some (TDone _) | Some (TWaitingFlag _ _) => Error (ErrBranchNotRunnable j)
  | Some (TRunning cur) =>
      let tid := cursor_tid cur in
      let path := cursor_path cur in
      let rho := cursor_env cur in
      let stk := cursor_stack cur in
      let o := (tid, path) in
      let dv := mem_done_val (ms_mem st) in
      let aw := sync_active_wait (ms_sync st) in
      match cursor_cmd cur with
      | Alloc tt x n =>
          let addr := address_at layout (InBranch o) in
          match mem_lookup addr (ms_mem st) with
          | Some _ => Error (ErrAllocAlreadyWritten o addr)
          | None =>
              cur' <-? exec_advance budget j tid (xO path) (bind rho x (Known (VMemory addr))) n stk ;;
              let ev := EventRecord o (LAlloc addr) in
              Ok (ev, MachineState (update_nth j (TRunning cur') (ms_threads st))
                        (ms_sync st) (ms_mem st)
                        (ev :: ms_rev_trace st) (ms_rev_uses st))
          end
      | LetAtomic tt x f vs n =>
          r <-? exec_resolve_operands dv rho o 0 vs ;;
          let '(args, uses) := r in
          match eval_atomic f args with
          | None => Error (ErrInvalidAtomic o)
          | Some res =>
              cur' <-? exec_advance budget j tid (xO path) (bind rho x (Known res)) n stk ;;
              let ev := EventRecord o (LAtomic f args res) in
              Ok (ev, MachineState (update_nth j (TRunning cur') (ms_threads st))
                        (ms_sync st) (ms_mem st)
                        (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))
          end
      | AssignPipe tt x v n =>
          r <-? exec_resolve_operand dv rho o 0 v ;;
          let '(val, uses) := r in
          match val with
          | VPipe p =>
              if check_declared_pipe tgt p then
                cur' <-? exec_advance budget j tid (xO path) (bind rho x (Known (VPipe p))) n stk ;;
                let ev := EventRecord o (LPipeAssignment x p) in
                Ok (ev, MachineState (update_nth j (TRunning cur') (ms_threads st))
                          (ms_sync st) (ms_mem st)
                          (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))
              else Error (ErrPermissionDenied o)
          | _ => Error (ErrTypeMismatch o)
          end
      | Read tt x d v n =>
          r <-? exec_resolve_exec dv rho o [v] (queue d) ;;
          let '(p, args, uses) := r in
          match args with
          | [VMemory a] =>
              if check_declared_resource tgt (resource d) && check_can_read tgt (resource d) a then
                _ <-? check_pipe_ready aw o p ;;
                cur' <-? exec_advance budget j tid (xO path) (bind rho x (Async o)) n stk ;;
                let disp := Dispatch (resource d) p in
                let ev := EventRecord o (LReadStart disp a) in
                let sync' := SyncState ((o, PRead disp a) :: sync_inflight (ms_sync st))
                                       (sync_flags (ms_sync st)) aw in
                Ok (ev, MachineState (update_nth j (TRunning cur') (ms_threads st))
                          sync' (ms_mem st)
                          (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))
              else Error (ErrPermissionDenied o)
          | _ => Error (ErrTypeMismatch o)
          end
      | Write tt d v1 v2 n =>
          r <-? exec_resolve_exec dv rho o [v1; v2] (queue d) ;;
          let '(p, args, uses) := r in
          match args with
          | [VMemory a; data] =>
              if check_declared_resource tgt (resource d) && check_can_write tgt (resource d) a then
                _ <-? check_pipe_ready aw o p ;;
                cur' <-? exec_advance budget j tid (xO path) rho n stk ;;
                let disp := Dispatch (resource d) p in
                let ev := EventRecord o (LWriteStart disp a data) in
                let sync' := SyncState ((o, PWrite disp a data) :: sync_inflight (ms_sync st))
                                       (sync_flags (ms_sync st)) aw in
                Ok (ev, MachineState (update_nth j (TRunning cur') (ms_threads st))
                          sync' (ms_mem st)
                          (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))
              else Error (ErrPermissionDenied o)
          | _ => Error (ErrTypeMismatch o)
          end
      | CCompute tt x d vs n =>
          r <-? exec_resolve_exec dv rho o vs (queue d) ;;
          let '(p, args, uses) := r in
          if check_declared_resource tgt (resource d) then
            _ <-? check_pipe_ready aw o p ;;
            cur' <-? exec_advance budget j tid (xO path) (bind rho x (Async o)) n stk ;;
            let disp := Dispatch (resource d) p in
            let ev := EventRecord o (LComputeStart disp args) in
            let sync' := SyncState ((o, PCompute disp args) :: sync_inflight (ms_sync st))
                                   (sync_flags (ms_sync st)) aw in
            Ok (ev, MachineState (update_nth j (TRunning cur') (ms_threads st))
                      sync' (ms_mem st)
                      (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))
          else Error (ErrPermissionDenied o)
      | SetFlag tt src dst v n =>
          r <-? exec_resolve_operands dv rho o 0 [src; dst; v] ;;
          let '(args, uses) := r in
          match args with
          | [VPipe p; VPipe q; VEvent fl] =>
              if check_declared_pipe tgt p && check_declared_pipe tgt q then
                _ <-? check_pipe_ready aw o (Some p) ;;
                cur' <-? exec_advance budget j tid (xO path) rho n stk ;;
                let deps := inflight_on_pipe peq p (sync_inflight (ms_sync st)) in
                let ev := EventRecord o (LSetFlagStart p q fl) in
                let sync' := SyncState ((o, PSetFlag p q fl deps) :: sync_inflight (ms_sync st))
                                       (sync_flags (ms_sync st)) aw in
                Ok (ev, MachineState (update_nth j (TRunning cur') (ms_threads st))
                          sync' (ms_mem st)
                          (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))
              else Error (ErrPermissionDenied o)
          | _ => Error (ErrTypeMismatch o)
          end
      | WaitFlag tt src dst v n =>
          r <-? exec_resolve_operands dv rho o 0 [src; dst; v] ;;
          let '(args, uses) := r in
          match args with
          | [VPipe p; VPipe q; VEvent fl] =>
              if check_declared_pipe tgt p && check_declared_pipe tgt q then
                _ <-? check_pipe_ready aw o (Some q) ;;
                cur' <-? exec_advance budget j tid (xO path) rho n stk ;;
                let ev := EventRecord o (LWaitFlagStart p q fl) in
                let sync' := SyncState ((o, PWaitFlag p q fl j) :: sync_inflight (ms_sync st))
                                       (sync_flags (ms_sync st)) (active_wait_set q o aw) in
                Ok (ev, MachineState (update_nth j (TWaitingFlag o cur') (ms_threads st))
                          sync' (ms_mem st)
                          (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))
              else Error (ErrPermissionDenied o)
          | _ => Error (ErrTypeMismatch o)
          end
      | If tt cond y n =>
          r <-? exec_resolve_operand dv rho o 0 cond ;;
          let '(val, uses) := r in
          match val with
          | VBool b =>
              cur' <-? exec_advance budget j tid (if b then xO path else xI path)
                         rho (if b then y else n) stk ;;
              let ev := EventRecord o (LBranch b) in
              Ok (ev, MachineState (update_nth j (TRunning cur') (ms_threads st))
                        (ms_sync st) (ms_mem st)
                        (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))
          | _ => Error (ErrTypeMismatch o)
          end
      | Return tt vs =>
          r <-? exec_resolve_operands dv rho o 0 vs ;;
          let '(args, uses) := r in
          let ev := EventRecord o (LReturn args) in
          Ok (ev, MachineState (update_nth j (TDone args) (ms_threads st))
                    (ms_sync st) (ms_mem st)
                    (ev :: ms_rev_trace st) (rev_append uses (ms_rev_uses st)))
      | CAlias _ _ _ | Select _ _ _ _ _ | For _ _ _ _ _ | LoopEnd =>
          Error (ErrRefocusStuck j)
      end
  end.

Definition exec_finish_op (o : op_id) (st : machine_state)
    : result step_error (Rec * machine_state) :=
  match lookup_inflight o (ms_sync st) with
  | None => Error (ErrInflightNotFound o)
  | Some pk =>
      let inflight' := remove_assoc op_id_eqb o (sync_inflight (ms_sync st)) in
      let flags := sync_flags (ms_sync st) in
      let aw := sync_active_wait (ms_sync st) in
      match pk with
      | PRead _ a =>
          let ov := match mem_lookup a (ms_mem st) with
                    | Some v => Some v
                    | None => pick_uninit_mem cpol a
                    end in
          match ov with
          | None => Error (ErrUninitMemoryRead o a)
          | Some res =>
              let ev := EventRecord o (LReadEnd res) in
              let sync' := SyncState inflight' flags aw in
              let mem' := MemState (mem_writes (ms_mem st)) ((o, res) :: mem_done_val (ms_mem st)) in
              Ok (ev, MachineState (ms_threads st) sync' mem'
                        (ev :: ms_rev_trace st) (ms_rev_uses st))
          end
      | PWrite _ a data =>
          let ev := EventRecord o LWriteEnd in
          let sync' := SyncState inflight' flags aw in
          let mem' := MemState ((a, data) :: mem_writes (ms_mem st)) (mem_done_val (ms_mem st)) in
          Ok (ev, MachineState (ms_threads st) sync' mem'
                    (ev :: ms_rev_trace st) (ms_rev_uses st))
      | PCompute d args =>
          match exec_comp emodel (resource d) args with
          | None => Error (ErrComputeUndefined o)
          | Some res =>
              let ev := EventRecord o (LComputeEnd res) in
              let sync' := SyncState inflight' flags aw in
              let mem' := MemState (mem_writes (ms_mem st)) ((o, res) :: mem_done_val (ms_mem st)) in
              Ok (ev, MachineState (ms_threads st) sync' mem'
                        (ev :: ms_rev_trace st) (ms_rev_uses st))
          end
      | PSetFlag p q fl deps =>
          if deps_drained deps (sync_inflight (ms_sync st)) then
            if negb (flag_is_set peq eeq p q fl flags) then
              let ev := EventRecord o LSetFlagEnd in
              let sync' := SyncState inflight' (flag_set_true p q fl flags) aw in
              Ok (ev, MachineState (ms_threads st) sync' (ms_mem st)
                        (ev :: ms_rev_trace st) (ms_rev_uses st))
            else Error (ErrFlagNotReady o)
          else Error (ErrSetFlagDepsPending o)
      | PWaitFlag p q fl j =>
          if flag_is_set peq eeq p q fl flags then
            match nth_error (ms_threads st) j with
            | Some (TWaitingFlag w next_cur) =>
                if op_id_eqb w o then
                  let ev := EventRecord o LWaitFlagEnd in
                  let sync' := SyncState inflight' (flag_set_false peq eeq p q fl flags)
                                         (active_wait_clear peq q aw) in
                  Ok (ev, MachineState (update_nth j (TRunning next_cur) (ms_threads st))
                            sync' (ms_mem st) (ev :: ms_rev_trace st) (ms_rev_uses st))
                else Error (ErrBranchNotRunnable j)
            | _ => Error (ErrBranchNotRunnable j)
            end
          else Error (ErrFlagNotReady o)
      end
  end.

(* 可执行单步函数对关系型自动机 auto_step 的健全性引理 *)

Lemma exec_resolve_operand_sound dv rho o idx v a uses :
  exec_resolve_operand dv rho o idx v = Ok (a, uses) ->
  resolve_operand_rel dv rho o idx v a uses.
Proof.
  unfold exec_resolve_operand.
  destruct (resolve rho v) as [[a0 | r] |] eqn:Hr; [| | discriminate].
  - intros H; inversion H; subst. apply ResKnown; exact Hr.
  - destruct (lookup_assoc op_id_eqb r dv) as [res |] eqn:Hdv.
    + intros H; inversion H; subst. apply ResAsync; [exact Hr | intros ? E; congruence].
    + destruct (pick_early_async cpol o idx r) as [a0 |] eqn:Hp; [| discriminate].
      intros H; inversion H; subst. apply ResAsync; [exact Hr | intros ? E; congruence].
Qed.

Lemma exec_resolve_operands_sound dv rho o idx vs args uses :
  exec_resolve_operands dv rho o idx vs = Ok (args, uses) ->
  resolve_operands_rel dv rho o idx vs args uses.
Proof.
  revert idx args uses. induction vs as [|v vs IH]; intros idx args uses; cbn.
  - intros H; inversion H; subst; constructor.
  - destruct (exec_resolve_operand dv rho o idx v) as [[a u1]|] eqn:H1; [| discriminate].
    cbn. destruct (exec_resolve_operands dv rho o (S idx) vs) as [[as' u2]|] eqn:H2; [| discriminate].
    cbn. intros H; inversion H; subst.
    constructor; [eapply exec_resolve_operand_sound; eassumption | eapply IH; eassumption].
Qed.

Lemma exec_resolve_exec_sound dv rho o vs q p args uses :
  exec_resolve_exec dv rho o vs q = Ok (p, args, uses) ->
  resolve_exec_rel dv rho o vs q p args uses.
Proof.
  unfold exec_resolve_exec. destruct q as [vq|].
  - destruct (exec_resolve_operands dv rho o 0 (vq :: vs)) as [[vals u]|] eqn:H;
      cbn [result_bind]; [| discriminate].
    destruct vals as [|val rest]; [discriminate |].
    destruct val; try discriminate.
    intros H0; inversion H0; subst.
    apply ResQueued. eapply exec_resolve_operands_sound; eassumption.
  - destruct (exec_resolve_operands dv rho o 0 vs) as [[vals u]|] eqn:H;
      cbn [result_bind]; [| discriminate].
    intros H0; inversion H0; subst.
    apply ResDirect. eapply exec_resolve_operands_sound; eassumption.
Qed.

Lemma check_pipe_ready_sound aw o p :
  check_pipe_ready aw o p = Ok tt ->
  pipe_ready (exec_cfg tgt) (pipe_eq tgt) aw p.
Proof.
  unfold check_pipe_ready, pipe_ready. destruct p as [q|]; [| trivial].
  destruct (check_declared_pipe tgt q) eqn:Hd; [| discriminate].
  destruct (active_wait_of peq q aw) eqn:Haw; [discriminate |].
  intros _; split; [apply (check_declared_pipe_sound tgt); exact Hd | exact Haw].
Qed.

Lemma exec_issue_sound budget j st ev st' :
  exec_issue_branch budget j st = Ok (ev, st') ->
  auto_step layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st ev st'.
Proof.
  unfold exec_issue_branch. intros H.
  destruct (nth_error (ms_threads st) j) as [[cur|w nc|rs]|] eqn:Hth; try discriminate.
  destruct cur as [tid path rho cmd stk].
  cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack] in H.
  destruct cmd as [o vs | x v n | o x n | o x f vs n | x b y z n | o x v n
                  | o x d vs n | o x d v n | o d v1 v2 n | o src dst v n | o src dst v n
                  | x lo hi body after | | o cond y n]; try discriminate;
    try destruct o.
  - (* Return *)
    destruct (exec_resolve_operands _ _ _ _ vs) as [[args uses]|] eqn:Hr; cbn [result_bind] in H; [| discriminate].
    inversion H; subst.
    eapply StepReturn; [exact Hth | reflexivity | eapply exec_resolve_operands_sound; exact Hr].
  - (* Alloc *)
    destruct (mem_lookup (address_at layout (InBranch (tid, path))) (ms_mem st)) eqn:Hm; [discriminate |].
    unfold exec_advance in H. destruct (refocus budget _) as [cur'|] eqn:Href; cbn [result_bind] in H; [| discriminate].
    inversion H; subst.
    eapply StepAlloc; [exact Hth | reflexivity | reflexivity | exact Hm | exact Href].
  - (* LetAtomic *)
    destruct (exec_resolve_operands _ _ _ _ vs) as [[args uses]|] eqn:Hr; cbn [result_bind] in H; [| discriminate].
    destruct (eval_atomic f args) as [res|] eqn:Ha; [| discriminate].
    unfold exec_advance in H. destruct (refocus budget _) as [cur'|] eqn:Href; cbn [result_bind] in H; [| discriminate].
    inversion H; subst.
    eapply StepAtomic; [exact Hth | reflexivity | eapply exec_resolve_operands_sound; exact Hr | exact Ha | exact Href].
  - (* AssignPipe *)
    destruct (exec_resolve_operand _ _ _ _ v) as [[val uses]|] eqn:Hr; cbn [result_bind] in H; [| discriminate].
    destruct val; try discriminate.
    destruct (check_declared_pipe tgt p) eqn:Hp; [| discriminate].
    unfold exec_advance in H. destruct (refocus budget _) as [cur'|] eqn:Href; cbn [result_bind] in H; [| discriminate].
    inversion H; subst.
    eapply StepAssignPipe; [exact Hth | reflexivity | eapply exec_resolve_operand_sound; exact Hr
      | apply (check_declared_pipe_sound tgt); exact Hp | exact Href].
  - (* CCompute *)
    destruct (exec_resolve_exec _ _ _ vs (queue d)) as [[[p args] uses]|] eqn:Hr; cbn [result_bind] in H; [| discriminate].
    destruct (check_declared_resource tgt (resource d)) eqn:Hd; [| discriminate].
    destruct (check_pipe_ready _ _ p) as [[]|] eqn:Hpr; cbn [result_bind] in H; [| discriminate].
    unfold exec_advance in H. destruct (refocus budget _) as [cur'|] eqn:Href; cbn [result_bind] in H; [| discriminate].
    inversion H; subst.
    eapply StepComputeStart; [exact Hth | reflexivity | eapply exec_resolve_exec_sound; exact Hr
      | apply (check_declared_resource_sound tgt); exact Hd
      | eapply check_pipe_ready_sound; exact Hpr | exact Href].
  - (* Read *)
    destruct (exec_resolve_exec _ _ _ [v] (queue d)) as [[[p args] uses]|] eqn:Hr; cbn [result_bind] in H; [| discriminate].
    destruct args as [|val rest]; try discriminate. destruct val; try discriminate.
    destruct rest; try discriminate.
    destruct (check_declared_resource tgt (resource d)) eqn:Hd; cbn [andb] in H; [| discriminate].
    destruct (check_can_read tgt (resource d) address) eqn:Hcr; cbn [andb] in H; [| discriminate].
    destruct (check_pipe_ready _ _ p) as [[]|] eqn:Hpr; cbn [result_bind] in H; [| discriminate].
    unfold exec_advance in H. destruct (refocus budget _) as [cur'|] eqn:Href; cbn [result_bind] in H; [| discriminate].
    inversion H; subst.
    eapply StepReadStart; [exact Hth | reflexivity | eapply exec_resolve_exec_sound; exact Hr
      | apply (check_declared_resource_sound tgt); exact Hd
      | apply (check_can_read_sound tgt); exact Hcr
      | eapply check_pipe_ready_sound; exact Hpr | exact Href].
  - (* Write *)
    destruct (exec_resolve_exec _ _ _ [v1; v2] (queue d)) as [[[p args] uses]|] eqn:Hr; cbn [result_bind] in H; [| discriminate].
    destruct args as [|val1 rest1]; try discriminate. destruct val1; try discriminate.
    destruct rest1 as [|val2 rest2]; try discriminate. destruct rest2; try discriminate.
    destruct (check_declared_resource tgt (resource d)) eqn:Hd; cbn [andb] in H; [| discriminate].
    destruct (check_can_write tgt (resource d) address) eqn:Hcw; cbn [andb] in H; [| discriminate].
    destruct (check_pipe_ready _ _ p) as [[]|] eqn:Hpr; cbn [result_bind] in H; [| discriminate].
    unfold exec_advance in H. destruct (refocus budget _) as [cur'|] eqn:Href; cbn [result_bind] in H; [| discriminate].
    inversion H; subst.
    eapply StepWriteStart; [exact Hth | reflexivity | eapply exec_resolve_exec_sound; exact Hr
      | apply (check_declared_resource_sound tgt); exact Hd
      | apply (check_can_write_sound tgt); exact Hcw
      | eapply check_pipe_ready_sound; exact Hpr | exact Href].
  - (* SetFlag *)
    destruct (exec_resolve_operands _ _ _ _ [src; dst; v]) as [[args uses]|] eqn:Hr; cbn [result_bind] in H; [| discriminate].
    destruct args as [|v1 r1]; try discriminate. destruct v1; try discriminate.
    destruct r1 as [|v2 r2]; try discriminate. destruct v2; try discriminate.
    destruct r2 as [|v3 r3]; try discriminate. destruct v3; try discriminate.
    destruct r3; try discriminate.
    destruct (check_declared_pipe tgt p) eqn:Hp; cbn [andb] in H; [| discriminate].
    destruct (check_declared_pipe tgt p0) eqn:Hq; cbn [andb] in H; [| discriminate].
    destruct (check_pipe_ready _ _ (Some p)) as [[]|] eqn:Hpr; cbn [result_bind] in H; [| discriminate].
    unfold exec_advance in H. destruct (refocus budget _) as [cur'|] eqn:Href; cbn [result_bind] in H; [| discriminate].
    inversion H; subst.
    eapply StepSetFlagStart; [exact Hth | reflexivity | eapply exec_resolve_operands_sound; exact Hr
      | apply (check_declared_pipe_sound tgt); exact Hp
      | apply (check_declared_pipe_sound tgt); exact Hq
      | eapply check_pipe_ready_sound; exact Hpr | exact Href].
  - (* WaitFlag *)
    destruct (exec_resolve_operands _ _ _ _ [src; dst; v]) as [[args uses]|] eqn:Hr; cbn [result_bind] in H; [| discriminate].
    destruct args as [|v1 r1]; try discriminate. destruct v1; try discriminate.
    destruct r1 as [|v2 r2]; try discriminate. destruct v2; try discriminate.
    destruct r2 as [|v3 r3]; try discriminate. destruct v3; try discriminate.
    destruct r3; try discriminate.
    destruct (check_declared_pipe tgt p) eqn:Hp; cbn [andb] in H; [| discriminate].
    destruct (check_declared_pipe tgt p0) eqn:Hq; cbn [andb] in H; [| discriminate].
    destruct (check_pipe_ready _ _ (Some p0)) as [[]|] eqn:Hpr; cbn [result_bind] in H; [| discriminate].
    unfold exec_advance in H. destruct (refocus budget _) as [cur'|] eqn:Href; cbn [result_bind] in H; [| discriminate].
    inversion H; subst.
    eapply StepWaitFlagStart; [exact Hth | reflexivity | eapply exec_resolve_operands_sound; exact Hr
      | apply (check_declared_pipe_sound tgt); exact Hp
      | apply (check_declared_pipe_sound tgt); exact Hq
      | eapply check_pipe_ready_sound; exact Hpr | exact Href].
  - (* If *)
    destruct (exec_resolve_operand _ _ _ _ cond) as [[val uses]|] eqn:Hr; cbn [result_bind] in H; [| discriminate].
    destruct val; try discriminate.
    unfold exec_advance in H. destruct (refocus budget _) as [cur'|] eqn:Href; cbn [result_bind] in H; [| discriminate].
    inversion H; subst.
    eapply StepIf; [exact Hth | reflexivity | eapply exec_resolve_operand_sound; exact Hr | exact Href].
Qed.

Lemma exec_finish_sound budget o st ev st' :
  exec_finish_op o st = Ok (ev, st') ->
  auto_step layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st ev st'.
Proof.
  unfold exec_finish_op.
  destruct (lookup_inflight o (ms_sync st)) as [pk|] eqn:Hinf; [| discriminate].
  destruct pk as [d a | d a data | d args | p q fl deps | p q fl j].
  - destruct (mem_lookup a (ms_mem st)) as [v0|] eqn:Hm.
    + intros H; inversion H; subst.
      eapply StepReadEnd; [exact Hinf | intros ? E; congruence].
    + destruct (pick_uninit_mem cpol a) as [res|] eqn:Hp; [| discriminate].
      intros H; inversion H; subst.
      eapply StepReadEnd; [exact Hinf | intros ? E; congruence].
  - intros H; inversion H; subst. eapply StepWriteEnd; exact Hinf.
  - destruct (exec_comp emodel (resource d) args) as [res|] eqn:Hc; [| discriminate].
    intros H; inversion H; subst.
    eapply StepComputeEnd; [exact Hinf | apply (exec_comp_sound emodel); exact Hc].
  - destruct (deps_drained deps (sync_inflight (ms_sync st))) eqn:Hdd; [| discriminate].
    destruct (flag_is_set peq eeq p q fl (sync_flags (ms_sync st))) eqn:Hf; cbn; [discriminate |].
    intros H; inversion H; subst.
    eapply StepSetFlagEnd; [exact Hinf | exact Hdd | exact Hf].
  - destruct (flag_is_set peq eeq p q fl (sync_flags (ms_sync st))) eqn:Hf; [| discriminate].
    destruct (nth_error (ms_threads st) j) as [[|w nc|]|] eqn:Hth; try discriminate.
    destruct (op_id_eqb w o) eqn:Heq; [| discriminate].
    apply op_id_eqb_spec in Heq; subst w.
    intros H; inversion H; subst.
    eapply StepWaitFlagEnd; [exact Hinf | exact Hf | exact Hth].
Qed.

End ExecutableStep.
End Automaton.

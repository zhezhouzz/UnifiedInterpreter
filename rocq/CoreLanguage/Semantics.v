From Stdlib Require Import List Lia.
From stdpp Require Import gmap.
From UnifiedInterpreter.CoreLanguage Require Import Syntax State Events.

Import ListNotations.

Section Semantics.
Context {Numeric : Type}.

Definition init_task (M : model Numeric) (locals : gmap var (value Numeric))
    (operation : op Numeric) : option (task_state Numeric) :=
  match operation with
  | ORead region =>
      match eval_expr M locals region with
      | Some (VRegion addresses) => Some (Reading addresses ∅)
      | _ => None
      end
  | OWrite region contents =>
      match eval_expr M locals region, eval_expr M locals contents with
      | Some (VRegion addresses), Some (VMap values) =>
          Some (Writing addresses values)
      | _, _ => None
      end
  | OCompute kind function arguments =>
      match eval_exprs M locals arguments with
      | Some values => Some (Computing kind function values)
      | None => None
      end
  end.

Definition valid_task (M : model Numeric) (p : pipeline_id) (s : machine Numeric)
    (body : task_state Numeric) : Prop :=
  match body with
  | Reading addresses collected =>
      collected = ∅ /\ addresses ⊆ dom (memory s) /\
      forall a, a ∈ addresses -> can_read M p a = true
  | Writing addresses values =>
      addresses ⊆ dom (memory s) /\ dom values = addresses /\
      forall a v, values !! a = Some v ->
        can_write M p a = true /\ type_ok M a v = true
  | Computing kind function arguments =>
      pipeline_kind M p = kind /\
      supports M p function (map value_type_of arguments) = true /\
      exists result, compute_eval M function arguments = Some result
  | Done _ => False
  end.

Definition begin_state (s : machine Numeric) (p : pipeline_id)
    (body : task_state Numeric) : machine Numeric :=
  set_next_task
    (set_tasks s (<[next_task s := {| task_owner := p; task_body := body |}]>
      (tasks s))) (S (next_task s)).

Definition begin_pipeline (t : pipeline_state Numeric) (h : handle) (j : task_id)
    : pipeline_state Numeric :=
  set_handles (set_code t CSkip) (<[h := j]> (pipeline_handles t)).

Definition end_pipeline (t : pipeline_state Numeric) (x : var) (h : handle)
    (result : value Numeric) : pipeline_state Numeric :=
  set_handles (set_locals (set_code t CSkip)
    (<[x := result]> (pipeline_locals t))) (delete h (pipeline_handles t)).

(* 控制步骤只修改当前 pipeline，后台任务由独立规则推进。 *)
Inductive pipeline_step (M : model Numeric) (p : pipeline_id) :
    machine Numeric -> pipeline_state Numeric -> label Numeric ->
    machine Numeric -> pipeline_state Numeric -> Prop :=
| PipelineAssign s t x expression result :
    pipeline_code t = CAssign x expression ->
    eval_expr M (pipeline_locals t) expression = Some result ->
    pipeline_step M p s t (LAssign p x result) s
      (set_locals (set_code t CSkip) (<[x := result]> (pipeline_locals t)))
| PipelineBegin s t h operation body :
    pipeline_code t = CBegin h operation ->
    pipeline_handles t !! h = None ->
    init_task M (pipeline_locals t) operation = Some body ->
    valid_task M p s body ->
    pipeline_step M p s t (LBegin p (next_task s) operation)
      (begin_state s p body) (begin_pipeline t h (next_task s))
| PipelineEnd s t x h j result :
    pipeline_code t = CEnd x h ->
    pipeline_handles t !! h = Some j ->
    tasks s !! j = Some {| task_owner := p; task_body := Done result |} ->
    pipeline_step M p s t (LJoin p j)
      (set_tasks s (delete j (tasks s))) (end_pipeline t x h result)
| PipelineSet s t event :
    pipeline_code t = CSetFlag event ->
    may_set M p event ->
    drained s p ->
    pipeline_step M p s t (LSet p event)
      (set_flags s (<[event := true]> (flags s))) (set_code t CSkip)
| PipelineWait s t event :
    pipeline_code t = CWaitFlag event ->
    may_wait M p event ->
    flags s !! event = Some true ->
    pipeline_step M p s t (LWait p event)
      (set_flags s (<[event := false]> (flags s))) (set_code t CSkip)
| PipelineLock s t lock :
    pipeline_code t = CLock lock ->
    lock_member M p lock ->
    locks s !! lock = Some None ->
    pipeline_step M p s t (LAcquire p lock)
      (set_locks s (<[lock := Some p]> (locks s))) (set_code t CSkip)
| PipelineUnlock s t lock :
    pipeline_code t = CUnlock lock ->
    lock_member M p lock ->
    locks s !! lock = Some (Some p) ->
    pipeline_step M p s t (LRelease p lock)
      (set_locks s (<[lock := None]> (locks s))) (set_code t CSkip)
| PipelineSeqSkip s t tail :
    pipeline_code t = CSeq CSkip tail ->
    pipeline_step M p s t (LControl p) s (set_code t tail)
| PipelineSeq s t first tail event s' t' :
    pipeline_code t = CSeq first tail ->
    pipeline_step M p s (set_code t first) event s' t' ->
    pipeline_step M p s t event s' (set_code t' (CSeq (pipeline_code t') tail))
| PipelineIfTrue s t test yes no :
    pipeline_code t = CIf test yes no ->
    eval_expr M (pipeline_locals t) test = Some (VBool true) ->
    pipeline_step M p s t (LControl p) s (set_code t yes)
| PipelineIfFalse s t test yes no :
    pipeline_code t = CIf test yes no ->
    eval_expr M (pipeline_locals t) test = Some (VBool false) ->
    pipeline_step M p s t (LControl p) s (set_code t no)
| PipelineWhile s t test body :
    pipeline_code t = CWhile test body ->
    pipeline_step M p s t (LControl p) s
      (set_code t (CIf test (CSeq body (CWhile test body)) CSkip)).

Definition head_error (M : model Numeric) (p : pipeline_id) (s : machine Numeric)
    (t : pipeline_state Numeric) : Prop :=
  match pipeline_code t with
  | CAssign _ expression => eval_expr M (pipeline_locals t) expression = None
  | CBegin h operation =>
      match pipeline_handles t !! h with
      | Some _ => True
      | None =>
          match init_task M (pipeline_locals t) operation with
          | None => True
          | Some body => ~ valid_task M p s body
          end
      end
  | CEnd _ h =>
      match pipeline_handles t !! h with
      | None => True
      | Some j =>
          match tasks s !! j with
          | None => True
          | Some task => task_owner task <> p
          end
      end
  | CSetFlag event => ~ may_set M p event
  | CWaitFlag event => ~ may_wait M p event
  | CLock lock => ~ lock_member M p lock
  | CUnlock lock =>
      ~ lock_member M p lock \/ locks s !! lock <> Some (Some p)
  | CIf test _ _ =>
      match eval_expr M (pipeline_locals t) test with
      | Some (VBool _) => False
      | _ => True
      end
  | CSkip | CSeq _ _ | CWhile _ _ => False
  end.

Definition pipeline_error (M : model Numeric) (p : pipeline_id) (s : machine Numeric)
    (t : pipeline_state Numeric) : Prop :=
  exists context head,
    pipeline_code t = fill context head /\
    head_error M p s (set_code t head).

Inductive task_step (M : model Numeric) :
    machine Numeric -> label Numeric -> machine Numeric -> Prop :=
| TaskRead s p j remaining collected a v :
    tasks s !! j = Some
      {| task_owner := p; task_body := Reading remaining collected |} ->
    a ∈ remaining ->
    memory s !! a = Some v ->
    task_step M s (LRead p j a v)
      (set_tasks s (<[j := {| task_owner := p;
        task_body := Reading (remaining ∖ {[a]}) (<[a := v]> collected) |}]>
        (tasks s)))
| TaskWrite s p j remaining values a v :
    tasks s !! j = Some
      {| task_owner := p; task_body := Writing remaining values |} ->
    a ∈ remaining ->
    values !! a = Some v ->
    task_step M s (LWrite p j a v)
      (set_tasks (set_memory s (<[a := v]> (memory s)))
        (<[j := {| task_owner := p;
          task_body := Writing (remaining ∖ {[a]}) values |}]> (tasks s)))
| TaskFinishRead s p j values :
    tasks s !! j = Some
      {| task_owner := p; task_body := Reading ∅ values |} ->
    task_step M s (LFinish p j)
      (set_tasks s (<[j := {| task_owner := p; task_body := Done (VMap values) |}]>
        (tasks s)))
| TaskFinishWrite s p j values :
    tasks s !! j = Some
      {| task_owner := p; task_body := Writing ∅ values |} ->
    task_step M s (LFinish p j)
      (set_tasks s (<[j := {| task_owner := p; task_body := Done VUnit |}]>
        (tasks s)))
| TaskFinishCompute s p j kind function arguments result :
    tasks s !! j = Some
      {| task_owner := p; task_body := Computing kind function arguments |} ->
    compute_eval M function arguments = Some result ->
    task_step M s (LFinish p j)
      (set_tasks s (<[j := {| task_owner := p; task_body := Done result |}]>
        (tasks s))).

Inductive step (M : model Numeric) :
    configuration Numeric -> label Numeric -> configuration Numeric -> Prop :=
| StepControl s p t event s' t' :
    p ∈ declared_pipelines M ->
    pipelines s !! p = Some t ->
    pipeline_step M p s t event s' t' ->
    step M (Running s) event
      (Running (set_pipelines s' (<[p := t']> (pipelines s'))))
| StepTask s event s' :
    task_step M s event s' ->
    step M (Running s) event (Running s')
| StepError s p t :
    p ∈ declared_pipelines M ->
    pipelines s !! p = Some t ->
    pipeline_error M p s t ->
    step M (Running s) (LError p) Error.

Definition terminal (s : machine Numeric) : Prop :=
  (forall p t, pipelines s !! p = Some t -> pipeline_code t = CSkip) /\
  (forall j task, tasks s !! j = Some task -> task_active (task_body task) = false).

Definition deadlocked (M : model Numeric) (s : machine Numeric) : Prop :=
  ~ terminal s /\ forall event next, ~ step M (Running s) event next.

Lemma error_has_no_successor (M : model Numeric) event next :
  ~ step M Error event next.
Proof. intros H; inversion H. Qed.

Lemma compute_checks_kind (M : model Numeric) p s kind function arguments :
  valid_task M p s (Computing kind function arguments) ->
  pipeline_kind M p = kind.
Proof. intros [H _]; exact H. Qed.

Lemma task_step_preserves_control (M : model Numeric) s event s' :
  task_step M s event s' -> pipelines s' = pipelines s.
Proof. intros H; destruct H; reflexivity. Qed.

Lemma task_step_preserves_sync (M : model Numeric) s event s' :
  task_step M s event s' -> flags s' = flags s /\ locks s' = locks s.
Proof. intros H; destruct H; split; reflexivity. Qed.

Lemma compute_finish_preserves_memory (M : model Numeric)
    s p j kind function arguments result :
  tasks s !! j = Some
    {| task_owner := p; task_body := Computing kind function arguments |} ->
  compute_eval M function arguments = Some result ->
  exists s', task_step M s (LFinish p j) s' /\ memory s' = memory s.
Proof.
  intros Htask Hcompute.
  eexists; split.
  - eapply TaskFinishCompute; eauto.
  - reflexivity.
Qed.

End Semantics.

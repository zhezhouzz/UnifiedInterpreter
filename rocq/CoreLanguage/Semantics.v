From Stdlib Require Import List Lia.
From stdpp Require Import gmap.
From UnifiedInterpreter.CoreLanguage Require Import Syntax State Events.

Import ListNotations.

Section Semantics.
Context {Numeric : Type}.

Definition init_operation (M : model Numeric) (locals : gmap var (value Numeric))
    (operation : op Numeric) : option (operation_state Numeric) :=
  match operation with
  | ORead region =>
      match eval_expr M locals region with
      | Some (VRegion addresses) => Some (Reading addresses ∅)
      | _ => None
      end
  | OWrite region contents =>
      match eval_expr M locals region, eval_expr M locals contents with
      | Some (VRegion addresses), Some (VMap values) => Some (Writing addresses values)
      | _, _ => None
      end
  | OCompute kind function arguments =>
      match eval_exprs M locals arguments with
      | Some values => Some (Computing kind function values)
      | None => None
      end
  end.

Definition valid_operation (M : model Numeric) (p : pipeline_id) (s : machine Numeric)
    (body : operation_state Numeric) : Prop :=
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

Inductive pipeline_step (M : model Numeric) (p : pipeline_id) :
    machine Numeric -> pipeline_state Numeric -> label Numeric ->
    machine Numeric -> pipeline_state Numeric -> Prop :=
| PipelineAssign s t x expression result :
    pipeline_code t = CAssign x expression -> pipeline_operation t = None ->
    eval_expr M (pipeline_locals t) expression = Some result ->
    pipeline_step M p s t (LAssign p x result) s
      (set_locals (set_code t CSkip) (<[x := result]> (pipeline_locals t)))
| PipelineStart s t x operation body :
    pipeline_code t = COp x operation -> pipeline_operation t = None ->
    init_operation M (pipeline_locals t) operation = Some body ->
    valid_operation M p s body ->
    pipeline_step M p s t (LStart p operation) s (set_operation t (Some body))
| PipelineRead s t x operation remaining collected a v :
    pipeline_code t = COp x operation ->
    pipeline_operation t = Some (Reading remaining collected) ->
    a ∈ remaining -> memory s !! a = Some v ->
    pipeline_step M p s t (LRead p a v) s
      (set_operation t (Some (Reading (remaining ∖ {[a]}) (<[a := v]> collected))))
| PipelineWrite s t x operation remaining values a v :
    pipeline_code t = COp x operation ->
    pipeline_operation t = Some (Writing remaining values) ->
    a ∈ remaining -> values !! a = Some v ->
    pipeline_step M p s t (LWrite p a v) (set_memory s (<[a := v]> (memory s)))
      (set_operation t (Some (Writing (remaining ∖ {[a]}) values)))
| PipelineReadFinished s t x operation values :
    pipeline_code t = COp x operation ->
    pipeline_operation t = Some (Reading ∅ values) ->
    pipeline_step M p s t (LControl p) s (set_operation t (Some (Done (VMap values))))
| PipelineWriteFinished s t x operation values :
    pipeline_code t = COp x operation ->
    pipeline_operation t = Some (Writing ∅ values) ->
    pipeline_step M p s t (LControl p) s (set_operation t (Some (Done VUnit)))
| PipelineComputeFinished s t x operation kind function arguments result :
    pipeline_code t = COp x operation ->
    pipeline_operation t = Some (Computing kind function arguments) ->
    compute_eval M function arguments = Some result ->
    pipeline_step M p s t (LControl p) s (set_operation t (Some (Done result)))
| PipelineComplete s t x operation result :
    pipeline_code t = COp x operation -> pipeline_operation t = Some (Done result) ->
    pipeline_step M p s t (LComplete p x result) s
      (set_operation (set_locals (set_code t CSkip)
        (<[x := result]> (pipeline_locals t))) None)
| PipelineSet s t event :
    pipeline_code t = CSetFlag event -> pipeline_operation t = None ->
    may_set M p event ->
    pipeline_step M p s t (LSet p event)
      (set_flags s (<[event := true]> (flags s))) (set_code t CSkip)
| PipelineWait s t event :
    pipeline_code t = CWaitFlag event -> pipeline_operation t = None ->
    may_wait M p event -> flags s !! event = Some true ->
    pipeline_step M p s t (LWait p event)
      (set_flags s (<[event := false]> (flags s))) (set_code t CSkip)
| PipelineLock s t lock :
    pipeline_code t = CLock lock -> pipeline_operation t = None ->
    lock_member M p lock -> locks s !! lock = Some None ->
    pipeline_step M p s t (LAcquire p lock)
      (set_locks s (<[lock := Some p]> (locks s))) (set_code t CSkip)
| PipelineUnlock s t lock :
    pipeline_code t = CUnlock lock -> pipeline_operation t = None ->
    lock_member M p lock -> locks s !! lock = Some (Some p) ->
    pipeline_step M p s t (LRelease p lock)
      (set_locks s (<[lock := None]> (locks s))) (set_code t CSkip)
| PipelineSeqSkip s t tail :
    pipeline_code t = CSeq CSkip tail -> pipeline_operation t = None ->
    pipeline_step M p s t (LControl p) s (set_code t tail)
| PipelineSeq s t first tail event s' t' :
    pipeline_code t = CSeq first tail ->
    pipeline_step M p s (set_code t first) event s' t' ->
    pipeline_step M p s t event s' (set_code t' (CSeq (pipeline_code t') tail))
| PipelineIfTrue s t test yes no :
    pipeline_code t = CIf test yes no -> pipeline_operation t = None ->
    eval_expr M (pipeline_locals t) test = Some (VBool true) ->
    pipeline_step M p s t (LControl p) s (set_code t yes)
| PipelineIfFalse s t test yes no :
    pipeline_code t = CIf test yes no -> pipeline_operation t = None ->
    eval_expr M (pipeline_locals t) test = Some (VBool false) ->
    pipeline_step M p s t (LControl p) s (set_code t no)
| PipelineWhile s t test body :
    pipeline_code t = CWhile test body -> pipeline_operation t = None ->
    pipeline_step M p s t (LControl p) s
      (set_code t (CIf test (CSeq body (CWhile test body)) CSkip)).

Definition head_error (M : model Numeric) (p : pipeline_id) (s : machine Numeric)
    (t : pipeline_state Numeric) : Prop :=
  match pipeline_code t with
  | CAssign _ expression => eval_expr M (pipeline_locals t) expression = None
  | COp _ operation =>
      match init_operation M (pipeline_locals t) operation with
      | None => True
      | Some body => ~ valid_operation M p s body
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
  pipeline_operation t = None /\ exists context head,
    pipeline_code t = fill context head /\
    head_error M p s (set_code t head).

Inductive step (M : model Numeric) :
    configuration Numeric -> label Numeric -> configuration Numeric -> Prop :=
| StepControl s p t event s' t' :
    p ∈ declared_pipelines M -> pipelines s !! p = Some t ->
    pipeline_step M p s t event s' t' ->
    step M (Running s) event
      (Running (set_pipelines s' (<[p := t']> (pipelines s'))))
| StepError s p t :
    p ∈ declared_pipelines M -> pipelines s !! p = Some t ->
    pipeline_error M p s t ->
    step M (Running s) (LError p) Error.

Definition terminal (s : machine Numeric) : Prop :=
  forall p t, pipelines s !! p = Some t ->
    pipeline_code t = CSkip /\ pipeline_operation t = None.

Definition deadlocked (M : model Numeric) (s : machine Numeric) : Prop :=
  ~ terminal s /\ forall event next, ~ step M (Running s) event next.

Lemma error_has_no_successor (M : model Numeric) event next :
  ~ step M Error event next.
Proof. intros H; inversion H. Qed.

Lemma compute_checks_kind (M : model Numeric) p s kind function arguments :
  valid_operation M p s (Computing kind function arguments) ->
  pipeline_kind M p = kind.
Proof. intros [H _]; exact H. Qed.

End Semantics.

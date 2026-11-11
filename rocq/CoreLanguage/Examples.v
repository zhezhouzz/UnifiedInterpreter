From Stdlib Require Import ZArith List Lia.
From stdpp Require Import gmap.
From UnifiedInterpreter.CoreLanguage Require Import Syntax State Events Semantics Traces Properties.

Import ListNotations.
Open Scope Z_scope.

Module ConcreteExamples.

Definition arithmetic (f : function_id) (args : list (value Z)) : option (value Z) :=
  match f, args with
  | 0%nat, [VScalar x; VScalar y] => Some (VScalar (x + y))
  | 1%nat, [VVector [x1; x2]; VVector [y1; y2]] =>
      Some (VVector [x1 + y1; x2 + y2])
  | 2%nat, [VMatrix [[a; b]; [c; d]]; VMatrix [[e; f]; [g; h]]] =>
      Some (VMatrix [[a * e + b * g; a * f + b * h];
                     [c * e + d * g; c * f + d * h]])
  | _, _ => None
  end.

Definition primitives (f : primitive_id) (args : list (value Z)) : option (value Z) :=
  match f, args with
  | 0%nat, [VScalar x; VScalar y] => Some (VScalar (x + y))
  | 1%nat, [VMap entries; VAddress a] => entries !! a
  | _, _ => None
  end.

Close Scope Z_scope.

Local Notation "'Int' n" := (@VScalar Z n%Z) (at level 10).
Local Notation "'Vec' xs" := (@VVector Z xs%Z) (at level 10).
Local Notation "'Mat' xs" := (@VMatrix Z xs%Z) (at level 10).

Definition forward_event : event_key :=
  {| event_scope := 0; event_source := 0; event_target := 1; event_number := 0 |}.
Definition reverse_event : event_key :=
  {| event_scope := 0; event_source := 1; event_target := 0; event_number := 0 |}.

Definition concrete_model : model Z :=
  {| pipeline_kind := fun p => if Nat.eqb p 1 then Cube else Vector;
     primitive_eval := primitives;
     compute_eval := arithmetic;
     compute_signature := fun f =>
       match f with
       | 0 => Some ([TyScalar; TyScalar], TyScalar)
       | 1 => Some ([TyVector 2; TyVector 2], TyVector 2)
       | 2 => Some ([TyMatrix [2; 2]; TyMatrix [2; 2]], TyMatrix [2; 2])
       | _ => None
       end;
     supports := fun p f tys =>
       match p, f, tys with
       | 0%nat, 0%nat, [TyScalar; TyScalar] => true
       | 0%nat, 1%nat, [TyVector 2; TyVector 2] => true
       | 1%nat, 2%nat, [TyMatrix [2; 2]; TyMatrix [2; 2]] => true
       | _, _, _ => false
       end;
     can_read := fun _ _ => true;
     can_write := fun _ _ => true;
     type_ok := fun _ v => match v with VScalar _ => true | _ => false end;
     declared_pipelines := {[0%nat; 1%nat]};
     declared_events := {[forward_event; reverse_event]};
     scope_participants := fun _ => {[0%nat; 1%nat]};
     lock_participants := {[0%nat := {[0%nat; 1%nat]}]} |}.

Definition base_memory : gmap address (value Z) := {[0 := Int 0; 1 := Int 0]}.

Definition start (first second : command Z) : machine Z :=
  initial_machine concrete_model {[0 := first; 1 := second]} base_memory ∅.

Lemma concrete_model_well_formed : well_formed_model concrete_model.
Proof.
  split.
  - intros e He.
    change (e ∈ ({[forward_event; reverse_event]} : gset event_key)) in He.
    assert (e = forward_event \/ e = reverse_event) as [-> | ->] by set_solver;
      vm_compute; tauto.
  - split.
    + intros l participants H.
      change (({[0 := {[0; 1]}]} : gmap lock_id (gset pipeline_id)) !! l = Some participants) in H.
      apply lookup_singleton_Some in H. destruct H as [Hl Hp]. subst l participants.
      set_solver.
    + intros f args result H.
      change (arithmetic f args = Some result) in H.
      destruct f as [|[|[|f]]]; unfold arithmetic in H;
        try discriminate;
        repeat match type of H with
        | context [match ?input with _ => _ end] =>
            destruct input; cbn in H; try discriminate
        end;
        inversion H; subst; eexists _, _; repeat split; reflexivity.
Qed.

Lemma start_well_formed first second :
  initial_well_formed concrete_model {[0 := first; 1 := second]} base_memory ∅.
Proof.
  split; [apply concrete_model_well_formed | ].
  split; [vm_compute; reflexivity | ].
  split; [rewrite dom_empty_L; set_solver | ].
  intros a v H.
  unfold base_memory in H. apply lookup_insert_Some in H.
  destruct H as [[Ha Hv] | [_ H]].
  - subst a v. reflexivity.
  - apply lookup_singleton_Some in H. destruct H as [Ha Hv]. subst a v. reflexivity.
Qed.

Definition vector_op : op Z :=
  OCompute Vector 1 [EValue (Vec [1; 2]); EValue (Vec [10; 20])].
Definition cube_op : op Z :=
  OCompute Cube 2 [EValue (Mat [[1; 2]; [3; 4]]);
                   EValue (Mat [[5; 6]; [7; 8]])].

Definition vector_command : command Z := COp 0 vector_op.
Definition cube_command : command Z := COp 0 cube_op.

Definition vector_body : operation_state Z :=
  Computing Vector 1 [Vec [1; 2]; Vec [10; 20]].
Definition cube_body : operation_state Z :=
  Computing Cube 2 [Mat [[1; 2]; [3; 4]]; Mat [[5; 6]; [7; 8]]].

Definition local (code : command Z) (locals : gmap var (value Z))
    (current : option (operation_state Z)) : pipeline_state Z :=
  {| pipeline_code := code; pipeline_locals := locals; pipeline_operation := current |}.

Definition snapshot (mem : gmap address (value Z))
    (left right : pipeline_state Z) : machine Z :=
  {| memory := mem; flags := flags (start CSkip CSkip);
     locks := locks (start CSkip CSkip); pipelines := {[0 := left; 1 := right]} |}.

Definition vector_idle := local vector_command ∅ None.
Definition cube_idle := local cube_command ∅ None.
Definition vector_running := local vector_command ∅ (Some vector_body).
Definition cube_running := local cube_command ∅ (Some cube_body).
Definition vector_done := local vector_command ∅ (Some (Done (Vec [11; 22]))).
Definition cube_done := local cube_command ∅ (Some (Done (Mat [[19; 22]; [43; 50]]))).
Definition vector_final := local CSkip {[0 := Vec [11; 22]]} None.
Definition cube_final := local CSkip {[0 := Mat [[19; 22]; [43; 50]]]} None.

Definition calc1 := snapshot base_memory vector_running cube_idle.
Definition calc2 := snapshot base_memory vector_running cube_running.
Definition calc3 := snapshot base_memory vector_done cube_running.
Definition calc4 := snapshot base_memory vector_final cube_running.
Definition calc5 := snapshot base_memory vector_final cube_done.
Definition calc6 := snapshot base_memory vector_final cube_final.

Lemma step_to_named first event raw last :
  step concrete_model first event raw -> raw = last -> step concrete_model first event last.
Proof. intros transition equal. subst last. exact transition. Qed.

Ltac control_at owner :=
  eapply StepControl with (p := owner); [vm_compute; tauto | reflexivity |].

Example cube_vector_interleaving :
  steps concrete_model (Running (start vector_command cube_command))
    [LStart 0 vector_op; LStart 1 cube_op; LControl 0;
     LComplete 0 0 (Vec [11; 22]); LControl 1;
     LComplete 1 0 (Mat [[19; 22]; [43; 50]])] (Running calc6).
Proof.
  eapply StepsCons with (next := Running calc1).
  { eapply step_to_named.
    { control_at 0. eapply PipelineStart; [reflexivity | reflexivity | reflexivity |].
      repeat split; try reflexivity. eexists; reflexivity. }
    reflexivity. }
  eapply StepsCons with (next := Running calc2).
  { eapply step_to_named.
    { control_at 1. eapply PipelineStart; [reflexivity | reflexivity | reflexivity |].
      repeat split; try reflexivity. eexists; reflexivity. }
    reflexivity. }
  eapply StepsCons with (next := Running calc3).
  { eapply step_to_named. { control_at 0. eapply PipelineComputeFinished; reflexivity. }
    reflexivity. }
  eapply StepsCons with (next := Running calc4).
  { eapply step_to_named. { control_at 0. eapply PipelineComplete; reflexivity. }
    reflexivity. }
  eapply StepsCons with (next := Running calc5).
  { eapply step_to_named. { control_at 1. eapply PipelineComputeFinished; reflexivity. }
    reflexivity. }
  eapply StepsCons with (next := Running calc6).
  { eapply step_to_named. { control_at 1. eapply PipelineComplete; reflexivity. }
    reflexivity. }
  constructor.
Qed.

Lemma calc6_terminal : terminal calc6.
Proof.
  intros p t H. change (({[0 := vector_final; 1 := cube_final]} :
    gmap pipeline_id (pipeline_state Z)) !! p = Some t) in H.
  apply lookup_insert_Some in H as [[_ equality] | [_ H]].
  - subst t. split; reflexivity.
  - apply lookup_singleton_Some in H as [_ equality]. subst t. split; reflexivity.
Qed.

Example vector_cannot_execute_cube s t s' t' :
  ~ pipeline_step concrete_model 0 s t (LStart 0 cube_op) s' t'.
Proof.
  intros transition. apply pipeline_step_compute_kind in transition. discriminate.
Qed.

Example wrong_exec_kind_rejected :
  step concrete_model (Running (start (COp 0 cube_op) CSkip)) (LError 0) Error.
Proof.
  eapply StepError with (p := 0%nat).
  - vm_compute; tauto.
  - reflexivity.
  - split; [reflexivity |]. exists Hole, (COp 0 cube_op). split; [reflexivity |].
    vm_compute. intros [H _]. discriminate H.
Qed.

Fixpoint blocked_wait (s : machine Z) (p : pipeline_id) (c : command Z) : Prop :=
  match c with
  | CWaitFlag e => may_wait concrete_model p e /\ flags s !! e = Some false
  | CSeq first _ => blocked_wait s p first
  | _ => False
  end.

Lemma blocked_wait_context s p context head :
  blocked_wait s p (fill context head) -> blocked_wait s p head.
Proof. induction context; cbn; auto. Qed.

Lemma blocked_wait_no_pipeline_step s p t event next t' :
  pipeline_step concrete_model p s t event next t' ->
  blocked_wait s p (pipeline_code t) -> False.
Proof.
  intros Hstep. induction Hstep; intros Hblocked;
    rewrite H in Hblocked; cbn [blocked_wait] in Hblocked; try contradiction.
  destruct Hblocked as [_ Hzero]. congruence.
Qed.

Lemma blocked_wait_no_error s p t :
  blocked_wait s p (pipeline_code t) -> ~ pipeline_error concrete_model p s t.
Proof.
  intros Hblocked [_ [context [head [Hcode Herror]]]].
  rewrite Hcode in Hblocked. apply blocked_wait_context in Hblocked.
  unfold head_error in Herror.
  destruct head; cbn [blocked_wait set_code] in *; try contradiction; try tauto.
  change (~ may_wait concrete_model p event) in Herror. tauto.
Qed.

Lemma all_waiting_deadlocked s :
  (forall p t, pipelines s !! p = Some t -> blocked_wait s p (pipeline_code t)) ->
  (exists p t, pipelines s !! p = Some t) -> deadlocked concrete_model s.
Proof.
  intros Hblocked [p [t Hlookup]]. split.
  - intros Hterminal.
    specialize (Hblocked p t Hlookup).
    rewrite (proj1 (Hterminal p t Hlookup)) in Hblocked. exact Hblocked.
  - intros event next Hstep. inversion Hstep; subst.
    + eapply blocked_wait_no_pipeline_step; eauto.
    + eapply blocked_wait_no_error; eauto.
Qed.

Definition first_waiter : command Z :=
  CSeq (CWaitFlag reverse_event) (CSetFlag forward_event).
Definition second_waiter : command Z :=
  CSeq (CWaitFlag forward_event) (CSetFlag reverse_event).

Example cyclic_wait_is_deadlocked :
  deadlocked concrete_model (start first_waiter second_waiter).
Proof.
  apply all_waiting_deadlocked.
  - intros p t H.
    change (({[0 := local first_waiter ∅ None;
               1 := local second_waiter ∅ None]}
      : gmap pipeline_id (pipeline_state Z)) !! p = Some t) in H.
    apply lookup_insert_Some in H as [[Hp Ht] | [_ H]].
    + subst p t. split; [split; [vm_compute; tauto | reflexivity] | reflexivity].
    + apply lookup_singleton_Some in H as [Hp Ht]. subst p t.
      split; [split; [vm_compute; tauto | reflexivity] | reflexivity].
  - exists 0. eexists. reflexivity.
Qed.

Definition write_operation : op Z :=
  OWrite (EValue (VRegion {[0]})) (EValue (VMap {[0 := Int 41]})).

Definition flag_producer : command Z :=
  CSeq (COp 0 write_operation) (CSetFlag forward_event).

Definition locked_writer : command Z :=
  CSeq (CLock 0) (CSeq (COp 0 write_operation) (CUnlock 0)).

Ltac normalize_source :=
  lazymatch goal with
  | |- step ?m (Running ?s) ?event ?next =>
      let normalized := eval vm_compute in s in
      change (step m (Running normalized) event next)
  end.

Ltac sequential_control owner :=
  normalize_source; eapply StepControl with (p := owner);
  [vm_compute; tauto | reflexivity |].

Ltac sequence_head := eapply PipelineSeq; [reflexivity |].

Ltac start_write :=
  eapply PipelineStart;
  [reflexivity | reflexivity | reflexivity |
    split;
    [change (({[0]} : gset address) ⊆ {[0; 1]}); set_solver
    | split;
      [reflexivity
      | intros a v H; apply lookup_singleton_Some in H;
        destruct H as [Ha Hv]; subst a v; split; reflexivity]]].

Definition first_add : op Z := OCompute Vector 0 [EValue (Int 2); EValue (Int 3)].
Definition second_add : op Z := OCompute Vector 0 [EVar 0; EValue (Int 10)].
Definition sequential_adds : command Z := CSeq (COp 0 first_add) (COp 1 second_add).

Example sequential_adds_execution :
  exists final,
    steps concrete_model (Running (start sequential_adds CSkip))
      [LStart 0 first_add; LControl 0; LComplete 0 0 (Int 5); LControl 0;
       LStart 0 second_add; LControl 0; LComplete 0 1 (Int 15)] (Running final) /\
    exists t, pipelines final !! 0 = Some t /\
      pipeline_locals t !! 0 = Some (Int 5) /\ pipeline_locals t !! 1 = Some (Int 15).
Proof.
  eexists; split.
  - eapply StepsCons.
    + sequential_control 0%nat. sequence_head. eapply PipelineStart;
        [reflexivity | reflexivity | reflexivity | repeat split; try reflexivity; eexists; reflexivity].
    + eapply StepsCons.
      * sequential_control 0%nat. sequence_head. eapply PipelineComputeFinished; reflexivity.
      * eapply StepsCons.
        -- sequential_control 0%nat. sequence_head. eapply PipelineComplete; reflexivity.
        -- eapply StepsCons.
           ++ sequential_control 0%nat. eapply PipelineSeqSkip; reflexivity.
           ++ eapply StepsCons.
              ** sequential_control 0%nat. eapply PipelineStart;
                   [reflexivity | reflexivity | reflexivity | repeat split; try reflexivity; eexists; reflexivity].
              ** eapply StepsCons.
                 --- sequential_control 0%nat. eapply PipelineComputeFinished; reflexivity.
                 --- eapply StepsCons.
                     +++ sequential_control 0%nat. eapply PipelineComplete; reflexivity.
                     +++ constructor.
  - eexists. repeat split; reflexivity.
Qed.

Example flag_write_execution :
  exists final,
    steps concrete_model (Running (start flag_producer (CWaitFlag forward_event)))
      [LStart 0 write_operation; LWrite 0 0 (Int 41); LControl 0;
       LComplete 0 0 VUnit; LControl 0; LSet 0 forward_event;
       LWait 1 forward_event] (Running final) /\
    memory final !! 0 = Some (Int 41) /\ flags final !! forward_event = Some false.
Proof.
  eexists; split.
  - eapply StepsCons.
    + sequential_control 0%nat. sequence_head. start_write.
    + eapply StepsCons.
      * sequential_control 0%nat. sequence_head.
        eapply PipelineWrite; [reflexivity | reflexivity | set_solver | reflexivity].
      * eapply StepsCons.
        -- sequential_control 0%nat. sequence_head. eapply PipelineWriteFinished; reflexivity.
        -- eapply StepsCons.
           ++ sequential_control 0%nat. sequence_head. eapply PipelineComplete; reflexivity.
           ++ eapply StepsCons.
              ** sequential_control 0%nat. eapply PipelineSeqSkip; reflexivity.
              ** eapply StepsCons.
                 --- sequential_control 0%nat. eapply PipelineSet;
                       [reflexivity | reflexivity | split; [vm_compute; tauto | reflexivity]].
                 --- eapply StepsCons.
                     +++ sequential_control 1%nat. eapply PipelineWait;
                           [reflexivity | reflexivity | split; [vm_compute; tauto | reflexivity] | reflexivity].
                     +++ constructor.
  - split; reflexivity.
Qed.

Example locked_write_execution :
  exists final,
    steps concrete_model (Running (start locked_writer CSkip))
      [LAcquire 0 0; LControl 0; LStart 0 write_operation;
       LWrite 0 0 (Int 41); LControl 0; LComplete 0 0 VUnit;
       LControl 0; LRelease 0 0] (Running final) /\
    memory final !! 0 = Some (Int 41) /\ locks final !! 0 = Some None.
Proof.
  eexists; split.
  - eapply StepsCons.
    + sequential_control 0%nat. sequence_head. eapply PipelineLock;
        [reflexivity | reflexivity | exists {[0; 1]}; split; [reflexivity | set_solver] | reflexivity].
    + eapply StepsCons.
      * sequential_control 0%nat. eapply PipelineSeqSkip; reflexivity.
      * eapply StepsCons.
        -- sequential_control 0%nat. sequence_head. start_write.
        -- eapply StepsCons.
           ++ sequential_control 0%nat. sequence_head.
              eapply PipelineWrite; [reflexivity | reflexivity | set_solver | reflexivity].
           ++ eapply StepsCons.
              ** sequential_control 0%nat. sequence_head. eapply PipelineWriteFinished; reflexivity.
              ** eapply StepsCons.
                 --- sequential_control 0%nat. sequence_head. eapply PipelineComplete; reflexivity.
                 --- eapply StepsCons.
                     +++ sequential_control 0%nat. eapply PipelineSeqSkip; reflexivity.
                     +++ eapply StepsCons.
                         *** sequential_control 0%nat. eapply PipelineUnlock;
                               [reflexivity | reflexivity |
                                exists {[0; 1]}; split; [reflexivity | set_solver] | reflexivity].
                         *** constructor.
  - split; reflexivity.
Qed.

End ConcreteExamples.

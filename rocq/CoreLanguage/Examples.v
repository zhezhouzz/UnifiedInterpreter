From Stdlib Require Import ZArith List Lia.
From stdpp Require Import gmap.
From UnifiedInterpreter.CoreLanguage Require Import Syntax State Events Semantics Traces.

Import ListNotations.
Open Scope Z_scope.

Module ConcreteExamples.

(* 函数编号分别表示整数加法、向量加法和二阶矩阵乘法。 *)
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

Definition primitives (f : primitive_id) (args : list (value Z))
    : option (value Z) :=
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

Definition base_memory : gmap address (value Z) :=
  {[0%nat := Int 0; 1%nat := Int 0]}.

Definition start (first second : command Z) : machine Z :=
  initial_machine concrete_model {[0%nat := first; 1%nat := second]}
    base_memory ∅.

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
  split.
  - intros a v H.
    unfold base_memory in H. apply lookup_insert_Some in H.
    destruct H as [[Ha Hv] | [_ H]].
    + subst a v. reflexivity.
    + apply lookup_singleton_Some in H. destruct H as [Ha Hv]. subst a v. reflexivity.
  - apply initial_tasks_fresh.
Qed.

Lemma terminal_from_codes (s : machine Z) :
  tasks s = ∅ ->
  pipeline_code <$> pipelines s = {[0 := CSkip; 1 := CSkip]} ->
  terminal s.
Proof.
  intros Htasks Hcodes. split.
  - intros p t Hlookup.
    assert ((pipeline_code <$> pipelines s) !! p = Some (pipeline_code t)) as Hcode.
    { rewrite lookup_fmap, Hlookup. reflexivity. }
    rewrite Hcodes in Hcode.
    apply lookup_insert_Some in Hcode.
    destruct Hcode as [[_ H] | [_ H]].
    + symmetry; congruence.
    + apply lookup_singleton_Some in H. destruct H as [_ H]. symmetry; congruence.
  - intros j t H. rewrite Htasks, lookup_empty in H. discriminate.
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
  - destruct Hblocked as [_ Hzero]. congruence.
Qed.

Lemma blocked_wait_no_error s p t :
  blocked_wait s p (pipeline_code t) ->
  ~ pipeline_error concrete_model p s t.
Proof.
  intros Hblocked [context [head [Hcode Herror]]].
  rewrite Hcode in Hblocked.
  apply blocked_wait_context in Hblocked.
  unfold head_error in Herror.
  destruct head; cbn [blocked_wait set_code] in *;
    try contradiction; try tauto.
  change (~ may_wait concrete_model p event) in Herror. tauto.
Qed.

Lemma all_waiting_deadlocked s :
  tasks s = ∅ ->
  (forall p t, pipelines s !! p = Some t -> blocked_wait s p (pipeline_code t)) ->
  (exists p t, pipelines s !! p = Some t) ->
  deadlocked concrete_model s.
Proof.
  intros Htasks Hblocked [p [t Hlookup]]. split.
  - intros [Hterminal _].
    specialize (Hblocked p t Hlookup).
    rewrite (Hterminal p t Hlookup) in Hblocked. exact Hblocked.
  - intros event next Hstep. inversion Hstep; subst.
    + eapply blocked_wait_no_pipeline_step; eauto.
    + match goal with H : task_step _ _ _ _ |- _ => destruct H end;
        match goal with H : tasks s !! _ = _ |- _ =>
          rewrite Htasks, lookup_empty in H; discriminate
        end.
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
  - reflexivity.
  - intros p t H.
    change (({[0 := {| pipeline_code := first_waiter;
                      pipeline_locals := ∅; pipeline_handles := ∅ |};
               1 := {| pipeline_code := second_waiter;
                      pipeline_locals := ∅; pipeline_handles := ∅ |}]}
      : gmap pipeline_id (pipeline_state Z)) !! p = Some t) in H.
    apply lookup_insert_Some in H.
    destruct H as [[Hp Ht] | [_ H]].
    + subst p t. split; [split; [vm_compute; tauto | reflexivity] | reflexivity].
    + apply lookup_singleton_Some in H. destruct H as [Hp Ht]. subst p t.
      split; [split; [vm_compute; tauto | reflexivity] | reflexivity].
  - exists 0. eexists. reflexivity.
Qed.

Definition add_operation : op Z :=
  OCompute Vector 0 [EValue (Int 2); EValue (Int 3)].

Definition handle_program : command Z :=
  CSeq (CBegin 0 add_operation)
    (CSeq (CAssign 0 (EValue (Int 10)))
      (CSeq (CEnd 1 0)
        (CAssign 2 (EApply 0 [EVar 1; EVar 0])))).

(* 每个控制步骤都使用语义中的规则，有限映射查询由内核计算。 *)
Ltac normalize_source :=
  lazymatch goal with
  | |- step ?m (Running ?s) ?event ?next =>
      let normalized := eval vm_compute in s in
      change (step m (Running normalized) event next)
  end.

Ltac control_at owner :=
  normalize_source;
  eapply StepControl with (p := owner);
  [ vm_compute; tauto | reflexivity | ].

Ltac sequence_head :=
  eapply PipelineSeq; [reflexivity | ].

Ltac sequence_skip :=
  eapply PipelineSeqSkip; reflexivity.

Ltac begin_add :=
  eapply PipelineBegin;
  [reflexivity | reflexivity | reflexivity |
   repeat split; try reflexivity; eexists; reflexivity].

Ltac finish_compute :=
  normalize_source;
  eapply StepTask; eapply TaskFinishCompute; reflexivity.

Ltac join_task :=
  eapply PipelineEnd; reflexivity.

Example handle_execution :
  exists final,
    steps concrete_model (Running (start handle_program CSkip))
      [LBegin 0 0 add_operation; LControl 0;
       LAssign 0 0 (Int 10); LControl 0; LFinish 0 0;
       LJoin 0 0; LControl 0; LAssign 0 2 (Int 15)]
      (Running final) /\
    (exists t, pipelines final !! 0%nat = Some t /\
       pipeline_locals t !! 1%nat = Some (Int 5) /\
       pipeline_locals t !! 2%nat = Some (Int 15) /\
       pipeline_handles t = ∅) /\
    tasks final = ∅ /\ memory final = base_memory /\ terminal final.
Proof.
  eexists; split.
  - eapply StepsCons.
    + control_at 0%nat. sequence_head. begin_add.
    + eapply StepsCons.
      * control_at 0%nat. sequence_skip.
      * eapply StepsCons.
        -- control_at 0%nat. sequence_head.
           eapply PipelineAssign; reflexivity.
        -- eapply StepsCons.
           ++ control_at 0%nat. sequence_skip.
           ++ eapply StepsCons.
              ** finish_compute.
              ** eapply StepsCons.
                 --- control_at 0%nat. sequence_head. join_task.
                 --- eapply StepsCons.
                     +++ control_at 0%nat. sequence_skip.
                     +++ eapply StepsCons.
                         *** control_at 0%nat.
                             eapply PipelineAssign; reflexivity.
                         *** apply StepsRefl.
  - split.
    + eexists; repeat split; reflexivity.
    + split; [reflexivity | ]. split; [reflexivity | ].
      apply terminal_from_codes; reflexivity.
Qed.

Definition matrix_operation : op Z :=
  OCompute Cube 2
    [EValue (Mat [[1; 2]; [3; 4]]);
     EValue (Mat [[5; 6]; [7; 8]])].

Definition vector_operation : op Z :=
  OCompute Vector 1
    [EValue (Vec [10; 20]); EValue (Vec [1; 2])].

Definition cube_program : command Z := CSeq (CBegin 0 matrix_operation) (CEnd 0 0).
Definition vector_program : command Z := CSeq (CBegin 0 vector_operation) (CEnd 0 0).

Example cube_vector_execution :
  exists final,
    steps concrete_model (Running (start vector_program cube_program))
      [LBegin 1 0 matrix_operation; LBegin 0 1 vector_operation;
       LFinish 0 1; LControl 0; LJoin 0 1;
       LFinish 1 0; LControl 1; LJoin 1 0]
      (Running final) /\
    (exists tv, pipelines final !! 0%nat = Some tv /\
      pipeline_locals tv !! 0%nat = Some (Vec [11; 22])) /\
    (exists tc, pipelines final !! 1%nat = Some tc /\
      pipeline_locals tc !! 0%nat = Some (Mat [[19; 22]; [43; 50]])) /\
    tasks final = ∅ /\ memory final = base_memory /\ terminal final.
Proof.
  eexists; split.
  - eapply StepsCons.
    + control_at 1%nat. sequence_head. begin_add.
    + eapply StepsCons.
      * control_at 0%nat. sequence_head. begin_add.
      * eapply StepsCons.
        -- finish_compute.
        -- eapply StepsCons.
           ++ control_at 0%nat. sequence_skip.
           ++ eapply StepsCons.
              ** control_at 0%nat. join_task.
              ** eapply StepsCons.
                 --- finish_compute.
                 --- eapply StepsCons.
                     +++ control_at 1%nat. sequence_skip.
                     +++ eapply StepsCons.
                         *** control_at 1%nat. join_task.
                         *** apply StepsRefl.
  - split.
    + eexists; split; reflexivity.
    + split.
      * eexists; split; reflexivity.
      * split; [reflexivity | ]. split; [reflexivity | ].
        apply terminal_from_codes; reflexivity.
Qed.

Definition two_tasks_program : command Z :=
  CSeq (CBegin 0 add_operation)
    (CSeq (CBegin 1 vector_operation)
      (CSeq (CEnd 0 0) (CEnd 1 1))).

Example same_pipeline_reverse_completion :
  exists final,
    steps concrete_model (Running (start two_tasks_program CSkip))
      [LBegin 0 0 add_operation; LControl 0;
       LBegin 0 1 vector_operation; LFinish 0 1; LFinish 0 0;
       LControl 0; LJoin 0 0; LControl 0; LJoin 0 1]
      (Running final) /\
    (exists t, pipelines final !! 0%nat = Some t /\
      pipeline_locals t !! 0%nat = Some (Int 5) /\
      pipeline_locals t !! 1%nat = Some (Vec [11; 22])) /\
    tasks final = ∅ /\ terminal final.
Proof.
  eexists; split.
  - eapply StepsCons.
    + control_at 0%nat. sequence_head. begin_add.
    + eapply StepsCons.
      * control_at 0%nat. sequence_skip.
      * eapply StepsCons.
        -- control_at 0%nat. sequence_head. begin_add.
        -- eapply StepsCons.
           ++ finish_compute.
           ++ eapply StepsCons.
              ** finish_compute.
              ** eapply StepsCons.
                 --- control_at 0%nat. sequence_skip.
                 --- eapply StepsCons.
                     +++ control_at 0%nat. sequence_head. join_task.
                     +++ eapply StepsCons.
                         *** control_at 0%nat. sequence_skip.
                         *** eapply StepsCons.
                             ---- control_at 0%nat. join_task.
                             ---- apply StepsRefl.
  - split.
    + eexists; repeat split; reflexivity.
    + split; [reflexivity | ]. apply terminal_from_codes; reflexivity.
Qed.

Example wrong_exec_kind_rejected :
  step concrete_model (Running (start (CBegin 0 matrix_operation) CSkip))
    (LError 0) Error.
Proof.
  eapply StepError with (p := 0%nat).
  - vm_compute; tauto.
  - reflexivity.
  - exists Hole, (CBegin 0 matrix_operation). split; [reflexivity | ].
    vm_compute. intros [H _]. discriminate H.
Qed.

Definition write_operation : op Z :=
  OWrite (EValue (VRegion {[0]})) (EValue (VMap {[0 := Int 41]})).

Definition flag_producer : command Z :=
  CSeq (CBegin 0 write_operation) (CSeq (CSetFlag forward_event) (CEnd 0 0)).

Ltac begin_write :=
  eapply PipelineBegin;
  [reflexivity | reflexivity | reflexivity |
    split;
    [ change (({[0]} : gset address) ⊆ {[0; 1]}); set_solver
    | split;
      [ reflexivity
      | intros a v H; apply lookup_singleton_Some in H;
        destruct H as [Ha Hv]; subst a v; split; reflexivity ] ] ].

Example flag_write_execution :
  exists final,
    steps concrete_model
      (Running (start flag_producer (CWaitFlag forward_event)))
      [LBegin 0 0 write_operation; LControl 0;
       LWrite 0 0 0 (Int 41); LFinish 0 0; LSet 0 forward_event;
       LControl 0; LJoin 0 0; LWait 1 forward_event]
      (Running final) /\
    memory final !! 0 = Some (Int 41) /\
    flags final !! forward_event = Some false /\
    tasks final = ∅ /\ terminal final.
Proof.
  eexists; split.
  - eapply StepsCons.
    + control_at 0%nat. sequence_head. begin_write.
    + eapply StepsCons.
      * control_at 0%nat. sequence_skip.
      * eapply StepsCons.
        -- normalize_source. eapply StepTask. eapply TaskWrite; [reflexivity | set_solver | reflexivity].
        -- eapply StepsCons.
           ++ normalize_source. eapply StepTask. eapply TaskFinishWrite. reflexivity.
           ++ eapply StepsCons.
              ** control_at 0%nat. sequence_head. eapply PipelineSet.
                 --- reflexivity.
                 --- split; [vm_compute; tauto | reflexivity].
                 --- intros j t H _.
                     change (({[0 := {| task_owner := 0; task_body := Done (@VUnit Z) |}]}
                        : gmap task_id (task Z)) !! j = Some t) in H.
                     apply lookup_singleton_Some in H.
                     destruct H as [Hj Ht]. subst j t. reflexivity.
              ** eapply StepsCons.
                 --- control_at 0%nat. sequence_skip.
                 --- eapply StepsCons.
                     +++ control_at 0%nat. join_task.
                     +++ eapply StepsCons.
                         *** control_at 1%nat. eapply PipelineWait.
                             ---- reflexivity.
                             ---- split; [vm_compute; tauto | reflexivity].
                             ---- reflexivity.
                         *** apply StepsRefl.
  - split; [reflexivity | ]. split; [reflexivity | ].
    split; [reflexivity | ]. apply terminal_from_codes; reflexivity.
Qed.

Lemma unfinished_task_prevents_set s p j body t next t' event :
  tasks s !! j = Some {| task_owner := p; task_body := body |} ->
  task_active body = true ->
  pipeline_code t = CSetFlag event ->
  ~ pipeline_step concrete_model p s t (LSet p event) next t'.
Proof.
  intros Htask Hactive Hcode Hstep. inversion Hstep; subst;
    try (rewrite Hcode in *; discriminate).
  match goal with
  | H : drained s p |- _ =>
      specialize (H j {| task_owner := p; task_body := body |} Htask eq_refl);
      cbn in H; congruence
  end.
Qed.

Definition locked_writer : command Z :=
  CSeq (CLock 0)
    (CSeq (CBegin 0 write_operation) (CSeq (CEnd 0 0) (CUnlock 0))).

Example locked_write_execution :
  exists final,
    steps concrete_model (Running (start locked_writer CSkip))
      [LAcquire 0 0; LControl 0; LBegin 0 0 write_operation;
       LControl 0; LWrite 0 0 0 (Int 41); LFinish 0 0;
       LJoin 0 0; LControl 0; LRelease 0 0]
      (Running final) /\
    memory final !! 0 = Some (Int 41) /\
    locks final !! 0 = Some None /\ tasks final = ∅ /\ terminal final.
Proof.
  eexists; split.
  - eapply StepsCons.
    + control_at 0%nat. sequence_head. eapply PipelineLock.
      * reflexivity.
      * exists {[0; 1]}. split; [reflexivity | set_solver].
      * reflexivity.
    + eapply StepsCons.
      * control_at 0%nat. sequence_skip.
      * eapply StepsCons.
        -- control_at 0%nat. sequence_head. begin_write.
        -- eapply StepsCons.
           ++ control_at 0%nat. sequence_skip.
           ++ eapply StepsCons.
              ** normalize_source. eapply StepTask. eapply TaskWrite; [reflexivity | set_solver | reflexivity].
              ** eapply StepsCons.
                 --- normalize_source. eapply StepTask. eapply TaskFinishWrite. reflexivity.
                 --- eapply StepsCons.
                     +++ control_at 0%nat. sequence_head. join_task.
                     +++ eapply StepsCons.
                         *** control_at 0%nat. sequence_skip.
                         *** eapply StepsCons.
                             ---- control_at 0%nat. eapply PipelineUnlock.
                                  ++++ reflexivity.
                                  ++++ exists {[0; 1]}. split; [reflexivity | set_solver].
                                  ++++ reflexivity.
                             ---- apply StepsRefl.
  - split; [reflexivity | ]. split; [reflexivity | ].
    split; [reflexivity | ]. apply terminal_from_codes; reflexivity.
Qed.

End ConcreteExamples.

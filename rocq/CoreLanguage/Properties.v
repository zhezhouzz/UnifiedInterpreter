From Stdlib Require Import List Lia.
From stdpp Require Import gmap.
From UnifiedInterpreter.CoreLanguage Require Import Syntax State Events Semantics Traces.

Set Implicit Arguments.

Section Properties.
Context {Numeric : Type}.

Lemma fresh_next_task_absent (s : machine Numeric) :
  task_ids_fresh s -> tasks s !! next_task s = None.
Proof.
  intros Hfresh. destruct (tasks s !! next_task s) as [t|] eqn:Hlookup.
  - specialize (Hfresh _ _ Hlookup). lia.
  - reflexivity.
Qed.

Lemma begin_state_preserves_freshness (s : machine Numeric) p body :
  task_ids_fresh s -> task_ids_fresh (begin_state s p body).
Proof.
  intros Hfresh j t Hlookup.
  cbn [begin_state set_next_task set_tasks tasks next_task] in *.
  apply lookup_insert_Some in Hlookup.
  destruct Hlookup as [[Heq _]|[_ Hlookup]].
  - subst j. lia.
  - specialize (Hfresh _ _ Hlookup). lia.
Qed.

Lemma delete_task_preserves_freshness (s : machine Numeric) j :
  task_ids_fresh s -> task_ids_fresh (set_tasks s (delete j (tasks s))).
Proof.
  intros Hfresh k t Hlookup.
  cbn [set_tasks tasks] in Hlookup.
  apply lookup_delete_Some in Hlookup as [_ Hlookup].
  exact (Hfresh _ _ Hlookup).
Qed.

Lemma replace_task_preserves_freshness (s : machine Numeric) j old replacement :
  tasks s !! j = Some old -> task_ids_fresh s ->
  task_ids_fresh (set_tasks s (<[j := replacement]> (tasks s))).
Proof.
  intros Hold Hfresh k t Hlookup.
  cbn [set_tasks tasks] in Hlookup.
  apply lookup_insert_Some in Hlookup.
  destruct Hlookup as [[Heq _]|[_ Hlookup]].
  - subst k. exact (Hfresh _ _ Hold).
  - exact (Hfresh _ _ Hlookup).
Qed.

Lemma pipeline_step_preserves_freshness (M : model Numeric) p s t event s' t' :
  pipeline_step M p s t event s' t' ->
  task_ids_fresh s -> task_ids_fresh s'.
Proof.
  intros Hstep. induction Hstep; intros Hfresh; try exact Hfresh.
  - apply begin_state_preserves_freshness; exact Hfresh.
  - apply delete_task_preserves_freshness; exact Hfresh.
  - apply IHHstep; exact Hfresh.
Qed.

Lemma task_step_preserves_freshness (M : model Numeric) s event s' :
  task_step M s event s' -> task_ids_fresh s -> task_ids_fresh s'.
Proof.
  intros Hstep Hfresh. destruct Hstep; intros k t Hlookup;
    cbn [set_tasks set_memory tasks next_task] in *;
    apply lookup_insert_Some in Hlookup;
    destruct Hlookup as [[Heq _]|[_ Hlookup]];
    subst; eapply Hfresh; eauto.
Qed.

Lemma step_preserves_freshness (M : model Numeric) s event s' :
  step M (Running s) event (Running s') ->
  task_ids_fresh s -> task_ids_fresh s'.
Proof.
  intros Hstep Hfresh. inversion Hstep; subst.
  - exact (pipeline_step_preserves_freshness H4 Hfresh).
  - eapply task_step_preserves_freshness; eauto.
Qed.

Lemma pipeline_step_begin_number (M : model Numeric) p s t event s' t' :
  pipeline_step M p s t event s' t' ->
  forall owner j operation, event = LBegin owner j operation -> j = next_task s.
Proof.
  intros Hstep. induction Hstep; intros owner jid operation' Hlabel;
    try discriminate.
  - inversion Hlabel; reflexivity.
  - eapply IHHstep; exact Hlabel.
Qed.

Lemma pipeline_begin_allocates_fresh (M : model Numeric) p s t owner j operation s' t' :
  pipeline_step M p s t (LBegin owner j operation) s' t' ->
  task_ids_fresh s -> tasks s !! j = None.
Proof.
  intros Hstep Hfresh.
  pose proof (pipeline_step_begin_number Hstep eq_refl) as Hnumber.
  rewrite Hnumber. apply fresh_next_task_absent; exact Hfresh.
Qed.

Lemma step_begin_allocates_fresh (M : model Numeric) s p j operation s' :
  step M (Running s) (LBegin p j operation) (Running s') ->
  task_ids_fresh s -> tasks s !! j = None.
Proof.
  intros Hstep Hfresh. inversion Hstep; subst.
  - eapply pipeline_begin_allocates_fresh; eauto.
  - match goal with H : task_step _ _ _ _ |- _ => inversion H end.
Qed.

Lemma pipeline_step_compute_kind (M : model Numeric) p s t event s' t' :
  pipeline_step M p s t event s' t' ->
  forall owner j kind function arguments,
    event = LBegin owner j (OCompute kind function arguments) ->
    pipeline_kind M owner = kind.
Proof.
  intros Hstep. induction Hstep; intros owner jid kind function arguments Hlabel;
    try discriminate.
  - inversion Hlabel; subst. unfold init_task in H1.
    destruct (eval_exprs M (pipeline_locals t) arguments) as [values|];
      inversion H1; subst.
    exact (proj1 H2).
  - eapply IHHstep; exact Hlabel.
Qed.

Lemma step_compute_kind (M : model Numeric) s p j kind function arguments s' :
  step M (Running s) (LBegin p j (OCompute kind function arguments)) (Running s') ->
  pipeline_kind M p = kind.
Proof.
  intros Hstep. inversion Hstep; subst.
  - eapply pipeline_step_compute_kind; eauto.
  - match goal with H : task_step _ _ _ _ |- _ => inversion H end.
Qed.

Lemma skip_has_no_pipeline_step (M : model Numeric) p s t event s' t' :
  pipeline_code t = CSkip -> ~ pipeline_step M p s t event s' t'.
Proof. intros Hcode Hstep. inversion Hstep; congruence. Qed.

Lemma skip_has_no_pipeline_error (M : model Numeric) p s t :
  pipeline_code t = CSkip -> ~ pipeline_error M p s t.
Proof.
  intros Hcode [context [head [Hcontext Herror]]].
  rewrite Hcode in Hcontext. destruct context; simpl in Hcontext.
  - subst head. exact Herror.
  - discriminate.
Qed.

Lemma task_step_requires_active (M : model Numeric) s event s' :
  task_step M s event s' ->
  exists j t, tasks s !! j = Some t /\ task_active (task_body t) = true.
Proof.
  intros Hstep. destruct Hstep;
    (do 2 eexists; split; [eassumption | reflexivity]).
Qed.

Lemma terminal_has_no_successor (M : model Numeric) s :
  terminal s -> forall event next, ~ step M (Running s) event next.
Proof.
  intros [Hcodes Htasks] event next Hstep. inversion Hstep; subst.
  - eapply skip_has_no_pipeline_step; [eapply Hcodes; eauto | eassumption].
  - match goal with H : task_step _ _ _ _ |- _ =>
      destruct (task_step_requires_active H) as [j [t [Hlookup Hactive]]] end.
    specialize (Htasks _ _ Hlookup). congruence.
  - eapply skip_has_no_pipeline_error; [eapply Hcodes; eauto | eassumption].
Qed.

Lemma terminal_execution_maximal (M : model Numeric) first events s :
  steps M first events (Running s) -> terminal s ->
  maximal_finite_execution M first events (Running s).
Proof.
  intros Hsteps Hterminal. split; [exact Hsteps |].
  unfold irreducible. intros event next.
  eapply terminal_has_no_successor; exact Hterminal.
Qed.

Definition configuration_fresh (state : configuration Numeric) : Prop :=
  match state with
  | Running s => task_ids_fresh s
  | Error => True
  end.

Lemma step_preserves_configuration_freshness (M : model Numeric) first event last :
  step M first event last -> configuration_fresh first -> configuration_fresh last.
Proof.
  intros Hstep Hfresh. destruct first, last; simpl in *; try exact I.
  - eapply step_preserves_freshness; eauto.
  - inversion Hstep.
Qed.

Lemma steps_preserve_configuration_freshness (M : model Numeric) first events last :
  steps M first events last -> configuration_fresh first -> configuration_fresh last.
Proof.
  intros Hsteps. induction Hsteps; intros Hfresh.
  - exact Hfresh.
  - apply IHHsteps. eapply step_preserves_configuration_freshness; eauto.
Qed.

Lemma steps_preserve_freshness (M : model Numeric) s events s' :
  steps M (Running s) events (Running s') ->
  task_ids_fresh s -> task_ids_fresh s'.
Proof.
  intros Hsteps Hfresh.
  exact (steps_preserve_configuration_freshness Hsteps Hfresh).
Qed.

End Properties.

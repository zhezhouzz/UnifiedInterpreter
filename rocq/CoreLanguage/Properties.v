From Stdlib Require Import List Lia.
From stdpp Require Import gmap.
From UnifiedInterpreter.CoreLanguage Require Import Syntax State Events Semantics Traces.

Set Implicit Arguments.

Section Properties.
Context {Numeric : Type}.

Lemma pipeline_start_requires_idle (M : model Numeric) p s t operation s' t' :
  pipeline_step M p s t (LStart p operation) s' t' ->
  pipeline_operation t = None.
Proof.
  intros transition. remember (LStart p operation) as event eqn:Hevent.
  induction transition; inversion Hevent; subst; simpl in *; eauto.
Qed.

Lemma pipeline_complete_requires_done (M : model Numeric) p s t x result s' t' :
  pipeline_step M p s t (LComplete p x result) s' t' ->
  pipeline_operation t = Some (Done result).
Proof.
  intros transition. remember (LComplete p x result) as event eqn:Hevent.
  induction transition; inversion Hevent; subst; simpl in *; eauto.
Qed.

Lemma pipeline_set_requires_idle (M : model Numeric) p s t key s' t' :
  pipeline_step M p s t (LSet p key) s' t' -> pipeline_operation t = None.
Proof.
  intros transition. remember (LSet p key) as event eqn:Hevent.
  induction transition; inversion Hevent; subst; simpl in *; eauto.
Qed.

Lemma pipeline_release_requires_idle (M : model Numeric) p s t lock s' t' :
  pipeline_step M p s t (LRelease p lock) s' t' -> pipeline_operation t = None.
Proof.
  intros transition. remember (LRelease p lock) as event eqn:Hevent.
  induction transition; inversion Hevent; subst; simpl in *; eauto.
Qed.

Lemma pipeline_step_compute_kind (M : model Numeric) p s t kind function arguments s' t' :
  pipeline_step M p s t (LStart p (OCompute kind function arguments)) s' t' ->
  pipeline_kind M p = kind.
Proof.
  intros transition. remember (LStart p (OCompute kind function arguments)) as event
    eqn:Hevent.
  induction transition; inversion Hevent; subst; simpl in *; eauto.
  unfold init_operation in H1.
  destruct (eval_exprs M (pipeline_locals t) arguments); inversion H1; subst.
  exact (proj1 H2).
Qed.

Lemma pipeline_step_owner (M : model Numeric) p s t event s' t' :
  pipeline_step M p s t event s' t' -> event_owner event = p.
Proof. intros transition. induction transition; simpl; auto. Qed.

Lemma step_start_requires_idle (M : model Numeric) s p operation s' :
  step M (Running s) (LStart p operation) (Running s') ->
  exists t, pipelines s !! p = Some t /\ pipeline_operation t = None.
Proof.
  intros transition. inversion transition; subst.
  match goal with
  | H : pipeline_step _ _ _ _ _ _ _, Hlookup : pipelines _ !! _ = Some _ |- _ =>
      pose proof (pipeline_step_owner H) as owner; simpl in owner; subst;
      eexists; split; [exact Hlookup | eapply pipeline_start_requires_idle; exact H]
  end.
Qed.

Lemma active_pipeline_cannot_start (M : model Numeric) p s t body operation s' t' :
  pipeline_operation t = Some body ->
  ~ pipeline_step M p s t (LStart p operation) s' t'.
Proof.
  intros active transition.
  apply pipeline_start_requires_idle in transition. congruence.
Qed.

Lemma step_compute_kind (M : model Numeric) s p kind function arguments s' :
  step M (Running s) (LStart p (OCompute kind function arguments)) (Running s') ->
  pipeline_kind M p = kind.
Proof.
  intros transition. inversion transition; subst.
  match goal with H : pipeline_step _ _ _ _ _ _ _ |- _ =>
    pose proof (pipeline_step_owner H) as owner; simpl in owner; subst;
    eapply pipeline_step_compute_kind; exact H
  end.
Qed.

Lemma skip_has_no_pipeline_step (M : model Numeric) p s t event s' t' :
  pipeline_code t = CSkip -> ~ pipeline_step M p s t event s' t'.
Proof. intros code transition. inversion transition; congruence. Qed.

Lemma skip_has_no_pipeline_error (M : model Numeric) p s t :
  pipeline_code t = CSkip -> ~ pipeline_error M p s t.
Proof.
  intros code [_ [context [head [equation error]]]].
  rewrite code in equation. destruct context; simpl in equation.
  - subst head. exact error.
  - discriminate.
Qed.

Lemma terminal_has_no_successor (M : model Numeric) s :
  terminal s -> forall event next, ~ step M (Running s) event next.
Proof.
  intros terminated event next transition. inversion transition; subst.
  - eapply skip_has_no_pipeline_step; [|eassumption].
    eapply (proj1 (terminated _ _ H1)).
  - eapply skip_has_no_pipeline_error; [|eassumption].
    eapply (proj1 (terminated _ _ H1)).
Qed.

Lemma terminal_execution_maximal (M : model Numeric) first events s :
  steps M first events (Running s) -> terminal s ->
  maximal_finite_execution M first events (Running s).
Proof.
  intros execution terminated. split; [exact execution |].
  unfold irreducible. intros event next.
  eapply terminal_has_no_successor; exact terminated.
Qed.

End Properties.

From Stdlib Require Import List Arith Lia.
From UnifiedInterpreter.CoreLanguage Require Import Syntax State Events Semantics.

Import ListNotations.
Set Implicit Arguments.

Section Executions.
  Context {Numeric : Type} (m : model Numeric).

  Inductive steps : configuration Numeric -> list (label Numeric) ->
      configuration Numeric -> Prop :=
  | StepsRefl configuration : steps configuration [] configuration
  | StepsCons first event next events last :
      step m first event next -> steps next events last ->
      steps first (event :: events) last.

  Definition irreducible (configuration : configuration Numeric) : Prop :=
    forall event next, ~ step m configuration event next.

  Definition maximal_finite_execution first events last : Prop :=
    steps first events last /\ irreducible last.

  Definition infinite_execution
      (states : nat -> configuration Numeric)
      (events : nat -> label Numeric) : Prop :=
    forall n, step m (states n) (events n) (states (S n)).

  Lemma steps_append first events middle more last :
    steps first events middle -> steps middle more last ->
    steps first (events ++ more) last.
  Proof.
    intros execution continuation. induction execution; simpl.
    - exact continuation.
    - econstructor; eauto.
  Qed.

  Lemma steps_single first event last :
    step m first event last -> steps first [event] last.
  Proof. intros transition. econstructor; [exact transition | constructor]. Qed.

  Lemma infinite_execution_prefix states events :
    infinite_execution states events ->
    forall n, steps (states 0) (map events (seq 0 n)) (states n).
  Proof.
    intros execution n. induction n as [|n IH].
    - constructor.
    - rewrite seq_S, map_app. simpl.
      replace (0 + n) with n by lia.
      eapply steps_append; [exact IH |].
      apply steps_single. apply execution.
  Qed.
End Executions.

Inductive behavior (Numeric : Type) : Type :=
| FiniteBehavior (events : list (label Numeric))
    (last : configuration Numeric)
| InfiniteBehavior (states : nat -> configuration Numeric)
    (events : nat -> label Numeric).

Arguments FiniteBehavior {Numeric} _ _.
Arguments InfiniteBehavior {Numeric} _ _.

Definition behaviors {Numeric} (m : model Numeric)
    (initial : configuration Numeric) (execution : behavior Numeric) : Prop :=
  match execution with
  | FiniteBehavior events last => maximal_finite_execution m initial events last
  | InfiniteBehavior states events =>
      states 0 = initial /\ infinite_execution m states events
  end.

Definition program_semantics {Numeric} (m : model Numeric)
    (prog : program Numeric) (execution : behavior Numeric) : Prop :=
  exists initial_memory initial_locals,
    initial_well_formed m prog initial_memory initial_locals /\
    behaviors m (Running (initial_machine m prog initial_memory initial_locals)) execution.

Definition scheduling_entity := pipeline_id.

Definition scheduled_entity {Numeric} (event : label Numeric) : scheduling_entity :=
  event_owner event.

Definition entity_enabled {Numeric} (m : model Numeric)
    (entity : scheduling_entity) (state : configuration Numeric) : Prop :=
  exists event next, step m state event next /\ scheduled_entity event = entity.

Definition weakly_fair {Numeric} (m : model Numeric)
    (states : nat -> configuration Numeric) (events : nat -> label Numeric) : Prop :=
  forall entity first,
    (forall index, first <= index -> entity_enabled m entity (states index)) ->
    exists index, first <= index /\ scheduled_entity (events index) = entity.

Definition fair_infinite_execution {Numeric} (m : model Numeric)
    (states : nat -> configuration Numeric) (events : nat -> label Numeric) : Prop :=
  infinite_execution m states events /\ weakly_fair m states events.

Section EventRelations.
  Context {Numeric : Type}.

  Definition event_at (trace : list (label Numeric)) (index : nat)
      (event : label Numeric) : Prop := nth_error trace index = Some event.

  (* 同一主体的全部先后事件均连接，传递闭包与相邻事件定义相同。 *)
  Definition po_edge (trace : list (label Numeric)) (a b : nat) : Prop :=
    a < b /\ exists first second p,
      event_at trace a first /\ event_at trace b second /\
      event_owner first = p /\ event_owner second = p.

  Definition touches_flag (event : event_key) (label : label Numeric) : Prop :=
    match label with
    | LSet _ changed | LWait _ changed => changed = event
    | _ => False
    end.

  Definition flag_edge (trace : list (label Numeric)) (a b : nat) : Prop :=
    a < b /\ exists setter waiter event,
      event_at trace a (LSet setter event) /\
      event_at trace b (LWait waiter event) /\
      forall index label,
        a < index < b -> event_at trace index label ->
        ~ touches_flag event label.

  Definition acquires_lock (lock : lock_id) (label : label Numeric) : Prop :=
    match label with
    | LAcquire _ acquired => acquired = lock
    | _ => False
    end.

  Definition mutex_edge (trace : list (label Numeric)) (a b : nat) : Prop :=
    a < b /\ exists releaser acquirer lock,
      event_at trace a (LRelease releaser lock) /\
      event_at trace b (LAcquire acquirer lock) /\
      forall index label,
        a < index < b -> event_at trace index label ->
        ~ acquires_lock lock label.

  Inductive synchronization_edge (trace : list (label Numeric))
      (a b : nat) : Prop :=
  | EdgePo : po_edge trace a b -> synchronization_edge trace a b
  | EdgeFlag : flag_edge trace a b -> synchronization_edge trace a b
  | EdgeMutex : mutex_edge trace a b -> synchronization_edge trace a b.

  Inductive happens_before (trace : list (label Numeric)) : nat -> nat -> Prop :=
  | HBEdge a b : synchronization_edge trace a b -> happens_before trace a b
  | HBTrans a b c : happens_before trace a b -> happens_before trace b c ->
      happens_before trace a c.

  Definition Conflict (trace : list (label Numeric)) (a b : nat) : Prop :=
    exists first second location first_write second_write,
      event_at trace a first /\ event_at trace b second /\
      access first = Some (location, first_write) /\
      access second = Some (location, second_write) /\
      (first_write = true \/ second_write = true).

  Definition Race (trace : list (label Numeric)) (a b : nat) : Prop :=
    a <> b /\ Conflict trace a b /\
    ~ happens_before trace a b /\ ~ happens_before trace b a.

  Definition race_free_trace (trace : list (label Numeric)) : Prop :=
    forall a b, ~ Race trace a b.

  Lemma synchronization_edge_forward trace a b :
    synchronization_edge trace a b -> a < b.
  Proof. intros edge. destruct edge; destruct H; assumption. Qed.

  Lemma happens_before_forward trace a b : happens_before trace a b -> a < b.
  Proof.
    intros ordering. induction ordering.
    - eapply synchronization_edge_forward; eauto.
    - lia.
  Qed.

  Lemma happens_before_irreflexive trace a : ~ happens_before trace a a.
  Proof. intros ordering. apply happens_before_forward in ordering. lia. Qed.

  Lemma happens_before_asymmetric trace a b :
    happens_before trace a b -> ~ happens_before trace b a.
  Proof.
    intros forward backward.
    apply happens_before_forward in forward.
    apply happens_before_forward in backward. lia.
  Qed.

  Lemma adjacent_happens_before_edge trace a :
    happens_before trace a (S a) -> synchronization_edge trace a (S a).
  Proof.
    intros ordering. inversion ordering; subst; [assumption |].
    match goal with
    | H1 : happens_before _ _ _, H2 : happens_before _ _ _ |- _ =>
        apply happens_before_forward in H1;
        apply happens_before_forward in H2; lia
    end.
  Qed.

  Lemma same_pipeline_order trace a b first second :
    a < b -> event_at trace a first -> event_at trace b second ->
    event_owner first = event_owner second -> happens_before trace a b.
  Proof.
    intros order at_first at_second owner. apply HBEdge, EdgePo.
    split; [exact order |]. exists first, second, (event_owner first).
    repeat split; assumption || reflexivity || symmetry; assumption.
  Qed.

  Lemma same_pipeline_no_race trace a b first second :
    event_at trace a first -> event_at trace b second ->
    event_owner first = event_owner second -> ~ Race trace a b.
  Proof.
    intros at_first at_second owner [different [_ [forward backward]]].
    destruct (Nat.lt_trichotomy a b) as [less | [equal | greater]].
    - apply forward. eapply same_pipeline_order; eauto.
    - contradiction.
    - apply backward. eapply same_pipeline_order; eauto.
  Qed.

  Lemma Race_symmetric trace a b : Race trace a b -> Race trace b a.
  Proof.
    intros [distinct [[first [second [location [fw [sw
      [at_first [at_second [access_first [access_second written]]]]]]]]]
      [forward backward]]].
    split; [congruence |]. split; [|auto].
    exists second, first, location, sw, fw.
    split; [exact at_second |]. split; [exact at_first |].
    split; [exact access_second |]. split; [exact access_first |].
    destruct written; [right | left]; assumption.
  Qed.

  Lemma overwritten_flag_set_not_edge setter waiter (event : event_key) :
    ~ flag_edge [@LSet Numeric setter event; LSet setter event; LWait waiter event] 0 2.
  Proof.
    intros [_ [setter' [waiter' [event' [at_set [at_wait uninterrupted]]]]]].
    unfold event_at in at_set. simpl in at_set. inversion at_set; subst setter' event'.
    specialize (uninterrupted 1 (LSet setter event) ltac:(lia) eq_refl).
    apply uninterrupted. reflexivity.
  Qed.

  Lemma latest_flag_set_edge setter waiter (event : event_key) :
    flag_edge [@LSet Numeric setter event; LSet setter event; LWait waiter event] 1 2.
  Proof.
    split; [lia |]. exists setter, waiter, event.
    split; [reflexivity |]. split; [reflexivity |].
    intros index label order at_event. lia.
  Qed.

  Lemma consumed_flag_set_not_edge setter waiter (event : event_key) :
    ~ flag_edge [@LSet Numeric setter event; LWait waiter event; LWait waiter event] 0 2.
  Proof.
    intros [_ [setter' [waiter' [event' [at_set [at_wait uninterrupted]]]]]].
    unfold event_at in at_set. simpl in at_set. inversion at_set; subst setter' event'.
    specialize (uninterrupted 1 (LWait waiter event) ltac:(lia) eq_refl).
    apply uninterrupted. reflexivity.
  Qed.

End EventRelations.

Definition race_free_from {Numeric} (m : model Numeric)
    (initial : configuration Numeric) : Prop :=
  forall events last, steps m initial events last -> race_free_trace events.

Definition race_free {Numeric} (m : model Numeric)
    (initial : configuration Numeric -> Prop) : Prop :=
  forall state, initial state -> race_free_from m state.

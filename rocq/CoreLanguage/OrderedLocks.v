From Stdlib Require Import List Arith Lia.
From stdpp Require Import gmap.
From UnifiedInterpreter.CoreLanguage Require Import Syntax State Events Semantics.

Import ListNotations.
Set Implicit Arguments.

Definition lock_order := lock_id -> nat -> pipeline_id.

Definition well_formed_order {Numeric} (m : model Numeric)
    (order : lock_order) : Prop :=
  forall lock participants turn,
    lock_participants m !! lock = Some participants ->
    order lock turn ∈ participants.

Record ordered_machine (Numeric : Type) := {
  base_machine : machine Numeric;
  lock_turns : gmap lock_id nat
}.

Arguments base_machine {Numeric} _.
Arguments lock_turns {Numeric} _.

Inductive ordered_configuration (Numeric : Type) : Type :=
| OrderedRunning (state : ordered_machine Numeric)
| OrderedError.

Arguments OrderedRunning {Numeric} _.
Arguments OrderedError {Numeric}.

Definition erase_order {Numeric} (state : ordered_configuration Numeric)
    : configuration Numeric :=
  match state with
  | OrderedRunning s => Running (base_machine s)
  | OrderedError => Error
  end.

Definition initial_ordered_machine {Numeric} (m : model Numeric)
    (prog : program Numeric) initial_memory initial_locals : ordered_machine Numeric :=
  {| base_machine := initial_machine m prog initial_memory initial_locals;
     lock_turns := (fun _ => 0) <$> lock_participants m |}.

Definition initial_ordered_well_formed {Numeric} (m : model Numeric)
    (order : lock_order) (prog : program Numeric) initial_memory initial_locals : Prop :=
  initial_well_formed m prog initial_memory initial_locals /\ well_formed_order m order.

Definition turns_well_formed {Numeric} (m : model Numeric)
    (s : ordered_machine Numeric) : Prop :=
  forall lock,
    is_Some (lock_turns s !! lock) <-> is_Some (lock_participants m !! lock).

Definition nonlocking_event {Numeric} (event : label Numeric) : Prop :=
  match event with
  | LAcquire _ _ | LRelease _ _ => False
  | _ => True
  end.

(* 按标签约束普通步骤，顺序组合内部的获取和释放使用相同规则。 *)
Inductive ordered_step {Numeric} (m : model Numeric) (order : lock_order) :
    ordered_configuration Numeric -> label Numeric ->
    ordered_configuration Numeric -> Prop :=
| OrderedOrdinary s event next :
    step m (Running (base_machine s)) event (Running next) ->
    nonlocking_event event ->
    ordered_step m order (OrderedRunning s) event
      (OrderedRunning {| base_machine := next; lock_turns := lock_turns s |})
| OrderedAcquire s p lock next turn :
    step m (Running (base_machine s)) (LAcquire p lock) (Running next) ->
    lock_turns s !! lock = Some turn ->
    order lock turn = p ->
    ordered_step m order (OrderedRunning s) (LAcquire p lock)
      (OrderedRunning {| base_machine := next; lock_turns := lock_turns s |})
| OrderedRelease s p lock next turn :
    step m (Running (base_machine s)) (LRelease p lock) (Running next) ->
    lock_turns s !! lock = Some turn ->
    ordered_step m order (OrderedRunning s) (LRelease p lock)
      (OrderedRunning
        {| base_machine := next;
           lock_turns := <[lock := S turn]> (lock_turns s) |})
| OrderedFailure s p :
    step m (Running (base_machine s)) (LError p) Error ->
    ordered_step m order (OrderedRunning s) (LError p) OrderedError.

Definition ordered_terminal {Numeric} (s : ordered_machine Numeric) : Prop :=
  terminal (base_machine s).

Definition ordered_deadlocked {Numeric} (m : model Numeric) (order : lock_order)
    (s : ordered_machine Numeric) : Prop :=
  ~ ordered_terminal s /\
  forall event next, ~ ordered_step m order (OrderedRunning s) event next.

Section Properties.
  Context {Numeric : Type} (m : model Numeric) (order : lock_order).

  Lemma ordered_step_erases first event last :
    ordered_step m order first event last ->
    step m (erase_order first) event (erase_order last).
  Proof. intros transition. destruct transition; simpl; assumption. Qed.

  Lemma ordered_error_has_no_successor event next :
    ~ ordered_step m order OrderedError event next.
  Proof. intros transition. inversion transition. Qed.

  Lemma ordered_failure_iff s p :
    ordered_step m order (OrderedRunning s) (LError p) OrderedError <->
    step m (Running (base_machine s)) (LError p) Error.
  Proof.
    split.
    - intros transition. inversion transition; assumption.
    - apply OrderedFailure.
  Qed.

  Lemma ordered_acquire_checks_turn s p lock next :
    ordered_step m order (OrderedRunning s) (LAcquire p lock) next ->
    exists turn, lock_turns s !! lock = Some turn /\ order lock turn = p.
  Proof.
    intros transition. inversion transition; subst; simpl in *; try contradiction.
    eauto.
  Qed.

  Lemma wrong_turn_blocks_acquire s p lock turn next :
    lock_turns s !! lock = Some turn -> order lock turn <> p ->
    ~ ordered_step m order (OrderedRunning s) (LAcquire p lock) next.
  Proof.
    intros at_turn wrong transition.
    apply ordered_acquire_checks_turn in transition.
    destruct transition as [actual [lookup_actual owner]]. congruence.
  Qed.

  Lemma ordered_acquire_preserves_turns s p lock next :
    ordered_step m order (OrderedRunning s) (LAcquire p lock)
      (OrderedRunning next) -> lock_turns next = lock_turns s.
  Proof. intros transition. inversion transition; subst; simpl in *; tauto. Qed.

  Lemma ordered_release_advances_turn s p lock next :
    ordered_step m order (OrderedRunning s) (LRelease p lock)
      (OrderedRunning next) ->
    exists turn, lock_turns s !! lock = Some turn /\
      lock_turns next = <[lock := S turn]> (lock_turns s).
  Proof.
    intros transition. inversion transition; subst; simpl in *; try contradiction.
    eauto.
  Qed.

  Lemma ordered_release_next_turn s p lock next turn :
    ordered_step m order (OrderedRunning s) (LRelease p lock)
      (OrderedRunning next) -> lock_turns s !! lock = Some turn ->
    lock_turns next !! lock = Some (S turn).
  Proof.
    intros transition old_turn.
    apply ordered_release_advances_turn in transition.
    destruct transition as [actual [at_actual updated]].
    assert (actual = turn) by congruence. subst actual.
    rewrite updated, lookup_insert. case_decide; congruence.
  Qed.

  Lemma nonrelease_preserves_turns s event next :
    ordered_step m order (OrderedRunning s) event (OrderedRunning next) ->
    (forall p lock, event <> LRelease p lock) ->
    lock_turns next = lock_turns s.
  Proof.
    intros transition no_release. inversion transition; subst; simpl; auto.
    exfalso. eapply no_release. reflexivity.
  Qed.

  Lemma ordered_step_preserves_turn_domain s event next :
    ordered_step m order (OrderedRunning s) event (OrderedRunning next) ->
    forall lock, is_Some (lock_turns next !! lock) <->
      is_Some (lock_turns s !! lock).
  Proof.
    intros transition queried. inversion transition; subst; simpl; try tauto.
    destruct (decide (queried = lock)) as [same | different].
    - subst queried. rewrite lookup_insert. case_decide; [|congruence]. split; intros.
      + eexists; eassumption.
      + eexists; reflexivity.
    - rewrite lookup_insert_ne; auto.
  Qed.

  Lemma ordered_step_preserves_well_formed_turns s event next :
    ordered_step m order (OrderedRunning s) event (OrderedRunning next) ->
    turns_well_formed m s -> turns_well_formed m next.
  Proof.
    intros transition well_formed lock.
    rewrite (ordered_step_preserves_turn_domain transition lock).
    apply well_formed.
  Qed.

  Lemma initial_ordered_turn_zero prog initial_memory initial_locals lock participants :
    lock_participants m !! lock = Some participants ->
    lock_turns (initial_ordered_machine m prog initial_memory initial_locals) !! lock =
      Some 0.
  Proof.
    intros declared. simpl. rewrite lookup_fmap, declared. reflexivity.
  Qed.

  Lemma initial_turns_well_formed prog initial_memory initial_locals :
    turns_well_formed m
      (initial_ordered_machine m prog initial_memory initial_locals).
  Proof.
    intros lock. simpl. rewrite lookup_fmap.
    destruct (lock_participants m !! lock); simpl; split;
      intros [witness equation]; inversion equation; eauto.
  Qed.

  Lemma valid_order_selects_member lock participants turn :
    well_formed_order m order ->
    lock_participants m !! lock = Some participants ->
    lock_member m (order lock turn) lock.
  Proof.
    intros valid declared. exists participants. split; [exact declared |].
    eapply valid; eauto.
  Qed.

  Lemma sequence_lock_obeys_order s p t lock following turn :
    p ∈ declared_pipelines m -> pipelines (base_machine s) !! p = Some t ->
    pipeline_code t = CSeq (CLock lock) following ->
    lock_member m p lock -> locks (base_machine s) !! lock = Some None ->
    lock_turns s !! lock = Some turn -> order lock turn = p ->
    exists next, ordered_step m order (OrderedRunning s) (LAcquire p lock)
      (OrderedRunning next).
  Proof.
    intros declared at_pipeline code member free at_turn selected.
    eexists. eapply OrderedAcquire; [|exact at_turn |exact selected].
    eapply StepControl; [exact declared |exact at_pipeline |].
    eapply PipelineSeq; [exact code |].
    eapply PipelineLock; [reflexivity |exact member |exact free].
  Qed.
End Properties.

(* 两个参与者反复轮转，定义在每一个自然数轮次上。 *)
Definition alternating_order : lock_order := fun _ turn => turn mod 2.

Lemma alternating_order_first_four lock :
  alternating_order lock 0 = 0 /\ alternating_order lock 1 = 1 /\
  alternating_order lock 2 = 0 /\ alternating_order lock 3 = 1.
Proof. repeat split; reflexivity. Qed.

Lemma alternating_order_periodic lock turn :
  alternating_order lock (turn + 2) = alternating_order lock turn.
Proof.
  unfold alternating_order. replace (turn + 2) with (turn + 1 * 2) by lia.
  apply Nat.Div0.mod_add.
Qed.

Lemma alternating_order_well_formed {Numeric} (m : model Numeric) :
  (forall lock participants, lock_participants m !! lock = Some participants ->
    0 ∈ participants /\ 1 ∈ participants) ->
  well_formed_order m alternating_order.
Proof.
  intros participants_valid lock participants turn declared.
  destruct (participants_valid lock participants declared) as [zero one].
  unfold alternating_order.
  assert (turn mod 2 < 2) by (apply Nat.mod_upper_bound; lia).
  assert (turn mod 2 = 0 \/ turn mod 2 = 1) by lia.
  destruct H0 as [first | second]; rewrite first || rewrite second; assumption.
Qed.

Lemma alternating_first_turn_blocks_second {Numeric} (m : model Numeric)
    s lock next :
  lock_turns s !! lock = Some 0 ->
  ~ ordered_step m alternating_order (OrderedRunning s) (LAcquire 1 lock) next.
Proof.
  intros at_turn. eapply wrong_turn_blocks_acquire; [exact at_turn |].
  discriminate.
Qed.

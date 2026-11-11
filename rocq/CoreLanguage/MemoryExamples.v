From Stdlib Require Import ZArith List.
From stdpp Require Import gmap.
From UnifiedInterpreter.CoreLanguage Require Import
  Syntax State Events Semantics Traces Examples.

Import ListNotations ConcreteExamples.

Module RegionReadExample.

Local Notation "'Int' n" := (@VScalar Z n%Z) (at level 10).

Definition region_read : op Z := ORead (EValue (VRegion {[0; 1]})).

Definition region_write : op Z :=
  OWrite (EValue (VRegion {[0; 1]}))
    (EValue (VMap {[0 := Int 41; 1 := Int 42]})).

Definition reader : command Z := CSeq (CBegin 0 region_read) (CEnd 0 0).
Definition writer : command Z := CSeq (CBegin 0 region_write) (CEnd 0 0).

Definition mixed_values : gmap address (value Z) := {[0 := Int 0; 1 := Int 42]}.

(* 先读取地址 0，两个地址写入完成后再读取地址 1。 *)
Definition region_interleaving : list (label Z) :=
  [LBegin 0 0 region_read; LRead 0 0 0 (Int 0);
   LBegin 1 1 region_write; LWrite 1 1 0 (Int 41); LWrite 1 1 1 (Int 42);
   LFinish 1 1; LRead 0 0 1 (Int 42); LFinish 0 0;
   LControl 0; LJoin 0 0; LControl 1; LJoin 1 1].

Definition local_state (code : command Z) (locals : gmap var (value Z))
    (handles : gmap handle task_id) : pipeline_state Z :=
  {| pipeline_code := code; pipeline_locals := locals; pipeline_handles := handles |}.

Definition reader_task (body : task_state Z) : task Z :=
  {| task_owner := 0; task_body := body |}.
Definition writer_task (body : task_state Z) : task Z :=
  {| task_owner := 1; task_body := body |}.

Definition snapshot (mem : gmap address (value Z)) (jobs : gmap task_id (task Z))
    (fresh : nat) (reader_state writer_state : pipeline_state Z) : machine Z :=
  {| memory := mem;
     flags := flags (start CSkip CSkip);
     locks := locks (start CSkip CSkip);
     tasks := jobs; next_task := fresh;
     pipelines := {[0 := reader_state; 1 := writer_state]} |}.

Definition reader_pending := local_state (CSeq CSkip (CEnd 0 0)) ∅ {[0 := 0]}.
Definition writer_pending := local_state (CSeq CSkip (CEnd 0 0)) ∅ {[0 := 1]}.
Definition write_values : gmap address (value Z) := {[0 := Int 41; 1 := Int 42]}.
Definition partial_memory : gmap address (value Z) := {[0 := Int 41; 1 := Int 0]}.
Definition unfinished_read := reader_task (Reading {[1]} {[0 := Int 0]}).
Definition finished_write := writer_task (Done (@VUnit Z)).
Definition finished_read := reader_task (Done (VMap mixed_values)).

(* 中间状态直接列出各个分量，逐步证明保持固定的状态表达式大小。 *)
Definition state1 := snapshot base_memory {[0 := reader_task (Reading {[0; 1]} ∅)]}
  1 reader_pending (local_state writer ∅ ∅).
Definition state2 := snapshot base_memory {[0 := unfinished_read]}
  1 reader_pending (local_state writer ∅ ∅).
Definition state3 := snapshot base_memory
  {[0 := unfinished_read; 1 := writer_task (Writing {[0; 1]} write_values)]}
  2 reader_pending writer_pending.
Definition state4 := snapshot partial_memory
  {[0 := unfinished_read; 1 := writer_task (Writing {[1]} write_values)]}
  2 reader_pending writer_pending.
Definition state5 := snapshot write_values
  {[0 := unfinished_read; 1 := writer_task (Writing ∅ write_values)]}
  2 reader_pending writer_pending.
Definition state6 := snapshot write_values {[0 := unfinished_read; 1 := finished_write]}
  2 reader_pending writer_pending.
Definition state7 := snapshot write_values
  {[0 := reader_task (Reading ∅ mixed_values); 1 := finished_write]}
  2 reader_pending writer_pending.
Definition state8 := snapshot write_values {[0 := finished_read; 1 := finished_write]}
  2 reader_pending writer_pending.
Definition state9 := snapshot write_values {[0 := finished_read; 1 := finished_write]}
  2 (local_state (CEnd 0 0) ∅ {[0 := 0]}) writer_pending.
Definition state10 := snapshot write_values {[1 := finished_write]}
  2 (local_state CSkip {[0 := VMap mixed_values]} ∅) writer_pending.
Definition state11 := snapshot write_values {[1 := finished_write]}
  2 (local_state CSkip {[0 := VMap mixed_values]} ∅)
    (local_state (CEnd 0 0) ∅ {[0 := 1]}).
Definition state12 := snapshot write_values ∅
  2 (local_state CSkip {[0 := VMap mixed_values]} ∅)
    (local_state CSkip {[0 := VUnit]} ∅).

Lemma step_to_named first event raw last :
  step concrete_model first event raw -> raw = last ->
  step concrete_model first event last.
Proof. intros transition equal. subst last. exact transition. Qed.

Example interleaved_region_read :
  exists final,
    steps concrete_model (Running (start reader writer)) region_interleaving
      (Running final) /\
    memory final = {[0 := Int 41; 1 := Int 42]} /\
    (exists t, pipelines final !! 0 = Some t /\
      pipeline_locals t !! 0 = Some (VMap mixed_values) /\ pipeline_handles t = ∅) /\
    (exists t, pipelines final !! 1 = Some t /\
      pipeline_locals t !! 0 = Some VUnit /\ pipeline_handles t = ∅) /\
    tasks final = ∅ /\ terminal final.
Proof.
  exists state12; split.
  - unfold region_interleaving.
    eapply StepsCons with (next := Running state1).
    { eapply step_to_named.
      { control_at 0%nat. sequence_head. eapply PipelineBegin.
      - reflexivity.
      - reflexivity.
      - reflexivity.
      - split; [reflexivity |]. split.
        + change (({[0; 1]} : gset address) ⊆ {[0; 1]}). set_solver.
        + intros a contained. reflexivity. }
      reflexivity. }
    eapply StepsCons with (next := Running state2).
    { eapply step_to_named.
      - eapply StepTask. eapply TaskRead; [reflexivity | set_solver | reflexivity].
      - reflexivity. }
    eapply StepsCons with (next := Running state3).
    { eapply step_to_named.
      { control_at 1%nat. sequence_head. eapply PipelineBegin.
      - reflexivity.
      - reflexivity.
      - reflexivity.
      - split.
        + change (({[0; 1]} : gset address) ⊆ {[0; 1]}). set_solver.
        + split; [reflexivity |]. intros a v lookup_value.
          change (({[0 := Int 41; 1 := Int 42]} : gmap address (value Z)) !! a =
            Some v) in lookup_value.
          apply lookup_insert_Some in lookup_value.
          destruct lookup_value as [[at_zero value_zero] | [_ at_one]].
          * subst a v. split; reflexivity.
          * apply lookup_singleton_Some in at_one.
            destruct at_one as [at_one value_one]. subst a v. split; reflexivity. }
      reflexivity. }
    eapply StepsCons with (next := Running state4).
    { eapply step_to_named.
      - eapply StepTask. eapply TaskWrite; [reflexivity | set_solver | reflexivity].
      - reflexivity. }
    eapply StepsCons with (next := Running state5).
    { eapply step_to_named.
      - eapply StepTask. eapply TaskWrite; [reflexivity | set_solver | reflexivity].
      - reflexivity. }
    eapply StepsCons with (next := Running state6).
    { eapply step_to_named.
      - eapply StepTask. eapply TaskFinishWrite. reflexivity.
      - reflexivity. }
    eapply StepsCons with (next := Running state7).
    { eapply step_to_named.
      - eapply StepTask. eapply TaskRead; [reflexivity | set_solver | reflexivity].
      - reflexivity. }
    eapply StepsCons with (next := Running state8).
    { eapply step_to_named.
      - eapply StepTask. eapply TaskFinishRead. reflexivity.
      - reflexivity. }
    eapply StepsCons with (next := Running state9).
    { eapply step_to_named; [control_at 0%nat; sequence_skip | reflexivity]. }
    eapply StepsCons with (next := Running state10).
    { eapply step_to_named; [control_at 0%nat; join_task | reflexivity]. }
    eapply StepsCons with (next := Running state11).
    { eapply step_to_named; [control_at 1%nat; sequence_skip | reflexivity]. }
    eapply StepsCons with (next := Running state12).
    { eapply step_to_named; [control_at 1%nat; join_task | reflexivity]. }
    apply StepsRefl.
  - split; [reflexivity |]. split.
    + eexists. repeat split; reflexivity.
    + split.
      * eexists. repeat split; reflexivity.
      * split; [reflexivity |]. apply terminal_from_codes; reflexivity.
Qed.

Lemma mixed_values_at_both_addresses :
  mixed_values !! 0 = Some (Int 0) /\ mixed_values !! 1 = Some (Int 42).
Proof. split; reflexivity. Qed.

Lemma mixed_values_differ_from_memory_phases :
  mixed_values <> base_memory /\
  mixed_values <> {[0 := Int 41; 1 := Int 0]} /\
  mixed_values <> {[0 := Int 41; 1 := Int 42]}.
Proof.
  split.
  - intros same. assert (mixed_values !! 1 = base_memory !! 1) by congruence.
    discriminate.
  - split; intros same;
      assert (mixed_values !! 0 = Some (Int 41)) by (rewrite same; reflexivity);
      discriminate.
Qed.

End RegionReadExample.

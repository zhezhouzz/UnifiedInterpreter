From Stdlib Require Import ZArith List.
From stdpp Require Import gmap.
From UnifiedInterpreter.CoreLanguage Require Import
  Syntax State Events Semantics Traces Properties Examples.

Import ListNotations ConcreteExamples.

Module RegionReadExample.

Local Notation "'Int' n" := (@VScalar Z n%Z) (at level 10).

Definition region_read : op Z := ORead (EValue (VRegion {[0; 1]})).
Definition region_write : op Z :=
  OWrite (EValue (VRegion {[0; 1]}))
    (EValue (VMap {[0 := Int 41; 1 := Int 42]})).
Definition reader : command Z := COp 0 region_read.
Definition writer : command Z := COp 0 region_write.
Definition mixed_values : gmap address (value Z) := {[0 := Int 0; 1 := Int 42]}.
Definition write_values : gmap address (value Z) := {[0 := Int 41; 1 := Int 42]}.
Definition partial_memory : gmap address (value Z) := {[0 := Int 41; 1 := Int 0]}.

Definition reader_idle := local reader ∅ None.
Definition writer_idle := local writer ∅ None.
Definition read0 := local reader ∅ (Some (Reading {[0; 1]} ∅)).
Definition read1 := local reader ∅ (Some (Reading {[1]} {[0 := Int 0]})).
Definition read2 := local reader ∅ (Some (Reading ∅ mixed_values)).
Definition read_done := local reader ∅ (Some (Done (VMap mixed_values))).
Definition read_final := local CSkip {[0 := VMap mixed_values]} None.
Definition write0 := local writer ∅ (Some (Writing {[0; 1]} write_values)).
Definition write1 := local writer ∅ (Some (Writing {[1]} write_values)).
Definition write2 := local writer ∅ (Some (Writing ∅ write_values)).
Definition write_done := local writer ∅ (Some (Done VUnit)).
Definition write_final := local CSkip {[0 := VUnit]} None.

Definition state1 := snapshot base_memory read0 writer_idle.
Definition state2 := snapshot base_memory read1 writer_idle.
Definition state3 := snapshot base_memory read1 write0.
Definition state4 := snapshot partial_memory read1 write1.
Definition state5 := snapshot write_values read1 write2.
Definition state6 := snapshot write_values read1 write_done.
Definition state7 := snapshot write_values read2 write_done.
Definition state8 := snapshot write_values read_done write_done.
Definition state9 := snapshot write_values read_done write_final.
Definition state10 := snapshot write_values read_final write_final.

Definition region_interleaving : list (label Z) :=
  [LStart 0 region_read; LRead 0 0 (Int 0); LStart 1 region_write;
   LWrite 1 0 (Int 41); LWrite 1 1 (Int 42); LControl 1;
   LRead 0 1 (Int 42); LControl 0; LComplete 1 0 VUnit;
   LComplete 0 0 (VMap mixed_values)].

Ltac control_at owner :=
  eapply StepControl with (p := owner); [vm_compute; tauto | reflexivity |].

Example interleaved_region_read :
  steps concrete_model (Running (start reader writer)) region_interleaving (Running state10).
Proof.
  unfold region_interleaving.
  eapply StepsCons with (next := Running state1).
  { eapply step_to_named. { control_at 0.
    eapply PipelineStart; [reflexivity | reflexivity | reflexivity |].
    split; [reflexivity |]. split.
    - change (({[0; 1]} : gset address) ⊆ {[0; 1]}). set_solver.
    - intros a contained. reflexivity. } reflexivity. }
  eapply StepsCons with (next := Running state2).
  { eapply step_to_named. { control_at 0.
    eapply PipelineRead; [reflexivity | reflexivity | set_solver | reflexivity]. }
    reflexivity. }
  eapply StepsCons with (next := Running state3).
  { eapply step_to_named. { control_at 1.
    eapply PipelineStart; [reflexivity | reflexivity | reflexivity |].
    split.
    - change (({[0; 1]} : gset address) ⊆ {[0; 1]}). set_solver.
    - split; [reflexivity |]. intros a v lookup_value.
      change (({[0 := Int 41; 1 := Int 42]} : gmap address (value Z)) !! a =
        Some v) in lookup_value.
      apply lookup_insert_Some in lookup_value.
      destruct lookup_value as [[at_zero value_zero] | [_ at_one]].
      + subst a v. split; reflexivity.
      + apply lookup_singleton_Some in at_one.
        destruct at_one as [at_one value_one]. subst a v. split; reflexivity. }
    reflexivity. }
  eapply StepsCons with (next := Running state4).
  { eapply step_to_named. { control_at 1.
    eapply PipelineWrite; [reflexivity | reflexivity | set_solver | reflexivity]. }
    reflexivity. }
  eapply StepsCons with (next := Running state5).
  { eapply step_to_named. { control_at 1.
    eapply PipelineWrite; [reflexivity | reflexivity | set_solver | reflexivity]. }
    reflexivity. }
  eapply StepsCons with (next := Running state6).
  { eapply step_to_named. { control_at 1. eapply PipelineWriteFinished; reflexivity. }
    reflexivity. }
  eapply StepsCons with (next := Running state7).
  { eapply step_to_named. { control_at 0.
    eapply PipelineRead; [reflexivity | reflexivity | set_solver | reflexivity]. }
    reflexivity. }
  eapply StepsCons with (next := Running state8).
  { eapply step_to_named. { control_at 0. eapply PipelineReadFinished; reflexivity. }
    reflexivity. }
  eapply StepsCons with (next := Running state9).
  { eapply step_to_named. { control_at 1. eapply PipelineComplete; reflexivity. }
    reflexivity. }
  eapply StepsCons with (next := Running state10).
  { eapply step_to_named. { control_at 0. eapply PipelineComplete; reflexivity. }
    reflexivity. }
  constructor.
Qed.

Lemma state10_terminal : terminal state10.
Proof.
  intros p t H. change (({[0 := read_final; 1 := write_final]} :
    gmap pipeline_id (pipeline_state Z)) !! p = Some t) in H.
  apply lookup_insert_Some in H as [[_ equality] | [_ H]].
  - subst t. split; reflexivity.
  - apply lookup_singleton_Some in H as [_ equality]. subst t. split; reflexivity.
Qed.

Lemma state10_results :
  memory state10 = write_values /\
  (exists t, pipelines state10 !! 0 = Some t /\
    pipeline_locals t !! 0 = Some (VMap mixed_values)) /\
  (exists t, pipelines state10 !! 1 = Some t /\
    pipeline_locals t !! 0 = Some VUnit).
Proof.
  split; [reflexivity |]. split.
  - exists read_final. split; reflexivity.
  - exists write_final. split; reflexivity.
Qed.

Lemma mixed_values_at_both_addresses :
  mixed_values !! 0 = Some (Int 0) /\ mixed_values !! 1 = Some (Int 42).
Proof. split; reflexivity. Qed.

Lemma mixed_values_differ_from_memory_phases :
  mixed_values <> base_memory /\ mixed_values <> partial_memory /\ mixed_values <> write_values.
Proof.
  split.
  - intros same. assert (mixed_values !! 1 = base_memory !! 1) by congruence.
    discriminate.
  - split; intros same;
      assert (mixed_values !! 0 = Some (Int 41)) by (rewrite same; reflexivity);
      discriminate.
Qed.

End RegionReadExample.

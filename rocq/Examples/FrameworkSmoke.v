From Stdlib Require Import List ZArith.
From UnifiedInterpreter.Base Require Import StateM.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Unified Require Import Events State.
From UnifiedInterpreter.HFusion Require Import Instructions.

Import ListNotations.

Definition smoke_initial : unified_state Z := initial_unified_state.

Definition smoke_result :
    exec_result event runtime_error (unified_state Z) allocation_id :=
  exec_alloc [10%Z; 20%Z; 30%Z] smoke_initial.

Example smoke_allocates_id_zero :
  match smoke_result with
  | ExecOk id _ _ => id = 0%nat
  | ExecError _ _ _ => False
  end.
Proof. reflexivity. Qed.

Example smoke_preserves_descriptors :
  match smoke_result with
  | ExecOk _ state _ =>
      unified_descriptors state = unified_descriptors smoke_initial
  | ExecError _ _ _ => False
  end.
Proof. reflexivity. Qed.

Example smoke_emits_three_events :
  match smoke_result with
  | ExecOk _ _ events => List.length events = 3%nat
  | ExecError _ _ _ => False
  end.
Proof. reflexivity. Qed.

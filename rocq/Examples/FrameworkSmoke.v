From Stdlib Require Import List ZArith.
From UnifiedInterpreter.Base Require Import Result StateM.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors State.
From UnifiedInterpreter.HFusion Require Import Instructions.

Import ListNotations.

Definition smoke_initial : unified_state Z := initial_unified_state.

Definition smoke_result :
    result runtime_error (allocation_id * unified_state Z) :=
  exec_alloc [10%Z; 20%Z; 30%Z] smoke_initial.

Example smoke_allocates_id_zero :
  match smoke_result with
  | Ok (id, _) => id = 0%nat
  | Error _ => False
  end.
Proof. reflexivity. Qed.

Example smoke_allocation_is_readable :
  match smoke_result with
  | Ok (id, state) =>
      lookup_block id (unified_memory state) =
      Some {| block_elements := [10%Z; 20%Z; 30%Z] |}
  | Error _ => False
  end.
Proof. reflexivity. Qed.

Example smoke_preserves_descriptor_map :
  match smoke_result with
  | Ok (_, state) =>
      memory_descriptors (unified_memory state) =
      memory_descriptors (unified_memory smoke_initial)
  | Error _ => False
  end.
Proof. reflexivity. Qed.

Example failure_exposes_no_partial_state :
  @exec_fail Z smoke_initial = Error InvalidMemoryAccess.
Proof. reflexivity. Qed.

Definition allocate_then_fail :
    M runtime_error (unified_state Z) unit :=
  _ <- exec_alloc [42%Z] ;;
  fail InvalidMemoryAccess.

Example failed_sequence_exposes_no_intermediate_state :
  allocate_then_fail smoke_initial = Error InvalidMemoryAccess.
Proof. reflexivity. Qed.

From Stdlib Require Import List ZArith.
From UnifiedInterpreter.Base Require Import Result Free Lens StateM.
From UnifiedInterpreter.Type Require Import MLIR HFusion.
From UnifiedInterpreter.Memory Require Import Model Effects Handler.
From UnifiedInterpreter.Unified Require Import State Errors Events.
From UnifiedInterpreter.HFusion Require Import Instr Runtime.
From UnifiedInterpreter.HFusion.Semantics Require Import Memory.
From UnifiedInterpreter.HIVM Require Import Instr Numeric Value Semantics Execution.
From UnifiedInterpreter.Examples Require Import HIVMCompute MemoryEffects.

Import ListNotations.
Open Scope Z_scope.
#[local] Existing Instance test_numeric.

(* Same structure as the compute artifact: view -> local copy -> to_tensor ->
   materialize on consumption -> HIVM calculation -> destination writeback. *)
Definition compute_memory_path : memory_computation Z (result runtime_error unit) :=
  view <-! sem_memref_reinterpret_cast 0%nat 1 [2%nat;2%nat] [3;1] ;;
  local <-! sem_memref_alloc ASDefault Float32Type [2%nat;2%nat] ;;
  sem_memref_copy [2%nat;2%nat] view local ;;!
  backed <-! sem_bufferization_to_tensor local [2%nat;2%nat] Float32Type
    writable_restrict ;;
  materialized <-! materialize backed ;;
  match materialized with
  | Error e => Return (Error e)
  | Ok src =>
      match sem_binary VAdd (TensorOperand src) (ScalarOperand Float32Type 10)
          (out [2%nat;2%nat]) with
      | Error e => Return (Error e)
      | Ok calculated =>
          dst <-! sem_memref_alloc ASDefault Float32Type [2%nat;2%nat] ;;
          write_result calculated dst
      end
  end.

Definition memory_result := run_memory 40 compute_memory_path input_memory.

Example composition_writes_expected_cells :
  match memory_result with
  | Ok (_, memory) =>
      match lookup_buffer 2%nat memory with
      | Some storage => buffer_cells storage =
          [Initialized 11;Initialized 12;Initialized 14;Initialized 15]
      | None => False end
  | Error _ => False end.
Proof. vm_compute. reflexivity. Qed.

Example composition_preserves_source :
  match memory_result with
  | Ok (_, memory) => lookup_buffer 0%nat memory = lookup_buffer 0%nat input_memory
  | Error _ => False end.
Proof. vm_compute. reflexivity. Qed.

(* Extra component exists only in this test: production state is not enlarged
   merely to demonstrate lenses. *)
Record larger_state := { larger_memory : memory_state Z; marker : nat }.
Definition test_memory_lens : Lens larger_state (memory_state Z) :=
  {| lens_get := larger_memory;
     lens_put := fun m s => {| larger_memory := m; marker := marker s |} |}.
Definition marker_lens : Lens larger_state nat :=
  {| lens_get := marker;
     lens_put := fun n s => {| larger_memory := larger_memory s; marker := n |} |}.
#[local] Instance larger_has_memory : HasMemory Z larger_state :=
  {| memory_lens := test_memory_lens |}.
#[local] Instance larger_memory_lawful : LawfulLens test_memory_lens.
Proof. constructor; intros; try reflexivity. destruct state; reflexivity. Qed.
#[local] Instance marker_lawful : LawfulLens marker_lens.
Proof. constructor; intros; try reflexivity. destruct state; reflexivity. Qed.
#[local] Instance independent_marker : IndependentLenses test_memory_lens marker_lens.
Proof. constructor; intros; reflexivity. Qed.

Definition larger_result := run_memory 40 compute_memory_path
  {| larger_memory := input_memory; marker := 73%nat |}.

Example same_computation_under_lens :
  match memory_result, larger_result with
  | Ok (answer,memory), Ok (answer',state) =>
      answer = answer' /\ memory = larger_memory state /\ marker state = 73%nat
  | _,_ => False end.
Proof. vm_compute. auto. Qed.

Lemma every_success_preserves_marker fuel
    (program : memory_computation Z (result runtime_error unit)) st st' answer :
  run_memory fuel program st = Ok (answer, st') -> marker st' = marker st.
Proof.
  change (run_memory fuel program st = Ok (answer, st') ->
    lens_get marker_lens st' = lens_get marker_lens st).
  eapply run_memory_preserves_independent; eauto with typeclass_instances.
Qed.

Definition allocate_then_inner_failure : memory_computation Z (result runtime_error unit) :=
  _ <-! sem_memref_alloc ASDefault Float32Type [1%nat] ;;
  Return (Error InvalidShape).
Example inner_error_does_not_commit :
  run_memory 4 allocate_then_inner_failure (empty_memory : memory_state Z) =
    Error InvalidShape.
Proof. reflexivity. Qed.
Example zero_fuel_is_error :
  run_memory 0 compute_memory_path input_memory = Error OutOfFuel.
Proof. reflexivity. Qed.
Example write_empty_is_error :
  write_result (out [2%nat]) 0%nat = Return (Error ReadUninitialized).
Proof. reflexivity. Qed.

Definition memory_check : bool :=
  match memory_result, larger_result with
  | Ok (_, memory), Ok (_, state) =>
      match lookup_buffer 2%nat memory with
      | Some storage =>
          Nat.eqb (marker state) 73 &&
          match buffer_cells storage with
          | [Initialized a;Initialized b;Initialized c;Initialized d] =>
              Z.eqb a 11 && Z.eqb b 12 && Z.eqb c 14 && Z.eqb d 15
          | _ => false end
      | None => false end
  | _,_ => false end.
Example extracted_memory_check_passes : memory_check = true.
Proof. reflexivity. Qed.

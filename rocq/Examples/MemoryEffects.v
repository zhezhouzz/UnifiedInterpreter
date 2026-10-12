From Stdlib Require Import List ZArith.
From stdpp Require Import gmap.
From UnifiedInterpreter.Base Require Import Free Result.
From UnifiedInterpreter.HFusion Require Import Instr Interpreter Runtime.
From UnifiedInterpreter.HFusion.Semantics Require Import Memory.
From UnifiedInterpreter.Memory Require Import Effects Handler Model.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Type Require Import HFusion MLIR Shape.
From UnifiedInterpreter.Unified Require Import Errors.

Import ListNotations.
Open Scope Z_scope.

Definition writable_restrict :=
  {| access_restrict := true; access_writable := true |}.

Definition input_memory : memory_state Z :=
  let '(allocation, memory) :=
    allocate_buffer ASGM Float32Type [0; 1; 2; 3; 4; 5] empty_memory in
  let descriptor :=
    {| descriptor_allocation := allocation;
       descriptor_offset := 0;
       descriptor_sizes := [6%nat];
       descriptor_strides := [1] |} in
  snd (insert_descriptor descriptor memory).

Definition artifact_memory_path : memory_computation Z (descriptor_id *
    descriptor_id * runtime_tensor Z) :=
  view <-! sem_memref_reinterpret_cast 0%nat 1 [2%nat; 2%nat] [3; 1] ;;
  local <-! sem_memref_alloc ASDefault Float32Type [2%nat; 2%nat] ;;
  sem_memref_copy [2%nat; 2%nat] view local ;;!
  tensor <-! sem_bufferization_to_tensor
    local [2%nat; 2%nat] Float32Type writable_restrict ;;
  Return (view, local, tensor).

Definition artifact_memory_result :=
  handle_memory 20 artifact_memory_path input_memory.

Example artifact_path_copies_strided_view :
  match artifact_memory_result with
  | Ok ((_, _, _), memory, _) =>
      match lookup_buffer 1%nat memory with
      | Some storage => buffer_cells storage =
          [Initialized 1; Initialized 2; Initialized 4; Initialized 5]
      | None => False
      end
  | Error _ => False
  end.
Proof. vm_compute. auto. Qed.

Example artifact_path_records_primitive_memory_actions :
  match artifact_memory_result with
  | Ok (_, _, trace) => length trace = 11%nat
  | Error _ => False
  end.
Proof. reflexivity. Qed.

Definition uninitialized_read : memory_computation Z Z :=
  descriptor <-! sem_memref_alloc ASDefault Float32Type [1%nat] ;;
  perform (Read descriptor [0%nat]).

Example allocation_cells_are_uninitialized :
  handle_memory 4 uninitialized_read empty_memory = Error ReadUninitialized.
Proof. reflexivity. Qed.

Example out_of_bounds_reinterpret_is_rejected :
  handle_memory 3
    (sem_memref_reinterpret_cast 0%nat 5 [2%nat] [1]) input_memory =
    Error (RuntimeMemoryError ViewAddressOutOfBounds).
Proof. reflexivity. Qed.

Example overlapping_copy_is_undefined :
  handle_memory 3 (sem_memref_copy [6%nat] 0%nat 0%nat) input_memory =
    Error (UndefinedBehavior CopySourceDestinationOverlap).
Proof. reflexivity. Qed.

Definition lazy_alias_program :
    memory_computation Z (option (packed_tensor Z)) :=
  tensor <-! sem_bufferization_to_tensor
    0%nat [6%nat] Float32Type writable_restrict ;;
  perform (Write 0%nat [0%nat] 99) ;;!
  materialize_runtime_tensor tensor.

Example to_tensor_is_a_live_alias :
  match handle_memory 12 lazy_alias_program input_memory with
  | Ok (Some (PackTensor _ _ tensor), _, _) =>
      tensor_elements tensor = [99; 1; 2; 3; 4; 5]
  | _ => False
  end.
Proof. reflexivity. Qed.

Definition duplicate_restrict_claim : memory_computation Z unit :=
  _ <-! sem_bufferization_to_tensor
    0%nat [6%nat] Float32Type writable_restrict ;;
  _ <-! sem_bufferization_to_tensor
    0%nat [6%nat] Float32Type writable_restrict ;;
  Return tt.

Example conflicting_restrict_alias_is_rejected :
  handle_memory 6 duplicate_restrict_claim input_memory =
    Error (RuntimeMemoryError RestrictAliasConflict).
Proof. reflexivity. Qed.

Definition owned_2 : runtime_tensor Z :=
  OwnedTensor (PackTensor [2%nat] Float32Type
    (@Build_tensor Z [2%nat] Float32Type [7; 8] eq_refl)).

Definition materialize_program : memory_computation Z (Z * Z) :=
  destination <-! sem_memref_alloc ASDefault Float32Type [2%nat] ;;
  _ <-! sem_bufferization_materialize_in_destination
    owned_2 destination true ;;
  first <-! perform (Read destination [0%nat]) ;;
  second <-! perform (Read destination [1%nat]) ;;
  Return (first, second).

Example materialize_writes_destination :
  match handle_memory 12 materialize_program empty_memory with
  | Ok ((first, second), _, _) => first = 7 /\ second = 8
  | Error _ => False
  end.
Proof. vm_compute. auto. Qed.

Example materialize_requires_writable_destination :
  let '(destination, memory) :=
    allocate_memref ASDefault Float32Type [2%nat] (empty_memory : memory_state Z) in
  handle_memory 4
    (sem_bufferization_materialize_in_destination owned_2 destination false)
    memory = Error (RuntimeMemoryError ReadOnlyTensorView).
Proof. reflexivity. Qed.

Definition alloc_instruction_type :=
  RankedMemRefType [StaticDim 2] Float32Type IdentityLayout ASDefault.

Definition alloc_instruction_result :=
  handle_memory 4
    (eval_memory_instruction [42%nat]
      (MemRefInstr (MemRefAlloc alloc_instruction_type))
      (∅ : ssa_environment Z)) empty_memory.

Example instruction_interpreter_binds_memref_result :
  match alloc_instruction_result with
  | Ok (Ok environment, _, _) =>
      environment !! 42%nat = Some (RuntimeMemRef 0%nat)
  | _ => False
  end.
Proof. reflexivity. Qed.

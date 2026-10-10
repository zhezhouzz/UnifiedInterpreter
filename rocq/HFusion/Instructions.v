From Stdlib Require Import List String.
From UnifiedInterpreter.Base Require Import StateM.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Unified Require Import Events State.
From UnifiedInterpreter.Value Require Import Scalar.

Import ListNotations.
Open Scope string_scope.
Set Implicit Arguments.

Definition local_fresh_id
    : M event runtime_error allocator_state allocation_id :=
  fun state =>
    let '(id, state') := local_fresh_allocation_id state in
    ExecOk id state' [].

Definition fresh_allocation_id {State} `{HasAllocator State}
    : M event runtime_error State allocation_id :=
  zoom allocator_lens local_fresh_id.

Definition local_store_allocation {Scalar}
    (id : allocation_id) (contents : list Scalar)
    : M event runtime_error (memory_state Scalar) unit :=
  modify (local_insert_allocation id
    {| allocation_elements := contents |}).

Definition store_allocation {Scalar State} `{HasMemory Scalar State}
    (id : allocation_id) (contents : list Scalar)
    : M event runtime_error State unit :=
  zoom memory_lens (local_store_allocation id contents).

(* This instruction demonstrates a multi-component operation assembled from
   independently reusable local state functions. *)
Definition exec_alloc {Scalar State}
    `{HasAllocator State} `{HasMemory Scalar State}
    (contents : list Scalar)
    : M event runtime_error State allocation_id :=
  emit (EInstructionStart "memref.alloc") ;;
  id <- fresh_allocation_id ;;
  store_allocation id contents ;;
  emit (EAllocation id (List.length contents)) ;;
  emit (EInstructionEnd "memref.alloc") ;;
  pure id.

Definition exec_scalar_add {Scalar State} `{ScalarOps Scalar}
    (left right : Scalar) : M event runtime_error State Scalar :=
  emit (EInstructionStart "arith.add") ;;
  let value := scalar_add left right in
  emit (EInstructionEnd "arith.add") ;;
  pure value.

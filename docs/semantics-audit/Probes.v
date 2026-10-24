(* Audit observations, not desired behavior or future regression requirements.
   These proofs expose limits of the current implementation. They deliberately
   do not belong to _CoqProject / the normal acceptance suite. See the report.
   Run from repository root:
   opam exec --switch=unified-interpreter -- rocq compile -Q rocq UnifiedInterpreter docs/semantics-audit/Probes.v
*)
From Stdlib Require Import List ZArith.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.Memory Require Import Handler Model.
From UnifiedInterpreter.HFusion.Semantics Require Import Memory.
From UnifiedInterpreter.HIVM Require Import Instr Semantics.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.Examples Require Import MemoryEffects HIVMCompute.
Import ListNotations.
Open Scope Z_scope.

Example current_self_copy_is_rejected :
  handle_memory 3 (sem_memref_copy [6%nat] 0%nat 0%nat) input_memory =
    Error (UndefinedBehavior CopySourceDestinationOverlap).
Proof. reflexivity. Qed.

Example descriptor_is_rejected_before_any_read :
  handle_memory 3 (sem_memref_reinterpret_cast 0%nat 5 [2%nat] [1]) input_memory =
    Error (RuntimeMemoryError ViewAddressOutOfBounds).
Proof. reflexivity. Qed.

Example numeric_interface_accepts_a_wrong_max_identity :
  observe (@sem_reduce Z test_numeric ReduceMax
    (v [1%nat;2%nat] Float32Type [-2000000;-3000000])
    (out [1%nat;1%nat]) [1%nat]) = Ok [-1000000].
Proof. reflexivity. Qed.

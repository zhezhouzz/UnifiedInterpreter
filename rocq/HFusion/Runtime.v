From Stdlib Require Import List.
From stdpp Require Import gmap.
From UnifiedInterpreter.HFusion Require Import Instr.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Type Require Import MLIR.

Set Implicit Arguments.

(* Tensor SSA values are either ordinary immutable tensor values or live views
   introduced by [bufferization.to_tensor].  The latter are materialized only
   when a tensor operation consumes them. *)
Inductive runtime_tensor (Scalar : Type) :=
| OwnedTensor (value : packed_tensor Scalar)
| MemRefBackedTensor (descriptor : descriptor_id)
    (shape : list nat) (element_type : mlir_type) (access : tensor_access).

Arguments OwnedTensor {Scalar} _.
Arguments MemRefBackedTensor {Scalar} _ _ _ _.

Inductive runtime_value (Scalar : Type) :=
| RuntimeScalar (element_type : mlir_type) (value : Scalar)
| RuntimeIndex (value : Z)
| RuntimeTensor (value : runtime_tensor Scalar)
| RuntimeMemRef (descriptor : descriptor_id).

Arguments RuntimeScalar {Scalar} _ _.
Arguments RuntimeIndex {Scalar} _.
Arguments RuntimeTensor {Scalar} _.
Arguments RuntimeMemRef {Scalar} _.

Definition ssa_environment (Scalar : Type) := gmap nat (runtime_value Scalar).

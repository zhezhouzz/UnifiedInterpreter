From UnifiedInterpreter.Base Require Import Lens.
From UnifiedInterpreter.Memory Require Import Model.

Set Implicit Arguments.

Record unified_state (Scalar : Type) := {
  unified_memory : memory_state Scalar
}.

(* Lenses only decompose fixed top-level components. Dynamic allocation
   separation is handled by finite-map lookup/update theorems. *)
Class HasMemory (Scalar State : Type) := {
  memory_lens : Lens State (memory_state Scalar)
}.

Definition unified_memory_lens {Scalar}
    : Lens (unified_state Scalar) (memory_state Scalar) :=
  {| lens_get := @unified_memory Scalar;
     lens_put := fun memory state =>
       {| unified_memory := memory |} |}.

#[global] Instance UnifiedHasMemory {Scalar}
    : HasMemory Scalar (unified_state Scalar) :=
  {| memory_lens := unified_memory_lens |}.

#[global] Instance UnifiedMemoryLawful {Scalar}
    : LawfulLens (@unified_memory_lens Scalar).
Proof. constructor; intros; destruct state; reflexivity. Qed.

Definition initial_unified_state {Scalar} : unified_state Scalar :=
  {| unified_memory := empty_memory |}.

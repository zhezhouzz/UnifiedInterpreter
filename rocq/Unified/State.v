From UnifiedInterpreter.Base Require Import Lens.
From UnifiedInterpreter.Memory Require Import Model.

Set Implicit Arguments.

(* An instruction states only that its ambient machine state contains memory.
   The current HFusion machine is memory_state itself; larger HIVM states can
   provide another instance without changing the instruction semantics. *)
Class HasMemory (Scalar State : Type) := {
  memory_lens : Lens State (memory_state Scalar)
}.

Definition memory_identity_lens {Scalar}
    : Lens (memory_state Scalar) (memory_state Scalar) :=
  {| lens_get := fun memory => memory;
     lens_put := fun memory _ => memory |}.

#[global] Instance MemoryHasMemory {Scalar}
    : HasMemory Scalar (memory_state Scalar) :=
  {| memory_lens := memory_identity_lens |}.

#[global] Instance MemoryIdentityLawful {Scalar}
    : LawfulLens (@memory_identity_lens Scalar).
Proof. constructor; reflexivity. Qed.

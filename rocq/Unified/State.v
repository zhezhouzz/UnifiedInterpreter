From UnifiedInterpreter.Base Require Import Lens.
From UnifiedInterpreter.Memory Require Import Model.

Set Implicit Arguments.

Record unified_state (Scalar : Type) := {
  unified_allocator : allocator_state;
  unified_memory : memory_state Scalar;
  unified_descriptors : descriptor_state;
  unified_steps : nat
}.

Class HasAllocator (State : Type) := {
  allocator_lens : Lens State allocator_state
}.

Class HasMemory (Scalar State : Type) := {
  memory_lens : Lens State (memory_state Scalar)
}.

Class HasDescriptors (State : Type) := {
  descriptor_lens : Lens State descriptor_state
}.

Definition unified_allocator_lens {Scalar}
    : Lens (unified_state Scalar) allocator_state :=
  {| lens_get := @unified_allocator Scalar;
     lens_put := fun allocator state =>
       {| unified_allocator := allocator;
          unified_memory := unified_memory state;
          unified_descriptors := unified_descriptors state;
          unified_steps := unified_steps state |} |}.

Definition unified_memory_lens {Scalar}
    : Lens (unified_state Scalar) (memory_state Scalar) :=
  {| lens_get := @unified_memory Scalar;
     lens_put := fun memory state =>
       {| unified_allocator := unified_allocator state;
          unified_memory := memory;
          unified_descriptors := unified_descriptors state;
          unified_steps := unified_steps state |} |}.

Definition unified_descriptor_lens {Scalar}
    : Lens (unified_state Scalar) descriptor_state :=
  {| lens_get := @unified_descriptors Scalar;
     lens_put := fun descriptor state =>
       {| unified_allocator := unified_allocator state;
          unified_memory := unified_memory state;
          unified_descriptors := descriptor;
          unified_steps := unified_steps state |} |}.

#[global] Instance UnifiedHasAllocator {Scalar}
    : HasAllocator (unified_state Scalar) :=
  {| allocator_lens := unified_allocator_lens |}.

#[global] Instance UnifiedHasMemory {Scalar}
    : HasMemory Scalar (unified_state Scalar) :=
  {| memory_lens := unified_memory_lens |}.

#[global] Instance UnifiedHasDescriptors {Scalar}
    : HasDescriptors (unified_state Scalar) :=
  {| descriptor_lens := unified_descriptor_lens |}.

#[global] Instance UnifiedAllocatorLawful {Scalar}
    : LawfulLens (@unified_allocator_lens Scalar).
Proof. constructor; intros; destruct state; reflexivity. Qed.

#[global] Instance UnifiedMemoryLawful {Scalar}
    : LawfulLens (@unified_memory_lens Scalar).
Proof. constructor; intros; destruct state; reflexivity. Qed.

#[global] Instance UnifiedDescriptorLawful {Scalar}
    : LawfulLens (@unified_descriptor_lens Scalar).
Proof. constructor; intros; destruct state; reflexivity. Qed.

#[global] Instance UnifiedAllocatorDescriptorIndependent {Scalar}
    : IndependentLenses (@unified_allocator_lens Scalar)
        (@unified_descriptor_lens Scalar).
Proof. constructor; intros; destruct state; reflexivity. Qed.

#[global] Instance UnifiedMemoryDescriptorIndependent {Scalar}
    : IndependentLenses (@unified_memory_lens Scalar)
        (@unified_descriptor_lens Scalar).
Proof. constructor; intros; destruct state; reflexivity. Qed.

#[global] Instance UnifiedAllocatorMemoryIndependent {Scalar}
    : IndependentLenses (@unified_allocator_lens Scalar)
        (@unified_memory_lens Scalar).
Proof. constructor; intros; destruct state; reflexivity. Qed.

Definition initial_unified_state {Scalar} : unified_state Scalar :=
  {| unified_allocator := empty_allocator;
     unified_memory := empty_memory;
     unified_descriptors := empty_descriptors;
     unified_steps := 0 |}.

From Stdlib Require Import List ZArith.
From stdpp Require Import gmap.

Import ListNotations.
Open Scope Z_scope.
Set Implicit Arguments.

Definition allocation_id := nat.
Definition descriptor_id := nat.

Record memory_block (Scalar : Type) := {
  block_elements : list Scalar
}.

(* A descriptor is a view. Creating one never creates another memory block. *)
Record memref_descriptor := {
  descriptor_allocation : allocation_id;
  descriptor_offset : Z;
  descriptor_sizes : list Z;
  descriptor_strides : list Z
}.

Record memory_state (Scalar : Type) := {
  memory_blocks : gmap nat (memory_block Scalar);
  memory_descriptors : gmap nat memref_descriptor;
  memory_next_allocation : allocation_id;
  memory_next_descriptor : descriptor_id
}.

Definition empty_memory {Scalar} : memory_state Scalar :=
  {| memory_blocks := ∅;
     memory_descriptors := ∅;
     memory_next_allocation := O;
     memory_next_descriptor := O |}.

Definition lookup_block {Scalar} (id : allocation_id)
    (memory : memory_state Scalar) : option (memory_block Scalar) :=
  memory_blocks memory !! id.

Definition lookup_descriptor {Scalar} (id : descriptor_id)
    (memory : memory_state Scalar) : option memref_descriptor :=
  memory_descriptors memory !! id.

Definition allocate_block {Scalar} (contents : list Scalar)
    (memory : memory_state Scalar) : allocation_id * memory_state Scalar :=
  let id := memory_next_allocation memory in
  (id,
   {| memory_blocks :=
        <[id := {| block_elements := contents |}]>
          (memory_blocks memory);
      memory_descriptors := memory_descriptors memory;
      memory_next_allocation := S id;
      memory_next_descriptor := memory_next_descriptor memory |}).

Definition insert_descriptor {Scalar} (descriptor : memref_descriptor)
    (memory : memory_state Scalar) : descriptor_id * memory_state Scalar :=
  let id := memory_next_descriptor memory in
  (id,
   {| memory_blocks := memory_blocks memory;
      memory_descriptors :=
        <[id := descriptor]> (memory_descriptors memory);
      memory_next_allocation := memory_next_allocation memory;
      memory_next_descriptor := S id |}).

Lemma allocate_block_lookup_new {Scalar} (contents : list Scalar)
    (memory memory' : memory_state Scalar) (id : allocation_id) :
  allocate_block contents memory = (id, memory') ->
  lookup_block id memory' = Some {| block_elements := contents |}.
Proof.
  unfold allocate_block. intro allocated.
  inversion allocated; subst. unfold lookup_block. cbn.
  apply lookup_insert_eq.
Qed.

Lemma allocate_block_preserves_descriptors {Scalar} (contents : list Scalar)
    (memory memory' : memory_state Scalar) (id : allocation_id) :
  allocate_block contents memory = (id, memory') ->
  memory_descriptors memory' = memory_descriptors memory.
Proof.
  unfold allocate_block. intro allocated. inversion allocated. reflexivity.
Qed.

Lemma allocate_block_preserves_other {Scalar} (contents : list Scalar)
    (memory memory' : memory_state Scalar)
    (fresh other : allocation_id) :
  allocate_block contents memory = (fresh, memory') ->
  fresh <> other ->
  lookup_block other memory' = lookup_block other memory.
Proof.
  unfold allocate_block. intros allocated not_equal.
  inversion allocated; subst. unfold lookup_block. cbn.
  apply lookup_insert_ne. congruence.
Qed.

Lemma insert_descriptor_preserves_blocks {Scalar}
    (descriptor : memref_descriptor) (memory memory' : memory_state Scalar)
    (id : descriptor_id) :
  insert_descriptor descriptor memory = (id, memory') ->
  memory_blocks memory' = memory_blocks memory.
Proof.
  unfold insert_descriptor. intro inserted. inversion inserted. reflexivity.
Qed.

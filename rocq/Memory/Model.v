From Stdlib Require Import List ZArith.

Import ListNotations.
Open Scope Z_scope.
Set Implicit Arguments.

Definition allocation_id := nat.
Definition descriptor_id := nat.

Record allocation (Scalar : Type) := {
  allocation_elements : list Scalar
}.

Record memref_descriptor := {
  descriptor_allocation : allocation_id;
  descriptor_offset : Z;
  descriptor_sizes : list Z;
  descriptor_strides : list Z
}.

Record allocator_state := {
  allocator_next : nat
}.

Record memory_state (Scalar : Type) := {
  memory_allocations : list (allocation_id * allocation Scalar)
}.

Record descriptor_state := {
  descriptors : list (descriptor_id * memref_descriptor);
  descriptor_next : nat
}.

Definition empty_allocator : allocator_state :=
  {| allocator_next := 0 |}.

Definition empty_memory {Scalar} : memory_state Scalar :=
  {| memory_allocations := [] |}.

Definition empty_descriptors : descriptor_state :=
  {| descriptors := []; descriptor_next := 0 |}.

Definition local_fresh_allocation_id (state : allocator_state)
    : allocation_id * allocator_state :=
  let id := allocator_next state in
  (id, {| allocator_next := S id |}).

Definition local_insert_allocation {Scalar}
    (id : allocation_id) (value : allocation Scalar)
    (state : memory_state Scalar) : memory_state Scalar :=
  {| memory_allocations :=
       (id, value) :: memory_allocations state |}.

From Stdlib Require Import List ZArith.
From stdpp Require Import gmap.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Type Require Import HFusion MLIR.

Import ListNotations.
Open Scope Z_scope.
Set Implicit Arguments.

Definition allocation_id := nat.
Definition descriptor_id := nat.

Inductive memory_cell (Value : Type) :=
| Uninitialized
| Initialized (value : Value).

Arguments Uninitialized {Value}.
Arguments Initialized {Value} _.

(* A buffer is mutable linear storage with allocation identity. Unlike a
   tensor, it has no intrinsic n-dimensional shape. *)
Record buffer (Value : Type) := {
  buffer_address_space : address_space;
  buffer_element_type : mlir_type;
  buffer_cells : list (memory_cell Value)
}.

(* A descriptor gives an n-dimensional interpretation of a buffer. Creating a
   descriptor changes metadata only and never creates another allocation. *)
Record memref_descriptor := {
  descriptor_allocation : allocation_id;
  descriptor_offset : Z;
  descriptor_sizes : list nat;
  descriptor_strides : list Z
}.

Record memory_state (Value : Type) := {
  memory_buffers : gmap nat (buffer Value);
  memory_descriptors : gmap nat memref_descriptor;
  (* Descriptor ids claimed by [bufferization.to_tensor restrict]. *)
  memory_restricted_descriptors : gset nat;
  memory_next_allocation : allocation_id;
  memory_next_descriptor : descriptor_id
}.

Inductive memory_error :=
| UnknownAllocation
| UnknownDescriptor
| InvalidViewRank
| ViewAddressOutOfBounds
| ReadUninitializedCell
| IncompatibleMemRef
| OverlappingCopy
| RestrictAliasConflict
| ReadOnlyTensorView.

Definition empty_memory {Value} : memory_state Value :=
  {| memory_buffers := ∅;
     memory_descriptors := ∅;
     memory_restricted_descriptors := ∅;
     memory_next_allocation := O;
     memory_next_descriptor := O |}.

Definition lookup_buffer {Value} (id : allocation_id)
    (memory : memory_state Value) : option (buffer Value) :=
  memory_buffers memory !! id.

Definition lookup_descriptor {Value} (id : descriptor_id)
    (memory : memory_state Value) : option memref_descriptor :=
  memory_descriptors memory !! id.

Definition allocate_buffer {Value} (space : address_space) (element_type : mlir_type)
    (contents : list Value) (memory : memory_state Value)
    : allocation_id * memory_state Value :=
  let id := memory_next_allocation memory in
  (id,
   {| memory_buffers :=
        <[id := {| buffer_address_space := space;
                   buffer_element_type := element_type;
                   buffer_cells := map Initialized contents |}]>
          (memory_buffers memory);
      memory_descriptors := memory_descriptors memory;
      memory_restricted_descriptors := memory_restricted_descriptors memory;
      memory_next_allocation := S id;
      memory_next_descriptor := memory_next_descriptor memory |}).

Definition insert_descriptor {Value} (descriptor : memref_descriptor)
    (memory : memory_state Value) : descriptor_id * memory_state Value :=
  let id := memory_next_descriptor memory in
  (id,
   {| memory_buffers := memory_buffers memory;
      memory_descriptors :=
        <[id := descriptor]> (memory_descriptors memory);
      memory_restricted_descriptors := memory_restricted_descriptors memory;
      memory_next_allocation := memory_next_allocation memory;
      memory_next_descriptor := S id |}).

Fixpoint view_cell_offset (offset : Z) (strides : list Z)
    (indices : list nat) : result memory_error Z :=
  match strides, indices with
  | [], [] => Ok offset
  | stride :: strides', index :: indices' =>
      view_cell_offset (offset + Z.of_nat index * stride) strides' indices'
  | _, _ => Error InvalidViewRank
  end.

Definition read_buffer_cell {Value} (storage : buffer Value) (address : Z)
    : result memory_error Value :=
  match address with
  | Zneg _ => Error ViewAddressOutOfBounds
  | Z0 =>
      match List.nth_error (buffer_cells storage) 0 with
      | Some (Initialized value) => Ok value
      | Some Uninitialized => Error ReadUninitializedCell
      | None => Error ViewAddressOutOfBounds
      end
  | Zpos positive =>
      match List.nth_error (buffer_cells storage) (Pos.to_nat positive) with
      | Some (Initialized value) => Ok value
      | Some Uninitialized => Error ReadUninitializedCell
      | None => Error ViewAddressOutOfBounds
      end
end.

Fixpoint replace_nth {A} (index : nat) (value : A) (values : list A)
    : option (list A) :=
  match index, values with
  | O, _ :: rest => Some (value :: rest)
  | S index', head :: rest =>
      match replace_nth index' value rest with
      | Some rest' => Some (head :: rest')
      | None => None
      end
  | _, _ => None
  end.

Definition write_buffer_cell {Value} (storage : buffer Value) (address : Z)
    (value : Value) : result memory_error (buffer Value) :=
  match address with
  | Zneg _ => Error ViewAddressOutOfBounds
  | Z0 =>
      match replace_nth 0 (Initialized value) (buffer_cells storage) with
      | Some cells =>
          Ok {| buffer_address_space := buffer_address_space storage;
                buffer_element_type := buffer_element_type storage;
                buffer_cells := cells |}
      | None => Error ViewAddressOutOfBounds
      end
  | Zpos positive =>
      match replace_nth (Pos.to_nat positive) (Initialized value)
          (buffer_cells storage) with
      | Some cells =>
          Ok {| buffer_address_space := buffer_address_space storage;
                buffer_element_type := buffer_element_type storage;
                buffer_cells := cells |}
      | None => Error ViewAddressOutOfBounds
      end
  end.

Fixpoint row_major_strides (dimensions : list nat) : list Z :=
  match dimensions with
  | [] => []
  | _ :: rest => Z.of_nat (num_elements rest) :: row_major_strides rest
  end.

Definition allocate_memref {Value} (space : address_space)
    (element_type : mlir_type) (dimensions : list nat)
    (memory : memory_state Value) : descriptor_id * memory_state Value :=
  let allocation := memory_next_allocation memory in
  let descriptor := memory_next_descriptor memory in
  let storage :=
    {| buffer_address_space := space;
       buffer_element_type := element_type;
       buffer_cells := repeat Uninitialized (num_elements dimensions) |} in
  let view :=
    {| descriptor_allocation := allocation;
       descriptor_offset := 0;
       descriptor_sizes := dimensions;
       descriptor_strides := row_major_strides dimensions |} in
  (descriptor,
   {| memory_buffers := <[allocation := storage]> (memory_buffers memory);
      memory_descriptors := <[descriptor := view]> (memory_descriptors memory);
      memory_restricted_descriptors := memory_restricted_descriptors memory;
      memory_next_allocation := S allocation;
      memory_next_descriptor := S descriptor |}).

Definition descriptor_addresses (descriptor : memref_descriptor) : list Z :=
  map (fun coordinate =>
    match view_cell_offset (descriptor_offset descriptor)
        (descriptor_strides descriptor) coordinate with
    | Ok address => address
    | Error _ => descriptor_offset descriptor
    end) (tensor_indices (descriptor_sizes descriptor)).

Definition descriptors_overlap (left right : memref_descriptor) : bool :=
  Nat.eqb (descriptor_allocation left) (descriptor_allocation right) &&
  existsb (fun address => existsb (Z.eqb address)
    (descriptor_addresses right)) (descriptor_addresses left).

Fixpoint read_coordinates {Value} (storage : buffer Value)
    (offset : Z) (strides : list Z) (coordinates : list (list nat))
    : result memory_error (list Value) :=
  match coordinates with
  | [] => Ok []
  | coordinate :: rest =>
      address <-? view_cell_offset offset strides coordinate ;;
      value <-? read_buffer_cell storage address ;;
      values <-? read_coordinates storage offset strides rest ;;
      Ok (value :: values)
  end.

(* Materialize the current contents observed through a memref descriptor as an
   independent tensor value. Later writes to the buffer do not mutate the
   returned tensor. *)
Definition read_view {Value} (memory : memory_state Value)
    (descriptor_id : descriptor_id) : result memory_error (packed_tensor Value) :=
  match lookup_descriptor descriptor_id memory with
  | None => Error UnknownDescriptor
  | Some descriptor =>
      match lookup_buffer (descriptor_allocation descriptor) memory with
      | None => Error UnknownAllocation
      | Some storage =>
          values <-?
            read_coordinates storage
              (descriptor_offset descriptor)
              (descriptor_strides descriptor)
              (tensor_indices (descriptor_sizes descriptor)) ;;
          let shape := descriptor_sizes descriptor in
          let element_type := buffer_element_type storage in
          match tensor_of_list shape element_type values with
          | Some value => Ok (PackTensor shape element_type value)
          | None => Error ViewAddressOutOfBounds
          end
      end
  end.

Lemma allocate_buffer_lookup_new {Value} (space : address_space)
    (element_type : mlir_type)
    (contents : list Value) (memory memory' : memory_state Value)
    (id : allocation_id) :
  allocate_buffer space element_type contents memory = (id, memory') ->
  lookup_buffer id memory' =
    Some {| buffer_address_space := space;
            buffer_element_type := element_type;
            buffer_cells := map Initialized contents |}.
Proof.
  unfold allocate_buffer. intro allocated.
  inversion allocated; subst. unfold lookup_buffer. cbn.
  apply lookup_insert_eq.
Qed.

Lemma allocate_buffer_preserves_descriptors {Value} (space : address_space)
    (element_type : mlir_type)
    (contents : list Value) (memory memory' : memory_state Value)
    (id : allocation_id) :
  allocate_buffer space element_type contents memory = (id, memory') ->
  memory_descriptors memory' = memory_descriptors memory.
Proof.
  unfold allocate_buffer. intro allocated. inversion allocated. reflexivity.
Qed.

Lemma allocate_buffer_preserves_other {Value} (space : address_space)
    (element_type : mlir_type)
    (contents : list Value) (memory memory' : memory_state Value)
    (fresh other : allocation_id) :
  allocate_buffer space element_type contents memory = (fresh, memory') ->
  fresh <> other ->
  lookup_buffer other memory' = lookup_buffer other memory.
Proof.
  unfold allocate_buffer. intros allocated not_equal.
  inversion allocated; subst. unfold lookup_buffer. cbn.
  apply lookup_insert_ne. congruence.
Qed.

Lemma insert_descriptor_preserves_buffers {Value}
    (descriptor : memref_descriptor) (memory memory' : memory_state Value)
    (id : descriptor_id) :
  insert_descriptor descriptor memory = (id, memory') ->
  memory_buffers memory' = memory_buffers memory.
Proof.
  unfold insert_descriptor. intro inserted. inversion inserted. reflexivity.
Qed.

From Stdlib Require Import List ZArith PArray Uint63 Lia.
From stdpp Require Import gmap.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Type Require Import HFusion MLIR.
From UnifiedInterpreter.Memory Require ListModel.

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

Definition page_size : Z := 4096.
Definition page_index (address : Z) := address / page_size.
Definition page_offset (address : Z) := Uint63.of_Z (address mod page_size).

Record cell_page (Value : Type) := {
  page_data : PArray.array (memory_cell Value);
  page_length : PArray.length page_data = 4096%uint63
}.

Definition empty_page {Value} (_ : unit) : cell_page Value.
Proof.
  refine {| page_data := PArray.make 4096%uint63 Uninitialized |}.
  reflexivity.
Defined.

Definition update_page {Value} (page : cell_page Value) (index : Uint63.int)
    (value : memory_cell Value) : cell_page Value.
Proof.
  refine {| page_data := PArray.set (page_data page) index value |}.
  rewrite PArray.length_set. apply page_length.
Defined.

Record cell_storage (Value : Type) := {
  cells_length : Z;
  cells_pages : gmap Z (cell_page Value)
}.

Definition empty_cells {Value} (size : nat) : cell_storage Value :=
  {| cells_length := Z.of_nat size; cells_pages := ∅ |}.

Definition cells_get {Value} (cells : cell_storage Value) (address : Z)
    : memory_cell Value :=
  match cells_pages cells !! page_index address with
  | None => Uninitialized
  | Some page => PArray.get (page_data page) (page_offset address)
  end.

Definition cells_set {Value} (cells : cell_storage Value) (address : Z)
    (value : memory_cell Value) : cell_storage Value :=
  let page := match cells_pages cells !! page_index address with
              | Some page => page | None => empty_page tt end in
  {| cells_length := cells_length cells;
     cells_pages := <[page_index address :=
       update_page page (page_offset address) value]> (cells_pages cells) |}.

Fixpoint initialize_cells {Value} (contents : list Value) (address : Z)
    (cells : cell_storage Value) : cell_storage Value :=
  match contents with
  | [] => cells
  | value :: rest => initialize_cells rest (address + 1)
      (cells_set cells address (Initialized value))
  end.

Definition cells_of_list {Value} (contents : list Value) : cell_storage Value :=
  initialize_cells contents 0 (empty_cells (List.length contents)).

Definition cells_to_list {Value} (cells : cell_storage Value)
    : list (memory_cell Value) :=
  map (fun index => cells_get cells (Z.of_nat index))
    (seq 0 (Z.to_nat (cells_length cells))).

Record buffer (Value : Type) := {
  buffer_address_space : address_space;
  buffer_element_type : mlir_type;
  buffer_cells : cell_storage Value
}.

Record memref_descriptor := {
  descriptor_allocation : allocation_id;
  descriptor_offset : Z;
  descriptor_sizes : list nat;
  descriptor_strides : list Z
}.

Record memory_state (Value : Type) := {
  memory_buffers : gmap nat (buffer Value);
  memory_descriptors : gmap nat memref_descriptor;
  memory_restricted_descriptors : gset nat;
  memory_next_allocation : allocation_id;
  memory_next_descriptor : descriptor_id
}.

Definition memory_error := ListModel.memory_error.
Notation UnknownAllocation := ListModel.UnknownAllocation.
Notation UnknownDescriptor := ListModel.UnknownDescriptor.
Notation InvalidViewRank := ListModel.InvalidViewRank.
Notation ViewAddressOutOfBounds := ListModel.ViewAddressOutOfBounds.
Notation ReadUninitializedCell := ListModel.ReadUninitializedCell.
Notation IncompatibleMemRef := ListModel.IncompatibleMemRef.
Notation OverlappingCopy := ListModel.OverlappingCopy.
Notation RestrictAliasConflict := ListModel.RestrictAliasConflict.
Notation ReadOnlyTensorView := ListModel.ReadOnlyTensorView.

Definition empty_memory {Value} : memory_state Value :=
  {| memory_buffers := ∅; memory_descriptors := ∅;
     memory_restricted_descriptors := ∅;
     memory_next_allocation := O; memory_next_descriptor := O |}.

Definition lookup_buffer {Value} (id : allocation_id)
    (memory : memory_state Value) : option (buffer Value) := memory_buffers memory !! id.
Definition lookup_descriptor {Value} (id : descriptor_id)
    (memory : memory_state Value) : option memref_descriptor := memory_descriptors memory !! id.

Definition allocate_buffer {Value} (space : address_space) (element_type : mlir_type)
    (contents : list Value) (memory : memory_state Value)
    : allocation_id * memory_state Value :=
  let id := memory_next_allocation memory in
  (id, {| memory_buffers := <[id :=
      {| buffer_address_space := space; buffer_element_type := element_type;
         buffer_cells := cells_of_list contents |}]> (memory_buffers memory);
    memory_descriptors := memory_descriptors memory;
    memory_restricted_descriptors := memory_restricted_descriptors memory;
    memory_next_allocation := S id; memory_next_descriptor := memory_next_descriptor memory |}).

Definition insert_descriptor {Value} (descriptor : memref_descriptor)
    (memory : memory_state Value) : descriptor_id * memory_state Value :=
  let id := memory_next_descriptor memory in
  (id, {| memory_buffers := memory_buffers memory;
    memory_descriptors := <[id := descriptor]> (memory_descriptors memory);
    memory_restricted_descriptors := memory_restricted_descriptors memory;
    memory_next_allocation := memory_next_allocation memory; memory_next_descriptor := S id |}).

Definition view_cell_offset := ListModel.view_cell_offset.

Definition read_buffer_cell {Value} (storage : buffer Value) (address : Z)
    : result memory_error Value :=
  if (0 <=? address) && (address <? cells_length (buffer_cells storage)) then
    match cells_get (buffer_cells storage) address with
    | Initialized value => Ok value
    | Uninitialized => Error ReadUninitializedCell
    end
  else Error ViewAddressOutOfBounds.

Definition write_buffer_cell {Value} (storage : buffer Value) (address : Z)
    (value : Value) : result memory_error (buffer Value) :=
  if (0 <=? address) && (address <? cells_length (buffer_cells storage)) then
    Ok {| buffer_address_space := buffer_address_space storage;
          buffer_element_type := buffer_element_type storage;
          buffer_cells := cells_set (buffer_cells storage) address (Initialized value) |}
  else Error ViewAddressOutOfBounds.

Definition row_major_strides := ListModel.row_major_strides.

Definition allocate_memref {Value} (space : address_space)
    (element_type : mlir_type) (dimensions : list nat)
    (memory : memory_state Value) : descriptor_id * memory_state Value :=
  let allocation := memory_next_allocation memory in
  let descriptor := memory_next_descriptor memory in
  let storage := {| buffer_address_space := space; buffer_element_type := element_type;
                    buffer_cells := empty_cells (num_elements dimensions) |} in
  let view := {| descriptor_allocation := allocation; descriptor_offset := 0;
    descriptor_sizes := dimensions; descriptor_strides := row_major_strides dimensions |} in
  (descriptor, {| memory_buffers := <[allocation := storage]> (memory_buffers memory);
    memory_descriptors := <[descriptor := view]> (memory_descriptors memory);
    memory_restricted_descriptors := memory_restricted_descriptors memory;
    memory_next_allocation := S allocation; memory_next_descriptor := S descriptor |}).

Definition descriptor_addresses (descriptor : memref_descriptor) : list Z :=
  map (fun coordinate =>
    match view_cell_offset (descriptor_offset descriptor) (descriptor_strides descriptor) coordinate with
    | Ok address => address | Error _ => descriptor_offset descriptor end)
    (tensor_indices (descriptor_sizes descriptor)).

Definition descriptors_overlap (left right : memref_descriptor) : bool :=
  Nat.eqb (descriptor_allocation left) (descriptor_allocation right) &&
  existsb (fun address => existsb (Z.eqb address) (descriptor_addresses right))
    (descriptor_addresses left).

(* Nat -> Z 使用二进制递归，避免逐个递增构造地址。 *)
Fixpoint address_of_nat_aux (fuel index : nat) : Z :=
  match fuel, index with
  | O, _ | _, O => 0
  | S fuel', S _ =>
    let half := Nat.div2 index in
    let value := address_of_nat_aux fuel' half in
    if Nat.eqb index (half + half) then value + value else value + value + 1
  end.
Definition address_of_nat (index : nat) : Z := address_of_nat_aux index index.
Lemma address_of_nat_aux_correct fuel index :
  (index <= fuel)%nat -> address_of_nat_aux fuel index = Z.of_nat index.
Proof.
  revert index. induction fuel as [|fuel IH]; intros index H.
  - assert (index = O) by lia. subst. reflexivity.
  - destruct index as [|index]; [reflexivity|].
    change ((if Nat.eqb (S index) (Nat.div2 (S index) + Nat.div2 (S index))
      then address_of_nat_aux fuel (Nat.div2 (S index)) + address_of_nat_aux fuel (Nat.div2 (S index))
      else address_of_nat_aux fuel (Nat.div2 (S index)) + address_of_nat_aux fuel (Nat.div2 (S index)) + 1)
      = Z.of_nat (S index)).
    rewrite IH by (apply Nat.div2_decr; exact H).
    destruct (Nat.Even_or_Odd (S index)) as [Heven|Hodd].
    + apply Nat.Even_double in Heven. rewrite Nat.double_twice in Heven.
      assert (Nat.eqb (S index) (Nat.div2 (S index) + Nat.div2 (S index)) = true)
        as E by (apply Nat.eqb_eq; lia). rewrite E. lia.
    + apply Nat.Odd_double in Hodd. rewrite Nat.double_twice in Hodd.
      assert (Nat.eqb (S index) (Nat.div2 (S index) + Nat.div2 (S index)) = false)
        as E by (apply Nat.eqb_neq; lia). rewrite E. lia.
Qed.
Lemma address_of_nat_correct index : address_of_nat index = Z.of_nat index.
Proof. apply address_of_nat_aux_correct. lia. Qed.

Definition coordinate_address offset strides coordinate : result memory_error Z :=
  target <-? ListModel.coordinate_target offset strides coordinate ;;
  Ok (address_of_nat target).

Lemma coordinate_address_correct offset strides coordinate :
  coordinate_address offset strides coordinate =
    match view_cell_offset offset strides coordinate with
    | Ok address => if 0 <=? address then Ok address else Error ViewAddressOutOfBounds
    | Error error => Error error end.
Proof.
  unfold coordinate_address. rewrite ListModel.coordinate_target_eq_z.
  unfold ListModel.coordinate_target_z. fold view_cell_offset.
  destruct (view_cell_offset offset strides coordinate)
    as [address|error]; cbn [result_bind]; auto.
  destruct (0 <=? address) eqn:H; cbn [result_bind]; auto.
  rewrite address_of_nat_correct, Z2Nat.id; [reflexivity|now apply Z.leb_le].
Qed.

Fixpoint read_pointwise {Value} (storage : buffer Value) offset strides coordinates
    : result memory_error (list Value) :=
  match coordinates with
  | [] => Ok []
  | coordinate :: rest =>
    address <-? view_cell_offset offset strides coordinate ;;
    value <-? read_buffer_cell storage address ;;
    values <-? read_pointwise storage offset strides rest ;; Ok (value :: values)
  end.

Fixpoint write_pointwise {Value} (storage : buffer Value) offset strides coordinates values
    : result memory_error (buffer Value) :=
  match coordinates, values with
  | [], [] => Ok storage
  | coordinate :: rest, value :: tail =>
    address <-? view_cell_offset offset strides coordinate ;;
    updated <-? write_buffer_cell storage address value ;;
    write_pointwise updated offset strides rest tail
  | _, _ => Error InvalidViewRank end.

Fixpoint read_coordinates {Value} (storage : buffer Value) offset strides coordinates
    : result memory_error (list Value) :=
  match coordinates with
  | [] => Ok []
  | coordinate :: rest =>
    address <-? coordinate_address offset strides coordinate ;;
    value <-? read_buffer_cell storage address ;;
    values <-? read_coordinates storage offset strides rest ;; Ok (value :: values)
  end.

Fixpoint write_coordinates {Value} (storage : buffer Value) offset strides coordinates values
    : result memory_error (buffer Value) :=
  match coordinates, values with
  | [], [] => Ok storage
  | coordinate :: rest, value :: tail =>
    address <-? coordinate_address offset strides coordinate ;;
    updated <-? write_buffer_cell storage address value ;;
    write_coordinates updated offset strides rest tail
  | _, _ => Error InvalidViewRank end.

Theorem read_coordinates_correct Value (storage : buffer Value) offset strides coordinates :
  read_coordinates storage offset strides coordinates = read_pointwise storage offset strides coordinates.
Proof.
  induction coordinates as [|coordinate rest IH]; cbn; auto.
  rewrite coordinate_address_correct. destruct (view_cell_offset offset strides coordinate)
    as [address|error]; cbn; auto.
  destruct (0 <=? address) eqn:H; cbn.
  - rewrite IH. reflexivity.
  - unfold read_buffer_cell. rewrite H. reflexivity.
Qed.

Theorem write_coordinates_correct Value (storage : buffer Value) offset strides coordinates values :
  write_coordinates storage offset strides coordinates values =
  write_pointwise storage offset strides coordinates values.
Proof.
  revert storage values. induction coordinates as [|coordinate rest IH];
    intros storage []; cbn; auto.
  rewrite coordinate_address_correct. destruct (view_cell_offset offset strides coordinate)
    as [address|error]; cbn; auto.
  destruct (0 <=? address) eqn:H; cbn.
  - destruct (write_buffer_cell storage address v); cbn; auto.
  - unfold write_buffer_cell. rewrite H. reflexivity.
Qed.

Definition read_view {Value} (memory : memory_state Value) (id : descriptor_id)
    : result memory_error (packed_tensor Value) :=
  match lookup_descriptor id memory with
  | None => Error UnknownDescriptor
  | Some descriptor =>
    match lookup_buffer (descriptor_allocation descriptor) memory with
    | None => Error UnknownAllocation
    | Some storage =>
      values <-? read_coordinates storage (descriptor_offset descriptor)
        (descriptor_strides descriptor) (tensor_indices (descriptor_sizes descriptor)) ;;
      let shape := descriptor_sizes descriptor in
      let ty := buffer_element_type storage in
      match tensor_of_list shape ty values with
      | Some value => Ok (PackTensor shape ty value)
      | None => Error ViewAddressOutOfBounds end
    end
  end.

Lemma allocate_buffer_lookup_new {Value} space element_type contents
    (memory memory' : memory_state Value) id :
  allocate_buffer space element_type contents memory = (id, memory') ->
  lookup_buffer id memory' = Some {| buffer_address_space := space;
    buffer_element_type := element_type; buffer_cells := cells_of_list contents |}.
Proof.
  unfold allocate_buffer. intros H; inversion H; subst.
  unfold lookup_buffer; cbn. apply lookup_insert_eq.
Qed.
Lemma allocate_buffer_preserves_descriptors {Value} space element_type contents
    (memory memory' : memory_state Value) id :
  allocate_buffer space element_type contents memory = (id, memory') ->
  memory_descriptors memory' = memory_descriptors memory.
Proof. unfold allocate_buffer. intros H; inversion H; reflexivity. Qed.
Lemma allocate_buffer_preserves_other {Value} space element_type contents
    (memory memory' : memory_state Value) fresh other :
  allocate_buffer space element_type contents memory = (fresh, memory') -> fresh <> other ->
  lookup_buffer other memory' = lookup_buffer other memory.
Proof.
  unfold allocate_buffer. intros H Hne; inversion H; subst.
  unfold lookup_buffer; cbn. apply lookup_insert_ne. congruence.
Qed.
Lemma insert_descriptor_preserves_buffers {Value} descriptor
    (memory memory' : memory_state Value) id :
  insert_descriptor descriptor memory = (id, memory') -> memory_buffers memory' = memory_buffers memory.
Proof. unfold insert_descriptor. intros H; inversion H; reflexivity. Qed.

From Stdlib Require Import List ZArith Lia Sorting.Sorted Sorting.Permutation Sorting.Mergesort.
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

(* The address-indexed view of a cell list, used by both the general and the
   one-pass paths.  [read_buffer_cell] is this function at a non-negative [Z]. *)
Definition cell_at {Value} (cells : list (memory_cell Value)) (address : nat)
    : result memory_error Value :=
  match nth_error cells address with
  | Some (Initialized value) => Ok value
  | Some Uninitialized => Error ReadUninitializedCell
  | None => Error ViewAddressOutOfBounds
  end.

Lemma read_buffer_cell_nonnegative {Value} (storage : buffer Value) (address : Z) :
  0 <= address ->
  read_buffer_cell storage address =
  cell_at (buffer_cells storage) (Z.to_nat address).
Proof.
  intros nonnegative. destruct address as [|positive|positive]; cbn.
  - reflexivity.
  - reflexivity.
  - (* Zneg: contradicts non-negativity *)
    exfalso. lia.
Qed.

Lemma read_buffer_cell_of_nat {Value} (storage : buffer Value) (address : nat) :
  read_buffer_cell storage (Z.of_nat address) =
  cell_at (buffer_cells storage) address.
Proof.
  rewrite read_buffer_cell_nonnegative by apply Nat2Z.is_nonneg.
  rewrite Nat2Z.id. reflexivity.
Qed.

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

Fixpoint read_pointwise {Value} (storage : buffer Value)
    (offset : Z) (strides : list Z) (coordinates : list (list nat))
    : result memory_error (list Value) :=
  match coordinates with
  | [] => Ok []
  | coordinate :: rest =>
      address <-? view_cell_offset offset strides coordinate ;;
      value <-? read_buffer_cell storage address ;;
      values <-? read_pointwise storage offset strides rest ;;
      Ok (value :: values)
  end.

(* Bulk write.  Each cell is updated independently and later writes observe the
   storage produced by earlier ones, which is exactly the sequence of
   [write_buffer_cell] calls over the same coordinates.

   [read_pointwise] and [write_pointwise] are the *specification* of bulk
   access: one [read_buffer_cell] / [write_buffer_cell] per coordinate, in
   coordinate order, short-circuiting at the first error.  They are never
   executed.  [read_coordinates] and [write_coordinates] below are the single
   implementation, and [read_coordinates_correct] / [write_coordinates_correct]
   prove that the implementation returns exactly what these do. *)
Fixpoint write_pointwise {Value} (storage : buffer Value)
    (offset : Z) (strides : list Z) (coordinates : list (list nat))
    (values : list Value) : result memory_error (buffer Value) :=
  match coordinates, values with
  | [], [] => Ok storage
  | coordinate :: rest, value :: values' =>
      address <-? view_cell_offset offset strides coordinate ;;
      storage' <-? write_buffer_cell storage address value ;;
      write_pointwise storage' offset strides rest values'
  | _, _ => Error InvalidViewRank
  end.


(* The single-cell write, address-indexed in [nat]. *)
Definition write_cell_at {Value} (cells : list (memory_cell Value))
    (address : nat) (value : Value) : result memory_error (list (memory_cell Value)) :=
  match replace_nth address (Initialized value) cells with
  | Some cells' => Ok cells'
  | None => Error ViewAddressOutOfBounds
  end.

Lemma write_buffer_cell_nonnegative {Value} (storage : buffer Value)
    (address : Z) (value : Value) :
  0 <= address ->
  write_buffer_cell storage address value =
  match replace_nth (Z.to_nat address) (Initialized value) (buffer_cells storage) with
  | Some cells' =>
      Ok {| buffer_address_space := buffer_address_space storage;
            buffer_element_type := buffer_element_type storage;
            buffer_cells := cells' |}
  | None => Error ViewAddressOutOfBounds
  end.
Proof.
  destruct address as [|positive|positive]; cbn; intro nonnegative.
  - reflexivity.
  - reflexivity.
  - exfalso. lia.
Qed.

Lemma write_buffer_cell_nat {Value} (space : address_space)
    (element_type : mlir_type) (cells : list (memory_cell Value))
    (address : nat) (value : Value) :
  write_buffer_cell
    {| buffer_address_space := space;
       buffer_element_type := element_type;
       buffer_cells := cells |} (Z.of_nat address) value =
  match write_cell_at cells address value with
  | Ok cells' =>
      Ok {| buffer_address_space := space;
            buffer_element_type := element_type;
            buffer_cells := cells' |}
  | Error error => Error error
  end.
Proof.
  rewrite write_buffer_cell_nonnegative by apply Nat2Z.is_nonneg.
  rewrite Nat2Z.id.
  unfold write_cell_at.
  cbn.
  destruct (replace_nth address (Initialized value) cells) as [cells'|];
    reflexivity.
Qed.

(* ------------------------------------------------------------------ *)
(* A polymorphic merge sort                                           *)
(* ------------------------------------------------------------------ *)

(* [Sorting.Mergesort.Sort] is a functor over a *module*, and Coq modules
   cannot be parameterised by a type, so it can only be instantiated at one
   fixed element type.  The bulk access path has to sort two different element
   types ([nat * nat] for the addresses and [nat * result] for the answers), so
   the same algorithm is spelled out once here, polymorphically, together with
   the two facts its callers need: the result is sorted and it is a
   permutation of the input. *)

Local Open Scope nat_scope.

Section MergeSort.

  Context {A : Type}.
  Context (leb : A -> A -> bool).
  Context (leb_total : forall a1 a2 : A, leb a1 a2 = true \/ leb a2 a1 = true).
  Context (leb_trans :
    forall x y z : A, leb x y = true -> leb y z = true -> leb x z = true).

  Definition le_rel (left right : A) : Prop := leb left right = true.

  (* Bottom-up merge sort with a stack of pending runs, as in
     [Sorting.Mergesort]; the stack keeps the recursion structural. *)
  Fixpoint merge_runs (l1 l2 : list A) : list A :=
    let fix merge_aux (l2' : list A) : list A :=
      match l1, l2' with
      | [], _ => l2'
      | _, [] => l1
      | a1 :: l1', a2 :: l2'' =>
          if leb a1 a2 then a1 :: merge_runs l1' l2'
          else a2 :: merge_aux l2''
      end
    in merge_aux l2.

  Fixpoint merge_into_stack (stack : list (option (list A))) (l : list A)
      : list (option (list A)) :=
    match stack with
    | [] => [Some l]
    | None :: stack' => Some l :: stack'
    | Some l' :: stack' => None :: merge_into_stack stack' (merge_runs l' l)
    end.

  Fixpoint merge_stack (stack : list (option (list A))) : list A :=
    match stack with
    | [] => []
    | None :: stack' => merge_stack stack'
    | Some l :: stack' => merge_runs l (merge_stack stack')
    end.

  Fixpoint iter_merge (stack : list (option (list A))) (l : list A) : list A :=
    match l with
    | [] => merge_stack stack
    | a :: l' => iter_merge (merge_into_stack stack [a]) l'
    end.

  Definition msort (l : list A) : list A := iter_merge [] l.

  Fixpoint SortedStack (stack : list (option (list A))) : Prop :=
    match stack with
    | [] => True
    | None :: stack' => SortedStack stack'
    | Some l :: stack' => StronglySorted le_rel l /\ SortedStack stack'
    end.

  Fixpoint flatten_stack (stack : list (option (list A))) : list A :=
    match stack with
    | [] => []
    | None :: stack' => flatten_stack stack'
    | Some l :: stack' => l ++ flatten_stack stack'
    end.

  Lemma merge_runs_nil_left (l : list A) : merge_runs [] l = l.
  Proof. destruct l; reflexivity. Qed.

  Lemma merge_runs_nil_right (l : list A) : merge_runs l [] = l.
  Proof. destruct l; reflexivity. Qed.

  Lemma merge_runs_cons (a1 : A) (l1 : list A) (a2 : A) (l2 : list A) :
    merge_runs (a1 :: l1) (a2 :: l2) =
    if leb a1 a2 then a1 :: merge_runs l1 (a2 :: l2)
    else a2 :: merge_runs (a1 :: l1) l2.
  Proof. reflexivity. Qed.

  (* A bound that holds of both runs holds of the merge. *)
  Lemma merge_runs_Forall (x : A) :
    forall (l1 l2 : list A),
      Forall (le_rel x) l1 -> Forall (le_rel x) l2 ->
      Forall (le_rel x) (merge_runs l1 l2).
  Proof.
    intros l1. induction l1 as [|a1 l1 IH1]; intros l2 bound1 bound2.
    - rewrite merge_runs_nil_left. exact bound2.
    - revert bound1 bound2. induction l2 as [|a2 l2 IH2]; intros bound1 bound2.
      + rewrite merge_runs_nil_right. exact bound1.
      + rewrite merge_runs_cons. destruct (leb a1 a2).
        * constructor.
          -- apply (Forall_inv bound1).
          -- apply (IH1 (a2 :: l2)).
             ++ apply (Forall_inv_tail bound1).
             ++ exact bound2.
        * constructor.
          -- apply (Forall_inv bound2).
          -- apply (IH2 bound1 (Forall_inv_tail bound2)).
  Qed.

  Theorem merge_runs_sorted : forall l1 l2,
    StronglySorted le_rel l1 -> StronglySorted le_rel l2 ->
    StronglySorted le_rel (merge_runs l1 l2).
Proof.
  intros l1. induction l1 as [|a1 l1 IH1]; intros l2 sorted1 sorted2.
  - rewrite merge_runs_nil_left. exact sorted2.
  - revert sorted2. induction l2 as [|a2 l2 IH2]; intros sorted2.
    + rewrite merge_runs_nil_right. exact sorted1.
    + rewrite merge_runs_cons. destruct (leb a1 a2) eqn:ordered.
      * constructor.
        -- apply (IH1 (a2 :: l2) (proj1 (StronglySorted_inv sorted1)) sorted2).
        -- apply merge_runs_Forall.
           ++ apply (proj2 (StronglySorted_inv sorted1)).
           ++ constructor.
              ** exact ordered.
              ** eapply Forall_impl.
                 { apply (proj2 (StronglySorted_inv sorted2)). }
                 { intros y inside. exact (@leb_trans a1 a2 y ordered inside). }
      * assert (later : leb a2 a1 = true).
        { destruct (@leb_total a2 a1) as [total | total]; [exact total |].
          rewrite ordered in total. discriminate total. }
        constructor.
        -- apply (IH2 (proj1 (StronglySorted_inv sorted2))).
        -- apply merge_runs_Forall.
           ++ constructor.
              ** exact later.
              ** eapply Forall_impl.
                 { apply (proj2 (StronglySorted_inv sorted1)). }
                 { intros y inside. exact (@leb_trans a2 a1 y later inside). }
           ++ apply (proj2 (StronglySorted_inv sorted2)).
Qed.

  Theorem merge_runs_permutation : forall l1 l2,
    Permutation (l1 ++ l2) (merge_runs l1 l2).
Proof.
  intros l1. induction l1 as [|a l1 IH1]; intros l2.
  - rewrite merge_runs_nil_left. apply Permutation_refl.
  - induction l2 as [|a0 l2 IH2].
    + rewrite merge_runs_nil_right, app_nil_r. apply Permutation_refl.
    + rewrite merge_runs_cons. destruct (leb a a0).
      * cbn [app]. apply Permutation_cons.
        -- reflexivity.
        -- apply IH1.
      * apply Permutation_sym, Permutation_cons_app, Permutation_sym. apply IH2.
Qed.

  Theorem merge_into_stack_sorted : forall stack l,
    SortedStack stack -> StronglySorted le_rel l ->
    SortedStack (merge_into_stack stack l).
  Proof.
    induction stack as [|[|]]; intros; simpl.
    - auto.
    - apply IHstack.
      + destruct H as (_, H1). fold SortedStack in H1. auto.
      + apply merge_runs_sorted; auto; destruct H; auto.
    - auto.
  Qed.

  Theorem merge_into_stack_permutation : forall stack l,
    Permutation (l ++ flatten_stack stack)
                (flatten_stack (merge_into_stack stack l)).
  Proof.
    induction stack as [|[]]; simpl; intros.
    - reflexivity.
    - rewrite app_assoc.
      etransitivity.
      + apply Permutation_app_tail.
        etransitivity.
        * apply Permutation_app_comm.
        * apply merge_runs_permutation.
      + apply IHstack.
    - reflexivity.
  Qed.

  Theorem merge_stack_sorted : forall stack,
    SortedStack stack -> StronglySorted le_rel (merge_stack stack).
  Proof.
    induction stack as [|[|]]; simpl; intros.
    - constructor; auto.
    - apply merge_runs_sorted; tauto.
    - auto.
  Qed.

  Theorem merge_stack_permutation : forall stack,
    Permutation (flatten_stack stack) (merge_stack stack).
  Proof.
    induction stack as [|[]]; simpl.
    - trivial.
    - transitivity (l ++ merge_stack stack).
      + apply Permutation_app_head; trivial.
      + apply merge_runs_permutation.
    - assumption.
  Qed.

  Theorem iter_merge_sorted : forall stack l,
    SortedStack stack -> StronglySorted le_rel (iter_merge stack l).
  Proof.
    intros stack l bound. revert bound. revert stack.
    induction l as [|a l IH]; intros stack bound; simpl.
    - apply merge_stack_sorted. exact bound.
    - apply (IH (merge_into_stack stack [a])).
      apply merge_into_stack_sorted; [exact bound | constructor; constructor].
  Qed.

  Theorem iter_merge_permutation : forall l stack,
    Permutation (flatten_stack stack ++ l) (iter_merge stack l).
  Proof.
    induction l; simpl; intros.
    - rewrite app_nil_r. apply merge_stack_permutation.
    - change (a :: l) with ([a] ++ l).
      rewrite app_assoc.
      etransitivity.
      + apply Permutation_app_tail.
        etransitivity.
        * apply Permutation_app_comm.
        * apply merge_into_stack_permutation.
      + apply IHl.
  Qed.

  Theorem msort_strongly_sorted : forall l, StronglySorted le_rel (msort l).
  Proof. intro. apply iter_merge_sorted. constructor. Qed.

  Theorem msort_sorted : forall l, Sorted le_rel (msort l).
  Proof. intro. apply StronglySorted_Sorted. apply msort_strongly_sorted. Qed.

  Theorem msort_permutation : forall l, Permutation l (msort l).
  Proof. intro. apply (iter_merge_permutation l []). Qed.

End MergeSort.

(* The two orders the bulk path sorts with. *)
Definition entry_leb (left right : nat * nat) : bool :=
  if Nat.eqb (fst left) (fst right) then Nat.leb (snd left) (snd right)
  else Nat.leb (fst left) (fst right).

Definition position_leb {B : Type} (left right : nat * B) : bool :=
  Nat.leb (fst left) (fst right).

Lemma entry_leb_spec (left right : nat * nat) :
  entry_leb left right = true <->
  (fst left < fst right \/ (fst left = fst right /\ snd left <= snd right)).
Proof.
  unfold entry_leb.
  destruct (Nat.eqb (fst left) (fst right)) eqn:same.
  - apply Nat.eqb_eq in same. split; intro bound.
    + apply Nat.leb_le in bound. lia.
    + apply Nat.leb_le. lia.
  - apply Nat.eqb_neq in same. split; intro bound.
    + apply Nat.leb_le in bound. lia.
    + destruct bound as [less | [equal _]]; [apply Nat.leb_le; lia | congruence].
Qed.

Lemma position_leb_spec {B : Type} (left right : nat * B) :
  position_leb left right = true <-> fst left <= fst right.
Proof. unfold position_leb. apply Nat.leb_le. Qed.

Lemma entry_leb_total (left right : nat * nat) :
  entry_leb left right = true \/ entry_leb right left = true.
Proof.
  destruct (entry_leb left right) eqn:forward.
  - left. reflexivity.
  - right. apply entry_leb_spec.
    assert (notboth :
      ~ (fst left < fst right \/ (fst left = fst right /\ snd left <= snd right))).
    { intro both. rewrite (proj2 (entry_leb_spec left right) both) in forward.
      discriminate. }
    destruct (Nat.lt_ge_cases (fst right) (fst left)) as [less | ge].
    + left. exact less.
    + right. split; lia.
Qed.

Lemma position_leb_total {B : Type} (left right : nat * B) :
  position_leb left right = true \/ position_leb right left = true.
Proof.
  destruct (position_leb left right) eqn:forward.
  - left. reflexivity.
  - right. apply position_leb_spec.
    destruct (Nat.le_ge_cases (fst left) (fst right)) as [le | ge].
    + rewrite (proj2 (position_leb_spec left right) le) in forward. discriminate.
    + exact ge.
Qed.

Lemma entry_leb_trans :
  forall x y z : nat * nat,
    entry_leb x y = true -> entry_leb y z = true -> entry_leb x z = true.
Proof.
  intros x y z xy yz.
  apply entry_leb_spec in xy. apply entry_leb_spec in yz. apply entry_leb_spec.
  destruct xy as [less | [equal le]]; destruct yz as [less' | [equal' le']];
    [left; lia | left; lia | left; lia | right; split; lia].
Qed.

Lemma position_leb_trans :
  forall {B : Type} (x y z : nat * B),
    position_leb x y = true -> position_leb y z = true -> position_leb x z = true.
Proof.
  intros B x y z xy yz.
  apply position_leb_spec in xy. apply position_leb_spec in yz.
  apply position_leb_spec. lia.
Qed.

Lemma entry_leb_address (left right : nat * nat) :
  entry_leb left right = true -> fst left <= fst right.
Proof. intro bound. apply entry_leb_spec in bound. lia. Qed.



Definition entry_sort (l : list (nat * nat)) : list (nat * nat) :=
  @msort (nat * nat) entry_leb l.

Definition position_sort {B : Type} (l : list (nat * B)) : list (nat * B) :=
  @msort (nat * B) (@position_leb B) l.

Lemma entry_sort_sorted (l : list (nat * nat)) :
  Sorted (fun left right : nat * nat => entry_leb left right = true)
         (entry_sort l).
Proof. exact (@msort_sorted (nat * nat) entry_leb entry_leb_total entry_leb_trans l). Qed.

Lemma entry_sort_permutation (l : list (nat * nat)) :
  Permutation l (entry_sort l).
Proof. exact (@msort_permutation (nat * nat) entry_leb l). Qed.

Lemma position_sort_sorted {B : Type} (l : list (nat * B)) :
  Sorted (fun left right : nat * B => position_leb left right = true)
         (position_sort l).
Proof. exact (@msort_sorted (nat * B) (@position_leb B) (@position_leb_total B) (@position_leb_trans B) l). Qed.

Lemma position_sort_permutation {B : Type} (l : list (nat * B)) :
  Permutation l (position_sort l).
Proof. exact (@msort_permutation (nat * B) (@position_leb B) l). Qed.

(* ================================================================== *)
(* Bulk access                                                        *)
(* ================================================================== *)

(* A bulk request reads or writes one cell per coordinate.  Doing that
   pointwise costs O(k*n) because [read_buffer_cell] walks the cell list from
   its head; the implementation below instead sorts the requested addresses,
   walks the cells once and puts the answers back in coordinate order.  It is
   the only implementation: [read_pointwise] / [write_pointwise] above are the
   specification, and [read_coordinates_correct] / [write_coordinates_correct]
   state that the implementation returns exactly what they do. *)

(* ------------------------------------------------------------------ *)
(* Sign-magnitude address arithmetic                                   *)
(* ------------------------------------------------------------------ *)

(* [view_cell_offset] adds [Z.of_nat index * stride] once per axis.  [Z.of_nat]
   costs time proportional to the number it encodes, so computing k addresses
   that way is quadratic in the address magnitude, and that dominates
   everything else for a large range.  The implementation therefore carries the
   address as a sign and a [nat] magnitude: every step is O(1) [nat]
   arithmetic, and a negative address is just a sign bit rather than a reason
   to run a different computation.  There is exactly one arithmetic path here;
   [coordinate_target] is the only place that interprets the sign, and it makes
   the same decision [read_buffer_cell] makes for a [Zneg] address.

   Extraction caveat: [Extract.v] maps [nat] to the OCaml [int], so these
   magnitudes are exact only below 2^62, while the [Z] specification above is
   unbounded.  This is unreachable through [handle_effect] -- [Reinterpret]
   validates descriptors in [Z] and every address term is non-negative, so an
   accepted address is below the cell-list length -- but a direct caller of the
   exported [read_coordinates] / [write_coordinates] with an offset or stride
   of 2^62 or more would wrap where the model does not. *)

Definition magnitude_of_z (z : Z) : bool * nat :=
  match z with
  | Z0 => (false, 0)
  | Zpos positive => (false, Pos.to_nat positive)
  | Zneg positive => (true, Pos.to_nat positive)
  end.

Definition signed_value (signed : bool * nat) : Z :=
  if fst signed then Z.opp (Z.of_nat (snd signed)) else Z.of_nat (snd signed).

(* A zero magnitude has no sign, so every value built below is normalised. *)
Definition signed_normal (signed : bool * nat) : bool * nat :=
  if Nat.eqb (snd signed) 0 then (false, 0) else signed.

Definition signed_add (left right : bool * nat) : bool * nat :=
  signed_normal
    (if Bool.eqb (fst left) (fst right) then
       (fst left, snd left + snd right)
     else if Nat.leb (snd right) (snd left) then
       (fst left, snd left - snd right)
     else (fst right, snd right - snd left)).

Definition signed_scale (index : nat) (signed : bool * nat) : bool * nat :=
  signed_normal (fst signed, index * snd signed).

Fixpoint signed_offset (acc : bool * nat) (strides : list Z)
    (indices : list nat) : option (bool * nat) :=
  match strides, indices with
  | [], [] => Some (signed_normal acc)
  | stride :: strides', index :: indices' =>
      signed_offset
        (signed_add acc (signed_scale index (magnitude_of_z stride)))
        strides' indices'
  | _, _ => None
  end.

Definition signed_view_cell_offset (offset : Z) (strides : list Z)
    (coordinate : list nat) : option (bool * nat) :=
  signed_offset (magnitude_of_z offset) strides coordinate.

Lemma magnitude_of_z_value (z : Z) : signed_value (magnitude_of_z z) = z.
Proof.
  destruct z as [|positive|positive];
    cbn [magnitude_of_z signed_value fst snd].
  - reflexivity.
  - rewrite positive_nat_Z. reflexivity.
  - rewrite positive_nat_Z. reflexivity.
Qed.

Lemma signed_normal_value (signed : bool * nat) :
  signed_value (signed_normal signed) = signed_value signed.
Proof.
  destruct signed as [negative magnitude].
  unfold signed_normal. cbn [fst snd].
  destruct (Nat.eqb magnitude 0) eqn:zero.
  - apply Nat.eqb_eq in zero. subst magnitude.
    destruct negative; reflexivity.
  - reflexivity.
Qed.

Lemma signed_normal_negative (signed : bool * nat) :
  fst (signed_normal signed) = true -> snd (signed_normal signed) > 0.
Proof.
  destruct signed as [negative magnitude].
  unfold signed_normal. cbn [fst snd].
  destruct (Nat.eqb magnitude 0) eqn:zero; cbn [fst snd].
  - discriminate.
  - intro. apply Nat.eqb_neq in zero. lia.
Qed.

Lemma signed_add_value (left right : bool * nat) :
  signed_value (signed_add left right)
  = (signed_value left + signed_value right)%Z.
Proof.
  destruct left as [left_negative left_magnitude],
    right as [right_negative right_magnitude].
  unfold signed_add.
  rewrite signed_normal_value.
  destruct (Bool.eqb left_negative right_negative) eqn:same.
  - (* the two signs agree, so the magnitudes add *)
    destruct left_negative, right_negative; cbn [eqb] in same;
      try discriminate same; cbn [Bool.eqb fst snd signed_value].
    + rewrite Nat2Z.inj_add. ring.
    + rewrite Nat2Z.inj_add. ring.
  - (* the signs differ, so the smaller magnitude is subtracted *)
    destruct left_negative, right_negative; cbn [eqb] in same;
      try discriminate same; cbn [Bool.eqb fst snd].
    + destruct (Nat.leb right_magnitude left_magnitude) eqn:cmp;
        cbn [signed_value fst snd].
      * apply Nat.leb_le in cmp.
        rewrite (Nat2Z.inj_sub left_magnitude right_magnitude) by lia. ring.
      * assert (le : left_magnitude <= right_magnitude).
        { destruct (Nat.le_ge_cases left_magnitude right_magnitude) as [bound|bound];
            [exact bound | exfalso; apply Nat.leb_le in bound;
                           rewrite bound in cmp; discriminate cmp]. }
        rewrite (Nat2Z.inj_sub right_magnitude left_magnitude) by lia. ring.
    + destruct (Nat.leb right_magnitude left_magnitude) eqn:cmp;
        cbn [signed_value fst snd].
      * apply Nat.leb_le in cmp.
        rewrite (Nat2Z.inj_sub left_magnitude right_magnitude) by lia. ring.
      * assert (le : left_magnitude <= right_magnitude).
        { destruct (Nat.le_ge_cases left_magnitude right_magnitude) as [bound|bound];
            [exact bound | exfalso; apply Nat.leb_le in bound;
                           rewrite bound in cmp; discriminate cmp]. }
        rewrite (Nat2Z.inj_sub right_magnitude left_magnitude) by lia. ring.
Qed.

Lemma signed_scale_value (index : nat) (signed : bool * nat) :
  signed_value (signed_scale index signed)
  = (Z.of_nat index * signed_value signed)%Z.
Proof.
  destruct signed as [negative magnitude].
  unfold signed_scale. rewrite signed_normal_value.
  destruct negative; cbn [fst snd signed_value].
  - rewrite Nat2Z.inj_mul. ring.
  - rewrite Nat2Z.inj_mul. ring.
Qed.

Lemma signed_offset_some :
  forall (strides : list Z) (indices : list nat) (acc : bool * nat)
    (result : bool * nat),
    signed_offset acc strides indices = Some result ->
    view_cell_offset (signed_value acc) strides indices = Ok (signed_value result).
Proof.
  induction strides as [|stride strides' IH]; intros indices acc result step.
  - destruct indices as [|index indices'].
    + cbn [signed_offset] in step. injection step as same. subst result.
      cbn [view_cell_offset]. rewrite signed_normal_value. reflexivity.
    + cbn [signed_offset] in step. discriminate step.
  - destruct indices as [|index indices'].
    + cbn [signed_offset] in step. discriminate step.
    + cbn [signed_offset] in step.
      specialize (IH indices'
        (signed_add acc (signed_scale index (magnitude_of_z stride))) result step).
      rewrite signed_add_value, signed_scale_value, magnitude_of_z_value in IH.
      cbn [view_cell_offset]. exact IH.
Qed.

Lemma signed_offset_none :
  forall (strides : list Z) (indices : list nat) (acc : bool * nat),
    signed_offset acc strides indices = None ->
    view_cell_offset (signed_value acc) strides indices = Error InvalidViewRank.
Proof.
  induction strides as [|stride strides' IH]; intros indices acc step.
  - destruct indices as [|index indices']; cbn [signed_offset] in step.
    + discriminate step.
    + cbn [view_cell_offset]. reflexivity.
  - destruct indices as [|index indices']; cbn [signed_offset] in step.
    + cbn [view_cell_offset]. reflexivity.
    + specialize (IH indices'
        (signed_add acc (signed_scale index (magnitude_of_z stride))) step).
      rewrite signed_add_value, signed_scale_value, magnitude_of_z_value in IH.
      cbn [view_cell_offset]. exact IH.
Qed.

Lemma signed_offset_normalised :
  forall (strides : list Z) (indices : list nat) (acc result : bool * nat),
    signed_offset acc strides indices = Some result ->
    fst result = true -> snd result > 0.
Proof.
  induction strides as [|stride strides' IH]; intros indices acc result step.
  - destruct indices as [|index indices'].
    + cbn [signed_offset] in step. injection step as same. subst result.
      apply signed_normal_negative.
    + cbn [signed_offset] in step. discriminate step.
  - destruct indices as [|index indices'].
    + cbn [signed_offset] in step. discriminate step.
    + cbn [signed_offset] in step.
      exact (IH indices'
        (signed_add acc (signed_scale index (magnitude_of_z stride))) result step).
Qed.

(* The reference behaviour, spelled out on [Z]: this is what the pointwise path
   does, and it is what [coordinate_target] has to reproduce. *)
Definition coordinate_target_z (offset : Z) (strides : list Z)
    (coordinate : list nat) : result memory_error nat :=
  match view_cell_offset offset strides coordinate with
  | Ok address =>
      if Z.leb 0%Z address then Ok (Z.to_nat address)
      else Error ViewAddressOutOfBounds
  | Error error => Error error
  end.

Definition coordinate_target (offset : Z) (strides : list Z)
    (coordinate : list nat) : result memory_error nat :=
  match signed_view_cell_offset offset strides coordinate with
  | None => Error InvalidViewRank
  | Some (negative, magnitude) =>
      if negative then Error ViewAddressOutOfBounds else Ok magnitude
  end.

Lemma z_leb_opp_of_nat (magnitude : nat) :
  magnitude > 0 -> Z.leb 0%Z (Z.opp (Z.of_nat magnitude)) = false.
Proof.
  intro positive.
  destruct magnitude as [|magnitude']; [lia|].
  cbn [Z.of_nat Z.opp]. reflexivity.
Qed.

Lemma z_leb_zero_of_nat (magnitude : nat) :
  Z.leb 0%Z (Z.of_nat magnitude) = true.
Proof. destruct magnitude; reflexivity. Qed.

Lemma coordinate_target_eq_z (offset : Z) (strides : list Z)
    (coordinate : list nat) :
  coordinate_target offset strides coordinate
  = coordinate_target_z offset strides coordinate.
Proof.
  unfold coordinate_target, coordinate_target_z, signed_view_cell_offset.
  destruct (signed_offset (magnitude_of_z offset) strides coordinate)
    as [[negative magnitude]|] eqn:step.
  - assert (hit : view_cell_offset offset strides coordinate
                  = Ok (signed_value (negative, magnitude))).
    { replace offset with (signed_value (magnitude_of_z offset))
        by (apply magnitude_of_z_value).
      exact (@signed_offset_some strides coordinate (magnitude_of_z offset)
               (negative, magnitude) step). }
    rewrite hit.
    destruct negative; cbn [fst snd signed_value].
    + assert (positive : magnitude > 0)
        by (apply (@signed_offset_normalised strides coordinate
                     (magnitude_of_z offset) (true, magnitude) step); reflexivity).
      rewrite z_leb_opp_of_nat by exact positive. reflexivity.
    + rewrite z_leb_zero_of_nat, Nat2Z.id. reflexivity.
  - assert (miss : view_cell_offset offset strides coordinate
                  = Error InvalidViewRank).
    { replace offset with (signed_value (magnitude_of_z offset))
        by (apply magnitude_of_z_value).
      exact (@signed_offset_none strides coordinate (magnitude_of_z offset) step). }
    rewrite miss. reflexivity.
Qed.

Definition cell_value {Value} (cell : memory_cell Value)
    : result memory_error Value :=
  match cell with
  | Uninitialized => Error ReadUninitializedCell
  | Initialized value => Ok value
  end.

Lemma read_step_bind_z {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinate : list nat)
    (next : Value -> result memory_error (list Value)) :
  (address <-? view_cell_offset offset strides coordinate ;;
   value <-? read_buffer_cell storage address ;;
   next value)
  = match coordinate_target_z offset strides coordinate with
    | Ok target => value <-? cell_at (buffer_cells storage) target ;; next value
    | Error error => Error error
    end.
Proof.
  unfold coordinate_target_z.
  destruct (view_cell_offset offset strides coordinate) as [address|error]; cbn.
  - destruct (Z.leb 0 address) eqn:bound.
    + apply Z.leb_le in bound.
      rewrite read_buffer_cell_nonnegative by exact bound. reflexivity.
    + assert (negative : (address < 0)%Z).
      { apply Z.nle_gt. intro nonnegative.
        rewrite (proj2 (Z.leb_le 0%Z address) nonnegative) in bound. discriminate. }
      destruct address as [|positive|positive]; cbn in *; try lia.
      reflexivity.
  - reflexivity.
Qed.

Lemma read_step_bind {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinate : list nat)
    (next : Value -> result memory_error (list Value)) :
  (address <-? view_cell_offset offset strides coordinate ;;
   value <-? read_buffer_cell storage address ;;
   next value)
  = match coordinate_target offset strides coordinate with
    | Ok target => value <-? cell_at (buffer_cells storage) target ;; next value
    | Error error => Error error
    end.
Proof.
  rewrite coordinate_target_eq_z. apply read_step_bind_z.
Qed.

(* ------------------------------------------------------------------ *)
(* The one-pass walk                                                  *)
(* ------------------------------------------------------------------ *)

Definition entry_le (left right : nat * nat) : Prop := entry_leb left right = true.


(* Every entry after the head of a sorted list addresses a cell at least as far
   along as the head does. *)
Lemma sorted_entry_head :
  forall (a : nat * nat) (rest : list (nat * nat)),
    Sorted entry_le (a :: rest) -> forall e, In e rest -> fst a <= fst e.
Proof.
  intros a rest. revert a. induction rest as [|head tail IH];
    intros a sorted e inside.
  - destruct inside.
  - apply Sorted_inv in sorted. destruct sorted as [sorted_tail head_rel].
    apply HdRel_inv in head_rel.
    assert (a_head : fst a <= fst head)
      by (apply (entry_leb_address a head); exact head_rel).
    destruct inside as [same | later].
    + subst e. exact a_head.
    + assert (head_e : fst head <= fst e) by (apply (IH head sorted_tail e later)). lia.
Qed.

(* Walk the cell list once, in increasing address order, emitting one result
   per entry in the order the entries are given.  [entries] must be sorted by
   address and every address must be reachable from [cursor].  The walk keeps
   the cell it landed on, so several entries may address the same cell: reading
   it again is free and keeps the walk one-pass. *)
Fixpoint read_walk {Value} (cells : list (memory_cell Value)) (cursor : nat)
    (entries : list (nat * nat)) : list (nat * result memory_error Value) :=
  match entries with
  | [] => []
  | (target, index) :: rest =>
      if Nat.leb cursor target then
        match skipn (target - cursor) cells with
        | [] => (index, Error ViewAddressOutOfBounds) :: read_walk [] target rest
        | cell :: cells' =>
            (index, cell_value cell) :: read_walk (cell :: cells') target rest
        end
      else (index, Error ViewAddressOutOfBounds) :: read_walk cells cursor rest
  end.

(* Reading a sorted batch is the same as reading each address on its own: the
   walk's remaining cells are always a suffix of the original list, starting at
   the address it has reached. *)
Lemma read_walk_correct {Value} :
  forall (all : list (memory_cell Value)) cursor entries,
    Sorted entry_le entries ->
    (forall entry, In entry entries -> cursor <= fst entry) ->
    read_walk (skipn cursor all) cursor entries
    = map (fun entry => (snd entry, cell_at all (fst entry))) entries.
Proof.
  intros all cursor entries. revert all cursor.
  induction entries as [|entry rest IH]; intros all cursor sorted bound.
  - reflexivity.
  - destruct entry as [target index].
    assert (le_target : cursor <= target)
      by (exact (bound (target, index) (or_introl eq_refl))).
    assert (sorted_rest : Sorted entry_le rest) by (apply (proj1 (Sorted_inv sorted))).
    assert (later : forall e, In e rest -> target <= fst e).
    { intros e inside. exact (sorted_entry_head sorted e inside). }
    cbn [read_walk map fst snd].
    rewrite (proj2 (Nat.leb_le cursor target)) by exact le_target.
    assert (skip_twice : skipn (target - cursor) (skipn cursor all) = skipn target all).
    { rewrite skipn_skipn. replace (target - cursor + cursor) with target by lia.
      reflexivity. }
    rewrite skip_twice.
    destruct (skipn target all) as [|cell cells'] eqn:skipped.
    + assert (beyond : length all <= target).
      { apply nth_error_None. replace target with (target + 0) by lia.
        rewrite <- (nth_error_skipn target all 0). rewrite skipped. reflexivity. }
      assert (empty : cell_at all target = Error ViewAddressOutOfBounds).
      { unfold cell_at. apply nth_error_None in beyond. rewrite beyond. reflexivity. }
      rewrite empty. cbn [map fst snd].
      assert (recursor : read_walk [] target rest
                        = map (fun e => (snd e, cell_at all (fst e))) rest).
      { rewrite <- skipped. apply IH.
        - exact sorted_rest.
        - exact later. }
      rewrite recursor. reflexivity.
    + assert (nth : nth_error all target = Some cell).
      { replace target with (target + 0) by lia.
        rewrite <- (nth_error_skipn target all 0). rewrite skipped. reflexivity. }
      assert (hit : cell_at all target = cell_value cell).
      { unfold cell_at. rewrite nth. reflexivity. }
      rewrite hit. cbn [map fst snd].
      f_equal. rewrite <- skipped. apply IH.
      * exact sorted_rest.
      * exact later.
Qed.


(* ------------------------------------------------------------------ *)
(* Bulk read                                                          *)
(* ------------------------------------------------------------------ *)

(* Sequence a list of per-coordinate results: the first error wins and the
   values are collected in coordinate order. *)
Fixpoint sequence_results {Value} (results : list (result memory_error Value))
    : result memory_error (list Value) :=
  match results with
  | [] => Ok []
  | result :: rest =>
      value <-? result ;;
      values <-? sequence_results rest ;;
      Ok (value :: values)
  end.

Definition answer_of {Value} (cells : list (memory_cell Value))
    (target : result memory_error nat) : result memory_error Value :=
  match target with
  | Ok address => cell_at cells address
  | Error error => Error error
  end.

Definition answer_at {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinate : list nat) : result memory_error Value :=
  answer_of (buffer_cells storage) (coordinate_target offset strides coordinate).

Definition entry_answer {Value} (storage : buffer Value)
    (entry : result memory_error nat * nat) : nat * result memory_error Value :=
  (snd entry, answer_of (buffer_cells storage) (fst entry)).

Lemma entry_answer_eq {Value} (storage : buffer Value)
    (entry : result memory_error nat * nat) :
  entry_answer storage entry
  = (snd entry, answer_of (buffer_cells storage) (fst entry)).
Proof. destruct entry. reflexivity. Qed.

(* Split the per-coordinate targets into the ones that address a cell and the
   ones that report an error before touching any cell.  Both halves keep the
   coordinate order they had. *)
Fixpoint split_targets (entries : list (result memory_error nat * nat))
    : list (nat * nat) * list (result memory_error nat * nat) :=
  match entries with
  | [] => ([], [])
  | (Ok target, index) :: rest =>
      let '(good, bad) := split_targets rest in
      ((target, index) :: good, bad)
  | (Error error, index) :: rest =>
      let '(good, bad) := split_targets rest in
      (good, (Error error, index) :: bad)
  end.

Definition split_answer {Value} (storage : buffer Value)
    (halves : list (nat * nat) * list (result memory_error nat * nat))
    : list (nat * result memory_error Value) :=
  map (fun pair => (snd pair, answer_of (buffer_cells storage) (Ok (fst pair))))
      (fst halves)
  ++ map (entry_answer storage) (snd halves).

Lemma split_targets_permutation {Value} (storage : buffer Value)
    (entries : list (result memory_error nat * nat)) :
  Permutation (map (entry_answer storage) entries)
              (split_answer storage (split_targets entries)).
Proof.
  induction entries as [|entry rest IH].
  - cbn [split_targets split_answer map app]. apply Permutation_refl.
  - destruct entry as [target index]. destruct target as [address|error].
    + cbn [split_targets]. destruct (split_targets rest) as [good bad].
      cbn [split_answer map entry_answer fst snd] in *.
      apply Permutation_cons.
      * reflexivity.
      * exact IH.
    + cbn [split_targets]. destruct (split_targets rest) as [good bad].
      cbn [split_answer map entry_answer fst snd] in *.
      eapply Permutation_trans.
      * apply Permutation_cons.
        -- reflexivity.
        -- exact IH.
      * apply Permutation_cons_app. apply Permutation_refl.
Qed.

(* ------------------------------------------------------------------ *)
(* List plumbing                                                      *)
(* ------------------------------------------------------------------ *)

Lemma firstn_all_self {A : Type} (n : nat) (l : list A) :
  length l <= n -> firstn n l = l.
Proof.
  revert n. induction l as [|head tail IH]; intros n bound.
  - destruct n; reflexivity.
  - destruct n as [|n]; cbn [firstn].
    + cbn in bound. lia.
    + f_equal. apply IH. cbn in bound. lia.
Qed.

Lemma map_fst_combine {A B : Type} (l1 : list A) (l2 : list B) :
  map fst (combine l1 l2) = firstn (length l2) l1.
Proof.
  revert l2. induction l1 as [|head tail IH]; intros l2.
  - destruct l2; reflexivity.
  - destruct l2 as [|first rest]; cbn [combine map length firstn].
    + reflexivity.
    + f_equal. apply IH.
Qed.

Lemma firstn_seq (start n m : nat) :
  n <= m -> firstn n (seq start m) = seq start n.
Proof.
  revert m start. induction n as [|n IH]; intros m start bound.
  - reflexivity.
  - destruct m as [|m]; cbn [seq firstn].
    + cbn in bound. lia.
    + f_equal. apply IH. cbn in bound. lia.
Qed.

Lemma map_snd_combine {A B : Type} (l1 : list A) (l2 : list B) :
  map snd (combine l1 l2) = firstn (length l1) l2.
Proof.
  revert l2. induction l1 as [|head tail IH]; intros l2.
  - reflexivity.
  - destruct l2 as [|first rest]; cbn [combine map length firstn].
    + reflexivity.
    + f_equal. apply IH.
Qed.


Lemma map_combine_position {A B : Type} (f : A -> B) (l : list A) (start k : nat) :
  map (fun pair => (snd pair, f (fst pair))) (combine l (seq start k))
  = combine (seq start k) (map f l).
Proof.
  revert k start. induction l as [|head tail IH]; intros k start.
  - destruct k; reflexivity.
  - destruct k as [|k]; cbn [seq combine map].
    + reflexivity.
    + f_equal. apply IH.
Qed.

Lemma combine_seq_left_fst_ge {A : Type} (l : list A) (start k : nat) :
  forall pair, In pair (combine (seq start k) l) -> start <= fst pair.
Proof.
  revert l start. induction k as [|k IH]; intros l start pair inside.
  - cbn [seq combine] in inside. destruct inside.
  - destruct l as [|head tail]; cbn [seq combine] in inside.
    + destruct inside.
    + destruct inside as [same | later].
      * subst pair. cbn [fst]. lia.
      * pose proof (IH tail (S start) pair later) as bound. cbn [fst] in bound. lia.
Qed.

(* Positions come out of [seq], so the canonical order is sorted. *)
Lemma sorted_combine_seq {A : Type} (l : list A) (start k : nat) :
  Sorted (fun left right : nat * A => position_leb left right = true)
          (combine (seq start k) l).
Proof.
  revert l start. induction k as [|k IH]; intros l start.
  - cbn [seq combine]. constructor.
  - destruct l as [|head tail]; cbn [seq combine].
    + constructor.
    + constructor.
      * apply IH.
      * destruct (combine (seq (S start) k) tail) as [|next rest] eqn:skipped.
        -- constructor.
        -- apply HdRel_cons. apply position_leb_spec.
           assert (inside : In next (combine (seq (S start) k) tail)).
           { rewrite skipped. left. reflexivity. }
           pose proof (combine_seq_left_fst_ge tail (S start) k next inside)
             as bound.
           cbn [fst] in bound. cbn [fst].
           lia.
Qed.

(* ------------------------------------------------------------------ *)
(* Sorted permutations are unique                                     *)
(* ------------------------------------------------------------------ *)

Lemma sorted_head_rel {A : Type} (R : A -> A -> Prop) :
  (forall x y z, R x y -> R y z -> R x z) ->
  forall (a : A) (l : list A), Sorted R (a :: l) -> forall x, In x l -> R a x.
Proof.
  intros trans a l. revert a.
  induction l as [|head tail IH]; intros a sorted x inside.
  - destruct inside.
  - apply Sorted_inv in sorted. destruct sorted as [sorted_tail head_rel].
    apply HdRel_inv in head_rel.
    destruct inside as [same | later].
    + subst x. exact head_rel.
    + assert (head_x : R head x) by (apply (IH head sorted_tail x later)).
      exact (trans a head x head_rel head_x).
Qed.
Arguments sorted_head_rel {A} R _ _ _ _ _ _.

Lemma in_map_of_key_eq {A K : Type} (key : A -> K) (l : list A) (x y : A) :
  In x l -> key x = key y -> In (key y) (map key l).
Proof.
  revert y. induction l as [|head tail IH]; intros y inside same.
  - destruct inside.
  - destruct inside as [equal | later].
    + left. rewrite equal. exact same.
    + right. apply IH; assumption.
Qed.

(* Two sorted lists that are permutations of each other and whose keys are
   distinct are the same list: the key decides the position and the position
   decides the element. *)
Lemma sorted_permutation_unique :
  forall (A K : Type) (key : A -> K) (le : K -> K -> Prop),
    (forall x, le x x) ->
    (forall x y, le x y -> le y x -> x = y) ->
    (forall x y z, le x y -> le y z -> le x z) ->
    forall l1 l2,
      Sorted (fun left right => le (key left) (key right)) l1 ->
      Sorted (fun left right => le (key left) (key right)) l2 ->
      List.NoDup (map key l1) ->
      Permutation l1 l2 ->
      l1 = l2.
Proof.
  intros A K key le refl antisym trans l1.
  induction l1 as [|first rest IH]; intros l2 sorted1 sorted2 nodup perm.
  - apply Permutation_nil in perm. symmetry. exact perm.
  - destruct l2 as [|other tail].
    + exfalso. pose proof (Permutation_nil (Permutation_sym perm)) as empty.
      discriminate empty.
    + assert (first_in : In first (other :: tail)).
      { apply Permutation_in with (l := first :: rest);
        [exact perm | left; reflexivity]. }
      assert (other_in : In other (first :: rest)).
      { apply Permutation_in with (l := other :: tail);
        [apply Permutation_sym; exact perm | left; reflexivity]. }
      assert (trans_key : forall x y z,
        le (key x) (key y) -> le (key y) (key z) -> le (key x) (key z)).
      { intros x y z xy yz. exact (trans (key x) (key y) (key z) xy yz). }
      assert (forward : le (key first) (key other)).
      { destruct other_in as [same | later].
        - subst other. apply refl.
        - exact (sorted_head_rel (fun left right => le (key left) (key right))
                   trans_key first rest sorted1 other later). }
      assert (backward : le (key other) (key first)).
      { destruct first_in as [same | later].
        - subst other. apply refl.
        - exact (sorted_head_rel (fun left right => le (key left) (key right))
                   trans_key other tail sorted2 first later). }
      assert (same_key : key first = key other) by (apply antisym; assumption).
      assert (same : first = other).
      { destruct other_in as [equal | later].
        - exact equal.
        - exfalso.
          assert (inside : In (key first) (map key rest)).
          { apply (@in_map_of_key_eq _ _ key rest other first later). symmetry.
            exact same_key. }
          change (List.NoDup (key first :: map key rest)) in nodup.
          inversion nodup as [| ? ? notin keep]; subst.
          exact (notin inside). }
      subst other.
      apply Sorted_inv in sorted1. destruct sorted1 as [sorted1 _].
      apply Sorted_inv in sorted2. destruct sorted2 as [sorted2 _].
      change (List.NoDup (key first :: map key rest)) in nodup.
      inversion nodup as [| ? ? notin keep]; subst.
      f_equal. apply (IH tail sorted1 sorted2 keep).
      apply Permutation_cons_inv in perm. exact perm.
Qed.

Lemma sorted_by_position_unique {A : Type} (l1 l2 : list (nat * A)) :
  Sorted (fun left right : nat * A => position_leb left right = true) l1 ->
  Sorted (fun left right : nat * A => position_leb left right = true) l2 ->
  List.NoDup (map fst l1) ->
  Permutation l1 l2 ->
  l1 = l2.
Proof.
  intros sorted1 sorted2 nodup perm.
  eapply (@sorted_permutation_unique (nat * A) nat fst (fun x y => Nat.leb x y = true)).
  - intros x. apply Nat.leb_refl.
  - intros x y xy yx. apply Nat.leb_le in xy. apply Nat.leb_le in yx. lia.
  - intros x y z xy yz. apply Nat.leb_le in xy. apply Nat.leb_le in yz.
    apply Nat.leb_le. lia.
  - exact sorted1.
  - exact sorted2.
  - exact nodup.
  - exact perm.
Qed.


(* ------------------------------------------------------------------ *)
(* The bulk reader                                                    *)
(* ------------------------------------------------------------------ *)

(* The per-coordinate targets, in coordinate order, paired with the position
   that identifies the coordinate. *)
Definition read_entries (offset : Z) (strides : list Z)
    (coordinates : list (list nat)) : list (result memory_error nat * nat) :=
  combine (map (coordinate_target offset strides) coordinates)
          (seq 0 (length coordinates)).

Definition read_good (offset : Z) (strides : list Z) (coordinates : list (list nat))
    : list (nat * nat) :=
  fst (split_targets (read_entries offset strides coordinates)).

Definition read_bad (offset : Z) (strides : list Z) (coordinates : list (list nat))
    : list (result memory_error nat * nat) :=
  snd (split_targets (read_entries offset strides coordinates)).

Definition read_walked {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat))
    : list (nat * result memory_error Value) :=
  read_walk (buffer_cells storage) 0 (entry_sort (read_good offset strides coordinates)).

Definition read_results {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat))
    : list (nat * result memory_error Value) :=
  read_walked storage offset strides coordinates
  ++ map (entry_answer storage) (read_bad offset strides coordinates).

Definition read_coordinates {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat))
    : result memory_error (list Value) :=
  sequence_results
    (map snd (position_sort (read_results storage offset strides coordinates))).

Lemma read_split (offset : Z) (strides : list Z) (coordinates : list (list nat)) :
  split_targets (read_entries offset strides coordinates)
  = (read_good offset strides coordinates, read_bad offset strides coordinates).
Proof.
  unfold read_good, read_bad.
  destruct (split_targets (read_entries offset strides coordinates)). reflexivity.
Qed.

(* The walk reads every entry of the address-sorted half. *)
Lemma read_walked_spec {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) :
  read_walked storage offset strides coordinates
  = map (fun pair => (snd pair, answer_of (buffer_cells storage) (Ok (fst pair))))
        (entry_sort (read_good offset strides coordinates)).
Proof.
  unfold read_walked.
  exact (@read_walk_correct Value (buffer_cells storage) 0
           (entry_sort (read_good offset strides coordinates))
           (entry_sort_sorted (read_good offset strides coordinates))
           (fun entry inside => Nat.le_0_l (fst entry))).
Qed.

(* The results are the answers of the entries, in some order. *)
Lemma read_results_permutation {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) :
  Permutation (read_results storage offset strides coordinates)
              (map (entry_answer storage) (read_entries offset strides coordinates)).
Proof.
  pose proof (split_targets_permutation storage (read_entries offset strides coordinates))
    as perm.
  rewrite read_split in perm. unfold split_answer in perm. cbn [fst snd] in perm.
  unfold read_results. rewrite read_walked_spec.
  eapply Permutation_trans.
  - apply Permutation_app.
    + apply Permutation_map. apply Permutation_sym. apply entry_sort_permutation.
    + apply Permutation_refl.
  - apply Permutation_sym. exact perm.
Qed.

Lemma read_entry_answers {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) :
  map (entry_answer storage) (read_entries offset strides coordinates)
  = combine (seq 0 (length coordinates))
            (map (answer_of (buffer_cells storage))
                 (map (coordinate_target offset strides) coordinates)).
Proof.
  unfold read_entries.
  rewrite <- (map_combine_position (answer_of (buffer_cells storage))
                 (map (coordinate_target offset strides) coordinates)
                 0 (length coordinates)).
  apply map_ext. intros [target index]. cbn [fst snd]. rewrite entry_answer_eq.
  reflexivity.
Qed.

Lemma read_entry_answers_sorted {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) :
  Sorted (fun left right : nat * result memory_error Value => position_leb left right = true)
          (map (entry_answer storage) (read_entries offset strides coordinates)).
Proof.
  rewrite read_entry_answers. apply sorted_combine_seq.
Qed.

Lemma length_read_entries (offset : Z) (strides : list Z)
    (coordinates : list (list nat)) :
  length (read_entries offset strides coordinates) = length coordinates.
Proof.
  unfold read_entries. rewrite length_combine.
  rewrite length_map, length_seq.
  lia.
Qed.

Lemma read_entry_positions {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) :
  map fst (map (entry_answer storage) (read_entries offset strides coordinates))
  = seq 0 (length coordinates).
Proof.
  rewrite map_map.
  transitivity (map snd (read_entries offset strides coordinates)).
  { apply map_ext. intros [target index]. cbn [fst snd]. reflexivity. }
  unfold read_entries. rewrite map_snd_combine.
  rewrite length_map. rewrite firstn_seq by lia. reflexivity.
Qed.

Lemma read_entry_answers_nodup {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) :
  List.NoDup
    (map fst (map (entry_answer storage) (read_entries offset strides coordinates))).
Proof.
  rewrite read_entry_positions. apply seq_NoDup.
Qed.

(* The second sort restores coordinate order. *)
Lemma read_position_sort {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) :
  position_sort (read_results storage offset strides coordinates)
  = map (entry_answer storage) (read_entries offset strides coordinates).
Proof.
  apply sorted_by_position_unique.
  - apply position_sort_sorted.
  - apply read_entry_answers_sorted.
  - apply (Permutation_NoDup
             (Permutation_map fst
                (Permutation_trans
                   (Permutation_sym
                      (read_results_permutation storage offset strides coordinates))
                   (position_sort_permutation
                      (read_results storage offset strides coordinates))))).
    apply read_entry_answers_nodup.
  - eapply Permutation_trans.
    + apply Permutation_sym. apply position_sort_permutation.
    + apply read_results_permutation.
Qed.

Lemma read_answers {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) :
  map snd (map (entry_answer storage) (read_entries offset strides coordinates))
  = map (answer_at storage offset strides) coordinates.
Proof.
  rewrite map_map.
  transitivity
    (map (fun entry : result memory_error nat * nat =>
            answer_of (buffer_cells storage) (fst entry))
         (read_entries offset strides coordinates)).
  { apply map_ext. intros [target index]. cbn [fst snd]. rewrite entry_answer_eq.
    reflexivity. }
  rewrite <- map_map.
  unfold read_entries. rewrite map_fst_combine. rewrite length_seq.
  rewrite (@firstn_all_self _ (length coordinates)
             (map (coordinate_target offset strides) coordinates))
    by (rewrite length_map; lia).
  rewrite map_map. apply map_ext. intros coordinate. unfold answer_at. reflexivity.
Qed.

(* The pointwise specification as a list of per-coordinate results. *)
Lemma read_pointwise_results {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) :
  read_pointwise storage offset strides coordinates
  = sequence_results (map (answer_at storage offset strides) coordinates).
Proof.
  induction coordinates as [|coordinate rest IH].
  - reflexivity.
  - cbn [read_pointwise map sequence_results].
    rewrite read_step_bind.
    unfold answer_at, answer_of.
    destruct (coordinate_target offset strides coordinate) as [target|error]; cbn.
    + rewrite IH. reflexivity.
    + reflexivity.
Qed.

Theorem read_coordinates_correct :
  forall (Value : Type) (storage : buffer Value) offset strides coordinates,
    read_coordinates storage offset strides coordinates
    = read_pointwise storage offset strides coordinates.
Proof.
  intros Value storage offset strides coordinates.
  unfold read_coordinates.
  rewrite read_position_sort.
  rewrite read_answers.
  symmetry. apply read_pointwise_results.
Qed.


(* ------------------------------------------------------------------ *)
(* Bulk write: the cell-level algebra                                 *)
(* ------------------------------------------------------------------ *)

(* A write update: the target cell, the position of the coordinate that asked
   for it, and the value.  The position decides which update wins when several
   coordinates address the same cell. *)
Definition update_target {Value} (update : (nat * nat) * Value) : nat :=
  fst (fst update).
Definition update_position {Value} (update : (nat * nat) * Value) : nat :=
  snd (fst update).
Definition update_value {Value} (update : (nat * nat) * Value) : Value :=
  snd update.

(* One cell replacement.  [replace_nth] fails past the end of the list, and
   then [write_buffer_cell] reports an error; on the success path the write is
   exactly this. *)
Definition replace_cell {Value} (cells : list (memory_cell Value))
    (target : nat) (value : Value) : list (memory_cell Value) :=
  match replace_nth target (Initialized value) cells with
  | Some cells' => cells'
  | None => cells
  end.

(* The sequence of single-cell writes the pointwise specification performs,
   over updates in coordinate order. *)
Fixpoint apply_updates {Value} (cells : list (memory_cell Value))
    (updates : list ((nat * nat) * Value)) : list (memory_cell Value) :=
  match updates with
  | [] => cells
  | update :: rest =>
      apply_updates (replace_cell cells (update_target update) (update_value update)) rest
  end.

(* The value that sequence leaves at [p]: that of the last update targeting
   [p], or nothing if no update targets it. *)
Fixpoint lookup_update {Value} (p : nat) (updates : list ((nat * nat) * Value))
    : option (nat * Value) :=
  match updates with
  | [] => None
  | update :: rest =>
      match lookup_update p rest with
      | Some found => Some found
      | None =>
          if Nat.eqb (update_target update) p
          then Some (update_position update, update_value update)
          else None
      end
  end.

Lemma replace_cell_nil {Value} (target : nat) (value : Value) :
  replace_cell ([] : list (memory_cell Value)) target value = [].
Proof. destruct target; reflexivity. Qed.

Lemma replace_cell_zero {Value} (cell : memory_cell Value)
    (rest : list (memory_cell Value)) (value : Value) :
  replace_cell (cell :: rest) 0 value = Initialized value :: rest.
Proof. reflexivity. Qed.

Lemma replace_cell_succ {Value} (cell : memory_cell Value)
    (rest : list (memory_cell Value)) (target : nat) (value : Value) :
  replace_cell (cell :: rest) (S target) value
  = cell :: replace_cell rest target value.
Proof.
  unfold replace_cell. cbn [replace_nth].
  destruct (replace_nth target (Initialized value) rest) as [rest'|]; reflexivity.
Qed.

Lemma replace_nth_inside {A : Type} (cells : list A) (target : nat) (value : A)
    (cells' : list A) :
  replace_nth target value cells = Some cells' -> target < length cells.
Proof.
  revert cells value cells'.
  induction target as [|previous IH]; intros cells value cells' written.
  - destruct cells as [|cell rest]; cbn [replace_nth] in written; [discriminate|].
    cbn [length]. lia.
  - destruct cells as [|cell rest]; cbn [replace_nth] in written; [discriminate|].
    destruct (replace_nth previous value rest) as [rest'|] eqn:inner;
      [|discriminate].
    pose proof (IH rest value rest' inner) as bound. cbn [length]. lia.
Qed.

Lemma length_replace_nth {A : Type} (cells : list A) (target : nat) (value : A)
    (cells' : list A) :
  replace_nth target value cells = Some cells' -> length cells' = length cells.
Proof.
  revert cells value cells'.
  induction target as [|previous IH]; intros cells value cells' written.
  - destruct cells as [|cell rest]; cbn [replace_nth] in written; [discriminate|].
    injection written as same. subst cells'. reflexivity.
  - destruct cells as [|cell rest]; cbn [replace_nth] in written; [discriminate|].
    destruct (replace_nth previous value rest) as [rest'|] eqn:inner;
      [|discriminate].
    injection written as same. subst cells'. cbn [length].
    rewrite (IH rest value rest' inner). reflexivity.
Qed.

Lemma length_replace_cell {Value} (cells : list (memory_cell Value))
    (target : nat) (value : Value) :
  length (replace_cell cells target value) = length cells.
Proof.
  unfold replace_cell.
  destruct (replace_nth target (Initialized value) cells) as [cells'|] eqn:written.
  - apply length_replace_nth in written. lia.
  - reflexivity.
Qed.

Lemma nth_error_replace_nth {A : Type} (cells : list A) (target : nat) (value : A)
    (cells' : list A) (p : nat) :
  replace_nth target value cells = Some cells' ->
  nth_error cells' p = if Nat.eqb target p then Some value else nth_error cells p.
Proof.
  revert cells value cells' p.
  induction target as [|previous IH]; intros cells value cells' p written.
  - destruct cells as [|cell rest]; cbn [replace_nth] in written; [discriminate|].
    injection written as same. subst cells'. cbn [nth_error].
    destruct (Nat.eqb 0 p) eqn:same_p.
    + apply Nat.eqb_eq in same_p. subst p. reflexivity.
    + destruct p as [|p']; [cbn in same_p; discriminate|]. reflexivity.
  - destruct cells as [|cell rest]; cbn [replace_nth] in written; [discriminate|].
    destruct (replace_nth previous value rest) as [rest'|] eqn:inner;
      [|discriminate].
    injection written as same. subst cells'. cbn [nth_error].
    destruct p as [|p'].
    + cbn [nth_error Nat.eqb]. reflexivity.
    + cbn [nth_error]. rewrite (IH rest value rest' p' inner). reflexivity.
Qed.

Lemma replace_nth_none {A : Type} (cells : list A) (target : nat) (value : A) :
  replace_nth target value cells = None -> length cells <= target.
Proof.
  revert cells value.
  induction target as [|previous IH]; intros cells value failed.
  - destruct cells as [|cell rest]; cbn [replace_nth] in failed.
    + cbn [length]. lia.
    + discriminate failed.
  - destruct cells as [|cell rest]; cbn [replace_nth] in failed.
    + cbn [length]. lia.
    + destruct (replace_nth previous value rest) as [rest'|] eqn:inner.
      * discriminate failed.
      * apply IH in inner. cbn [length]. lia.
Qed.

(* What a single replacement does to each position. *)
Lemma nth_error_replace_cell {Value} (cells : list (memory_cell Value))
    (target : nat) (value : Value) (p : nat) :
  nth_error (replace_cell cells target value) p
  = if Nat.eqb target p
    then (if Nat.ltb p (length cells) then Some (Initialized value)
          else nth_error cells p)
    else nth_error cells p.
Proof.
  unfold replace_cell.
  destruct (replace_nth target (Initialized value) cells) as [cells'|] eqn:written.
  - rewrite (@nth_error_replace_nth _ cells target (Initialized value) cells' p written).
    destruct (Nat.eqb target p) eqn:same.
    + apply Nat.eqb_eq in same. subst p.
      pose proof (@replace_nth_inside _ cells target (Initialized value) cells' written)
        as inside.
      rewrite (proj2 (Nat.ltb_lt target (length cells)) inside). reflexivity.
    + reflexivity.
  - destruct (Nat.eqb target p) eqn:same.
    + apply Nat.eqb_eq in same. subst p.
      pose proof (@replace_nth_none _ cells target (Initialized value) written)
        as bound.
      destruct (Nat.ltb target (length cells)) eqn:inside.
      * apply Nat.ltb_lt in inside. lia.
      * reflexivity.
    + reflexivity.
Qed.

(* Two replacements at different positions commute. *)
Lemma replace_cell_commute {Value} (cells : list (memory_cell Value))
    (target1 : nat) (value1 : Value) (target2 : nat) (value2 : Value) :
  target1 <> target2 ->
  replace_cell (replace_cell cells target1 value1) target2 value2
  = replace_cell (replace_cell cells target2 value2) target1 value1.
Proof.
  intros different.
  apply nth_error_ext. intro p.
  rewrite !nth_error_replace_cell. rewrite !length_replace_cell.
  destruct (Nat.eqb target1 p) eqn:same1;
    destruct (Nat.eqb target2 p) eqn:same2; try reflexivity.
  apply Nat.eqb_eq in same1. apply Nat.eqb_eq in same2.
  exfalso. apply different. congruence.
Qed.

(* Two replacements at the same position: the later one wins outright. *)
Lemma replace_cell_same {Value} (cells : list (memory_cell Value))
    (target : nat) (value1 value2 : Value) :
  replace_cell (replace_cell cells target value1) target value2
  = replace_cell cells target value2.
Proof.
  apply nth_error_ext. intro p.
  rewrite !nth_error_replace_cell. rewrite !length_replace_cell.
  destruct (Nat.eqb target p) eqn:same;
    destruct (Nat.ltb p (length cells)) eqn:inside; reflexivity.
Qed.


(* What the sequence of replacements leaves at each position: the value of the
   last update targeting it, or the original cell. *)
Lemma apply_updates_nth {Value} (cells : list (memory_cell Value))
    (updates : list ((nat * nat) * Value)) (p : nat) :
  nth_error (apply_updates cells updates) p
  = match lookup_update p updates with
    | Some found =>
        if Nat.ltb p (length cells) then Some (Initialized (snd found))
        else nth_error cells p
    | None => nth_error cells p
    end.
Proof.
  revert cells p.
  induction updates as [|update rest IH]; intros cells p.
  - reflexivity.
  - cbn [apply_updates]. rewrite IH. cbn [lookup_update].
    destruct (lookup_update p rest) as [[found_position found_value]|] eqn:found.
    + rewrite length_replace_cell.
      destruct (Nat.ltb p (length cells)) eqn:inside; [reflexivity|].
      rewrite nth_error_replace_cell. rewrite inside.
      destruct (Nat.eqb (update_target update) p); reflexivity.
    + destruct (Nat.eqb (update_target update) p) eqn:same.
      * rewrite nth_error_replace_cell. rewrite same.
        destruct (Nat.ltb p (length cells)) eqn:inside; reflexivity.
      * rewrite nth_error_replace_cell. rewrite same. reflexivity.
Qed.

(* Consequently the sequence depends only on [lookup_update]. *)
Lemma apply_updates_lookup {Value} (cells : list (memory_cell Value))
    (updates1 updates2 : list ((nat * nat) * Value)) :
  (forall p, lookup_update p updates1 = lookup_update p updates2) ->
  apply_updates cells updates1 = apply_updates cells updates2.
Proof.
  intros same. apply nth_error_ext. intro p.
  rewrite !apply_updates_nth. rewrite same.
  destruct (lookup_update p updates2) as [[found_position found_value]|];
    reflexivity.
Qed.


(* The updates that target [p], in the order they appear. *)
Fixpoint keep_target {Value} (p : nat) (updates : list ((nat * nat) * Value))
    : list ((nat * nat) * Value) :=
  match updates with
  | [] => []
  | update :: rest =>
      if Nat.eqb (update_target update) p
      then update :: keep_target p rest
      else keep_target p rest
  end.

Fixpoint last_of {A : Type} (l : list A) : option A :=
  match l with
  | [] => None
  | first :: rest =>
      match last_of rest with
      | Some found => Some found
      | None => Some first
      end
  end.

Lemma last_of_keep_cons {Value} (p : nat) (update : (nat * nat) * Value)
    (rest : list ((nat * nat) * Value)) :
  last_of (keep_target p (update :: rest))
  = if Nat.eqb (update_target update) p
    then match last_of (keep_target p rest) with
         | Some found => Some found
         | None => Some update
         end
    else last_of (keep_target p rest).
Proof.
  cbn [keep_target].
  destruct (Nat.eqb (update_target update) p) eqn:same.
  - cbn [last_of]. reflexivity.
  - reflexivity.
Qed.

Lemma lookup_update_keep {Value} (p : nat)
    (updates : list ((nat * nat) * Value)) :
  lookup_update p updates
  = match last_of (keep_target p updates) with
    | Some found => Some (update_position found, update_value found)
    | None => None
    end.
Proof.
  induction updates as [|update rest IH].
  - reflexivity.
  - cbn [lookup_update]. rewrite last_of_keep_cons. rewrite IH.
    destruct (Nat.eqb (update_target update) p) eqn:same;
      destruct (last_of (keep_target p rest)) as [found|]; reflexivity.
Qed.

Lemma keep_target_app {Value} (p : nat)
    (l1 l2 : list ((nat * nat) * Value)) :
  keep_target p (l1 ++ l2) = keep_target p l1 ++ keep_target p l2.
Proof.
  induction l1 as [|update rest IH]; cbn [app keep_target].
  - reflexivity.
  - destruct (Nat.eqb (update_target update) p); [cbn [app]; rewrite IH|rewrite IH];
      reflexivity.
Qed.

Lemma keep_target_permutation {Value} (p : nat)
    (l1 l2 : list ((nat * nat) * Value)) :
  Permutation l1 l2 -> Permutation (keep_target p l1) (keep_target p l2).
Proof.
  intro perm. induction perm as [|update rest rest' perm IH
    |update1 update2 rest
    |l1 l2 l3 perm1 IH1 perm2 IH2].
  - apply Permutation_refl.
  - cbn [keep_target]. destruct (Nat.eqb (update_target update) p).
    + apply Permutation_cons. { reflexivity. } exact IH.
    + exact IH.
  - cbn [keep_target].
    destruct (Nat.eqb (update_target update1) p) eqn:first;
      destruct (Nat.eqb (update_target update2) p) eqn:second;
      try apply Permutation_swap; apply Permutation_refl.
  - eapply Permutation_trans; [exact IH1 | exact IH2].
Qed.


(* Ordering write updates by target and then by coordinate position. *)
Definition write_leb {Value} (left right : (nat * nat) * Value) : bool :=
  entry_leb (update_target left, update_position left)
            (update_target right, update_position right).

Definition write_rel {Value} (left right : (nat * nat) * Value) : Prop :=
  write_leb left right = true.

Definition by_position {Value} (left right : (nat * nat) * Value) : Prop :=
  Nat.leb (update_position left) (update_position right) = true.

Lemma write_leb_total {Value} (left right : (nat * nat) * Value) :
  write_leb left right = true \/ write_leb right left = true.
Proof. unfold write_leb. apply entry_leb_total. Qed.

Lemma write_leb_trans {Value} :
  forall x y z : (nat * nat) * Value,
    write_leb x y = true -> write_leb y z = true -> write_leb x z = true.
Proof. unfold write_leb. intros. eapply entry_leb_trans; eassumption. Qed.

Definition write_sort {Value} (updates : list ((nat * nat) * Value))
    : list ((nat * nat) * Value) :=
  @msort ((nat * nat) * Value) (@write_leb Value) updates.

Lemma write_leb_spec {Value} (left right : (nat * nat) * Value) :
  write_leb left right = true <->
  (update_target left < update_target right \/
   (update_target left = update_target right /\
    update_position left <= update_position right)).
Proof. unfold write_leb. apply entry_leb_spec. Qed.

Lemma write_sort_sorted {Value} (updates : list ((nat * nat) * Value)) :
  Sorted (@write_rel Value) (write_sort updates).
Proof.
  exact (@msort_sorted ((nat * nat) * Value) (@write_leb Value)
           (@write_leb_total Value) (@write_leb_trans Value) updates).
Qed.

Lemma write_sort_permutation {Value} (updates : list ((nat * nat) * Value)) :
  Permutation updates (write_sort updates).
Proof.
  exact (@msort_permutation ((nat * nat) * Value) (@write_leb Value) updates).
Qed.

(* [Forall] as a pointwise statement, in terms of [In]. *)
Lemma Forall_In {A : Type} (P : A -> Prop) (l : list A) :
  Forall P l -> forall x, In x l -> P x.
Proof.
  intro all. induction all as [|head tail head_ok tail_ok IH]; intros x inside.
  - destruct inside.
  - destruct inside as [same | later].
    + subst x. exact head_ok.
    + apply IH. exact later.
Qed.

Lemma keep_target_In {Value} (p : nat) (l : list ((nat * nat) * Value)) :
  forall update, In update (keep_target p l) -> In update l.
Proof.
  induction l as [|head rest IH]; intros update inside.
  - destruct inside.
  - cbn [keep_target] in inside.
    destruct (Nat.eqb (update_target head) p) eqn:same.
    + destruct inside as [same_update | later].
      * left. exact same_update.
      * right. apply IH. exact later.
    + right. apply IH. exact inside.
Qed.

Lemma keep_target_target {Value} (p : nat) (l : list ((nat * nat) * Value)) :
  forall update, In update (keep_target p l) -> update_target update = p.
Proof.
  induction l as [|head rest IH]; intros update inside.
  - destruct inside.
  - cbn [keep_target] in inside.
    destruct (Nat.eqb (update_target head) p) eqn:same.
    + apply Nat.eqb_eq in same.
      destruct inside as [same_update | later].
      * subst update. exact same.
      * apply IH. exact later.
    + apply IH. exact inside.
Qed.

Lemma keep_target_In_map {Value} (p : nat) (l : list ((nat * nat) * Value)) :
  forall position, In position (map update_position (keep_target p l)) ->
    In position (map update_position l).
Proof.
  induction l as [|head rest IH]; intros position inside.
  - destruct inside.
  - cbn [keep_target] in inside. cbn [map] in inside.
    destruct (Nat.eqb (update_target head) p) eqn:same.
    + destruct inside as [same_position | later].
      * left. exact same_position.
      * right. apply IH. exact later.
    + right. apply IH. exact inside.
Qed.

(* A filtered subsequence of a sorted list is sorted. *)
Lemma keep_target_sorted {Value} (p : nat) (l : list ((nat * nat) * Value)) :
  Sorted (@write_rel Value) l ->
  Sorted (@by_position Value) (keep_target p l).
Proof.
  intro sorted. induction l as [|update rest IH].
  - constructor.
  - apply Sorted_inv in sorted. destruct sorted as [sorted_rest head_rel].
    cbn [keep_target].
    destruct (Nat.eqb (update_target update) p) eqn:same.
    + apply Nat.eqb_eq in same.
      apply Sorted_cons.
      * apply IH. exact sorted_rest.
      * destruct (keep_target p rest) as [|next later] eqn:kept.
        -- constructor.
        -- apply HdRel_cons.
           assert (inside : In next (keep_target p rest)) by (rewrite kept; left;
             reflexivity).
           assert (in_rest : In next rest)
             by (exact (@keep_target_In Value p rest next inside)).
           assert (target_next : update_target next = p)
             by (exact (@keep_target_target Value p rest next inside)).
           assert (ordered : write_leb update next = true).
           { apply (@sorted_head_rel ((nat * nat) * Value) (@write_rel Value)
                      (@write_leb_trans Value) update rest).
             - apply Sorted_cons; assumption.
             - exact in_rest. }
           apply write_leb_spec in ordered.
           destruct ordered as [less | [equal le]].
           { rewrite same in less. rewrite target_next in less. lia. }
           { apply Nat.leb_le. exact le. }
    + apply IH. exact sorted_rest.
Qed.

Lemma by_position_trans {Value} :
  forall x y z : (nat * nat) * Value,
    by_position x y -> by_position y z -> by_position x z.
Proof.
  intros x y z xy yz. unfold by_position in *.
  apply Nat.leb_le in xy. apply Nat.leb_le in yz. apply Nat.leb_le. lia.
Qed.

Lemma sorted_by_position_head {Value} :
  forall (a : (nat * nat) * Value) (l : list ((nat * nat) * Value)),
    Sorted (@by_position Value) (a :: l) ->
    forall x, In x l -> by_position a x.
Proof.
  intros a l. revert a. induction l as [|head tail IH]; intros a sorted x inside.
  - destruct inside.
  - apply Sorted_inv in sorted. destruct sorted as [sorted_rest head_rel].
    apply HdRel_inv in head_rel.
    destruct inside as [same | later].
    + subst x. exact head_rel.
    + assert (head_x : by_position head x)
        by (apply (IH head sorted_rest x later)).
      exact (@by_position_trans Value a head x head_rel head_x).
Qed.

Arguments sorted_by_position_head {Value} a l _ _ _.

(* A filtered subsequence of a list sorted by position stays sorted. *)
Lemma keep_target_sorted_position {Value} (p : nat)
    (l : list ((nat * nat) * Value)) :
  Sorted (@by_position Value) l -> Sorted (@by_position Value) (keep_target p l).
Proof.
  intro sorted. induction l as [|update rest IH].
  - constructor.
  - apply Sorted_inv in sorted. destruct sorted as [sorted_rest head_rel].
    cbn [keep_target].
    destruct (Nat.eqb (update_target update) p) eqn:same.
    + apply Sorted_cons.
      * apply IH. exact sorted_rest.
      * destruct (keep_target p rest) as [|next later] eqn:kept.
        -- constructor.
        -- apply HdRel_cons.
           assert (inside : In next (keep_target p rest))
             by (rewrite kept; left; reflexivity).
           assert (in_rest : In next rest)
             by (exact (@keep_target_In Value p rest next inside)).
           apply sorted_by_position_head with (a := update) (l := rest).
           { apply Sorted_cons; assumption. }
           { exact in_rest. }
    + apply IH. exact sorted_rest.
Qed.

(* A filtered subsequence of a duplicate-free list is duplicate-free. *)
Lemma keep_target_nodup {Value} (p : nat) (l : list ((nat * nat) * Value)) :
  List.NoDup (map update_position l) ->
  List.NoDup (map update_position (keep_target p l)).
Proof.
  intro nodup. induction l as [|update rest IH].
  - constructor.
  - change (List.NoDup (update_position update :: map update_position rest))
      in nodup.
    inversion nodup as [| ? ? notin keep]; subst.
    cbn [keep_target].
    destruct (Nat.eqb (update_target update) p) eqn:same.
    + cbn [map]. constructor.
      * intro inside. apply notin.
        apply keep_target_In_map with (p := p) in inside. exact inside.
      * apply IH. exact keep.
    + apply IH. exact keep.
Qed.

Lemma seq_In_ge (start len : nat) :
  forall x, In x (seq start len) -> start <= x.
Proof.
  revert start. induction len as [|len IH]; intros start x inside.
  - cbn [seq] in inside. destruct inside.
  - cbn [seq] in inside.
    destruct inside as [same | later].
    + subst x. lia.
    + apply (IH (S start) x) in later. lia.
Qed.

Lemma sorted_seq (start len : nat) :
  Sorted (fun left right => Nat.leb left right = true) (seq start len).
Proof.
  revert start. induction len as [|len IH]; intros start; cbn [seq].
  - constructor.
  - apply Sorted_cons.
    + apply IH.
    + destruct (seq (S start) len) as [|next later] eqn:skipped.
      * constructor.
      * apply HdRel_cons. cbn [Nat.leb].
        assert (bound : S start <= next).
        { apply (seq_In_ge (S start) len next). rewrite skipped. left. reflexivity. }
        apply Nat.leb_le. lia.
Qed.


(* The winner at a cell is the update with the greatest coordinate position.
   Sorting by target then position preserves that: within each target the
   positions stay in increasing order, so the last update kept for a target is
   the same one as in coordinate order. *)
Lemma lookup_update_sort {Value} (p : nat)
    (updates : list ((nat * nat) * Value)) :
  Sorted (@by_position Value) updates ->
  List.NoDup (map update_position updates) ->
  lookup_update p (write_sort updates) = lookup_update p updates.
Proof.
  intros increasing distinct.
  rewrite !lookup_update_keep.
  assert (perm : Permutation (keep_target p (write_sort updates))
                            (keep_target p updates))
    by (apply keep_target_permutation; apply Permutation_sym;
        apply write_sort_permutation).
  assert (sorted_sorted : Sorted (@by_position Value)
            (keep_target p (write_sort updates)))
    by (apply keep_target_sorted; apply write_sort_sorted).
  assert (sorted_coord : Sorted (@by_position Value) (keep_target p updates))
    by (apply keep_target_sorted_position; exact increasing).
  assert (nodup_sorted_list :
            List.NoDup (map update_position (write_sort updates))).
  { apply (@Permutation_NoDup _ (map update_position updates)).
    - apply Permutation_map. apply write_sort_permutation.
    - exact distinct. }
  assert (nodup_sorted : List.NoDup
            (map update_position (keep_target p (write_sort updates))))
    by (apply keep_target_nodup; exact nodup_sorted_list).
  assert (eq : keep_target p (write_sort updates) = keep_target p updates).
  { eapply (@sorted_permutation_unique ((nat * nat) * Value) nat update_position
              (fun x y => Nat.leb x y = true)).
    - intros x. apply Nat.leb_refl.
    - intros x y xy yx. apply Nat.leb_le in xy. apply Nat.leb_le in yx. lia.
    - intros x y z xy yz. apply Nat.leb_le in xy. apply Nat.leb_le in yz.
      apply Nat.leb_le. lia.
    - exact sorted_sorted.
    - exact sorted_coord.
    - exact nodup_sorted.
    - exact perm. }
  rewrite eq. reflexivity.
Qed.


Lemma last_of_nonempty {A : Type} (first : A) (rest : list A) :
  last_of (first :: rest) <> None.
Proof. cbn [last_of]. destruct (last_of rest); discriminate. Qed.

Lemma last_of_cons_cons {A : Type} (x y : A) (l : list A) :
  last_of (x :: y :: l) = last_of (y :: l).
Proof.
  cbn [last_of]. destruct (last_of l) as [found|]; reflexivity.
Qed.

(* When two adjacent updates target the same cell the earlier one is
   overwritten, so it can be dropped. *)
Lemma lookup_update_drop {Value} (p : nat) (update next : (nat * nat) * Value)
    (later : list ((nat * nat) * Value)) :
  update_target update = update_target next ->
  lookup_update p (update :: next :: later) = lookup_update p (next :: later).
Proof.
  intro same. rewrite !lookup_update_keep. cbn [keep_target]. rewrite same.
  destruct (Nat.eqb (update_target next) p) eqn:both.
  - rewrite last_of_cons_cons. reflexivity.
  - reflexivity.
Qed.

(* Keep only the last update of each run of equal targets. *)
Fixpoint winners {Value} (updates : list ((nat * nat) * Value))
    : list ((nat * nat) * Value) :=
  match updates with
  | [] => []
  | update :: rest =>
      match rest with
      | [] => [update]
      | next :: later =>
          if Nat.eqb (update_target update) (update_target next)
          then winners rest
          else update :: winners rest
      end
  end.

(* On a sorted list, dropping the overwritten entries changes nothing. *)
Lemma apply_updates_winners {Value} :
  forall (cells : list (memory_cell Value)) (updates : list ((nat * nat) * Value)),
    Sorted (@write_rel Value) updates ->
    apply_updates cells updates = apply_updates cells (winners updates).
Proof.
  intros cells updates. revert cells.
  induction updates as [|update rest IH]; intros cells sorted.
  - reflexivity.
  - destruct rest as [|next later].
    + reflexivity.
    + cbn [winners].
      destruct (Nat.eqb (update_target update) (update_target next)) eqn:same.
      * apply Nat.eqb_eq in same.
        transitivity (apply_updates cells (next :: later)).
        -- apply apply_updates_lookup. intro p.
           apply lookup_update_drop. exact same.
        -- apply IH. apply (proj1 (Sorted_inv sorted)).
      * change (apply_updates
                  (replace_cell cells (update_target update) (update_value update))
                  (next :: later)
                = apply_updates
                  (replace_cell cells (update_target update) (update_value update))
                  (winners (next :: later))).
        apply IH. apply (proj1 (Sorted_inv sorted)).
Qed.


(* ------------------------------------------------------------------ *)
(* Targets of the winning updates                                     *)
(* ------------------------------------------------------------------ *)

(* Strictly increasing targets, the order in which the one-pass walk visits the
   surviving updates.  Spelled with [= true] rather than relying on the bool-to-
   Prop coercion so that the arithmetic lemmas apply directly. *)
Definition increasing_target {Value} (left right : (nat * nat) * Value) : Prop :=
  Nat.ltb (update_target left) (update_target right) = true.

(* [winners] keeps a subsequence of its argument. *)
Lemma winners_In {Value} (l : list ((nat * nat) * Value)) :
  forall update, In update (winners l) -> In update l.
Proof.
  induction l as [|update rest IH]; intros found inside.
  - destruct inside.
  - destruct rest as [|next later].
    + cbn [winners] in inside. destruct inside as [same | empty].
      * left. exact same.
      * destruct empty.
    + cbn [winners] in inside.
      destruct (Nat.eqb (update_target update) (update_target next)) eqn:same.
      * right. apply IH. exact inside.
      * destruct inside as [same_found | later_in].
        -- left. exact same_found.
        -- right. apply IH. exact later_in.
Qed.

Lemma write_rel_of_leb {Value} (left right : (nat * nat) * Value) :
  write_leb left right = true -> update_target left <= update_target right.
Proof.
  intro rel. apply write_leb_spec in rel.
  destruct rel as [less | [equal _]]; lia.
Qed.

Lemma increasing_target_trans {Value} :
  forall x y z : (nat * nat) * Value,
    increasing_target x y -> increasing_target y z -> increasing_target x z.
Proof.
  intros x y z first second. unfold increasing_target in *.
  apply Nat.ltb_lt. apply Nat.ltb_lt in first. apply Nat.ltb_lt in second. lia.
Qed.

(* Every element after the head of a sorted list addresses a cell at least as far
   along as the head does. *)
Lemma write_sorted_head_le {Value} :
  forall (a : (nat * nat) * Value) (l : list ((nat * nat) * Value)),
    Sorted (@write_rel Value) (a :: l) ->
    forall x, In x l -> update_target a <= update_target x.
Proof.
  intros a l sorted x inside.
  pose proof (sorted_head_rel (@write_rel Value) (@write_leb_trans Value)
                a l sorted x inside) as rel.
  apply write_rel_of_leb in rel. exact rel.
Qed.

(* When the head and the next update disagree, the head's target is strictly
   below the target of every element that survives the filtering. *)
Lemma winners_head_target {Value} (update next : (nat * nat) * Value)
    (later : list ((nat * nat) * Value)) :
  Sorted (@write_rel Value) (update :: next :: later) ->
  update_target update <> update_target next ->
  forall head, In head (winners (next :: later)) ->
    increasing_target update head.
Proof.
  intros sorted different head inside.
  apply Sorted_inv in sorted. destruct sorted as [sorted_tail adjacent].
  apply HdRel_inv in adjacent.
  pose proof (@winners_In Value (next :: later) head inside) as head_in.
  assert (next_head : update_target next <= update_target head).
  { destruct head_in as [same | later_in].
    - subst head. lia.
    - exact (@write_sorted_head_le Value next later sorted_tail head later_in). }
  unfold increasing_target. apply Nat.ltb_lt.
  apply write_leb_spec in adjacent.
  destruct adjacent as [less | [equal _]].
  - lia.
  - exfalso. apply different. exact equal.
Qed.

(* The surviving updates have strictly increasing targets, so the walk below
   only ever moves forwards. *)
Lemma winners_sorted {Value} (l : list ((nat * nat) * Value)) :
  Sorted (@write_rel Value) l -> Sorted (@increasing_target Value) (winners l).
Proof.
  induction l as [|update rest IH]; intro sorted.
  - cbn [winners]. constructor.
  - destruct rest as [|next later].
    + cbn [winners]. constructor; constructor.
    + change (Sorted (@increasing_target Value)
                (if Nat.eqb (update_target update) (update_target next)
                 then winners (next :: later)
                 else update :: winners (next :: later))).
      destruct (Nat.eqb (update_target update) (update_target next)) eqn:same.
      * apply IH. apply (proj1 (Sorted_inv sorted)).
      * apply Sorted_cons.
        -- apply IH. apply (proj1 (Sorted_inv sorted)).
        -- destruct (winners (next :: later)) as [|head tail] eqn:kept.
           ++ constructor.
           ++ apply HdRel_cons.
              apply (@winners_head_target Value update next later sorted).
              ** apply Nat.eqb_neq. exact same.
              ** rewrite kept. left. reflexivity.
Qed.


(* ------------------------------------------------------------------ *)
(* List plumbing for the walk                                         *)
(* ------------------------------------------------------------------ *)

Lemma nth_error_absent_target {Value} (p : nat)
    (updates : list ((nat * nat) * Value)) :
  (forall update, In update updates -> update_target update <> p) ->
  lookup_update p updates = None.
Proof.
  induction updates as [|update rest IH]; intro absent.
  - reflexivity.
  - cbn [lookup_update].
    assert (rest_none : lookup_update p rest = None)
      by (apply IH; intros u inside; apply absent; right; exact inside).
    rewrite rest_none.
    assert (different : update_target update <> p)
      by (apply absent; left; reflexivity).
    destruct (Nat.eqb (update_target update) p) eqn:same.
    + apply Nat.eqb_eq in same. exfalso. exact (different same).
    + reflexivity.
Qed.

Lemma apply_updates_before {Value} (cells : list (memory_cell Value))
    (updates : list ((nat * nat) * Value)) (t p : nat) :
  (forall update, In update updates -> t < update_target update) ->
  p < t ->
  nth_error (apply_updates cells updates) p = nth_error cells p.
Proof.
  intros after before. rewrite apply_updates_nth.
  rewrite (@nth_error_absent_target Value p updates).
  - reflexivity.
  - intros update inside same. pose proof (after update inside). lia.
Qed.

(* ------------------------------------------------------------------ *)
(* What a sequence of updates does away from the cell it addresses    *)
(* ------------------------------------------------------------------ *)

(* Updates applied past a cell leave the earlier cells alone. *)
Lemma apply_updates_untouched {Value} (all : list (memory_cell Value))
    (target : nat) (value : Value) (updates : list ((nat * nat) * Value))
    (p : nat) :
  (forall update, In update updates -> target < update_target update) ->
  p < target ->
  nth_error (apply_updates (replace_cell all target value) updates) p
  = nth_error all p.
Proof.
  intros after before.
  transitivity (nth_error (replace_cell all target value) p).
  { apply (@apply_updates_before Value (replace_cell all target value) updates
             target p); assumption. }
  rewrite nth_error_replace_cell.
  destruct (Nat.eqb target p) eqn:same; [|reflexivity].
  apply Nat.eqb_eq in same. exfalso. lia.
Qed.

(* ... and they leave the cells past it alone as well: an update replaces one
   cell and nothing else. *)
Lemma apply_updates_replace_beyond {Value} (all : list (memory_cell Value))
    (target : nat) (value : Value) (updates : list ((nat * nat) * Value))
    (p : nat) :
  target < p ->
  nth_error (apply_updates (replace_cell all target value) updates) p
  = nth_error (apply_updates all updates) p.
Proof.
  intro beyond.
  rewrite !apply_updates_nth. rewrite length_replace_cell.
  destruct (lookup_update p updates) as [[found_position found_value]|].
  - destruct (Nat.ltb p (length all)) eqn:inside.
    + reflexivity.
    + rewrite nth_error_replace_cell.
      destruct (Nat.eqb target p) eqn:same; [|reflexivity].
      apply Nat.eqb_eq in same. exfalso. lia.
  - rewrite nth_error_replace_cell.
    destruct (Nat.eqb target p) eqn:same; [|reflexivity].
    apply Nat.eqb_eq in same. exfalso. lia.
Qed.

Lemma skipn_apply_updates_tail {Value} (all : list (memory_cell Value))
    (target : nat) (value : Value) (later : list ((nat * nat) * Value)) :
  skipn (S target) (apply_updates (replace_cell all target value) later)
  = skipn (S target) (apply_updates all later).
Proof.
  apply nth_error_ext. intro p.
  rewrite !nth_error_skipn.
  apply apply_updates_replace_beyond. lia.
Qed.

Lemma length_apply_updates {Value} :
  forall (cells : list (memory_cell Value))
         (updates : list ((nat * nat) * Value)),
    length (apply_updates cells updates) = length cells.
Proof.
  intros cells updates. revert cells.
  induction updates as [|update rest IH]; intro cells.
  - reflexivity.
  - cbn [apply_updates]. rewrite IH. apply length_replace_cell.
Qed.

(* The cell at the addressed position is the written value. *)
Lemma apply_updates_head {Value} (all : list (memory_cell Value))
    (target : nat) (value : Value) (later : list ((nat * nat) * Value)) :
  target < length all ->
  (forall update, In update later -> target < update_target update) ->
  nth_error (apply_updates (replace_cell all target value) later) target
  = Some (Initialized value).
Proof.
  intros inside after.
  rewrite apply_updates_nth.
  rewrite (@nth_error_absent_target Value target later).
  - rewrite nth_error_replace_cell.
    rewrite (proj2 (Nat.eqb_eq target target)) by reflexivity.
    rewrite (proj2 (Nat.ltb_lt target (length all))) by exact inside.
    reflexivity.
  - intros update inside_update. pose proof (after update inside_update). lia.
Qed.

(* Splitting a cell list at a position: [skipn] and [firstn] are the pieces. *)
Lemma skipn_nth_cons {A : Type} (l : list A) (n : nat) (x : A) :
  nth_error l n = Some x -> skipn n l = x :: skipn (S n) l.
Proof.
  revert l. induction n as [|n IH]; intros l hit.
  - destruct l as [|head tail]; cbn in hit; [discriminate|].
    injection hit as same. subst head. reflexivity.
  - destruct l as [|head tail]; cbn in hit; [discriminate|].
    cbn [skipn]. apply IH. exact hit.
Qed.

(* Two lists with the same length that agree on a prefix have the same prefix. *)
Lemma firstn_agree {A : Type} (n : nat) (l1 l2 : list A) :
  length l1 = length l2 ->
  (forall p, p < n -> nth_error l1 p = nth_error l2 p) ->
  n <= length l1 ->
  firstn n l1 = firstn n l2.
Proof.
  revert l1 l2. induction n as [|n IH]; intros l1 l2 len agree bound.
  - reflexivity.
  - destruct l1 as [|a1 r1]; destruct l2 as [|a2 r2]; cbn [length] in *.
    + reflexivity.
    + discriminate.
    + discriminate.
    + cbn [firstn]. f_equal.
      * assert (heads : nth_error (a1 :: r1) 0 = nth_error (a2 :: r2) 0)
          by (apply agree; lia).
        cbn [nth_error] in heads. injection heads as same. exact same.
      * apply IH with (l1 := r1) (l2 := r2).
        -- lia.
        -- intros p small. apply (agree (S p)). lia.
        -- lia.
Qed.

(* The head of a list sorted by strictly increasing targets is below every
   later target. *)
Lemma write_sorted_head_lt {Value} :
  forall (a : (nat * nat) * Value) (l : list ((nat * nat) * Value)),
    Sorted (@increasing_target Value) (a :: l) ->
    forall x, In x l -> increasing_target a x.
Proof.
  intros a l sorted x inside.
  exact (sorted_head_rel (@increasing_target Value)
           (@increasing_target_trans Value) a l sorted x inside).
Qed.

(* One step of the write sequence: the cells before the target are unchanged,
   the targeted cell gets the value, and the rest is the tail of the updates. *)
Lemma skipn_apply_updates_split {Value} (all : list (memory_cell Value))
    (target cursor : nat) (value : Value)
    (later : list ((nat * nat) * Value)) :
  cursor <= target ->
  target < length all ->
  (forall update, In update later -> target < update_target update) ->
  skipn cursor (apply_updates (replace_cell all target value) later)
  = firstn (target - cursor) (skipn cursor all)
    ++ Initialized value :: skipn (S target) (apply_updates all later).
Proof.
  intros bound inside after.
  assert (head_value
    : nth_error (apply_updates (replace_cell all target value) later) target
      = Some (Initialized value))
    by (apply apply_updates_head; assumption).
  assert (head_split
    : skipn target (apply_updates (replace_cell all target value) later)
      = Initialized value
        :: skipn (S target) (apply_updates (replace_cell all target value) later))
    by (apply skipn_nth_cons; exact head_value).
  rewrite <- (firstn_skipn (target - cursor)
                (skipn cursor (apply_updates (replace_cell all target value) later))).
  assert (prefix
    : firstn (target - cursor)
        (skipn cursor (apply_updates (replace_cell all target value) later))
      = firstn (target - cursor) (skipn cursor all)).
  { apply firstn_agree.
    - rewrite !length_skipn, length_apply_updates, length_replace_cell. reflexivity.
    - intros p small. rewrite !nth_error_skipn.
      apply (@apply_updates_untouched Value all target value later (cursor + p)).
      + exact after.
      + lia.
    - rewrite length_skipn, length_apply_updates, length_replace_cell. lia. }
  assert (middle
    : skipn (target - cursor)
        (skipn cursor (apply_updates (replace_cell all target value) later))
      = Initialized value :: skipn (S target) (apply_updates all later)).
  { rewrite skipn_skipn.
    replace (target - cursor + cursor) with target by lia.
    rewrite head_split, (@skipn_apply_updates_tail Value all target value later).
    reflexivity. }
  rewrite prefix, middle. reflexivity.
Qed.

(* ------------------------------------------------------------------ *)
(* The one-pass write walk                                            *)
(* ------------------------------------------------------------------ *)

(* Walk the cell list once, in increasing target order, writing one value per
   update.  Every step consumes [target - cursor] cells from the front of the
   list and drops the cell it wrote, so the whole walk is linear in the length
   of the list plus the number of updates.  Updates must be sorted by strictly
   increasing target and address a cell of the list. *)
Fixpoint write_walk {Value} (cells : list (memory_cell Value)) (cursor : nat)
    (updates : list ((nat * nat) * Value)) : list (memory_cell Value) :=
  match updates with
  | [] => cells
  | update :: later =>
      if Nat.leb cursor (update_target update) then
        match skipn (update_target update - cursor) cells with
        | [] => cells
        | cell :: cells' =>
            firstn (update_target update - cursor) cells
            ++ (Initialized (update_value update)
                :: write_walk cells' (S (update_target update)) later)
        end
      else cells
  end.

(* The walk writes exactly what the sequence of single-cell replacements does. *)
Lemma write_walk_correct {Value} :
  forall (all : list (memory_cell Value)) cursor updates,
    Sorted (@increasing_target Value) updates ->
    (forall update, In update updates -> cursor <= update_target update) ->
    (forall update, In update updates -> update_target update < length all) ->
    write_walk (skipn cursor all) cursor updates
    = skipn cursor (apply_updates all updates).
Proof.
  intros all cursor updates. revert all cursor.
  induction updates as [|update later IH]; intros all cursor sorted bound inside.
  - reflexivity.
  - destruct update as [[target position] value].
    cbn [write_walk apply_updates update_target update_value fst snd].
    assert (le_target : cursor <= target)
      by (exact (bound ((target, position), value) (or_introl eq_refl))).
    rewrite (proj2 (Nat.leb_le cursor target)) by exact le_target.
    assert (sorted_rest : Sorted (@increasing_target Value) later)
      by (apply (proj1 (Sorted_inv sorted))).
    assert (later_after : forall u, In u later -> target < update_target u).
    { intros u later_in.
      pose proof (@write_sorted_head_lt Value ((target, position), value) later
                    sorted u later_in) as rel.
      unfold increasing_target in rel. apply Nat.ltb_lt in rel. exact rel. }
    assert (later_bound : forall u, In u later -> S target <= update_target u).
    { intros u later_in. pose proof (later_after u later_in). lia. }
    assert (later_inside : forall u, In u later -> update_target u < length all)
      by (intros u later_in; apply inside; right; exact later_in).
    assert (skip_twice
      : skipn (target - cursor) (skipn cursor all) = skipn target all).
    { rewrite skipn_skipn. replace (target - cursor + cursor) with target by lia.
      reflexivity. }
    rewrite skip_twice.
    assert (target_inside : target < length all).
    { pose proof (inside ((target, position), value) (or_introl eq_refl)) as within.
      cbn [update_target fst snd] in within. exact within. }
    assert (progress : 0 < length (skipn target all)).
    { rewrite length_skipn. lia. }
    destruct (skipn target all) as [|cell cells'] eqn:skipped.
    + cbn [length] in progress. lia.
    + assert (step : skipn (S target) all = cells').
      { replace (S target) with (1 + target) by lia.
        rewrite <- skipn_skipn. rewrite skipped. reflexivity. }
      rewrite (@skipn_apply_updates_split Value all target cursor value later
                 le_target target_inside later_after).
      rewrite <- step.
      rewrite (@IH all (S target) sorted_rest later_bound later_inside).
      reflexivity.
Qed.


(* ------------------------------------------------------------------ *)
(* Bulk write: per-coordinate entries                                 *)
(* ------------------------------------------------------------------ *)

(* The pieces of one entry: the address computation (or the error it reports),
   the position of the coordinate that produced it, and the value.  The position
   decides which entry wins when several coordinates address the same cell. *)
Definition write_entry_target {Value}
    (entry : (result memory_error nat * nat) * Value) : result memory_error nat :=
  fst (fst entry).

Definition write_entry_position {Value}
    (entry : (result memory_error nat * nat) * Value) : nat :=
  snd (fst entry).

Definition write_entry_value {Value}
    (entry : (result memory_error nat * nat) * Value) : Value :=
  snd entry.

(* One entry per coordinate of the common prefix of [coordinates] and [values].
   The positions start at [start] so that a suffix of the coordinates can be
   described on its own; [write_entries] starts at 0. *)
Definition write_entries_from {Value : Type} (offset : Z) (strides : list Z)
    (start : nat) (coordinates : list (list nat)) (values : list Value)
    : list ((result memory_error nat * nat) * Value) :=
  combine (combine (map (coordinate_target offset strides) coordinates)
                   (seq start (length coordinates)))
          values.

Definition write_entries {Value : Type} (offset : Z) (strides : list Z)
    (coordinates : list (list nat)) (values : list Value)
    : list ((result memory_error nat * nat) * Value) :=
  write_entries_from offset strides 0 coordinates values.

Lemma combine_nil_right {A B : Type} (l : list A) : @combine A B l [] = [].
Proof. destruct l; reflexivity. Qed.

Lemma write_entries_from_cons {Value} (offset : Z) (strides : list Z)
    (start : nat) (coordinate : list nat) (rest : list (list nat))
    (value : Value) (values : list Value) :
  write_entries_from offset strides start (coordinate :: rest) (value :: values)
  = ((coordinate_target offset strides coordinate, start), value)
    :: write_entries_from offset strides (S start) rest values.
Proof. reflexivity. Qed.

Lemma write_entries_from_nil {Value} (offset : Z) (strides : list Z)
    (start : nat) (coordinates : list (list nat)) :
  write_entries_from offset strides start coordinates ([] : list Value) = [].
Proof. unfold write_entries_from. apply combine_nil_right. Qed.

(* An entry reports the error of its address computation, or an address error
   when the address is past the end of the cell list.  [limit] is the number of
   cells, computed once by the caller so that the classification stays linear. *)
Definition write_entry_error {Value} (limit : nat)
    (entry : (result memory_error nat * nat) * Value) : option memory_error :=
  match write_entry_target entry with
  | Error error => Some error
  | Ok target => if Nat.ltb target limit then None else Some ViewAddressOutOfBounds
  end.

(* The entries that address an existing cell, in coordinate order: the updates
   the walk performs. *)
Fixpoint write_good {Value} (limit : nat)
    (entries : list ((result memory_error nat * nat) * Value))
    : list ((nat * nat) * Value) :=
  match entries with
  | [] => []
  | entry :: rest =>
      match write_entry_target entry with
      | Error _ => write_good limit rest
      | Ok target =>
          if Nat.ltb target limit
          then ((target, write_entry_position entry), write_entry_value entry)
               :: write_good limit rest
          else write_good limit rest
      end
  end.

(* The entries that report an error, in coordinate order: the first one decides
   the error the whole write reports. *)
Fixpoint write_bad {Value} (limit : nat)
    (entries : list ((result memory_error nat * nat) * Value))
    : list (nat * memory_error) :=
  match entries with
  | [] => []
  | entry :: rest =>
      match write_entry_error limit entry with
      | Some error => (write_entry_position entry, error) :: write_bad limit rest
      | None => write_bad limit rest
      end
  end.

Definition first_error (errors : list (nat * memory_error)) : option memory_error :=
  match errors with
  | [] => None
  | (_, error) :: _ => Some error
  end.

(* The good entries as updates, addressed to the right cells. *)
Lemma write_good_target {Value} (limit : nat)
    (entries : list ((result memory_error nat * nat) * Value)) :
  forall update, In update (write_good limit entries) -> update_target update < limit.
Proof.
  induction entries as [|entry rest IH]; intros update inside.
  - destruct inside.
  - cbn [write_good] in inside.
    destruct (write_entry_target entry) as [target|error].
    + destruct (Nat.ltb target limit) eqn:within.
      * destruct inside as [same | later].
        -- subst update. cbn [update_target write_entry_position write_entry_value fst snd]. apply Nat.ltb_lt. exact within.
        -- apply IH. exact later.
      * apply IH. exact inside.
    + apply IH. exact inside.
Qed.

(* Positions in a good list never decrease. *)
Lemma write_good_position_ge {Value} (offset : Z) (strides : list Z) :
  forall (coordinates : list (list nat)) (values : list Value)
         (start limit : nat),
    forall update,
      In update (write_good limit
                   (write_entries_from offset strides start coordinates values)) ->
      start <= update_position update.
Proof.
  induction coordinates as [|coordinate rest IH];
    intros values start limit update inside.
  - cbn [write_entries_from combine map seq length write_good] in inside.
    destruct inside.
  - destruct values as [|value values'].
    + rewrite write_entries_from_nil in inside. cbn [write_good] in inside.
      destruct inside.
    + rewrite write_entries_from_cons in inside.
      cbn [write_good write_entry_target fst snd] in inside.
      destruct (coordinate_target offset strides coordinate) as [target|error].
      * destruct (Nat.ltb target limit) eqn:within.
        -- destruct inside as [same | later].
           ++ subst update.
              cbn [update_position write_entry_position write_entry_value fst snd].
              lia.
           ++ pose proof (IH values' (S start) limit update later) as lower. lia.
        -- pose proof (IH values' (S start) limit update inside) as lower. lia.
      * pose proof (IH values' (S start) limit update inside) as lower. lia.
Qed.

Lemma write_good_sorted_position {Value} (offset : Z) (strides : list Z) :
  forall (coordinates : list (list nat)) (values : list Value)
         (start limit : nat),
    Sorted (@by_position Value)
      (write_good limit
         (write_entries_from offset strides start coordinates values)).
Proof.
  induction coordinates as [|coordinate rest IH];
    intros values start limit.
  - cbn [write_entries_from combine map seq length write_good]. constructor.
  - destruct values as [|value values'].
    + rewrite write_entries_from_nil. cbn [write_good]. constructor.
    + rewrite write_entries_from_cons.
      cbn [write_good write_entry_target fst snd].
      destruct (coordinate_target offset strides coordinate) as [target|error].
      * destruct (Nat.ltb target limit) eqn:within.
        -- apply Sorted_cons.
           ++ apply (IH values' (S start) limit).
           ++ destruct (write_good limit
                          (write_entries_from offset strides (S start) rest values'))
                as [|next later] eqn:kept.
              ** constructor.
              ** apply HdRel_cons. unfold by_position. apply Nat.leb_le.
                 pose proof (@write_good_position_ge Value offset strides rest values'
                               (S start) limit next) as lower.
                 assert (inside : In next
                   (write_good limit
                      (write_entries_from offset strides (S start) rest values')))
                   by (rewrite kept; left; reflexivity).
                 pose proof (lower inside) as reach.
                 cbn [update_position write_entry_position write_entry_value fst snd] in *.
                 lia.
        -- apply (IH values' (S start) limit).
      * apply (IH values' (S start) limit).
Qed.

Lemma write_good_nodup_position {Value} (offset : Z) (strides : list Z) :
  forall (coordinates : list (list nat)) (values : list Value)
         (start limit : nat),
    List.NoDup (map update_position
      (write_good limit
         (write_entries_from offset strides start coordinates values))).
Proof.
  induction coordinates as [|coordinate rest IH];
    intros values start limit.
  - cbn [write_entries_from combine map seq length write_good]. constructor.
  - destruct values as [|value values'].
    + rewrite write_entries_from_nil. cbn [write_good map]. constructor.
    + rewrite write_entries_from_cons.
      cbn [write_good write_entry_target fst snd].
      destruct (coordinate_target offset strides coordinate) as [target|error].
      * destruct (Nat.ltb target limit) eqn:within.
        -- cbn [map update_position write_entry_position write_entry_value
                fst snd].
           constructor.
           ++ intro inside.
              apply in_map_iff in inside.
              destruct inside as [other [position_eq other_in]].
              pose proof (@write_good_position_ge Value offset strides rest values'
                            (S start) limit other other_in) as lower.
              rewrite <- position_eq in lower. lia.
           ++ apply (IH values' (S start) limit).
        -- apply (IH values' (S start) limit).
      * apply (IH values' (S start) limit).
Qed.

(* ------------------------------------------------------------------ *)
(* The bulk writer                                                    *)
(* ------------------------------------------------------------------ *)

Definition write_walked {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) (values : list Value)
    : list (memory_cell Value) :=
  write_walk (buffer_cells storage) 0
    (winners (write_sort (write_good (length (buffer_cells storage))
              (write_entries offset strides coordinates values)))).

(* Bulk write: classify every coordinate of the common prefix, report the first
   error in coordinate order if there is one, and otherwise walk the cells once
   writing the surviving updates in increasing address order.  Duplicate
   addresses are resolved towards the entry with the greatest coordinate
   position, and a length mismatch is reported only after the common prefix. *)
Definition write_coordinates {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) (values : list Value)
    : result memory_error (buffer Value) :=
  match first_error (write_bad (length (buffer_cells storage))
                       (write_entries offset strides coordinates values)) with
  | Some error => Error error
  | None =>
      if Nat.eqb (length coordinates) (length values) then
        Ok {| buffer_address_space := buffer_address_space storage;
              buffer_element_type := buffer_element_type storage;
              buffer_cells := write_walked storage offset strides coordinates values |}
      else Error InvalidViewRank
  end.

(* The walk writes exactly the values the pointwise sequence writes. *)
Lemma write_walked_apply {Value} (offset : Z) (strides : list Z) (start : nat)
    (coordinates : list (list nat)) (values : list Value) :
  forall cells : list (memory_cell Value),
    write_walk cells 0
      (winners (write_sort (write_good (length cells)
        (write_entries_from offset strides start coordinates values))))
    = apply_updates cells (write_good (length cells)
        (write_entries_from offset strides start coordinates values)).
Proof.
  intros cells.
  assert (sorted : Sorted (@write_rel Value)
            (write_sort (write_good (length cells)
               (write_entries_from offset strides start coordinates values))))
    by apply write_sort_sorted.
  assert (increasing : Sorted (@increasing_target Value)
            (winners (write_sort (write_good (length cells)
               (write_entries_from offset strides start coordinates values)))))
    by (apply winners_sorted; exact sorted).
  assert (within : forall update,
    In update (winners (write_sort (write_good (length cells)
       (write_entries_from offset strides start coordinates values))))
    -> update_target update < length cells).
  { intros update inside.
    pose proof (@winners_In Value
      (write_sort (write_good (length cells)
         (write_entries_from offset strides start coordinates values)))
      update inside) as sorted_in.
    apply (Permutation_in _
      (Permutation_sym (write_sort_permutation
        (write_good (length cells)
           (write_entries_from offset strides start coordinates values)))))
      in sorted_in.
    exact (@write_good_target Value (length cells)
             (write_entries_from offset strides start coordinates values)
             update sorted_in). }
  assert (reachable : forall update,
    In update (winners (write_sort (write_good (length cells)
       (write_entries_from offset strides start coordinates values))))
    -> 0 <= update_target update) by (intros update inside; lia).
  pose proof (@write_walk_correct Value cells 0
                (winners (write_sort (write_good (length cells)
                   (write_entries_from offset strides start coordinates values))))
                increasing reachable within) as walked.
  assert (zero : skipn 0 cells = cells) by reflexivity.
  rewrite zero in walked.
  rewrite walked.
  transitivity (apply_updates cells
    (write_sort (write_good (length cells)
       (write_entries_from offset strides start coordinates values)))).
  - symmetry. apply apply_updates_winners. exact sorted.
  - apply apply_updates_lookup. intro p.
    apply lookup_update_sort.
    + apply write_good_sorted_position.
    + apply write_good_nodup_position.
Qed.

(* The implementation computed on the storage record. *)
Lemma write_coordinates_spec {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) (values : list Value) :
  write_coordinates storage offset strides coordinates values
  = match first_error (write_bad (length (buffer_cells storage))
              (write_entries_from offset strides 0 coordinates values)) with
    | Some error => Error error
    | None =>
        if Nat.eqb (length coordinates) (length values) then
          Ok {| buffer_address_space := buffer_address_space storage;
                buffer_element_type := buffer_element_type storage;
                buffer_cells := apply_updates (buffer_cells storage)
                    (write_good (length (buffer_cells storage))
                      (write_entries_from offset strides 0 coordinates values)) |}
        else Error InvalidViewRank
    end.
Proof.
  unfold write_coordinates, write_walked, write_entries.
  destruct (first_error (write_bad (length (buffer_cells storage))
            (write_entries_from offset strides 0 coordinates values)))
    as [error|].
  - reflexivity.
  - destruct (Nat.eqb (length coordinates) (length values)).
    + rewrite (@write_walked_apply Value offset strides 0 coordinates values
                 (buffer_cells storage)).
      reflexivity.
    + reflexivity.
Qed.

(* The specification computed step by step: one [write_buffer_cell] per
   coordinate of the common prefix, in coordinate order, and a rank error when
   the two lists have different lengths. *)
Lemma write_pointwise_cons {Value} (offset : Z) (strides : list Z)
    (coordinate : list nat) (rest : list (list nat)) (value : Value)
    (values : list Value) (space : address_space) (element_type : mlir_type)
    (cells : list (memory_cell Value)) :
  write_pointwise {| buffer_address_space := space;
                     buffer_element_type := element_type;
                     buffer_cells := cells |} offset strides
    (coordinate :: rest) (value :: values)
  = match coordinate_target offset strides coordinate with
    | Error error => Error error
    | Ok target =>
        match replace_nth target (Initialized value) cells with
        | Some cells' =>
            write_pointwise {| buffer_address_space := space;
                               buffer_element_type := element_type;
                               buffer_cells := cells' |} offset strides rest values
        | None => Error ViewAddressOutOfBounds
        end
    end.
Proof.
  cbn [write_pointwise].
  rewrite coordinate_target_eq_z. unfold coordinate_target_z.
  destruct (view_cell_offset offset strides coordinate) as [address|error].
  - cbn [result_bind].
    destruct (Z.leb 0 address) eqn:positive.
    + apply Z.leb_le in positive.
      rewrite write_buffer_cell_nonnegative by exact positive.
      cbn [buffer_cells].
      destruct (replace_nth (Z.to_nat address) (Initialized value) cells)
        as [cells'|]; reflexivity.
    + assert (negative : (address < 0)%Z).
      { apply Z.nle_gt. intro nonnegative.
        rewrite (proj2 (Z.leb_le 0 address) nonnegative) in positive.
        discriminate positive. }
      destruct address as [|magnitude|magnitude]; cbn in *; try lia.
      reflexivity.
  - cbn [result_bind]. reflexivity.
Qed.

Lemma write_pointwise_spec {Value} (offset : Z) (strides : list Z) :
  forall (coordinates : list (list nat)) (values : list Value) (start : nat)
         (space : address_space) (element_type : mlir_type)
         (cells : list (memory_cell Value)),
    write_pointwise {| buffer_address_space := space;
                       buffer_element_type := element_type;
                       buffer_cells := cells |} offset strides coordinates values
    = match first_error (write_bad (length cells)
              (write_entries_from offset strides start coordinates values)) with
      | Some error => Error error
      | None =>
          if Nat.eqb (length coordinates) (length values) then
            Ok {| buffer_address_space := space;
                  buffer_element_type := element_type;
                  buffer_cells :=
                    apply_updates cells
                      (write_good (length cells)
                        (write_entries_from offset strides start coordinates values)) |}
          else Error InvalidViewRank
      end.
Proof.
  intros coordinates. induction coordinates as [|coordinate rest IH];
    intros values start space element_type cells.
  - destruct values as [|value values']; reflexivity.
  - destruct values as [|value values'].
    + rewrite (write_entries_from_nil offset strides start (coordinate :: rest)).
      reflexivity.
    + rewrite (@write_pointwise_cons Value offset strides coordinate rest value
                 values' space element_type cells).
      rewrite write_entries_from_cons.
      destruct (coordinate_target offset strides coordinate) as [target|error].
      * destruct (replace_nth target (Initialized value) cells) as [cells'|]
          eqn:written.
        -- cbn [write_bad write_good write_entry_error write_entry_target
                write_entry_position write_entry_value first_error fst snd].
           destruct (Nat.ltb target (length cells)) eqn:within.
           ++ apply Nat.ltb_lt in within.
              cbn [length].
              rewrite (@IH values' (S start) space element_type cells').
              assert (cell_eq : cells' = replace_cell cells target value).
              { unfold replace_cell. rewrite written. reflexivity. }
              assert (len_eq : length cells' = length cells)
                by (rewrite cell_eq; apply length_replace_cell).
              rewrite len_eq.
              rewrite cell_eq.
              reflexivity.
           ++ exfalso. apply Nat.ltb_ge in within.
              pose proof (@replace_nth_inside _ cells target (Initialized value)
                            cells' written) as inside.
              lia.
        -- cbn [write_bad write_good write_entry_error write_entry_target
                write_entry_position write_entry_value first_error fst snd].
           pose proof (@replace_nth_none _ cells target (Initialized value)
                         written) as beyond.
           destruct (Nat.ltb target (length cells)) eqn:within.
           ++ apply Nat.ltb_lt in within. lia.
           ++ cbn [first_error]. reflexivity.
      * cbn [write_bad write_good write_entry_error write_entry_target
              write_entry_position write_entry_value first_error fst snd].
        reflexivity.
Qed.

(* The specification on the storage record, which is what the implementation
   returns, so that the two can be compared directly. *)
Lemma write_pointwise_zero {Value} (storage : buffer Value) (offset : Z)
    (strides : list Z) (coordinates : list (list nat)) (values : list Value) :
  write_pointwise storage offset strides coordinates values
  = match first_error (write_bad (length (buffer_cells storage))
              (write_entries_from offset strides 0 coordinates values)) with
    | Some error => Error error
    | None =>
        if Nat.eqb (length coordinates) (length values) then
          Ok {| buffer_address_space := buffer_address_space storage;
                buffer_element_type := buffer_element_type storage;
                buffer_cells := apply_updates (buffer_cells storage)
                    (write_good (length (buffer_cells storage))
                      (write_entries_from offset strides 0 coordinates values)) |}
        else Error InvalidViewRank
    end.
Proof.
  destruct storage as [space element_type cells].
  apply (@write_pointwise_spec Value offset strides coordinates values 0
           space element_type cells).
Qed.

(* The write half of the bulk interface: the single one-pass implementation
   agrees exactly with the pointwise specification, error order included. *)
Theorem write_coordinates_correct :
  forall (Value : Type) (storage : buffer Value) offset strides coordinates values,
    write_coordinates storage offset strides coordinates values
    = write_pointwise storage offset strides coordinates values.
Proof.
  intros Value storage offset strides coordinates values.
  rewrite write_coordinates_spec.
  rewrite write_pointwise_zero.
  reflexivity.
Qed.

(* ------------------------------------------------------------------ *)
(* Behaviour pinned by computation                                    *)
(* ------------------------------------------------------------------ *)

Definition sample_buffer (cells : list nat) : buffer nat :=
  {| buffer_address_space := ASGM;
     buffer_element_type := IndexType;
     buffer_cells := map Initialized cells |}.

(* Ascending addresses. *)
Example read_ascending :
  read_coordinates (sample_buffer [10; 11; 12]) 0%Z [1%Z]
    [[0]; [1]; [2]] = Ok [10; 11; 12].
Proof. reflexivity. Qed.

(* Descending addresses: the answers still come back in coordinate order. *)
Example read_descending :
  read_coordinates (sample_buffer [10; 11; 12]) 0%Z [1%Z]
    [[2]; [1]; [0]] = Ok [12; 11; 10].
Proof. reflexivity. Qed.

(* A coordinate whose rank does not match the view. *)
Example read_rank_mismatch :
  read_coordinates (sample_buffer [10; 11]) 0%Z [1%Z]
    [[0]; [0; 0]] = Error InvalidViewRank.
Proof. reflexivity. Qed.

(* An uninitialised cell in the middle of the range. *)
Example read_uninitialized :
  read_coordinates
    {| buffer_address_space := ASGM;
       buffer_element_type := IndexType;
       buffer_cells := [Initialized 5; Uninitialized; Initialized 7] |}
    0%Z [1%Z] [[0]; [1]; [2]] = Error ReadUninitializedCell.
Proof. reflexivity. Qed.

(* A gap between the addressed cells. *)
Example read_gap :
  read_coordinates (sample_buffer [10; 11; 12; 13; 14]) 0%Z [2%Z]
    [[0]; [1]; [2]] = Ok [10; 12; 14].
Proof. reflexivity. Qed.

(* A negative offset: the address is negative, so the pointwise path reports an
   address error, not a rank error. *)
Example read_negative_offset :
  read_coordinates (sample_buffer [10; 11; 12]) (-1)%Z [1%Z]
    [[0]; [1]] = Error ViewAddressOutOfBounds.
Proof. reflexivity. Qed.

(* A negative stride: the addresses descend, and the answers still come back in
   coordinate order. *)
Example read_negative_stride :
  read_coordinates (sample_buffer [10; 11; 12]) 2%Z [(-1)%Z]
    [[0]; [1]; [2]] = Ok [12; 11; 10].
Proof. reflexivity. Qed.

(* A negative address that stays inside the range once the strides are added:
   only the resulting sign matters, not the sign of the offset. *)
Example read_offset_cancelled :
  read_coordinates (sample_buffer [10; 11; 12]) (-2)%Z [1%Z]
    [[2]; [3]; [4]] = Ok [10; 11; 12].
Proof. reflexivity. Qed.

(* Two coordinates address the same cell: the later one wins. *)
Example write_duplicate_last_wins :
  write_coordinates (sample_buffer [0; 0; 0]) 0%Z [1%Z] [[0]; [0]; [2]]
    [1; 2; 3] = Ok (sample_buffer [2; 0; 3]).
Proof. reflexivity. Qed.

(* Duplicate addresses are resolved by the original coordinate order, not by the
   order in which the walk happens to visit the cells: here the walk writes cell
   0 before cell 2, but the winning write to cell 2 is still the last
   coordinate. *)
Example write_duplicate_interleaved :
  write_coordinates (sample_buffer [0; 0; 0]) 0%Z [1%Z] [[2]; [0]; [2]]
    [1; 2; 3] = Ok (sample_buffer [2; 0; 3]).
Proof. reflexivity. Qed.

(* A length mismatch is reported after the common prefix: the first value is
   written to a cell that exists, and the surplus coordinate is never examined. *)
Example write_length_mismatch :
  write_coordinates (sample_buffer [0; 0; 0]) 0%Z [1%Z] [[0]; [1]] [7]
  = Error InvalidViewRank.
Proof. reflexivity. Qed.

(* A per-coordinate error in the common prefix beats the length mismatch. *)
Example write_prefix_error_before_length_mismatch :
  write_coordinates (sample_buffer [0; 0; 0]) 0%Z [1%Z] [[100]; [1]] [7]
  = Error ViewAddressOutOfBounds.
Proof. reflexivity. Qed.


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
From Stdlib Require Import List ZArith PArray Uint63 Lia.
From stdpp Require Import gmap.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Memory Require Import Model.

Import ListNotations.
Open Scope Z_scope.

Lemma page_offset_value address :
  Uint63.to_Z (page_offset address) = address mod page_size.
Proof.
  unfold page_offset. rewrite Uint63.of_Z_spec.
  apply Z.mod_small.
  pose proof (Z.mod_pos_bound address page_size).
  unfold page_size in *. change Uint63.wB with 9223372036854775808. lia.
Qed.

Lemma page_offset_in_bounds Value (page : cell_page Value) address :
  Uint63.ltb (page_offset address) (PArray.length (page_data page)) = true.
Proof.
  rewrite page_length. apply Uint63.ltb_spec. rewrite page_offset_value.
  change (address mod page_size < 4096).
  apply (proj2 (Z.mod_pos_bound address page_size ltac:(unfold page_size; lia))).
Qed.

Lemma page_coordinates_injective a b :
  page_index a = page_index b -> page_offset a = page_offset b -> a = b.
Proof.
  intros Hpage Hoffset.
  apply (f_equal Uint63.to_Z) in Hoffset.
  rewrite !page_offset_value in Hoffset.
  unfold page_index in Hpage.
  pose proof (Z.div_mod a page_size ltac:(unfold page_size; lia)).
  pose proof (Z.div_mod b page_size ltac:(unfold page_size; lia)). lia.
Qed.

Lemma cells_get_set_same Value (cells : cell_storage Value) address value :
  cells_get (cells_set cells address value) address = value.
Proof.
  unfold cells_get, cells_set; cbn. rewrite lookup_insert_eq.
  cbn. apply PArray.get_set_same. apply page_offset_in_bounds.
Qed.

Lemma cells_get_set_other Value (cells : cell_storage Value) a b value :
  a <> b -> cells_get (cells_set cells a value) b = cells_get cells b.
Proof.
  intros Hne. unfold cells_get, cells_set; cbn.
  destruct (decide (page_index a = page_index b)) as [Heq|Hdiff].
  - rewrite Heq, lookup_insert_eq.
    assert (Hoffset : page_offset a <> page_offset b).
    { intros H. apply Hne. now apply page_coordinates_injective. }
    destruct (cells_pages cells !! page_index b); cbn.
    + now rewrite PArray.get_set_other.
    + rewrite PArray.get_set_other by exact Hoffset.
      change (PArray.get (PArray.make 4096%uint63 (@Uninitialized Value))
        (page_offset b) = Uninitialized).
      apply PArray.get_make.
  - rewrite lookup_insert_ne; auto.
Qed.

Lemma cells_get_empty Value size address :
  @cells_get Value (empty_cells size) address = Uninitialized.
Proof. unfold cells_get, empty_cells; cbn. now rewrite lookup_empty. Qed.

Lemma initialize_cells_length Value (values : list Value) address cells :
  cells_length (initialize_cells values address cells) = cells_length cells.
Proof.
  revert address cells. induction values; intros; cbn; auto.
  rewrite IHvalues. reflexivity.
Qed.

Lemma initialize_cells_outside Value (values : list Value) start cells address :
  address < start \/ start + Z.of_nat (List.length values) <= address ->
  cells_get (initialize_cells values start cells) address = cells_get cells address.
Proof.
  revert start cells. induction values as [|value rest IH]; intros start cells H; cbn; auto.
  rewrite IH.
  - apply cells_get_set_other. cbn in H. lia.
  - cbn in H. rewrite Nat2Z.inj_succ in H. lia.
Qed.

Lemma initialize_cells_inside Value (values : list Value) index value start cells :
  List.nth_error values index = Some value ->
  cells_get (initialize_cells values start cells) (start + Z.of_nat index) =
    Initialized value.
Proof.
  revert index start cells. induction values as [|head rest IH]; intros index start cells H.
  - destruct index; discriminate.
  - destruct index as [|index]; cbn in H; cbn.
    + inversion H; subst. rewrite initialize_cells_outside by (left; lia).
      replace (start + Z.of_nat 0) with start by lia. apply cells_get_set_same.
    + rewrite Nat2Z.inj_succ.
      replace (start + Z.succ (Z.of_nat index)) with
        (start + 1 + Z.of_nat index) by lia. now apply IH.
Qed.

Lemma cells_of_list_length Value (values : list Value) :
  cells_length (cells_of_list values) = Z.of_nat (List.length values).
Proof. unfold cells_of_list. rewrite initialize_cells_length. reflexivity. Qed.

Lemma cells_of_list_get Value (values : list Value) index value :
  List.nth_error values index = Some value ->
  cells_get (cells_of_list values) (Z.of_nat index) = Initialized value.
Proof.
  intros H. unfold cells_of_list.
  change (cells_get (initialize_cells values 0 (empty_cells (List.length values)))
    (0 + Z.of_nat index) = Initialized value).
  now apply initialize_cells_inside.
Qed.

Lemma read_after_write_same Value (storage updated : buffer Value) address value :
  write_buffer_cell storage address value = Ok updated ->
  read_buffer_cell updated address = Ok value.
Proof.
  unfold write_buffer_cell. destruct ((0 <=? address) &&
    (address <? cells_length (buffer_cells storage))) eqn:H; try discriminate.
  intros E; inversion E; subst. unfold read_buffer_cell; cbn.
  rewrite H, cells_get_set_same. reflexivity.
Qed.

Lemma read_after_write_other Value (storage updated : buffer Value) a b value :
  a <> b -> write_buffer_cell storage a value = Ok updated ->
  read_buffer_cell updated b = read_buffer_cell storage b.
Proof.
  intros Hne. unfold write_buffer_cell.
  destruct ((0 <=? a) && (a <? cells_length (buffer_cells storage))); try discriminate.
  intros E; inversion E; subst. unfold read_buffer_cell; cbn.
  rewrite cells_get_set_other by exact Hne. reflexivity.
Qed.

(* 表示关系覆盖长度和每个可读取的单元，包括未初始化单元。 *)
Definition cells_represent {Value} (cells : cell_storage Value)
    (values : list (memory_cell Value)) : Prop :=
  cells_length cells = Z.of_nat (List.length values) /\
  forall index value, values !! index = Some value ->
    cells_get cells (Z.of_nat index) = value.

Lemma lookup_nth_error A (values : list A) index :
  values !! index = List.nth_error values index.
Proof. revert index. induction values; intros []; cbn; auto. Qed.

Lemma cells_of_list_represents Value (values : list Value) :
  cells_represent (cells_of_list values) (map Initialized values).
Proof.
  split.
  - rewrite cells_of_list_length, length_map. reflexivity.
  - intros index value H. rewrite list_lookup_fmap in H.
    destruct (values !! index) as [x|] eqn:E; cbn in H; try discriminate.
    inversion H; subst. apply cells_of_list_get. now rewrite <- lookup_nth_error.
Qed.

Lemma empty_cells_represents Value size :
  cells_represent (@empty_cells Value size) (repeat Uninitialized size).
Proof.
  split.
  - cbn. now rewrite repeat_length.
  - intros index value H. rewrite lookup_nth_error in H.
    assert (value = @Uninitialized Value).
    { eapply repeat_spec. eapply nth_error_In; exact H. }
    subst. apply cells_get_empty.
Qed.

Lemma cells_set_represents Value (cells : cell_storage Value) values index value :
  cells_represent cells values ->
  cells_represent (cells_set cells (Z.of_nat index) value) (<[index := value]> values).
Proof.
  intros [Hlen Hget]. split.
  - cbn. now rewrite length_insert.
  - intros other observed H. destruct (decide (index = other)) as [->|Hne].
    + destruct (decide (other < List.length values)%nat) as [Hlt|Hge].
      * rewrite list_lookup_insert_eq in H by exact Hlt.
        inversion H; subst. apply cells_get_set_same.
      * apply lookup_lt_Some in H. rewrite length_insert in H. lia.
    + rewrite list_lookup_insert_ne in H by exact Hne.
      rewrite cells_get_set_other by lia. now apply Hget.
Qed.

Definition list_read {Value} (values : list (memory_cell Value)) address
    : result memory_error Value :=
  if address <? 0 then Error ViewAddressOutOfBounds else
  match values !! Z.to_nat address with
  | None => Error ViewAddressOutOfBounds
  | Some Uninitialized => Error ReadUninitializedCell
  | Some (Initialized value) => Ok value
  end.

Theorem read_buffer_list_equivalence Value (storage : buffer Value) values address :
  cells_represent (buffer_cells storage) values ->
  read_buffer_cell storage address = list_read values address.
Proof.
  intros [Hlen Hget]. unfold read_buffer_cell, list_read. rewrite Hlen.
  destruct (address <? 0) eqn:Hnegative.
  - apply Z.ltb_lt in Hnegative.
    assert (0 <=? address = false) as H by (apply Z.leb_gt; lia).
    now rewrite H.
  - apply Z.ltb_ge in Hnegative.
    assert (0 <=? address = true) as H by (apply Z.leb_le; lia).
    rewrite H; cbn.
    destruct (values !! Z.to_nat address) as [cell|] eqn:E.
    + assert (address <? Z.of_nat (List.length values) = true) as Hlt.
      { apply Z.ltb_lt. apply lookup_lt_Some in E. lia. }
      rewrite Hlt.
      specialize (Hget _ _ E). rewrite Z2Nat.id in Hget by lia.
      now rewrite Hget.
    + assert (address <? Z.of_nat (List.length values) = false) as Hge.
      { apply Z.ltb_ge. apply lookup_ge_None in E. lia. }
      now rewrite Hge.
Qed.

Theorem write_buffer_list_equivalence Value (storage updated : buffer Value)
    values address value :
  cells_represent (buffer_cells storage) values ->
  write_buffer_cell storage address value = Ok updated ->
  (0 <= address < Z.of_nat (List.length values)) /\
  cells_represent (buffer_cells updated)
    (<[Z.to_nat address := Initialized value]> values) /\
  buffer_address_space updated = buffer_address_space storage /\
  buffer_element_type updated = buffer_element_type storage.
Proof.
  intros Hrep. unfold write_buffer_cell.
  destruct ((0 <=? address) && (address <? cells_length (buffer_cells storage)))
    eqn:Hbounds; try discriminate.
  intros E; inversion E; subst. apply andb_true_iff in Hbounds.
  destruct Hbounds as [Hlo Hhi]. apply Z.leb_le in Hlo. apply Z.ltb_lt in Hhi.
  destruct Hrep as [Hlen Hget]. split; [lia|]. split; [|auto].
  cbn. replace address with (Z.of_nat (Z.to_nat address)) by lia.
  rewrite Nat2Z.id.
  apply cells_set_represents. split; assumption.
Qed.

Theorem write_buffer_rejects_exactly Value (storage : buffer Value) address value :
  write_buffer_cell storage address value = Error ViewAddressOutOfBounds <->
  address < 0 \/ cells_length (buffer_cells storage) <= address.
Proof.
  unfold write_buffer_cell.
  destruct (0 <=? address) eqn:Hlo;
    destruct (address <? cells_length (buffer_cells storage)) eqn:Hhi; cbn;
    try apply Z.leb_le in Hlo; try apply Z.leb_gt in Hlo;
    try apply Z.ltb_lt in Hhi; try apply Z.ltb_ge in Hhi;
    split; intros; try discriminate; try reflexivity; lia.
Qed.

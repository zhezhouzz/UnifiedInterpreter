From Stdlib Require Import List Arith ZArith Lia Sorting.Sorted Sorting.Permutation.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics.
Import ListNotations.
Set Implicit Arguments.

Section Serialized.
Context {Float Pipe Unit : Type}.
Local Notation Label := (@label Float nat Pipe Unit).
Local Notation Rec := (@event_record Float nat Pipe Unit).
Local Notation Prog := (@program Float nat Pipe Unit op_id).

Record operation_events := {
  operation_id : op_id;
  operation_head : head;
  start_label : Label;
  finish_label : option Label
}.

Definition operation_signature b := (operation_id b, operation_head b).
Definition first_event b : Rec := EventRecord (operation_id b) (start_label b).
Definition last_event b : Rec :=
  EventRecord (operation_id b)
    (match finish_label b with Some l => l | None => start_label b end).
Definition operation_records b :=
  first_event b :: match finish_label b with Some _ => [last_event b] | None => [] end.

Definition operation_shape b :=
  kind (start_label b) = start_kind (operation_head b) /\
  match finish_label b with
  | Some l => kind l = end_kind (operation_head b) /\
              start_kind (operation_head b) <> end_kind (operation_head b)
  | None => start_kind (operation_head b) = end_kind (operation_head b)
  end.

Definition start_index i := 2 * i.
Definition finish_index i b :=
  match finish_label b with Some _ => S (start_index i) | None => start_index i end.

Fixpoint event_indices (i : nat) (blocks : list operation_events) : list nat :=
  match blocks with
  | [] => []
  | b :: rest => start_index i ::
      match finish_label b with
      | Some _ => S (start_index i) :: event_indices (S i) rest
      | None => event_indices (S i) rest
      end
  end.

Definition interpret_index (blocks : list operation_events) (event : nat) : Rec :=
  match nth_error blocks (Nat.div2 event) with
  | Some b => if Nat.even event then first_event b else last_event b
  | None => EventRecord (1%positive, 1%positive) (LReturn [])
  end.

Local Lemma first_index blocks i b :
  nth_error blocks i = Some b -> interpret_index blocks (start_index i) = first_event b.
Proof. intros at_i. unfold interpret_index, start_index. now rewrite Nat.div2_double, Nat.even_mul, at_i. Qed.
Arguments first_index {blocks i b} _.

Local Lemma last_index blocks i b :
  nth_error blocks i = Some b -> interpret_index blocks (finish_index i b) = last_event b.
Proof.
  intros at_i. unfold finish_index. destruct (finish_label b) eqn:finish.
  - unfold interpret_index, start_index.
    now rewrite Nat.div2_succ_double, Nat.even_succ, Nat.odd_mul, at_i.
  - rewrite (first_index at_i). unfold last_event, first_event. now rewrite finish.
Qed.
Arguments last_index {blocks i b} _.

Local Lemma indices_spec blocks base e :
  In e (event_indices base blocks) <->
  exists i b, nth_error blocks i = Some b /\
    (e = start_index (base+i) \/ e = finish_index (base+i) b).
Proof.
  revert base. induction blocks as [|b blocks IH]; intros base; cbn [event_indices].
  - split; [contradiction | intros ([|i] & item & lookup & _); discriminate].
  - destruct (finish_label b) eqn:has_finish; cbn [In]; rewrite IH; split.
    all: try (intros [<- | [<- | (i & item & lookup & pos)]] ||
      intros [<- | (i & item & lookup & pos)]);
      try solve [exists 0,b; rewrite Nat.add_0_r; cbn; unfold finish_index; rewrite has_finish; auto
        | exists (S i),item; rewrite Nat.add_succ_r; split; assumption].
    all: intros ([|i] & item & lookup & pos).
    all: try (inversion lookup; subst item; rewrite Nat.add_0_r in pos;
      unfold finish_index in pos; rewrite has_finish in pos; intuition).
    all: rewrite Nat.add_succ_r in pos; repeat right; eauto.
Qed.

Local Lemma indices_lower_bound blocks base e :
  In e (event_indices base blocks) -> (2 * base <= e)%nat.
Proof.
  intros member. apply indices_spec in member as (i & b & _ & [-> | ->]);
    unfold finish_index, start_index; try destruct (finish_label b); lia.
Qed.

Lemma serialized_records blocks :
  map (interpret_index blocks) (event_indices 0 blocks) = flat_map operation_records blocks.
Proof.
  assert (suffix_records : forall suffix pre,
    blocks = pre ++ suffix ->
    map (interpret_index blocks) (event_indices (length pre) suffix) = flat_map operation_records suffix).
  { induction suffix as [|b suffix IH]; intros pre eq; [reflexivity |].
    assert (I : nth_error blocks (length pre) = Some b).
    { rewrite eq, nth_error_app2, Nat.sub_diag; auto. }
    pose proof (IH (pre ++ [b])) as tail.
    rewrite length_app, Nat.add_1_r in tail.
    specialize (tail ltac:(now rewrite <- app_assoc)).
    cbn [event_indices map flat_map operation_records].
    rewrite (first_index I).
    assert (last := last_index I). unfold finish_index in last.
    unfold operation_records at 1. destruct (finish_label b); cbn [map app];
      rewrite ?last, tail; reflexivity. }
  exact (suffix_records blocks [] eq_refl).
Qed.

Lemma serialized_permissions
    (allowed : Label -> Prop) blocks :
  Forall (fun b => allowed (start_label b) /\ allowed (payload (last_event b))) blocks ->
  Forall (fun e => allowed (payload (interpret_index blocks e))) (event_indices 0 blocks).
Proof.
  intros every. change (Forall (fun e => (fun r => allowed (payload r)) (interpret_index blocks e))
    (event_indices 0 blocks)). rewrite <- Forall_map, serialized_records.
  induction every as [|b rest [a z] every IH]; cbn [flat_map operation_records].
  - constructor.
  - constructor; [exact a |]. destruct (finish_label b); cbn; auto.
Qed.

Lemma operation_records_owner b e :
  In e (operation_records b) -> owner e = operation_id b.
Proof.
  unfold operation_records. destruct (finish_label b); cbn.
  - intros [<-|[<-|[]]]; reflexivity.
  - intros [<-|[]]; reflexivity.
Qed.

Lemma serialized_records_unique blocks :
  Forall operation_shape blocks -> NoDup (map operation_id blocks) ->
  NoDup (flat_map operation_records blocks).
Proof.
  induction 1 as [|b rest B Bs IH]; cbn [flat_map]; [constructor |].
  intros unique. inversion unique as [|? ? fresh tail_unique]; subst.
  specialize (IH tail_unique).
  assert (distinct : forall e, In e (operation_records b) ->
    ~ In e (flat_map operation_records rest)).
  { intros e in_b present. apply in_flat_map in present as (other & in_other & owns).
    apply operation_records_owner in in_b, owns.
    apply fresh. rewrite <- in_b, owns. now apply in_map. }
  unfold operation_records at 1. destruct (finish_label b) as [ending|] eqn:E; cbn [app].
  - constructor.
    + intros [same|in_tail].
      * destruct B as [first condition]. rewrite E in condition.
        destruct condition as [last separated].
        apply separated.
        rewrite <- first, <- last.
        fold (first_event b) in same. assert (last_event b = EventRecord (operation_id b) ending)
          by (unfold last_event; now rewrite E).
        rewrite H in same. unfold first_event in same.
        injection same as payload_eq. now rewrite payload_eq.
      * apply (distinct (first_event b)); [unfold operation_records; now left | exact in_tail].
    + constructor; [ |exact IH]. apply distinct. unfold operation_records. rewrite E. now right; left.
  - constructor; [ |exact IH]. apply distinct. unfold operation_records. now left.
Qed.

Local Lemma distinct_ids {A B} (index : A -> B) xs a b :
  NoDup (map index xs) -> In a xs -> In b xs -> index a = index b -> a = b.
Proof.
  induction xs; cbn; [tauto |]. intros unique A1 B1 same.
  inversion unique as [|? ? missing tail]; subst.
  destruct A1 as [<-|A1], B1 as [<-|B1]; auto.
  - exfalso. apply missing. rewrite same. now apply in_map.
  - exfalso. apply missing. rewrite <- same. now apply in_map.
Qed.

Lemma serialized_results p blocks uses :
  Forall operation_shape blocks -> NoDup (map operation_id blocks) ->
  (forall use, In use uses ->
    exists b, In b blocks /\ operation_id b = producer use /\
      (finish_label b = Some (LReadEnd (used_value use)) \/
       finish_label b = Some (LComputeEnd (used_value use)))) ->
  completed_result_values p (event_indices 0 blocks) (interpret_index blocks) uses.
Proof.
  intros shape unique sources use e d result member _ in_trace R _.
  destruct (sources use member) as (b & B & owner_b & oracle).
  assert (present : In (interpret_index blocks d) (flat_map operation_records blocks)).
  { rewrite <- serialized_records. now apply in_map. }
  apply in_flat_map in present as (other & O & contains).
  pose proof (operation_records_owner contains) as D.
  assert (b = other).
  { eapply distinct_ids; eauto. destruct R as [E|E]; rewrite E in D; cbn in D; congruence. }
  subst other. clear D.
  unfold operation_records, last_event in contains.
  destruct oracle as [reading | computing]; rewrite ?reading, ?computing in contains; cbn in contains;
    destruct R as [R|R]; rewrite R in contains;
    destruct contains as [bad|[same|[]]]; try congruence.
  all: pose proof (proj1 (Forall_forall _ _) shape b B) as [S _];
    unfold first_event in bad; apply (f_equal payload) in bad; cbn in bad; rewrite bad in S;
    destruct (operation_head b); discriminate.
Qed.

Local Definition ignored_by_memory (l : Label) :=
  match l with LReadEnd _ | LWriteEnd | LAlloc _ => False | _ => True end.

Inductive operation_memory (written : memory_resource -> @value Float nat Pipe -> Prop)
    : operation_events -> Prop :=
| ReadMemory o d address result :
    (forall value, written address value -> value = result) ->
    operation_memory written
      {| operation_id := o; operation_head := HRead;
         start_label := LReadStart d address; finish_label := Some (LReadEnd result) |}
| WriteMemory o d address data :
    written address data ->
    operation_memory written
      {| operation_id := o; operation_head := HWrite;
         start_label := LWriteStart d address data; finish_label := Some LWriteEnd |}
| OtherMemory b :
    ignored_by_memory (start_label b) -> ignored_by_memory (payload (last_event b)) ->
    operation_memory written b.

Local Lemma ignore_memory l o past rest :
  ignored_by_memory l ->
  TraceSemantics.memory_history (EventRecord o l :: past) rest ->
  TraceSemantics.memory_history past (EventRecord o l :: rest).
Proof. destruct l; cbn; intuition. Qed.

Local Lemma ignore_latest l o address past :
  ignored_by_memory l ->
  TraceSemantics.latest_write address (EventRecord o l :: past) =
  TraceSemantics.latest_write address past.
Proof. destruct l; cbn; intuition. Qed.

Lemma serialized_memory written blocks :
  Forall (operation_memory written) blocks ->
  memory_values (event_indices 0 blocks) (interpret_index blocks).
Proof.
  unfold memory_values. rewrite serialized_records. intros checked.
  enough (forall past, (forall a v, TraceSemantics.latest_write a past = Some v -> written a v) ->
    TraceSemantics.memory_history past (flat_map operation_records blocks)).
  { apply H. discriminate. }
  induction checked as [|b blocks B checks IH]; intros past established; [exact I|].
  cbn [flat_map]. destruct B as [o d address result agrees|o d address data stores|b starts_ignored ends_ignored].
  - change (TraceSemantics.memory_history past
      (EventRecord o (LReadStart d address) :: EventRecord o (LReadEnd result) ::
       flat_map operation_records blocks)).
    cbn [TraceSemantics.memory_history payload owner].
    split; [exact I |].
    cbn [TraceSemantics.memory_history payload owner].
    unfold TraceSemantics.prior_start. cbn [find owner payload kind option_map].
    destruct (TraceSemantics.operation_eq_dec o o); [ |congruence].
    cbn [option_map payload TraceSemantics.latest_write].
    split.
    + destruct (TraceSemantics.latest_write address past) eqn:latest; [ | exact I].
      apply agrees. now apply established.
    + apply IH. intros a v prior. now apply established in prior.
  - change (TraceSemantics.memory_history past
      (EventRecord o (LWriteStart d address data) :: EventRecord o LWriteEnd ::
       flat_map operation_records blocks)).
    cbn [TraceSemantics.memory_history payload owner].
    split; [exact I |].
    cbn [TraceSemantics.memory_history payload owner].
    unfold TraceSemantics.prior_start. cbn [find owner payload kind option_map].
    destruct (TraceSemantics.operation_eq_dec o o); [ |congruence].
    cbn [option_map payload].
    split; [exact I |].
    apply IH. intros a v prior. cbn [TraceSemantics.latest_write payload owner] in prior.
    unfold TraceSemantics.prior_start in prior. cbn [find owner payload kind option_map] in prior.
    destruct (TraceSemantics.operation_eq_dec o o); [ |congruence].
    cbn [option_map payload] in prior.
    destruct (Nat.eqb address a) eqn:same.
    + apply Nat.eqb_eq in same. inversion prior; subst; exact stores.
    + apply established. exact prior.
  - unfold operation_records, first_event. cbn [app].
    apply ignore_memory; [exact starts_ignored|].
    destruct (finish_label b) as [ending|] eqn:E; cbn [app].
    + unfold last_event in *. rewrite E in *. apply ignore_memory; [exact ends_ignored |].
      apply IH. intros a v prior. rewrite !ignore_latest in prior by assumption. now apply established.
    + apply IH. intros a v prior. rewrite ignore_latest in prior by exact starts_ignored. now apply established.
Qed.

Local Lemma indices_sorted blocks base : StronglySorted lt (event_indices base blocks).
Proof.
  revert base. induction blocks as [|b blocks IH]; intros base; cbn [event_indices].
  - constructor.
  - assert (bound : forall e, In e (event_indices (S base) blocks) ->
      (2 * S base <= e)%nat) by eauto using indices_lower_bound.
    destruct (finish_label b); constructor.
    + constructor; [apply IH |]. apply Forall_forall. intros; unfold start_index; specialize (bound _ H); lia.
    + constructor; [lia |]. apply Forall_forall. intros; unfold start_index; specialize (bound _ H); lia.
    + apply IH.
    + apply Forall_forall. intros; unfold start_index; specialize (bound _ H); lia.
Qed.

Local Lemma order_from_sorted t a b :
  StronglySorted lt t -> earlier t a b -> (a < b)%nat.
Proof.
  intros sorted. induction sorted as [|x t sorted IH all];
    intros ([|i] & [|j] & I & J & lt); cbn in I,J; try discriminate; try lia.
  - inversion I; subst a. apply Forall_forall with (x := b) in all; eauto using nth_error_In.
  - apply IH. exists i,j. auto with arith.
Qed.

Local Lemma order_in_sorted t a b :
  StronglySorted lt t -> In a t -> In b t -> (a < b)%nat -> earlier t a b.
Proof.
  intros sorted. induction sorted as [|x t sorted IH all]; cbn; [tauto |].
  intros [<-|A] [<-|B] lt; try lia.
  - apply In_nth_error in B as (j & J). exists 0, (S j). cbn. auto with arith.
  - apply Forall_forall with (x := a) in all; auto. lia.
  - destruct (IH A B lt) as (i & j & I & J & early).
    exists (S i),(S j). cbn. auto with arith.
Qed.

Local Lemma nth_injective_keys {A B} (f : A -> B) xs i j a b :
  NoDup (map f xs) -> nth_error xs i = Some a -> nth_error xs j = Some b ->
  f a = f b -> i = j /\ a = b.
Proof.
  intros unique I J same.
  assert (mapped_i : nth_error (map f xs) i = Some (f a)) by now rewrite nth_error_map, I.
  assert (mapped_j : nth_error (map f xs) j = Some (f a)) by now rewrite nth_error_map, J, same.
  assert (i = j).
  { apply (proj1 (NoDup_nth_error _) unique); try congruence. apply nth_error_Some; congruence. }
  subst j. split; congruence.
Qed.
Arguments nth_injective_keys {A B} f {xs i j a b} _ _ _ _.

Section WellFormedSerialization.
Context (p : Prog) (blocks : list operation_events).
Hypothesis shape : Forall operation_shape blocks.
Hypothesis unique : NoDup (map operation_id blocks).
Hypothesis signatures : forall o h, In (o,h) (program_operations p) <->
  exists b, In b blocks /\ operation_id b = o /\ operation_head b = h.

Local Notation t := (event_indices 0 blocks).
Local Notation k := (interpret_index blocks).

Local Lemma block_for_head i b h :
  nth_error blocks i = Some b -> In (operation_id b,h) (program_operations p) ->
  operation_head b = h.
Proof.
  intros I member. apply signatures in member as (other & member & same & H).
  apply In_nth_error in member as (j & J).
  destruct (nth_injective_keys operation_id unique J I same) as [_ ->]. exact H.
Qed.

Local Lemma start_and_finish i b :
  nth_error blocks i = Some b ->
  starts p t k (operation_id b) (start_index i) /\
  finishes p t k (operation_id b) (finish_index i b).
Proof.
  intros I.
  assert (member : In b blocks) by eauto using nth_error_In.
  assert (op : In (operation_id b, operation_head b) (program_operations p)).
  { apply signatures. eauto. }
  pose proof (proj1 (Forall_forall _ _) shape b member) as [S E].
  split; unfold starts, finishes, event_at; [rewrite (first_index I) | rewrite (last_index I)];
    split; [apply indices_spec; exists i,b; auto | | apply indices_spec; exists i,b; auto |].
  - split; [reflexivity |]. exists (operation_head b). auto.
  - split; [reflexivity |]. exists (operation_head b). split; auto.
    unfold last_event. destruct (finish_label b); cbn in *; intuition congruence.
Qed.

Local Lemma identify_start o e :
  starts p t k o e ->
  exists i b, nth_error blocks i = Some b /\ operation_id b = o /\ e = start_index i.
Proof.
  intros (member & own & h & op & kind_eq).
  apply indices_spec in member as (i & b & I & [-> | ->]).
  - cbn [Nat.add] in own. rewrite (first_index I) in own. exists i,b; auto.
  - cbn [Nat.add] in own, kind_eq. rewrite (last_index I) in own, kind_eq. cbn in own. subst o.
    rewrite <- (block_for_head i h I op) in kind_eq.
    pose proof (proj1 (Forall_forall _ _) shape b (nth_error_In _ i I)) as [_ E].
    exists i,b. split; auto. split; auto.
    unfold finish_index. unfold last_event in kind_eq.
    destruct (finish_label b); cbn in *; intuition congruence.
Qed.

Local Lemma identify_finish o e :
  finishes p t k o e ->
  exists i b, nth_error blocks i = Some b /\ operation_id b = o /\ e = finish_index i b.
Proof.
  intros (member & own & h & op & kind_eq).
  apply indices_spec in member as (i & b & I & [-> | ->]).
  - cbn [Nat.add] in own, kind_eq. rewrite (first_index I) in own, kind_eq. cbn in own. subst o.
    rewrite <- (block_for_head i h I op) in kind_eq.
    pose proof (proj1 (Forall_forall _ _) shape b (nth_error_In _ i I)) as [S E].
    exists i,b. split; auto. split; auto.
    unfold finish_index. destruct (finish_label b); cbn in *; intuition congruence.
  - cbn [Nat.add] in own. rewrite (last_index I) in own. exists i,b; auto.
Qed.

Local Lemma ordered_between i j a b e f :
  nth_error blocks i = Some a -> nth_error blocks j = Some b -> (i < j)%nat ->
  (e = start_index i \/ e = finish_index i a) ->
  (f = start_index j \/ f = finish_index j b) ->
  earlier t e f.
Proof.
  intros A B order position_e position_f.
  apply order_in_sorted; try apply indices_sorted.
  - apply indices_spec. eauto.
  - apply indices_spec. eauto.
  - destruct position_e as [->| ->], position_f as [->| ->];
      unfold finish_index in *; repeat match goal with |- context [finish_label ?x] =>
        destruct (finish_label x) end; unfold start_index; lia.
Qed.

Theorem serialized_order :
  (forall o u, In (o,u) (po p) -> exists h, In (o,h) (program_operations p)) ->
  (forall i j a b, nth_error blocks i = Some a -> nth_error blocks j = Some b ->
    In (operation_id a, operation_id b) (po p) -> (i < j)%nat) ->
  A1 p t k /\ A2 p t k /\ A3 p t k /\ A5 p t k.
Proof.
  intros source_head branch_order. refine (conj _ (conj _ (conj _ _))).
  - intros o h op phases e E. destruct (identify_finish E) as (i & b & I & <- & ->).
    destruct (start_and_finish i I) as [start finish].
    exists (start_index i). split; auto.
    apply order_in_sorted; [apply indices_sorted | exact (proj1 start) | exact (proj1 finish) |].
    pose proof (proj1 (Forall_forall _ _) shape b (nth_error_In _ i I)) as [_ Eshape].
    rewrite <- (block_for_head i h I op) in phases.
    unfold finish_index. destruct (finish_label b); cbn in *; lia || contradiction.
  - intros o u edge. split.
    + intros e E. destruct (identify_start E) as (j & b & J & <- & ->).
      assert (member : exists h, In (o,h) (program_operations p)).
      { eauto. }
      destruct member as (h & H). apply signatures in H as (a & A & own & _).
      apply In_nth_error in A as (i & I). subst o.
      exists (start_index i). split; [exact (proj1 (start_and_finish i I)) |].
      eapply ordered_between; [exact I | exact J | eapply branch_order; eassumption | now left | now left].
    + intros e E. destruct (identify_start E) as (j & b & J & <- & ->).
      assert (member : exists h, In (o,h) (program_operations p)).
      { eauto. }
      destruct member as (h & H). apply signatures in H as (a & A & own & _).
      apply In_nth_error in A as (i & I). subst o.
      destruct (start_and_finish i I) as [start finish].
      assert (I_before_J : (i < j)%nat) by eauto.
      destruct (nonblocking (operation_head a)) eqn:nb.
      * exists (start_index i). split.
        2: { eapply ordered_between; [exact I | exact J | exact I_before_J | now left | now left]. }
        destruct start as (member & own & h' & op & S).
        pose proof (block_for_head i h' I op) as same; subst h'.
        split; auto. split; auto. exists (operation_head a). split; auto.
        unfold gate_kind. now rewrite nb.
      * exists (finish_index i a). split.
        2: { eapply ordered_between; [exact I | exact J | exact I_before_J | now right | now left]. }
        destruct finish as (member & own & h' & op & phase).
        pose proof (block_for_head i h' I op) as same; subst h'.
        split; auto. split; auto. exists (operation_head a). split; auto.
        unfold gate_kind. now rewrite nb.
  - intros f o p0 op (s & v & S & V & _ & _ & order) e E.
    destruct (identify_start S) as (i & a & I & <- & ->).
    destruct (identify_start V) as (j & b & J & <- & ->).
    destruct (identify_finish E) as (j' & b' & J' & own & ->).
    destruct (nth_injective_keys operation_id unique J' J own) as [-> ->].
    exists (finish_index i a). split; [exact (proj2 (start_and_finish i I)) |].
    apply (order_from_sorted (indices_sorted blocks 0)) in order.
    eapply ordered_between; [exact I | exact J | | now right | now right].
    unfold start_index in order; lia.
  - intros w u p0 op (s & v & S & V & _ & _ & order) e E.
    destruct (identify_start S) as (i & a & I & <- & ->).
    destruct (identify_start V) as (j & b & J & <- & ->).
    destruct (identify_start E) as (j' & b' & J' & own & ->).
    destruct (nth_injective_keys operation_id unique J' J own) as [-> ->].
    exists (finish_index i a). split; [exact (proj2 (start_and_finish i I)) |].
    apply (order_from_sorted (indices_sorted blocks 0)) in order.
    eapply ordered_between; [exact I | exact J | | now right | now left].
    unfold start_index in order; lia.
Qed.

Definition block_flag source target flag b letter :=
  match letter with
  | FlagSet => start_label b = LSetFlagStart source target flag /\
               kind (payload (last_event b)) = SetFlagEnd
  | FlagWait => start_label b = LWaitFlagStart source target flag /\
                kind (payload (last_event b)) = WaitFlagEnd
  end.

Local Lemma flag_at_last source target flag letter i b :
  nth_error blocks i = Some b ->
  flag_projection p t k source target flag (finish_index i b) letter <->
  block_flag source target flag b letter.
Proof.
  intros I. split.
  - intros (o & s & S & E & flag_spec).
    assert (same_owner : operation_id b = o).
    { destruct E as [_ [O _]]. rewrite (last_index I) in O. exact O. }
    destruct (identify_start S) as (j & item & J & O & ->).
    assert (owner_eq : operation_id item = operation_id b) by congruence.
    destruct (nth_injective_keys operation_id unique J I owner_eq) as [-> ->].
    rewrite (first_index I), (last_index I) in flag_spec.
    exact flag_spec.
  - intros flag_spec. destruct (start_and_finish i I) as [S E].
    exists (operation_id b), (start_index i). split; [exact S|]. split; [exact E|].
    rewrite (first_index I), (last_index I). exact flag_spec.
Qed.

Local Lemma flag_not_first source target flag letter i b :
  nth_error blocks i = Some b -> ~ flag_projection p t k source target flag (start_index i) letter.
Proof.
  intros I (o & s & _ & _ & signal).
  rewrite (first_index I) in signal.
  pose proof (proj1 (Forall_forall _ _) shape b (nth_error_In _ i I)) as [S _].
  destruct letter; destruct signal as [_ E]; cbn [first_event payload] in E;
    rewrite S in E; destruct (operation_head b); discriminate.
Qed.

Theorem serialized_flags source target flag word :
  projection (block_flag source target flag) blocks word ->
  projection (flag_projection p t k source target flag) t word.
Proof.
  intros marked.
  enough (forall suffix word' pre, blocks = pre ++ suffix ->
    projection (block_flag source target flag) suffix word' ->
    projection (flag_projection p t k source target flag) (event_indices (length pre) suffix) word').
  { exact (H blocks word [] eq_refl marked). }
  intros suffix word' pre eq proj. revert pre eq.
  induction proj as [|b rest letter word' B projected IH|b rest word' absent projected IH]; intros pre eq.
  - constructor.
  - assert (I : nth_error blocks (length pre) = Some b)
      by (rewrite eq, nth_error_app2, Nat.sub_diag; auto).
    assert (next : projection (flag_projection p t k source target flag)
      (event_indices (S (length pre)) rest) word').
    { pose proof (IH (pre ++ [b]) ltac:(now rewrite <- app_assoc)) as tail.
      now rewrite length_app, Nat.add_1_r in tail. }
    destruct (finish_label b) as [l|] eqn:end_of_block; cbn [event_indices]; rewrite end_of_block.
    + apply ProjectSkip.
      * intros [found evidence]. eapply flag_not_first; eauto.
      * apply ProjectKeep; [ |exact next].
        pose proof (proj2 (flag_at_last source target flag letter (length pre) I) B) as observed.
        unfold finish_index in observed. now rewrite end_of_block in observed.
    + exfalso. apply (flag_not_first (source:=source) (target:=target)
        (flag:=flag) (letter:=letter) (length pre) I).
      pose proof (proj2 (flag_at_last source target flag letter (length pre) I) B) as observed.
      unfold finish_index in observed. now rewrite end_of_block in observed.
  - assert (I : nth_error blocks (length pre) = Some b)
      by (rewrite eq, nth_error_app2, Nat.sub_diag; auto).
    assert (next : projection (flag_projection p t k source target flag)
      (event_indices (S (length pre)) rest) word').
    { pose proof (IH (pre ++ [b]) ltac:(now rewrite <- app_assoc)) as tail.
      now rewrite length_app, Nat.add_1_r in tail. }
    cbn [event_indices]. destruct (finish_label b) eqn:end_of_block;
      apply ProjectSkip; try exact next;
      try solve [intros [found evidence]; eapply flag_not_first; eauto].
    apply ProjectSkip; [ |exact next].
    intros [letter seen]. apply absent. exists letter.
    apply (proj1 (flag_at_last source target flag letter (length pre) I)).
    unfold finish_index. now rewrite end_of_block.
Qed.

End WellFormedSerialization.

Definition access_completed (t : list nat) (k : nat -> Rec) e :=
  match kind (payload (k e)) with
  | ReadStart | WriteStart =>
      exists d, In d t /\
        owner (k d) = owner (k e) /\
        earlier t e d /\
        kind (payload (k d)) =
          (match kind (payload (k e)) with
           | ReadStart => ReadEnd | _ => WriteEnd end)
  | _ => True
  end.

Lemma serialized_accesses_complete blocks :
  Forall operation_shape blocks ->
  Forall (access_completed (event_indices 0 blocks) (interpret_index blocks))
    (event_indices 0 blocks).
Proof.
  intros shapes. apply Forall_forall. intros e member. unfold access_completed.
  apply indices_spec in member as (i & b & I & position_e).
  cbn [Nat.add] in position_e.
  pose proof (proj1 (Forall_forall _ _) shapes b (nth_error_In _ i I)) as [S E].
  assert (start_done : access_completed (event_indices 0 blocks)
    (interpret_index blocks) (start_index i)).
  { unfold access_completed. rewrite (first_index I). cbn [first_event payload]. rewrite S.
    destruct (operation_head b) eqn:H; try exact Logic.I.
    all: destruct (finish_label b) as [finish|] eqn:F; [ |discriminate].
    all: exists (finish_index i b);
      assert (In (finish_index i b) (event_indices 0 blocks)) by (apply indices_spec; eauto);
      split; [assumption |]; split; [rewrite (last_index I); reflexivity |]; split.
    all: try solve [apply order_in_sorted; [apply indices_sorted |
       apply indices_spec; eauto | assumption | unfold finish_index; rewrite F; lia ]].
    all: rewrite (last_index I); unfold last_event; rewrite F; exact (proj1 E). }
  destruct position_e as [->| ->]; [exact start_done |].
  destruct (finish_label b) as [finish|] eqn:F.
  - rewrite (last_index I). unfold last_event. rewrite F. cbn [payload].
    rewrite (proj1 E). destruct (operation_head b); exact Logic.I.
  - unfold finish_index. now rewrite F.
Qed.
End Serialized.

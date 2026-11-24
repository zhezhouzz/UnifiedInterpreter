From Stdlib Require Import List Bool Arith Lia.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Export SerializedTrace Issue316Safety.
Import ListNotations.
Set Implicit Arguments.

Definition local_key p q e := Key false 0 p (Data q) e.
Definition free_keys := [local_key Vector MTE2 0; local_key Vector MTE2 1].

Definition initial_image {F16} count (input : nat -> tile F16) : memory (kernel_domains F16) :=
  fun i => if i =? output_index then Some Uninit else if (3 <=? i) && (i <? 3+count) then
    Some (Stored (@VFloat (kernel_domains F16) (input (i-3))))
  else None.

Section Overlap.
Context {F16 : Type} (exp_f16 : F16 -> F16) (input : nat -> tile F16).
Local Notation D := (kernel_domains F16).
Local Notation id_addr := (fun a : nat => a).
Local Notation H := (kernel_hw id_addr exp_f16).
Local Notation image := (initial_image 2 input).
Local Definition tile_op f a b := @Operation D f [@VView D a;@VView D b] [a] [b].
Local Definition fire p (it : item D) delta :=
  [Issued 0 (Submit p it); Done 0 p 0 it delta].
Local Definition release k : item D := SetItem false (Data MTE2) k.
Local Definition acquire k : item D := WaitItem false Vector k.
Local Definition in_tile i := Stored (@VFloat D (input i)).

(* 第 0 轮 Vector 操作和第 1 轮 MTE2 操作都已发射，均位于各自队首。 *)
Definition overlap_prefix : list (event D) :=
  [Issued 0 (reserve id_addr 0);Issued 0 (reserve id_addr 1)] ++
  fire Vector (release 0) [] ++ fire Vector (release 1) [] ++
  repeat (Issued 0 Control) 5 ++ fire MTE2 (acquire 0) [] ++
  fire MTE2 (tile_op load_op (src_index 0) 0) [(0,in_tile 0)] ++
  fire MTE2 (SetItem false (Data Vector) 0) [] ++ fire Vector (WaitItem false MTE2 0) [] ++
  [Issued 0 (op Vector exp_op 0 output_index);Issued 0 (put Vector MTE2 0);Issued 0 (Fence (Pipe Vector))] ++
  repeat (Issued 0 Control) 5 ++ fire MTE2 (acquire 1) [] ++
  [Issued 0 (op MTE2 load_op (src_index 1) 1)].
Local Definition load_next := Done 0 MTE2 0 (tile_op load_op (src_index 1) 1) [(1,in_tile 1)].
Local Definition compute_first := Done 0 Vector 0 (tile_op exp_op 0 output_index)
  [(output_index,transform exp_f16 exp_op (in_tile 0))].
Theorem issue316_load_compute_overlap :
  let o := history H [0] (initial image) overlap_prefix in
  opened_access o 0 MTE2 0 [src_index 1] [1] /\ opened_access o 0 Vector 0 [0] [output_index] /\
  issue316_trace id_addr exp_f16 2 image (overlap_prefix ++ [load_next;compute_first]) /\
  contents (history H [0] o [load_next;compute_first]) output_index =
    Some (Stored (@VFloat D (fun j => exp_f16 (input 0 j)))).
Proof.
  cbn zeta. split; [do 2 eexists; split; reflexivity|].
  split; [do 2 eexists; split; reflexivity|]. split; [|reflexivity].
  split.
  - split.
    + constructor; [|constructor]. cbn [fst snd]. rewrite issue316_plan.
      exists ([put MTE2 Vector 1;take MTE2 Vector 1;op Vector exp_op 1 output_index;
        put Vector MTE2 1;Fence (Pipe Vector)] ++ cleanup). reflexivity.
    + repeat constructor; simpl; auto.
  - apply checked_laws. vm_compute.
    repeat first [split | constructor | solve [intuition congruence] | eexists | reflexivity].
Qed.
End Overlap.

Section Execution.
Context {F16 : Type} (addr : nat -> nat) (exp_f16 : F16 -> F16).
Hypothesis injective : forall i j, addr i = addr j -> i=j.
Local Notation D := (kernel_domains F16).
Local Notation H := (kernel_hw addr exp_f16).
Local Notation O := (observations D).
Variable count : nat.
Definition allocated n i := i<n \/ 2<=i<3+count.
Record ready n keys (o : O) : Prop := {
  drained : forall s p, pending o s p = [];
  flags : forall k, token o k = true <-> In k keys;
  storage : forall i, i<3+count -> (exists c, contents o (addr i) = Some c) <-> allocated n i
}.
Definition builds n ks m ls acts :=
  forall o, ready n ks o -> fragment H [0] 0 o acts (ready m ls).
Lemma chain n ks m ls r rs x y :
  builds n ks m ls x -> builds m ls r rs y -> builds n ks r rs (x++y).
Proof. intros X Y o R. eapply fragment_append; [apply X; exact R|exact Y]. Qed.
Lemma same_keys n ks ls : (forall k, In k ks <-> In k ls) -> builds n ks n ls [].
Proof.
  intros E o [Q F M]. apply fragment_nil. constructor; auto. intro k. rewrite F. apply E.
Qed.
Lemma control n ks : builds n ks n ks [Control].
Proof.
  intros o R. exists [Issued 0 Control]. split; [cbv; auto|].
  split; [repeat constructor|]. split; [reflexivity|destruct o; exact R].
Qed.
Lemma reserve_one n ks : n<2 -> builds n ks (S n) ks [reserve addr n].
Proof.
  intros B o [Q F M]. assert (N : contents o (addr n) = None).
  { destruct (contents o (addr n)) eqn:E; auto. exfalso.
    assert (allocated n n) by (apply (M n ltac:(lia)); eauto). unfold allocated in *; lia. }
  exists [Issued 0 (reserve addr n)]. split.
  { cbn [checked allowed reserve queue_law flag_law memory_law allocation kernel_hw].
    repeat split; auto. }
  split; [repeat constructor|]. split; [reflexivity|].
  constructor; [exact Q|exact F|]. intros i L.
  change ((exists c, update (contents o) (addr n) (Some Uninit) (addr i) = Some c) <-> allocated (S n) i).
  unfold update. destruct (Nat.eqb (addr i) (addr n)) eqn:E.
  - apply Nat.eqb_eq, injective in E. subst. split; [unfold allocated; lia|eauto].
  - rewrite M by exact L. apply Nat.eqb_neq in E. assert (i<>n) by congruence. unfold allocated; lia.
Qed.

Definition eager o p (it : item D) delta :=
  after H [0] (after H [0] o (Issued 0 (Submit p it))) (Done 0 p 0 it delta).
Lemma eager_fragment n ks o p it delta (post : O -> Prop) :
  ready n ks o -> flag_law H [0] o (Done 0 p 0 it delta) ->
  memory_law H o (Done 0 p 0 it delta) -> post (eager o p it delta) ->
  fragment H [0] 0 o [Submit p it] post.
Proof.
  intros R F M K. exists [Issued 0 (Submit p it);Done 0 p 0 it delta].
  split; [|split; [repeat constructor|split; [reflexivity|exact K]]].
  cbn [checked]. split; [repeat split|]. split; [|exact I]. unfold allowed. split.
  - unfold queue_law. cbn [after pending]. rewrite !Nat.eqb_refl, (drained R).
    destruct it; split; reflexivity.
  - destruct it; exact (conj F M).
Qed.
Lemma eager_empty o p it delta : (forall s q, pending o s q = []) ->
  forall s q, pending (eager o p it delta) s q = [].
Proof.
  intros Q s q. unfold eager. cbn [after pending]. rewrite Q.
  destruct ((s =? 0) && (q =? p)); reflexivity.
Qed.
Lemma put_one n ks p q f : ~ In (local_key p q f) ks ->
  builds n ks n (local_key p q f :: ks) [put p q f].
Proof.
  intros K o R. apply (eager_fragment p (SetItem false (Data q) f) [] _ R).
  - constructor; [|constructor]. change (token o (local_key p q f) = false).
    destruct (token o _) eqn:T; auto. exfalso. apply K, (flags R); exact T.
  - reflexivity.
  - constructor; [apply eager_empty, (drained R)| |exact (storage R)].
    intro k. change ((if in_dec key_eq k [local_key p q f] then true else token o k)=true <-> In k (local_key p q f :: ks)).
    destruct (in_dec key_eq k [local_key p q f]) as [I|N]; simpl in *.
    + intuition.
    + rewrite (flags R); intuition.
Qed.
Lemma take_one n ks p q f : In (local_key p q f) ks ->
  builds n ks n (remove key_eq (local_key p q f) ks) [take p q f].
Proof.
  intros K o R. apply (eager_fragment q (WaitItem false p f) [] _ R).
  - apply (flags R); exact K.
  - reflexivity.
  - constructor; [apply eager_empty, (drained R)| |exact (storage R)].
    intro k. change ((if key_eq k (local_key p q f) then false else token o k)=true <-> In k (remove key_eq (local_key p q f) ks)).
    destruct (key_eq k (local_key p q f)) as [->|N].
    + split; [discriminate|intro I; exfalso; exact (remove_In _ _ _ I)].
    + rewrite (flags R). split; [apply in_in_remove; congruence|apply in_remove].
Qed.
Lemma operation ks p f i j : i<3+count -> j<3+count ->
  builds 2 ks 2 ks [op p f (addr i) (addr j)].
Proof.
  intros Bi Bj o R. assert (A : forall k, k<3+count -> exists c, contents o (addr k) = Some c)
    by (intros k B; apply (storage R B); unfold allocated; lia).
  destruct (A i Bi) as [c C]. set (v := transform exp_f16 f c).
  apply (eager_fragment p (@Operation D f [@VView D (addr i);@VView D (addr j)] [addr i] [addr j]) [(addr j,v)] _ R).
  - exact I.
  - cbn [memory_law]. split.
    + repeat constructor; apply A; assumption.
    + split; [repeat constructor; simpl; tauto|]. split; [apply incl_refl|].
      exists [(addr i,c)]. split; [unfold sample; simpl; now rewrite C|].
      exists (addr i),(addr j),c. auto.
  - constructor; [apply eager_empty, (drained R)|exact (flags R)|].
    intros k L. change ((exists w, update (contents o) (addr j) (Some v) (addr k) = Some w) <-> allocated 2 k).
    unfold update. destruct (addr k =? addr j) eqn:E; [|apply (storage R L)].
    apply Nat.eqb_eq, injective in E. subst. split; [unfold allocated; lia|eauto].
Qed.
Lemma fence_vector n ks : builds n ks n ks [Fence (Pipe Vector)].
Proof.
  intros o [Q F M]. exists [Issued 0 (Fence (Pipe Vector));Done 0 Vector 0 BarItem []].
  split.
  - cbn [checked]. unfold allowed,queue_law,flag_law,memory_law.
    cbn [after pending barriers existsb Nat.eqb andb orb Vector]. rewrite Q. repeat split.
  - split; [repeat constructor|]. split; [reflexivity|]. constructor; [|exact F|exact M].
    intros s p. cbn [history fold_left after pending barriers]. rewrite Q.
    destruct s as [|s], p as [|[|p]]; reflexivity.
Qed.
Lemma fence_all n ks : builds n ks n ks [Fence All].
Proof.
  intros o [Q F M]. exists [Issued 0 (Fence All);Done 0 MTE2 0 BarItem [];Done 0 Vector 0 BarItem []].
  split.
  - cbn [checked allowed queue_law flag_law memory_law after pending
      kernel_hw data_pipes barriers MTE2 Vector existsb Nat.eqb andb orb].
    unfold allowed, queue_law. cbn [after pending barriers kernel_hw data_pipes
      MTE2 Vector existsb Nat.eqb andb orb]. rewrite !Q. repeat split.
  - split; [repeat constructor|]. split; [reflexivity|].
    constructor; [|exact F|exact M]. intros s p.
    cbn [history fold_left after pending barriers data_pipes kernel_hw MTE2 Vector].
    rewrite Q. destruct s as [|s], p as [|[|p]]; reflexivity.
Qed.

Ltac solve_keys := vm_compute; intuition congruence.
(* 把一条源动作与其后的轨迹拼接；中间令牌集由对应引理推断。 *)
Ltac next_action rule :=
  lazymatch goal with |- builds ?a ?b ?c ?d (?x :: ?xs) =>
    change (builds a b c d ([x] ++ xs));
    eapply chain; [apply rule|] end.
Lemma setup_ready : builds 0 [] 2 free_keys (setup addr).
Proof.
  unfold setup. do 2 (next_action reserve_one; [lia|]).
  do 2 (next_action put_one; [solve_keys|]). apply same_keys. solve_keys.
Qed.
Lemma turn_ready i : i<count -> builds 2 free_keys 2 free_keys (turn addr i).
Proof.
  intro B. unfold turn,turn_with,slot. destruct (Nat.even i).
  all: do 5 (next_action control).
  all: next_action take_one; [solve_keys|].
  all: next_action operation; [unfold src_index; lia|lia|].
  all: next_action put_one; [solve_keys|].
  all: next_action take_one; [solve_keys|].
  all: next_action operation; [lia|unfold output_index; lia|].
  all: next_action put_one; [solve_keys|].
  all: next_action fence_vector. all: apply same_keys; solve_keys.
Qed.
Lemma loop_ready xs : Forall (fun i => i<count) xs ->
  builds 2 free_keys 2 free_keys (flat_map (turn addr) xs).
Proof.
  intro B. induction B; cbn [flat_map]; [apply same_keys; tauto|].
  apply chain with (m:=2) (ls:=free_keys); auto using turn_ready.
Qed.
Lemma cleanup_ready : builds 2 free_keys 2 [] cleanup.
Proof.
  unfold cleanup. next_action control. do 2 (next_action take_one; [solve_keys|]).
  next_action fence_all. apply same_keys. solve_keys.
Qed.
Definition initial_layout (m : memory D) :=
  forall i, i<3+count -> (exists c, m (addr i) = Some c) <-> allocated 0 i.
Theorem issue316_complete_trace_exists m : initial_layout m ->
  exists t, issue316_trace addr exp_f16 count m t /\
    program_semantics H kernel_params issue316 (kernel_env addr count) m t /\
    terminated H (kernel_alloc addr) issue316 (kernel_env addr count) m t /\
    (forall k, token (history H [0] (initial m) t) k = false) /\
    (forall side, addresses side t = buffer_sequence addr count).
Proof.
  intro M. assert (S : builds 0 [] 2 [] (actions addr count)).
  { unfold actions. eapply chain; [apply setup_ready|]. eapply chain; [apply loop_ready|apply cleanup_ready].
    apply Forall_forall. intros i I. apply in_seq in I. lia. }
  assert (R : ready 0 [] (initial m)).
  { constructor; [reflexivity|intro k; simpl; intuition discriminate|exact M]. }
  destruct (S _ R) as [t [C [Own [A EndState]]]].
  assert (T : issue316_trace addr exp_f16 count m t).
  { split; [split|exact (checked_laws H [0] (initial m) t C)].
    - constructor; [|constructor]. cbn [fst snd]. rewrite issue316_plan, A.
      exists []. now rewrite app_nil_r.
    - rewrite Forall_forall in *. intros e I. specialize (Own e I).
      change (In (owner e) [0]). rewrite Own. now left. }
  exists t. split; [exact T|]. split.
  - split; [apply issue316_well_formed|]. split; [intros s [|[|[|[|x]]]] _; reflexivity|exists (kernel_alloc addr); exact T].
  - split.
    + split; [constructor; [cbn [fst snd]; rewrite issue316_plan,A; reflexivity|constructor]|apply (drained EndState)].
    + split.
      * intro k. destruct (token _ k) eqn:E; auto. apply (flags EndState) in E. contradiction.
      * intro side. unfold addresses. rewrite A. apply selected_actions.
Qed.
End Execution.

Corollary issue316_complete_trace_for_all_counts {F16} (exp_f16 : F16 -> F16) input count :
  let addr := fun i : nat => i in let m := initial_image count input in
  exists t, issue316_trace addr exp_f16 count m t /\
    program_semantics (kernel_hw addr exp_f16) kernel_params issue316 (kernel_env addr count) m t /\
    terminated (kernel_hw addr exp_f16) (kernel_alloc addr) issue316 (kernel_env addr count) m t /\
    (forall k, token (history (kernel_hw addr exp_f16) [0] (initial m) t) k = false) /\
    (forall side, addresses side t = buffer_sequence addr count).
Proof.
  cbn zeta. apply issue316_complete_trace_exists; [auto|].
  intros i B. unfold initial_image,allocated,output_index. destruct (Nat.eqb_spec i 2) as [->|N].
  { split; [lia|eauto]. }
  destruct (Nat.leb_spec0 3 i), (Nat.ltb_spec0 i (3+count));
    simpl; split; intros; try lia; eauto; destruct H; discriminate.
Qed.

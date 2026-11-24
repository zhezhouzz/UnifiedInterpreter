From Stdlib Require Import List ZArith Lia Sorting.Permutation Sorting.Sorted.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Issue316 TraceSemantics.
Import ListNotations.
Set Implicit Arguments.

Local Lemma prefix_map {A B} (f : A -> list B) xs ys :
  prefix xs ys -> prefix (flat_map f xs) (flat_map f ys).
Proof. intros [suffix ->]. rewrite flat_map_app. eexists; reflexivity. Qed.

Local Lemma prefix_transitive {A} (a b c : list A) :
  prefix a b -> prefix b c -> prefix a c.
Proof. intros [x ->] [y ->]. exists (x ++ y). symmetry; apply app_assoc. Qed.

(* 一个分支已观察到的发起事件必须包含每个已发起命令的所有前驱。 *)
Local Lemma ordered_prefix {A} (requires : A -> A -> Prop) (xs ys : list A) :
  StronglySorted requires xs -> NoDup xs -> NoDup ys -> incl ys xs ->
  (forall pre b post a, ys = pre ++ b :: post -> requires a b -> In a xs -> In a pre) ->
  prefix ys xs.
Proof.
  intros sorted. revert ys. induction sorted as [|a xs sorted IH successors];
    intros [|b ys] unique observed subset prior.
  - exists []; reflexivity.
  - exfalso. apply (subset b). now left.
  - exists (a::xs); reflexivity.
  - inversion unique as [|? ? fresh tail_unique]; subst.
    inversion observed as [|? ? fresh_b tail_observed]; subst.
    destruct (subset b (or_introl eq_refl)) as [same | later].
    2: { exfalso. apply (prior [] b ys a eq_refl); [ | now left].
         exact (proj1 (Forall_forall _ _) successors b later). }
    subst b. destruct (IH ys tail_unique tail_observed) as [suffix eq].
    + intros x member. destruct (subset x (or_intror member)); congruence || assumption.
    + intros pre x post y eq edge member.
      destruct (prior (a :: pre) x post y (f_equal (cons a) eq) edge (or_intror member));
        congruence || assumption.
    + exists suffix. cbn. now rewrite eq.
Qed.

Inductive subsequence {A : Type} : list A -> list A -> Prop :=
| SubEmpty ys : subsequence [] ys
| SubKeep a xs ys : subsequence xs ys -> subsequence (a::xs) (a::ys)
| SubSkip a xs ys : subsequence xs ys -> subsequence xs (a::ys).

Local Lemma sub_incl {A} (xs ys : list A) : subsequence xs ys -> incl xs ys.
Proof. induction 1; unfold incl in *; cbn; intuition. Qed.

Local Lemma sub_app {A} (a b c d : list A) :
  subsequence a b -> subsequence c d -> subsequence (a++c) (b++d).
Proof. intros left right. induction left; cbn; auto using SubKeep, SubSkip.
  induction ys; cbn; auto using SubSkip. Qed.

Local Lemma sub_unique {A B} (f : A -> B) xs ys :
  subsequence xs ys -> NoDup (map f ys) -> NoDup (map f xs).
Proof.
  induction 1; cbn; intros unique; [constructor | | ]; inversion unique; subst; auto.
  constructor; auto. intros member. apply in_map_iff in member as (v & eq & member).
  match goal with H : ~ In _ _ |- _ => apply H end. rewrite <- eq. apply in_map. eapply sub_incl; eauto.
Qed.

Definition event_head k :=
  match k with
  | ReadStart | ReadEnd => HRead | WriteStart | WriteEnd => HWrite
  | ComputeStart | ComputeEnd => HCompute | SetFlagStart | SetFlagEnd => HSetFlag
  | WaitFlagStart | WaitFlagEnd => HWaitFlag | BranchEvent => HIf
  | ReturnEvent => HReturn | PipeAssignment => HAssignPipe
  | AtomicEvent => HAtomic | AllocEvent => HAlloc end.

Definition is_start k :=
  match k with ReadEnd | WriteEnd | ComputeEnd | SetFlagEnd | WaitFlagEnd => false
  | _ => true end.

Section BranchOrder.
Context {F E P U : Type}.
Local Notation Rec := (@event_record F E P U).
Local Notation Cmd := (@command F E P U op_id).
Local Notation Model := (@computation_model F E P U).
Definition start_list (events : list Rec) := filter (fun r => is_start (kind (payload r))) events.
Definition descriptor (r : Rec) := (owner r, event_head (kind (payload r))).

Local Lemma generated_ops layout (model : Model) rho c es uses :
  command_events layout model rho c es uses ->
  subsequence (map descriptor (start_list es)) (operations c).
Proof.
  induction 1; cbn in *; auto using SubEmpty, SubKeep.
  apply SubKeep. destruct b.
  - rewrite <- (app_nil_r (map _ _)). apply sub_app; auto using SubEmpty.
  - change (subsequence ([] ++ map descriptor (start_list events)) (operations yes ++ operations no)).
    apply sub_app; auto using SubEmpty.
Qed.

Local Lemma sorted_weaken {A} (R S : A -> A -> Prop) xs :
  (forall a b, R a b -> S a b) -> StronglySorted R xs -> StronglySorted S xs.
Proof. intros weak sorted. induction sorted as [|a l s IH all]; constructor; auto.
  apply Forall_forall; intros b member. apply weak. exact (proj1 (Forall_forall _ _) all b member).
Qed.

Local Lemma generated_owner layout (model : Model) rho c es uses r :
  command_events layout model rho c es uses -> In r (start_list es) -> In (owner r) (op_ids c).
Proof.
  intros gen member. apply in_map_iff. exists (descriptor r); split; [reflexivity |].
  eapply sub_incl; [exact (generated_ops gen) | now apply in_map].
Qed.

Local Lemma generated_order layout (model : Model) rho c es uses :
  command_events layout model rho c es uses ->
  StronglySorted (fun a b => In (owner a, owner b) (program_order c)) (start_list es).
Proof.
  intros gen. induction gen; cbn; try assumption; try constructor; try constructor.
  all: try match goal with H : command_events _ _ _ (if ?b then _ else _) _ _ |- _ =>
    destruct b; cbn in * end.
  all: try solve [eapply sorted_weaken; [ | eassumption]; intros; apply in_or_app; right;
    first [assumption | apply in_or_app; auto]].
  all: apply Forall_forall; intros r member; apply in_or_app; left;
    apply in_map_iff; exists (owner r); split; [reflexivity |];
    first [eapply generated_owner; eassumption | apply in_or_app; eauto using generated_owner].
Qed.
End BranchOrder.

Local Lemma split_filtered {A} (f : A -> bool) xs pre b post :
  filter f xs = pre ++ b :: post ->
  exists left right, xs = left ++ b :: right /\ filter f left = pre.
Proof.
  revert pre. induction xs as [|a xs IH]; intros pre eq; cbn in eq.
  - destruct pre; discriminate.
  - destruct (f a) eqn:F.
    + destruct pre as [|v pre]; injection eq as -> eq.
      * exists [], xs. auto.
      * destruct (IH _ eq) as (l & r & -> & Hl). exists (v::l), r.
        cbn. rewrite F,Hl. auto.
    + destruct (IH _ eq) as (l & r & -> & Hl). exists (a::l), r.
      cbn. rewrite F,Hl. auto.
Qed.

Local Lemma earlier_in_left {A B} (f : A -> B) t a b left right :
  earlier t a b -> NoDup (map f t) -> map f t = left ++ f b :: right -> In (f a) left.
Proof.
  intros (i & j & I & J & lt) unique eq.
  assert (at_i : nth_error (map f t) i = Some (f a)) by now rewrite nth_error_map, I.
  assert (at_j : nth_error (map f t) j = Some (f b)) by now rewrite nth_error_map, J.
  assert (j = length left).
  { apply (proj1 (NoDup_nth_error _) unique); [apply nth_error_Some; congruence |].
    rewrite at_j, eq, nth_error_app2, Nat.sub_diag; auto. }
  rewrite eq, nth_error_app1 in at_i by lia. eauto using nth_error_In.
Qed.

Local Lemma unique_key {A B} (key : A -> B) xs :
  NoDup (map key xs) -> forall a b, In a xs -> In b xs -> key a = key b -> a = b.
Proof.
  induction xs; cbn; [tauto |]. intros unique x y X Y same.
  inversion unique as [|? ? absent tail]; subst.
  destruct X as [<-|X], Y as [<-|Y]; auto.
  - exfalso. apply absent. rewrite same. now apply in_map.
  - exfalso. apply absent. rewrite <- same. now apply in_map.
Qed.

Section TraceOrder.
Context {F E P U : Type}.
Local Notation Rec := (@event_record F E P U).
Local Notation Prog := (@program F E P U op_id).
Local Notation Kappa := (@interpretation F E P U).
Definition on_branch (j : positive) (r : Rec) :=
  andb (is_start (kind (payload r))) (Pos.eqb (thread (owner r)) j).

Local Lemma branch_sub j candidates :
  subsequence (filter (on_branch j) candidates) (start_list candidates).
Proof.
  unfold on_branch, start_list. induction candidates as [|r rs IH]; cbn; [constructor |].
  destruct (is_start (kind (payload r))); cbn; auto.
  destruct (Pos.eqb _ _); auto using SubKeep, SubSkip.
Qed.

Local Lemma chronological_branch (p : Prog) t (k : Kappa) j candidates xs :
  A2 p t k -> NoDup (map k t) -> incl (map k t) candidates ->
  NoDup (map owner (start_list candidates)) ->
  incl (map descriptor (start_list candidates)) (program_operations p) ->
  xs = filter (on_branch j) candidates ->
  StronglySorted (fun a b => In (owner a, owner b) (po p)) xs ->
  prefix (filter (on_branch j) (map k t)) xs.
Proof.
  intros order unique subset ids ops eq sorted.
  assert (member : forall r, In r xs -> In r (start_list candidates) /\ on_branch j r = true).
  { intros r. rewrite eq, filter_In. intros [I test]. split; auto.
    unfold start_list. apply filter_In. split; auto. apply Bool.andb_true_iff in test; tauto. }
  assert (included : incl (filter (on_branch j) (map k t)) xs).
  { rewrite eq. intros r. rewrite !filter_In. intuition. }
  apply ordered_prefix with (requires := fun a b => In (owner a,owner b) (po p)); auto.
  - apply NoDup_map_inv with (f := owner).
    rewrite eq. eapply sub_unique; [apply branch_sub | exact ids].
  - now apply NoDup_filter.
  - intros pre b post a cut edge a_in.
    destruct (split_filtered _ _ _ _ _ cut) as (left & right & whole & projected).
    assert (b_in : In b (map k t)) by (rewrite whole; apply in_or_app; right; now left).
    apply in_map_iff in b_in as (eb & <- & eb_in).
    assert (in_xs : In (k eb) xs) by (apply included; rewrite cut; apply in_or_app; right; now left).
    destruct (member _ in_xs) as [bst _]. destruct (member _ a_in) as [ast active].
    assert (bs : starts p t k (owner (k eb)) eb).
    { repeat split; auto. exists (event_head (kind (payload (k eb)))). split.
      - apply ops. exact (in_map descriptor _ _ bst).
      - apply filter_In in bst as [_ test]. destruct (kind (payload (k eb))); easy. }
    destruct (proj1 (order _ _ edge) eb bs) as (ea & (ea_in & own & h & _ & phase) & before_b).
    assert (ea_start : In (k ea) (start_list candidates)).
    { apply filter_In. split; [apply subset; now apply in_map |].
      rewrite phase. destruct h; reflexivity. }
    assert (same : k ea = a) by (eapply unique_key; eauto).
    rewrite <- projected. apply filter_In. split; auto. rewrite <- same.
    eapply earlier_in_left; eauto.
Qed.
End TraceOrder.

Section Addresses.
Context {F16 : Type}.
Context (allocation : allocation_layout).
Local Notation V := (@value (@Tile F16) nat issue_pipe).
Local Notation Arg := (@operand (@Tile F16) nat issue_pipe).
Local Notation Cmd := (@command (@Tile F16) nat issue_pipe issue_resource).
Local Notation Model := (@computation_model (@Tile F16) nat issue_pipe issue_resource).
Local Notation Rec := (@event_record (@Tile F16) nat issue_pipe issue_resource).

Inductive side := Moving | Computing.
Definition addresses side (r : Rec) :=
  match side with Moving => transferred (payload r) | Computing => consumed (payload r) end.
Definition tracked side reading unit :=
  match side, reading, unit with Moving, false, TransferEngine | Computing, true, VectorUnit => true
  | _,_,_ => false end.
Definition expected_pipe side := match side with Moving => MTE2 | Computing => Vector end.

(* 只传播已知值。异步读取与计算可以返回任意数据，地址证明不需要选取这些值。 *)
Local Definition facts := var -> option V.
Local Definition assign (env : facts) x v : facts := fun y => if Nat.eqb x y then v else env y.
Local Definition lookup (env : facts) (v : Arg) :=
  match v with Literal a => Some a | OVar x => env x end.
Local Fixpoint arguments env vs :=
  match vs with
  | [] => Some []
  | v::rest => match lookup env v, arguments env rest with
               | Some a, Some args => Some (a::args) | _,_ => None end
  end.
Local Definition known_result env f vs :=
  match arguments env vs with Some args => eval_atomic f args | None => None end.
Local Definition access side reading env (d : execution issue_resource Arg) v
    (tail : option (list memory_resource)) :=
  if tracked side reading (resource d) then
    match queue d, lookup env v with
    | Some q, Some (VMemory a) =>
      match lookup env q, expected_pipe side with
      | Some (VPipe MTE2), MTE2 | Some (VPipe Vector), Vector => option_map (cons a) tail
      | _,_ => None end
    | _,_ => None end
  else tail.

Local Fixpoint summary {L} side env (c : Cmd L) : option (list memory_resource) :=
  match c with
  | Return _ _ => Some []
  | CAlias x v n => summary side (assign env x (lookup env v)) n
  | Select x b y z n =>
      match lookup env b with
      | Some (VBool test) => summary side (assign env x (lookup env (if test then y else z))) n
      | _ => None end
  | LetAtomic _ x f vs n => summary side (assign env x (known_result env f vs)) n
  | CCompute _ x _ _ n => summary side (assign env x None) n
  | Read _ x d a n => access side true env d a (summary side (assign env x None) n)
  | Write _ d a _ n => access side false env d a (summary side env n)
  | SetFlag _ _ _ _ n | WaitFlag _ _ _ _ n => summary side env n
  | _ => None end.

Local Lemma summary_labels {A B} (c : Cmd A) side (f : positive -> B) path env :
  summary side env (label_paths f path c) = summary side env c.
Proof.
  revert env path. induction c; intros; cbn; try reflexivity; try apply IHc;
    try (rewrite IHc; reflexivity).
  destruct (lookup env condition) as [[]|]; cbn; auto.
Qed.

Local Definition agrees env (rho : @environment (@Tile F16) nat issue_pipe) :=
  forall x v, env x = Some v -> rho x = Some (Known v).
Local Lemma lookup_agrees env rho : agrees env rho -> forall a v,
  lookup env a = Some v -> resolve rho a = Some (Known v).
Proof. intros H [l|x] v eq; cbn in *; congruence || eauto. Qed.
Local Lemma bind_agrees env rho x v b : agrees env rho ->
  (forall a, v = Some a -> b = Known a) -> agrees (assign env x v) (bind rho x b).
Proof. intros ag same y a. unfold assign,bind. destruct (Nat.eqb x y); intros eq;
  [now rewrite (same _ eq) | eauto]. Qed.
Local Lemma operand_known env rho o j v a uses : agrees env rho ->
  operand_value rho o j v a uses -> forall k, lookup env v = Some k -> a = k.
Proof. intros ag use k known. apply (lookup_agrees ag) in known. inversion use; congruence. Qed.
Local Lemma arguments_known env rho o j vs args uses : agrees env rho ->
  operand_values rho o j vs args uses -> forall vals, arguments env vs = Some vals -> args = vals.
Proof.
  intros ag values. induction values; intros vals eq; cbn in eq; [congruence |].
  destruct (lookup env v) eqn:one, (arguments env vs) eqn:tail_values; inversion eq; subst.
  f_equal; eauto using operand_known.
Qed.

Local Lemma prefix_push {A} (a:A) xs ys : prefix xs ys -> prefix (a::xs) (a::ys).
Proof. intros [rest ->]. exists rest. reflexivity. Qed.

Local Ltac take_values := repeat match goal with
  | h : execution_values _ _ _ _ _ _ _ |- _ => inversion h; subst; clear h
  | h : operand_values _ _ _ (_ :: _) _ _ |- _ => inversion h; subst; clear h
  | h : operand_values _ _ _ [] _ _ |- _ => inversion h; subst; clear h
  end.

Local Lemma access_sound side reading env rho o d v args pipe addr data uses tail expected :
  agrees env rho ->
  execution_values rho o (v :: args) (queue d) pipe (VMemory addr :: data) uses ->
  access side reading env d v tail = Some expected ->
  exists rest, tail = Some rest /\ expected =
    (if tracked side reading (resource d) then [addr] else []) ++ rest /\
    (tracked side reading (resource d) = true -> pipe = Some (expected_pipe side)).
Proof.
  intros ag vals. unfold access. destruct (tracked _ _ _) eqn:tracking; cbn.
  2: { intros eq; eauto; eexists; repeat split; eauto; discriminate. }
  destruct d as [unit [q|]]; cbn; [ | discriminate].
  destruct (lookup env v) as [[]|] eqn:av; try discriminate.
  destruct (lookup env q) as [[]|] eqn:qv; try discriminate.
  destruct p, (expected_pipe side); try discriminate; destruct tail; try discriminate;
    intros eq; inversion eq; subst; take_values;
    repeat match goal with h : operand_value _ _ _ _ _ _ |- _ =>
      let same := fresh "actual" in
      first [pose proof (operand_known ag h av) as same | pose proof (operand_known ag h qv) as same | idtac]; clear h end;
    eexists; repeat split; congruence.
Qed.

Local Lemma summary_sound side layout (model : Model) rho c es uses :
  command_events layout model rho c es uses -> forall env expected, agrees env rho ->
  summary side env c = Some expected -> prefix (flat_map (addresses side) es) expected.
Proof.
  intros gen. induction gen; intros env expected ag check; cbn in check;
    try discriminate; try solve [exists expected; reflexivity].
  - eapply IHgen; [ |exact check]. apply bind_agrees; auto. intros a ha.
    pose proof (lookup_agrees ag _ ha). congruence.
  - destruct (lookup env condition) as [[]|] eqn:test; try discriminate.
    pose proof (lookup_agrees ag _ test). assert (b0 = b) by congruence. subst b0.
    eapply IHgen; [ |exact check]. apply bind_agrees; auto.
    intros a ha. pose proof (lookup_agrees ag _ ha). congruence.
  - destruct side; cbn; eapply IHgen; [ |exact check | |exact check];
      apply bind_agrees; auto; intros a; unfold known_result;
      destruct (arguments env vs) eqn:known; try discriminate;
      pose proof (arguments_known ag H known); subst; congruence.
  - destruct (access_sound side true d _ ag H check) as (rest' & tail & -> & issued).
    assert (next : prefix (flat_map (addresses side) events) rest').
    { eapply IHgen; [ |exact tail]. apply bind_agrees; auto; discriminate. }
    destruct d as [unit q], side, unit; cbn in *; try (rewrite issued by reflexivity);
      cbn; auto using prefix_push; destruct p as [[]|]; exact next.
  - destruct side; cbn; eapply IHgen; [ |exact check | |exact check];
      apply bind_agrees; auto; discriminate.
  - destruct (access_sound side false d _ ag H check) as (rest' & tail & -> & issued).
    specialize (IHgen _ _ ag tail).
    destruct d as [unit q], side, unit; cbn in *; try (rewrite issued by reflexivity);
      cbn; auto using prefix_push; destruct p as [[]|]; exact IHgen.
  - destruct side; cbn; eauto.
  - destruct side; cbn; eauto.
  - destruct side; inversion check; exists []; reflexivity.
Qed.

Definition iteration_buffer (index : nat) :=
  if Z.eqb (Z.of_nat index mod 2) 0 then buffer_a allocation else buffer_b allocation.
Definition buffer_sequence count := map iteration_buffer (seq 0 count).

Local Definition stable (env : facts) pipe :=
  env bufA = Some (VMemory (buffer_a allocation)) /\
  env bufB = Some (VMemory (buffer_b allocation)) /\
  env active = Some (VPipe pipe).
Local Definition iterations index indices (body next : Cmd unit) :=
  fold_right (fun k n => CAlias index (integer (Z.of_nat k)) (expand_loops body n)) next indices.

Local Lemma loop_summary branch view count indices env :
  stable env (expected_pipe branch) ->
  summary view env (iterations i indices
    (match branch with Moving => load_iteration count | Computing => vector_iteration end)
    (Return tt [])) =
  Some (match branch,view with Moving,Moving | Computing,Computing => map iteration_buffer indices
        | _,_ => [] end).
Proof.
  revert env. induction indices as [|k indices IH]; intros env (A & B & p).
  - destruct branch,view; reflexivity.
  - match goal with |- summary _ _ (iterations _ _ ?body ?n) = ?rhs =>
      change (summary view env (CAlias i (integer (Z.of_nat k))
        (expand_loops body (iterations i indices body n))) = rhs) end.
    destruct branch,view; cbv beta iota zeta delta
      [load_iteration vector_iteration choose_slot fence expand_loops summary
       current access tracked expected_pipe known_result arguments lookup integer pipe_arg flag
       eval_atomic assign Nat.eqb bufA bufB active i slot first buf ready free src x y
       iteration_buffer map resource queue] in *.
    all: change (Z.eqb 2 0) with false in *; cbv beta iota zeta in *.
    all: destruct (Z.eqb (Z.of_nat k mod 2) 0); cbv beta iota zeta;
      rewrite ?A, ?B, ?p; cbv beta iota zeta delta [option_map].
    all: rewrite IH; [reflexivity | unfold stable; cbn; auto].
Qed.
Local Lemma init_summary view indices next result :
  (forall env, stable env Vector -> summary view env next = Some result) ->
  forall env, stable env Vector ->
    summary view env (iterations s indices initially_free next) = Some result.
Proof.
  intros continuation. induction indices as [|k indices IH]; intros env stable_env; [now apply continuation |].
  change (summary view env (CAlias s (integer (Z.of_nat k))
    (expand_loops initially_free (iterations s indices initially_free next))) = Some result).
  cbv beta iota zeta delta [summary expand_loops initially_free known_result arguments lookup
    assign Nat.eqb integer eval_atomic s initial initialFirst flag].
  destruct (Z.eqb (Z.of_nat k) 0); apply IH; exact stable_env.
Qed.

Local Definition expected branch view count :=
  match branch,view with Moving,Moving | Computing,Computing => buffer_sequence count
  | _,_ => [] end.

Local Lemma source_summaries count view :
  map (summary view (fun _ => None)) (expand_program (@branches F16 allocation count)) =
  [Some (expected Moving view count); Some (expected Computing view count)].
Proof.
  unfold branches, issue316, expand_program, instantiate_shared. cbn [List.map expand_loops].
  change (summary view
    (assign (assign (assign (fun _ => None) bufA (Some (VMemory (buffer_a allocation))))
      bufB (Some (VMemory (buffer_b allocation)))) active (Some (VPipe MTE2)))
    (iterations i (seq 0 (count - 0)) (load_iteration count) (Return tt [])) ::
    summary view
    (assign (assign (assign (fun _ => None) bufA (Some (VMemory (buffer_a allocation))))
      bufB (Some (VMemory (buffer_b allocation)))) active (Some (VPipe Vector)))
    (iterations s (seq 0 (Nat.min 2 count - 0)) initially_free
        (iterations i (seq 0 (count - 0)) vector_iteration (Return tt []))) :: [] =
        [Some (expected Moving view count); Some (expected Computing view count)]).
  rewrite !Nat.sub_0_r. f_equal.
  - apply (loop_summary Moving view count (seq 0 count)); repeat split.
  - f_equal. apply init_summary; [intros env stable_env | repeat split].
    exact (loop_summary Computing view count (seq 0 count) stable_env).
Qed.

Local Lemma addresses_of_starts view es :
  flat_map (addresses view) (start_list es) = flat_map (addresses view) es.
Proof.
  induction es as [|[o l] es IH]; [reflexivity |].
  destruct view,l; cbn [start_list filter flat_map is_start kind payload]; cbn;
    fold (start_list es); rewrite ?IH; reflexivity.
Qed.

Local Lemma thread_filter j tid (es : list Rec) :
  (forall r, In r (start_list es) -> thread (owner r) = tid) ->
  filter (on_branch j) es = if Pos.eqb tid j then start_list es else [].
Proof.
  intros threaded. induction es as [|r es IH]; [destruct (Pos.eqb _ _); reflexivity |].
  change ((if on_branch j r then r :: filter (on_branch j) es else filter (on_branch j) es) =
    (if Pos.eqb tid j then
      (if is_start (kind (payload r)) then r::start_list es else start_list es) else [])).
  unfold on_branch at 1.
  destruct (is_start (kind (payload r))) eqn:test; cbn [andb].
  - assert (tid_eq : thread (owner r) = tid).
    { apply threaded. apply filter_In; cbn; auto. }
    rewrite tid_eq, IH.
    + destruct (Pos.eqb tid j); reflexivity.
    + intros v H. apply threaded. apply filter_In in H. apply filter_In; cbn; tauto.
  - apply IH. intros v H. apply threaded. apply filter_In in H. apply filter_In; cbn; tauto.
Qed.

Local Lemma observed_branches layout (model : Model) c d a b au bu t k :
  command_events layout model empty_environment c a au ->
  command_events layout model empty_environment d b bu ->
  annotations_valid [c;d] -> A2 [c;d] t k ->
  NoDup (map k t) -> incl (map k t) (a++b) ->
  prefix (filter (on_branch 1) (map k t)) (start_list a) /\
  prefix (filter (on_branch 2) (map k t)) (start_list b).
Proof.
  intros ga gb [unique threads] order nodup member.
  assert (ta : forall r, In r (start_list a) -> thread (owner r) = 1%positive).
  { intros r h. apply (threads 0 c eq_refl). eauto using generated_owner. }
  assert (tb : forall r, In r (start_list b) -> thread (owner r) = 2%positive).
  { intros r h. apply (threads 1 d eq_refl). eauto using generated_owner. }
  assert (sub : subsequence (map descriptor (start_list (a++b))) (program_operations [c;d])).
  { unfold start_list; rewrite filter_app, map_app. cbn [program_operations concat map].
    rewrite app_nil_r. apply sub_app; eauto using generated_ops. }
  assert (ids : NoDup (map owner (start_list (a++b)))).
  { apply (sub_unique fst sub) in unique. now rewrite map_map in unique. }
  split; eapply chronological_branch with (candidates:=a++b) (p:=[c;d]); eauto using sub_incl.
  - rewrite filter_app, (thread_filter _ _ ta), (thread_filter _ _ tb); cbn; now rewrite app_nil_r.
  - eapply sorted_weaken; [ | exact (generated_order ga)]. intros; apply in_or_app; auto.
  - rewrite filter_app, (thread_filter _ _ ta), (thread_filter _ _ tb); reflexivity.
  - eapply sorted_weaken; [ | exact (generated_order gb)]. intros; apply in_or_app; right.
    apply in_or_app; auto.
Qed.

Local Lemma filter_addresses view j es :
  (forall r, In r es -> on_branch j r = false -> addresses view r = []) ->
  flat_map (addresses view) (filter (on_branch j) es) = flat_map (addresses view) es.
Proof.
  induction es as [|r es IH]; cbn; auto. intros only. destruct (on_branch j r) eqn:test;
    cbn; rewrite IH by (intros; apply only; auto).
  - reflexivity.
  - rewrite only; auto.
Qed.

Local Lemma candidates_on_branch view j a b trace :
  incl trace (a++b) ->
  (forall r, In r (start_list a) -> thread (owner r) = j) ->
  flat_map (addresses view) b = [] ->
  forall r, In r trace -> on_branch j r = false -> addresses view r = [].
Proof.
  intros subset threaded empty r hr off. apply subset, in_app_or in hr as [ha|hb].
  - unfold on_branch in off. destruct (is_start (kind (payload r))) eqn:test.
    + assert (thread (owner r) = j) by (apply threaded; apply filter_In; auto).
      now rewrite H, Pos.eqb_refl in off.
    + destruct r as [o l]; destruct view,l; cbn in *; congruence.
  - destruct (addresses view r) as [|v vs] eqn:eq; auto. exfalso.
    assert (In v (flat_map (addresses view) b)).
    { apply in_flat_map. exists r; rewrite eq; cbn; auto. }
    now rewrite empty in H.
Qed.

Local Lemma flat_after_map {A B C} (f : A -> B) (g : B -> list C) xs :
  flat_map g (map f xs) = flat_map (fun x => g (f x)) xs.
Proof. induction xs; cbn; congruence. Qed.

Theorem issue316_buffer_selection exp_f16 (model : Model) count t kappa :
  issue316_trace allocation exp_f16 model count t kappa ->
  prefix (flat_map (fun e => transferred (payload (kappa e))) t) (buffer_sequence count) /\
  prefix (flat_map (fun e => consumed (payload (kappa e))) t) (buffer_sequence count).
Proof.
  intros [_ [_ (p & [shape valid] & _ & _ & (uses & witness & sync & _) & _)]].
  assert (size : length p = 2).
  { apply (f_equal (@length _)) in shape.
    rewrite length_map in shape. exact shape. }
  destruct p as [|c [|d [|extra rest]]]; cbn in size; try discriminate.
  destruct witness as (events & ordered & gen & unique & perm & suffix & cut).
  inversion gen; subst; clear gen.
  match goal with h : program_events _ _ [_] _ _ |- _ => inversion h; subst; clear h end.
  match goal with h : program_events _ _ [] _ _ |- _ => inversion h; subst; clear h end.
  rewrite !app_nil_r in *.
  match goal with ga : command_events _ _ _ c ?a _, gb : command_events _ _ _ d ?b _ |- _ =>
    rename a into left_events, b into right_events, ga into left_gen, gb into right_gen end.
  assert (included : incl (map kappa t) (left_events ++ right_events)).
  { intros r hr. eapply Permutation_in; [apply Permutation_sym; exact perm |].
    apply in_or_app; auto. }
  assert (unique_trace : NoDup (map kappa t)).
  { apply (Permutation_NoDup perm) in unique. now apply NoDup_app_remove_r in unique. }
  destruct sync as [_ [order _]].
  destruct (observed_branches left_gen right_gen valid order unique_trace included) as [left right].
  assert (summaries : forall view,
    prefix (flat_map (addresses view) left_events) (expected Moving view count) /\
    prefix (flat_map (addresses view) right_events) (expected Computing view count)).
  { intros view. pose proof (source_summaries count view) as both. unfold branches in both.
    rewrite <- shape in both.
    cbn [map] in both. unfold erase_annotations in both. rewrite !summary_labels in both.
    injection both as sc sd. split; eapply summary_sound; eauto; intros v w; discriminate. }
  destruct (summaries Moving) as [load_ok no_load], (summaries Computing) as [no_vector vector_ok].
  apply prefix_map with (f:=addresses Moving) in left.
  apply prefix_map with (f:=addresses Computing) in right.
  rewrite addresses_of_starts in left,right.
  apply prefix_transitive with (c:=buffer_sequence count) in left; [ |exact load_ok].
  apply prefix_transitive with (c:=buffer_sequence count) in right; [ |exact vector_ok].
  destruct valid as [_ threads].
  assert (empty_prefix : forall l : list memory_resource, prefix l [] -> l = []).
  { intros [|v l] [suffix' eq]; congruence || discriminate. }
  rewrite filter_addresses in left.
  2: { eapply candidates_on_branch; [exact included | | exact (empty_prefix _ no_load)].
       intros r member. apply (threads 0 c eq_refl); eauto using generated_owner. }
  assert (swapped : incl (map kappa t) (right_events ++ left_events)).
  { intros r hr. specialize (included _ hr). apply in_app_or in included.
    apply in_or_app; tauto. }
  rewrite filter_addresses in right.
  2: { eapply candidates_on_branch; [exact swapped | | exact (empty_prefix _ no_vector)].
       intros r member. apply (threads 1 d eq_refl); eauto using generated_owner. }
  rewrite flat_after_map in left,right. exact (conj left right).
Qed.

Corollary issue316_iteration_address exp_f16 (model : Model) count t kappa index addr :
  issue316_trace allocation exp_f16 model count t kappa ->
  (nth_error (flat_map (fun e => transferred (payload (kappa e))) t) index = Some addr \/
   nth_error (flat_map (fun e => consumed (payload (kappa e))) t) index = Some addr) ->
  index < count /\ addr = iteration_buffer index.
Proof.
  intros legal. destruct (issue316_buffer_selection legal) as [writes reads].
  assert (at_index : forall xs, prefix xs (buffer_sequence count) ->
    nth_error xs index = Some addr -> index < count /\ addr = iteration_buffer index).
  { intros xs [suffix whole] observed.
    assert (inside : index < length xs) by (apply nth_error_Some; congruence).
    assert (selected : nth_error (buffer_sequence count) index = Some addr).
    { now rewrite whole, nth_error_app1. }
    unfold buffer_sequence in selected. rewrite nth_error_map, nth_error_seq in selected.
    destruct (Nat.ltb index count) eqn:valid; [ | discriminate].
    split; [now apply Nat.ltb_lt | cbn in selected; congruence]. }
  intros [write | read]; eauto.
Qed.
End Addresses.

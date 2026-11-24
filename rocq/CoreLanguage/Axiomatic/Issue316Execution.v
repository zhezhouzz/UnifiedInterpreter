From Stdlib Require Import List Bool Arith ZArith Lia Sorting.Permutation Sorting.Sorted.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Issue316 Issue316Safety SerializedTrace TraceSemantics.
Import ListNotations.
Set Implicit Arguments.

Section Execution.
Context {F16 : Type} (layout : allocation_layout).
Local Notation Tile := (@Issue316.Tile F16).
Local Notation Val := (@value Tile nat issue_pipe).
Local Notation Tag := (@label Tile nat issue_pipe issue_resource).
Local Notation Block := (@operation_events Tile issue_pipe issue_resource).
Local Notation Use := (@use_record Tile nat issue_pipe).
Local Notation Cmd := (@command Tile nat issue_pipe issue_resource).
Local Notation Model := (@computation_model Tile nat issue_pipe issue_resource).
Context (exp_f16 : F16 -> F16) (model : Model) (input : Tile).
Hypothesis computes : implements_vexp exp_f16 model.

Local Definition path depth : positive := Nat.iter depth xO 1%positive.
Local Definition position j depth : op_id := (j, path depth).
Local Definition atomic j depth op args result : Block :=
  {| operation_id := position j depth; operation_head := HAtomic;
     start_label := LAtomic op args result; finish_label := None |}.
Local Definition returning j depth : Block :=
  {| operation_id := position j depth; operation_head := HReturn;
     start_label := LReturn []; finish_label := None |}.
Local Definition asynchronous j depth h start finish : Block :=
  {| operation_id := position j depth; operation_head := h;
     start_label := start; finish_label := Some finish |}.
Local Definition setting j depth p q f :=
  asynchronous j depth HSetFlag (LSetFlagStart p q f) LSetFlagEnd.
Local Definition waiting j depth p q f :=
  asynchronous j depth HWaitFlag (LWaitFlagStart p q f) LWaitFlagEnd.
Local Definition reading j depth d a :=
  asynchronous j depth HRead (LReadStart d a) (LReadEnd (VFloat input)).
Local Definition writing j depth d a data :=
  asynchronous j depth HWrite (LWriteStart d a data) LWriteEnd.
Local Definition exponentiating j depth :=
  asynchronous j depth HCompute
    (LComputeStart (Dispatch VectorUnit (Some Vector)) [VFloat input])
    (LComputeEnd (VFloat (map_tile exp_f16 input))).

Local Definition slot_index k := (Z.of_nat k mod 2)%Z.
Local Definition first_slot k := Z.eqb (slot_index k) 0.
Local Definition ready_flag k : nat := if first_slot k then 0 else 1.
Local Definition free_flag k : nat := if first_slot k then 2 else 3.
Local Definition source k : memory_resource := 2 * S k.
Local Definition turn_prefix j depth k :=
  [atomic j (1+depth) IntMod [VInt (Z.of_nat k); VInt 2] (VInt (slot_index k));
   atomic j (2+depth) IntEq [VInt (slot_index k); VInt 0] (VBool (first_slot k))].

(* 每轮的路径从循环变量绑定开始，位移也计入没有事件的 Select。 *)
Local Definition move_blocks count depth k : list Block :=
  turn_prefix 1%positive depth k ++
  [atomic 1%positive (6+depth) (MemoryAt (input_addresses count))
      [VInt (Z.of_nat k)] (VMemory (source k));
   waiting 1%positive (7+depth) Vector MTE2 (free_flag k);
   reading 1%positive (8+depth) (Dispatch TransferEngine (Some MTE2)) (source k);
   setting 1%positive (9+depth) MTE2 MTE2 4;
   waiting 1%positive (10+depth) MTE2 MTE2 4;
   writing 1%positive (11+depth) (Dispatch TransferEngine (Some MTE2))
      (iteration_buffer layout k) (VFloat input);
   setting 1%positive (12+depth) MTE2 Vector (ready_flag k)].
Local Definition move_uses depth : list Use :=
  [UseRecord (position 1%positive (11+depth)) 2
     (position 1%positive (8+depth)) (VFloat input)].

Local Definition vector_blocks depth k : list Block :=
  turn_prefix 2%positive depth k ++
  [waiting 2%positive (6+depth) MTE2 Vector (ready_flag k);
   reading 2%positive (7+depth) (Dispatch VectorUnit (Some Vector)) (iteration_buffer layout k);
   setting 2%positive (8+depth) Vector Vector 4;
   waiting 2%positive (9+depth) Vector Vector 4;
   exponentiating 2%positive (10+depth);
   setting 2%positive (11+depth) Vector Vector 4;
   waiting 2%positive (12+depth) Vector Vector 4;
   writing 2%positive (13+depth) (Dispatch VectorUnit (Some Vector))
      output (VFloat (map_tile exp_f16 input));
   setting 2%positive (14+depth) Vector Vector 4;
   waiting 2%positive (15+depth) Vector Vector 4;
   setting 2%positive (16+depth) Vector MTE2 (free_flag k)].
Local Definition vector_uses depth : list Use :=
  [UseRecord (position 2%positive (10+depth)) 1
     (position 2%positive (7+depth)) (VFloat input);
   UseRecord (position 2%positive (13+depth)) 2
     (position 2%positive (10+depth)) (VFloat (map_tile exp_f16 input))].

Local Definition initial_blocks depth k : list Block :=
  [atomic 2%positive (1+depth) IntEq [VInt (Z.of_nat k); VInt 0] (VBool (Nat.eqb k 0));
   setting 2%positive (3+depth) Vector MTE2 (if Nat.eqb k 0 then 2 else 3)].

Local Fixpoint chunks {A} (width : nat) (body : nat -> nat -> list A) depth indices :=
  match indices with
  | [] => []
  | k :: rest => body depth k ++ chunks width body (width+depth) rest
  end.

Local Fixpoint paired_rounds count move_depth vec_depth indices :=
  match indices with
  | [] => []
  | k :: rest => move_blocks count move_depth k ++ vector_blocks vec_depth k ++
      paired_rounds count (13+move_depth) (17+vec_depth) rest
  end.

Local Definition prime_count count := Nat.min 2 count.
Local Definition vector_base count := 4 * prime_count count + 3.
Local Definition priming count := chunks 4 initial_blocks 3 (seq 0 (prime_count count)).
(* 先发出初始可用通知，再逐轮完成一次搬运、一次 Vector 计算。 *)
Local Definition schedule count :=
  priming count ++
  paired_rounds count 3 (vector_base count) (seq 0 count) ++
  [returning 1%positive (13 * count + 3);
   returning 2%positive (17 * count + vector_base count)].

Local Lemma paired_permutation count m v indices :
  Permutation (paired_rounds count m v indices)
    (chunks 13 (move_blocks count) m indices ++ chunks 17 vector_blocks v indices).
Proof.
  revert m v. induction indices as [|k rest IH]; intros m v; [reflexivity |].
  cbn [paired_rounds chunks].
  rewrite <- (app_assoc (move_blocks count m k)).
  apply Permutation_app_head.
  eapply Permutation_trans; [apply Permutation_app_head, IH |].
  rewrite app_assoc. eapply Permutation_trans; [apply Permutation_app_tail, Permutation_app_comm |].
  now rewrite <- app_assoc.
Qed.

Local Lemma source_address count k :
  (k < count)%nat -> eval_atomic (MemoryAt (input_addresses count)) [VInt (Z.of_nat k)] =
  Some (VMemory (source k) : Val).
Proof.
  intros bound. cbn [eval_atomic].
  assert (nonnegative : (Z.of_nat k <? 0)%Z = false) by (apply Z.ltb_ge; lia).
  rewrite nonnegative.
  unfold input_addresses, source. rewrite Nat2Z.id, nth_error_map, nth_error_seq.
  rewrite (proj2 (Nat.ltb_lt _ _) bound). reflexivity.
Qed.

Local Notation Env := (@environment Tile nat issue_pipe).
Local Notation Rec := (@event_record Tile nat issue_pipe issue_resource).
Local Definition stable (rho : Env) pipe :=
  rho bufA = Some (Known (VMemory (buffer_a layout))) /\
  rho bufB = Some (Known (VMemory (buffer_b layout))) /\
  rho active = Some (Known (VPipe pipe)).

Local Definition staged (j : positive) depth (body next : Cmd unit) :=
  label_paths (pair j) (path depth) (expand_loops body next).

Local Ltac issue_step :=
  first [eapply EventsAlias; [reflexivity |]
    | eapply EventsSelect with (b := true); [reflexivity | first [eassumption | reflexivity] |]
    | eapply EventsSelect with (b := false); [reflexivity | first [eassumption | reflexivity] |]
    | eapply EventsAtomic with (uses := [])
    | eapply EventsSetFlag with (uses := [])
    | eapply EventsWaitFlag with (uses := [])
    | eapply EventsRead with (uses := [])
    | eapply EventsCompute with (uses := [_])
    | eapply EventsWrite with (uses := [_])
    | apply QueuedValues | apply ValuesNil
    | lazymatch goal with
      | |- operand_values _ _ _ (OVar x :: _) _ _ => eapply ValuesCons with (uses := [_])
      | |- operand_values _ _ _ (OVar y :: _) _ _ => eapply ValuesCons with (uses := [_])
      | |- operand_values _ _ _ (_ :: _) _ _ => eapply ValuesCons with (uses := [])
      end
    | apply UseKnown; first [eassumption | reflexivity]
    | eapply UseAsync; reflexivity ].

Local Lemma move_command count depth k (next : Cmd unit) (events : list Rec) (uses : list Use) rho :
  (k < count)%nat ->
  stable rho MTE2 ->
  (forall env, stable env MTE2 ->
    command_events layout model env (label_paths (pair 1%positive) (path (13+depth)) next) events uses) ->
  command_events layout model rho
    (staged 1%positive depth (CAlias i (integer (Z.of_nat k)) (load_iteration count)) next)
    (flat_map operation_records (move_blocks count depth k) ++ events) (move_uses depth ++ uses).
Proof.
  intros bound [A [B P]] continuation.
  unfold staged, load_iteration, choose_slot, fence, move_blocks, move_uses, turn_prefix,
    waiting, reading, setting, writing, atomic, asynchronous, operation_records,
    first_event, last_event, position, free_flag, ready_flag, iteration_buffer.
  fold (first_slot k).
  destruct (first_slot k) eqn:which;
    cbn [expand_loops label_paths flat_map app finish_label start_label operation_id path Nat.iter Nat.add].
  all: pose proof which as modulus; unfold first_slot, slot_index in modulus; rewrite ?modulus.
  all: repeat first
    [ solve [apply continuation; exact (conj A (conj B P))]
    | issue_step
    | solve [apply source_address; exact bound]
    | solve [unfold first_slot in which; rewrite <- which; reflexivity]
    | solve [cbn [resolve bind Nat.eqb bufA bufB active i slot first buf ready free src x y current];
             rewrite ?which, ?A, ?B, ?P; reflexivity]
    | reflexivity ].
Qed.

Local Lemma vector_command depth k (next : Cmd unit) (events : list Rec) (uses : list Use) rho :
  stable rho Vector ->
  (forall env, stable env Vector ->
    command_events layout model env (label_paths (pair 2%positive) (path (17+depth)) next) events uses) ->
  command_events layout model rho
    (staged 2%positive depth (CAlias i (integer (Z.of_nat k)) vector_iteration) next)
    (flat_map operation_records (vector_blocks depth k) ++ events) (vector_uses depth ++ uses).
Proof.
  intros [A [B P]] continuation.
  unfold staged, vector_iteration, choose_slot, fence, vector_blocks, vector_uses, turn_prefix,
    waiting, reading, setting, writing, exponentiating, atomic, asynchronous, operation_records,
    first_event, last_event, position, free_flag, ready_flag, iteration_buffer.
  fold (first_slot k).
  destruct (first_slot k) eqn:which;
    cbn [expand_loops label_paths flat_map app finish_label start_label operation_id path Nat.iter Nat.add].
  all: pose proof which as modulus; unfold first_slot, slot_index in modulus; rewrite ?modulus.
  all: repeat first
    [ solve [apply continuation; exact (conj A (conj B P))]
    | issue_step
    | solve [apply (proj2 (computes input _)); reflexivity]
    | solve [unfold first_slot in which; rewrite <- which; reflexivity]
    | solve [cbn [resolve bind Nat.eqb bufA bufB active i slot first buf ready free src x y current];
             rewrite ?which, ?A, ?B, ?P; reflexivity]
    | reflexivity ].
Qed.
Local Lemma initial_command depth k (next : Cmd unit) (events : list Rec) (uses : list Use) rho :
  stable rho Vector ->
  (forall env, stable env Vector ->
    command_events layout model env (label_paths (pair 2%positive) (path (4+depth)) next) events uses) ->
  command_events layout model rho
    (staged 2%positive depth (CAlias s (integer (Z.of_nat k)) initially_free) next)
    (flat_map operation_records (initial_blocks depth k) ++ events) uses.
Proof.
  intros [A [B P]] continuation. destruct k as [|k].
  all: unfold staged, initially_free, initial_blocks, setting, atomic, asynchronous,
    operation_records, first_event, last_event, position.
  all: cbn [expand_loops label_paths flat_map app finish_label start_label operation_id path Nat.iter Nat.add Nat.eqb].
  all: repeat first [solve [apply continuation; exact (conj A (conj B P))] | issue_step | reflexivity].
Qed.

Local Definition expand_iterations (x : var) (body : Cmd unit) indices next :=
  fold_right (fun k n => CAlias x (integer (Z.of_nat k)) (expand_loops body n)) next indices.

Local Lemma run_chunks width blocks (uses : nat -> nat -> list Use) j x body pipe valid
    (one : forall depth k next events rest rho, valid k -> stable rho pipe ->
      (forall env, stable env pipe ->
        command_events layout model env (label_paths (pair j) (path (width+depth)) next) events rest) ->
      command_events layout model rho
        (staged j depth (CAlias x (integer (Z.of_nat k)) body) next)
        (flat_map operation_records (blocks depth k) ++ events) (uses depth k ++ rest)) :
  forall indices depth rho next events rest, Forall valid indices -> stable rho pipe ->
  (forall env, stable env pipe ->
    command_events layout model env
      (label_paths (pair j) (path (width * length indices + depth)) next) events rest) ->
  command_events layout model rho
    (label_paths (pair j) (path depth) (expand_iterations x body indices next))
    (flat_map operation_records (chunks width blocks depth indices) ++ events)
    (chunks width uses depth indices ++ rest).
Proof.
  intros indices. induction indices as [|k indices IH]; intros depth rho next events rest valid_indices stable_env tail.
  - cbn [length] in tail. rewrite Nat.mul_0_r in tail. apply tail. exact stable_env.
  - inversion valid_indices as [|? ? valid_k valid_tail]; subst.
    cbn [chunks]. rewrite flat_map_app, <- !app_assoc. apply one; auto.
    intros env H. unfold staged. eapply IH; [exact valid_tail | exact H |].
    cbn [length] in tail. rewrite Nat.mul_succ_r in tail. intros env' H'.
    replace (width * length indices + (width + depth)) with
      (width * length indices + width + depth) by lia. now apply tail.
Qed.

Local Definition move_run count := chunks 13 (move_blocks count) 3 (seq 0 count).
Local Definition vector_run count := chunks 17 vector_blocks (vector_base count) (seq 0 count).
Local Definition move_return count := returning 1%positive (13 * count + 3).
Local Definition vector_return count := returning 2%positive (17 * count + vector_base count).

Local Definition original_blocks count :=
  (move_run count ++ [move_return count]) ++ (priming count ++ vector_run count ++ [vector_return count]).
Local Definition original_uses count :=
  chunks 13 (fun depth _ => move_uses depth) 3 (seq 0 count) ++
  chunks 17 (fun depth _ => vector_uses depth) (vector_base count) (seq 0 count).

Local Lemma empty_chunks width depth indices :
  chunks width (fun _ _ => ([] : list Use)) depth indices = [].
Proof. revert depth. induction indices; intros; cbn [chunks app]; auto. Qed.

Local Lemma load_exec count :
  forall rho, stable rho MTE2 ->
  command_events layout model rho
    (label_paths (pair 1%positive) (path 3) (expand_loops (For i 0 count (load_iteration count) (Return tt [])) LoopEnd))
    (flat_map operation_records (move_run count ++ [move_return count]))
    (chunks 13 (fun depth _ => move_uses depth) 3 (seq 0 count)).
Proof.
  intros rho H. unfold move_run.
  rewrite flat_map_app, <- (app_nil_r (chunks 13 (fun depth _ => move_uses depth) 3 (seq 0 count))).
  cbn [expand_loops]. rewrite Nat.sub_0_r.
  apply (run_chunks 13 (move_blocks count) (fun depth _ => move_uses depth)
    (x:=i) (body:=load_iteration count) (pipe:=MTE2) (valid:=fun k => k < count)).
  - intros; eapply move_command; eassumption.
  - apply Forall_forall. intros k member. apply in_seq in member; lia.
  - exact H.
  - rewrite length_seq. intros. apply EventsReturn, ValuesNil.
Qed.

Local Lemma vector_exec count :
  forall rho, stable rho Vector ->
  command_events layout model rho
    (label_paths (pair 2%positive) (path 3)
      (expand_loops (For s 0 (prime_count count) initially_free
        (For i 0 count vector_iteration (Return tt []))) LoopEnd))
    (flat_map operation_records (priming count ++ vector_run count ++ [vector_return count]))
    (chunks 17 (fun depth _ => vector_uses depth) (vector_base count) (seq 0 count)).
Proof.
  intros rho H. unfold priming. rewrite flat_map_app. cbn [expand_loops]. rewrite !Nat.sub_0_r.
  rewrite <- (app_nil_l (chunks 17 _ _ _)), <- (empty_chunks 4 3 (seq 0 (prime_count count))).
  apply (run_chunks 4 initial_blocks (fun _ _ => []) (x:=s) (body:=initially_free)
    (pipe:=Vector) (valid:=fun _ => True)).
  - intros; simpl app. eapply initial_command; eassumption.
  - apply Forall_forall; auto.
  - exact H.
  - rewrite length_seq. intros env ready. unfold vector_run.
    rewrite flat_map_app, <- (app_nil_r
      (chunks 17 (fun depth _ => vector_uses depth) (vector_base count) (seq 0 count))).
    apply (run_chunks 17 vector_blocks (fun depth _ => vector_uses depth)
      (x:=i) (body:=vector_iteration) (pipe:=Vector) (valid:=fun _ => True)).
    + intros; eapply vector_command; eassumption.
    + apply Forall_forall; auto.
    + exact ready.
    + rewrite length_seq. intros. apply EventsReturn, ValuesNil.
Qed.

Local Lemma branch_candidates count :
  program_events layout model (annotate_program (branches layout count))
    (flat_map operation_records (original_blocks count)) (original_uses count).
Proof.
  unfold original_blocks, original_uses. rewrite flat_map_app.
  cbn [branches issue316 instantiate_shared annotate_program expand_program combine seq
    length map expand_loops].
  rewrite <- (app_nil_r (flat_map operation_records (priming count ++ vector_run count ++ [vector_return count]))).
  rewrite <- (app_nil_r (chunks 17 _ _ _)).
  eapply ProgramCons.
  - do 3 (eapply EventsAlias; [reflexivity |]). apply load_exec. repeat split.
  - eapply ProgramCons; [ | apply ProgramNil].
    do 3 (eapply EventsAlias; [reflexivity |]). apply vector_exec. repeat split.
Qed.
Local Fixpoint linear {L} (c : Cmd L) : Prop :=
  match c with
  | If _ _ _ _ => False
  | For _ _ _ b n => linear b /\ linear n
  | CAlias _ _ n | Select _ _ _ _ n | LetAtomic _ _ _ _ n | AssignPipe _ _ _ n
  | CCompute _ _ _ _ n | Alloc _ _ n | Read _ _ _ _ n | Write _ _ _ _ n
  | SetFlag _ _ _ _ n | WaitFlag _ _ _ _ n => linear n
  | _ => True
  end.

Local Lemma linear_expand {L} (c n : Cmd L) : linear c -> linear n -> linear (expand_loops c n).
Proof.
  revert n. induction c; cbn; intros n C N; auto; try contradiction.
  destruct C as [body next]. induction (seq lower (upper-lower)); cbn; eauto.
Qed.
Local Lemma linear_label {L M} (c : Cmd L) (f : positive -> M) p :
  linear c -> linear (label_paths f p c).
Proof. revert p. induction c; cbn; intuition. Qed.

Local Definition has_return (es : list Rec) :=
  exists e, In e es /\ kind (payload e) = ReturnEvent.

Local Lemma complete_signatures rho c es uses :
  command_events layout model rho c es uses -> linear c -> has_return es ->
  map descriptor (start_list es) = operations c.
Proof.
  intros generated. induction generated; cbn in *; intros straight ret;
    try contradiction; try reflexivity; try apply IHgenerated; auto.
  all: try solve [destruct ret as (? & [] & _)].
  all: f_equal; apply IHgenerated; [exact straight |];
    destruct ret as (e & member & kind_eq); cbn in member;
    repeat destruct member as [<-|member]; try discriminate; unfold has_return; eauto.
Qed.

Local Fixpoint rank (p : positive) : nat :=
  match p with xH => 0 | xO q | xI q => S (rank q) end.
Local Definition op_rank (o : op_id) := rank (snd o).
Local Lemma path_rank d : rank (path d) = d.
Proof. induction d; [reflexivity | change (S (rank (path d)) = S d); now rewrite IHd]. Qed.

Local Lemma labelled_depth {L} (c : Cmd L) j depth :
  linear c ->
  let ids := op_ids (label_paths (pair j) (path depth) c) in
  Forall (fun o => thread o = j /\ depth <= op_rank o) ids /\
  StronglySorted (fun a b => op_rank a < op_rank b) ids.
Proof.
  revert depth. induction c; intros depth line; cbn [label_paths linear op_ids operations] in *;
    try contradiction; try solve [split; constructor].
  all: unfold op_ids in *; cbn [operations map] in *.
  all: try solve
    [ pose proof (IHc (S depth) line) as [bound order]; split; [ |exact order];
      eapply Forall_impl; [ |exact bound]; cbn; intuition lia ].
  all: try solve [split; [constructor; [split; [reflexivity | change (depth <= rank (path depth)); rewrite path_rank; lia] | constructor] | repeat constructor]].
  all: specialize (IHc (S depth) line) as [bound sorted];
    split; constructor; try exact sorted.
  all: try solve [split; [reflexivity | change (depth <= rank (path depth)); rewrite path_rank; lia]].
  all: eapply Forall_impl; [ |exact bound]; intros a [tid lower]; cbn [fst op_rank snd] in *;
    try (intuition lia); change (rank (path depth) < op_rank a); rewrite path_rank; lia.
Qed.

Local Lemma linear_order {L} (c : Cmd L) (f : positive -> op_id) path0 o u :
  linear c -> In (o,u) (program_order (label_paths f path0 c)) ->
  exists pre mid tail, op_ids (label_paths f path0 c) = pre ++ o :: mid ++ u :: tail.
Proof.
  revert path0. induction c; intros path0 linear_code edge; cbn [label_paths program_order] in edge;
    try contradiction; try solve [apply IHc; assumption].
  all: apply in_app_or in edge as [edge | edge].
  all: try solve [apply in_map_iff in edge as (target_id & equal & member); injection equal as same_o same_u; subst o u;
    apply in_split in member as (mid & tail & cut); exists [],mid,tail;
    change (f path0 :: op_ids (label_paths f (xO path0) c) = f path0 :: mid ++ target_id :: tail);
    now rewrite cut].
  all: destruct (IHc _ linear_code edge) as (pre & mid & tail & cut);
    exists (f path0 :: pre), mid, tail;
    change (f path0 :: op_ids (label_paths f (xO path0) c) = (f path0 :: pre) ++ o :: mid ++ u :: tail);
    now rewrite cut.
Qed.

Local Lemma sorted_rank_order ids o u pre mid tail :
  StronglySorted (fun a b => op_rank a < op_rank b) ids ->
  ids = pre ++ o :: mid ++ u :: tail -> (op_rank o < op_rank u)%nat.
Proof.
  intros sort ->. induction pre; inversion sort as [|x xs sorted all]; subst.
  - apply Forall_forall with (x:=u) in all; auto. apply in_or_app; right; now left.
  - now apply IHpre.
Qed.
Local Definition annotated count : list (Cmd op_id) := annotate_program (branches layout count).
Local Definition load_source count : Cmd unit :=
  expand_loops (For i 0 count (load_iteration count) (Return tt [])) LoopEnd.
Local Definition vector_source count : Cmd unit :=
  expand_loops (For s 0 (prime_count count) initially_free
    (For i 0 count vector_iteration (Return tt []))) LoopEnd.
Local Lemma sources_linear count : linear (load_source count) /\ linear (vector_source count).
Proof. split; apply linear_expand; cbn; auto. Qed.

Local Lemma block_descriptors (blocks : list Block) :
  Forall operation_shape blocks ->
  map descriptor (start_list (flat_map operation_records blocks)) = map operation_signature blocks.
Proof.
  induction 1 as [|b blocks S all IH]; [reflexivity |].
  unfold start_list in *. cbn [flat_map]. rewrite filter_app, map_app, IH.
  f_equal. destruct b as [id h start finish]. destruct S as [S E].
  change (kind start = start_kind h) in S.
  unfold operation_records, first_event, last_event, operation_signature, descriptor.
  destruct finish as [ending|]; cbn [finish_label filter payload map operation_id start_label operation_head].
  - destruct E as [E different]. cbn in E, different.
    rewrite S,E. destruct h; cbn in *; try solve [now rewrite S]; exfalso; apply different; reflexivity.
  - rewrite S. destruct h; cbn; now rewrite S.
Qed.

Local Lemma chunks_All {A : Type} (P : A -> Prop) indices w body d :
  (forall k depth, In k indices -> Forall P (body depth k)) ->
  Forall P (chunks w body d indices).
Proof.
  revert d. induction indices; intros d H; cbn [chunks].
  - constructor.
  - apply Forall_app. split; [apply H; now left |]. apply IHindices. intros; apply H; now right.
Qed.

Local Lemma original_shape count : Forall operation_shape (original_blocks count).
Proof.
  unfold original_blocks, move_run, priming, vector_run.
  repeat rewrite Forall_app. repeat split.
  all: try (apply chunks_All; intros; unfold move_blocks, vector_blocks, initial_blocks, turn_prefix).
  all: repeat constructor; cbn; congruence.
Qed.

Local Lemma schedule_permutation count : Permutation (original_blocks count) (schedule count).
Proof.
  unfold original_blocks, schedule, move_run, priming, vector_run, move_return, vector_return.
  eapply Permutation_trans.
  2: { apply Permutation_app_head. apply Permutation_app_tail. symmetry. apply paired_permutation. }
  repeat rewrite <- app_assoc. cbn [app].
  eapply Permutation_trans.
  - apply Permutation_app_head.
    rewrite (app_assoc (chunks 4 initial_blocks 3 (seq 0 (prime_count count)))).
    apply Permutation_middle.
  - repeat rewrite <- app_assoc. apply Permutation_app_swap_app.
Qed.

Local Lemma last_return j d bs :
  has_return (flat_map operation_records (bs ++ [returning j d])).
Proof.
  unfold has_return. exists (first_event (returning j d)).
  rewrite flat_map_app. split; [apply in_or_app; right; now left | reflexivity].
Qed.

Local Lemma branch_signatures count :
  map operation_signature (move_run count ++ [move_return count]) =
    operations (label_paths (pair 1%positive) (path 3) (load_source count)) /\
  map operation_signature (priming count ++ vector_run count ++ [vector_return count]) =
    operations (label_paths (pair 2%positive) (path 3) (vector_source count)).
Proof.
  destruct (sources_linear count) as [L V].
  pose proof (original_shape count) as shapes. apply Forall_app in shapes as [SL SV].
  pose proof (load_exec count (rho:=bind (bind (bind empty_environment bufA
    (Known (VMemory (buffer_a layout)))) bufB (Known (VMemory (buffer_b layout))))
    active (Known (VPipe MTE2))) ltac:(repeat split)) as run_load.
  pose proof (vector_exec count (rho:=bind (bind (bind empty_environment bufA
    (Known (VMemory (buffer_a layout)))) bufB (Known (VMemory (buffer_b layout))))
    active (Known (VPipe Vector))) ltac:(repeat split)) as run_vector.
  split.
  - rewrite <- (block_descriptors SL).
    apply complete_signatures in run_load; [exact run_load | now apply linear_label |].
    apply last_return.
  - rewrite <- (block_descriptors SV).
    apply complete_signatures in run_vector; [exact run_vector | now apply linear_label |].
    rewrite app_assoc. apply last_return.
Qed.

Local Lemma order_signatures count :
  program_operations (annotated count) = map operation_signature (original_blocks count).
Proof.
  destruct (branch_signatures count) as [load vector].
  unfold original_blocks. rewrite map_app, load, vector.
  unfold annotated, annotate_program, branches, issue316, instantiate_shared,
    load_source, vector_source, prime_count.
  cbn [length map combine seq expand_program expand_loops label_paths operations program_operations concat].
  now rewrite app_nil_r.
Qed.
Local Definition in_thread j (b : Block) := Pos.eqb (thread (operation_id b)) j.
Local Definition load_order count := move_run count ++ [move_return count].
Local Definition vector_order count := priming count ++ vector_run count ++ [vector_return count].

Local Lemma filter_chunks {A} (f : A -> bool) w body indices :
  (forall d k, filter f (body d k) = body d k) ->
  forall d, filter f (chunks w body d indices) = chunks w body d indices.
Proof. intros test. induction indices; cbn [chunks]; auto. intros. now rewrite filter_app, test, IHindices. Qed.
Local Lemma skip_chunks {A} (f : A -> bool) w body indices :
  (forall d k, filter f (body d k) = []) ->
  forall d, filter f (chunks w body d indices) = [].
Proof. intros test. induction indices; cbn [chunks]; auto. intros. now rewrite filter_app, test, IHindices. Qed.

Local Lemma filter_rounds count indices :
  forall m v,
  filter (in_thread 1%positive) (paired_rounds count m v indices) =
    chunks 13 (move_blocks count) m indices /\
  filter (in_thread 2%positive) (paired_rounds count m v indices) =
    chunks 17 vector_blocks v indices.
Proof.
  induction indices; intros m v; [split; reflexivity |].
  cbn [paired_rounds chunks]. rewrite !filter_app.
  destruct (IHindices (13+m) (17+v)) as [L V]. rewrite L,V.
  split; reflexivity.
Qed.

Local Lemma scheduled_branches count :
  filter (in_thread 1%positive) (schedule count) = load_order count /\
  filter (in_thread 2%positive) (schedule count) = vector_order count.
Proof.
  unfold schedule, load_order, vector_order, priming, move_run, vector_run.
  rewrite !filter_app, skip_chunks by reflexivity.
  rewrite filter_chunks by reflexivity.
  destruct (filter_rounds count (seq 0 count) 3 (vector_base count)) as [L V].
  rewrite L,V. split; reflexivity.
Qed.

Local Definition load_ids count := op_ids (label_paths (pair 1%positive) (path 3) (load_source count)).
Local Definition vector_ids count := op_ids (label_paths (pair 2%positive) (path 3) (vector_source count)).

Local Lemma ids_properties count :
  Forall (fun o => thread o = 1%positive) (load_ids count) /\
  Forall (fun o => thread o = 2%positive) (vector_ids count) /\
  StronglySorted (fun a b => op_rank a < op_rank b) (load_ids count) /\
  StronglySorted (fun a b => op_rank a < op_rank b) (vector_ids count).
Proof.
  destruct (sources_linear count) as [L V].
  destruct (labelled_depth (load_source count) 1%positive 3 L) as [load_thread load_sorted].
  destruct (labelled_depth (vector_source count) 2%positive 3 V) as [vec_thread vec_sorted].
  repeat split; auto.
  - eapply Forall_impl; [ |exact load_thread]. intros a [owner_eq _]. exact owner_eq.
  - eapply Forall_impl; [ |exact vec_thread]. intros a [owner_eq _]. exact owner_eq.
Qed.

Local Lemma ids_without_repetitions ids :
  StronglySorted (fun a b => op_rank a < op_rank b) ids -> NoDup ids.
Proof.
  induction 1 as [|a ids sorted IH all]; constructor; auto.
  intros member. apply Forall_forall with (x:=a) in all; auto. lia.
Qed.

Local Lemma ids_disjoint count : forall o, In o (load_ids count) -> ~ In o (vector_ids count).
Proof.
  destruct (ids_properties count) as [L [V _]].
  intros o in_load in_vec. apply Forall_forall with (x:=o) in L,V; auto; congruence.
Qed.

Local Lemma original_ids count :
  map operation_id (original_blocks count) = load_ids count ++ vector_ids count.
Proof.
  destruct (branch_signatures count) as [L V].
  unfold original_blocks, load_ids, vector_ids, op_ids. rewrite map_app, <- L, <- V, !map_map. reflexivity.
Qed.

Local Lemma original_unique count : NoDup (map operation_id (original_blocks count)).
Proof.
  rewrite original_ids. destruct (ids_properties count) as [_ [_ [L V]]].
  pose proof (ids_disjoint count) as disjoint.
  apply ids_without_repetitions in L,V. revert L disjoint. generalize (load_ids count).
  intros ids. induction ids; cbn; auto. intros unique separated.
  inversion unique; subst. constructor.
  - rewrite in_app_iff. intros [member|member]; [congruence | eapply separated; eauto].
  - apply IHids; auto.
Qed.

Local Lemma blocks_unique count : NoDup (map operation_id (schedule count)).
Proof. eapply Permutation_NoDup; [apply Permutation_map, schedule_permutation | apply original_unique]. Qed.

Local Lemma concrete_heads count o h : In (o,h) (program_operations (annotated count)) <->
  exists b, In b (schedule count) /\ operation_id b = o /\ operation_head b = h.
Proof.
  rewrite order_signatures, in_map_iff. split; intros (b & member & W).
  - exists b. split.
    + eapply Permutation_in; [apply schedule_permutation | exact W].
    + unfold operation_signature in member. now injection member.
  - exists b. split.
    + unfold operation_signature. destruct W as [O H]. now rewrite O,H.
    + eapply Permutation_in; [symmetry; apply schedule_permutation | exact member].
Qed.

Local Lemma branch_edges count o u : In (o,u) (po (annotated count)) ->
  (In o (load_ids count) /\ In u (load_ids count) \/
   In o (vector_ids count) /\ In u (vector_ids count)) /\ (op_rank o < op_rank u)%nat.
Proof.
  intros edge. destruct (sources_linear count) as [L V].
  destruct (ids_properties count) as [_ [_ [LS VS]]].
  change (In (o,u) (program_order (label_paths (pair 1%positive) (path 3) (load_source count)) ++
    program_order (label_paths (pair 2%positive) (path 3) (vector_source count)) ++ [])) in edge.
  rewrite app_nil_r in edge. apply in_app_or in edge as [edge | edge].
  - destruct (linear_order (load_source count) _ _ _ _ L edge) as (pre & mid & tail & eq).
    change (load_ids count = pre ++ o :: mid ++ u :: tail) in eq.
    split.
    + left. rewrite eq. split; apply in_or_app; right; cbn;
        [now left | right; apply in_or_app; right; now left].
    + eapply sorted_rank_order; [exact LS | exact eq].
  - destruct (linear_order (vector_source count) _ _ _ _ V edge) as (pre & mid & tail & eq).
    change (vector_ids count = pre ++ o :: mid ++ u :: tail) in eq.
    split.
    + right. rewrite eq. split; apply in_or_app; right; cbn;
        [now left | right; apply in_or_app; right; now left].
    + eapply sorted_rank_order; [exact VS | exact eq].
Qed.

Local Lemma edge_has_head count o u :
  In (o,u) (po (annotated count)) -> exists h, In (o,h) (program_operations (annotated count)).
Proof.
  intros edge. apply branch_edges in edge as [[L|V] _].
  all: assert (In o (map fst (program_operations (annotated count)))).
  all: try (rewrite order_signatures, map_map; change (In o (map operation_id (original_blocks count)));
    rewrite original_ids, in_app_iff; tauto).
  all: apply in_map_iff in H as ([x h] & eq & member); cbn in eq; subst; eauto.
Qed.

Local Lemma two_positions {A} (xs : list A) i j a b :
  (i < j)%nat -> nth_error xs i = Some a -> nth_error xs j = Some b ->
  exists pre mid tail, xs = pre ++ a :: mid ++ b :: tail.
Proof.
  revert i j. induction xs as [|x xs IH]; intros [|i] [|j] order I J; try lia;
    cbn in I,J; try discriminate.
  - injection I as <-. apply nth_error_split in J as (mid & tail & cut & _).
    exists [],mid,tail. now rewrite cut.
  - destruct (IH i j ltac:(lia) I J) as (pre & mid & tail & cut).
    exists (x::pre),mid,tail. cbn. now rewrite cut.
Qed.

Local Lemma projected_ids count :
  map operation_id (filter (in_thread 1%positive) (schedule count)) = load_ids count /\
  map operation_id (filter (in_thread 2%positive) (schedule count)) = vector_ids count.
Proof.
  destruct (scheduled_branches count) as [L V]. rewrite L,V.
  destruct (branch_signatures count) as [load vector].
  unfold load_order, vector_order, load_ids, vector_ids, op_ids.
  rewrite <- load, <- vector, !map_map. split; reflexivity.
Qed.

Local Lemma schedule_order count i j a b :
  nth_error (schedule count) i = Some a -> nth_error (schedule count) j = Some b ->
  In (operation_id a, operation_id b) (po (annotated count)) -> (i < j)%nat.
Proof.
  intros I J edge.
  apply branch_edges in edge as [branches rank_lt].
  destruct (Nat.lt_trichotomy i j) as [lt | [same | reversed]]; auto.
  - subst j. assert (a = b) by congruence. subst b. lia.
  - exfalso. destruct (two_positions (schedule count) reversed J I) as (pre & mid & tail & cut).
    destruct (ids_properties count) as (LT & VT & LS & VS).
    destruct (projected_ids count) as [L V].
    destruct branches as [[LA LB]|[VA VB]].
    + apply Forall_forall with (x:=operation_id a) in LT as A; auto.
      pose proof (proj1 (Forall_forall _ _) LT (operation_id b) LB) as B.
      unfold in_thread in L. rewrite cut, filter_app in L. cbn [filter] in L.
      rewrite !filter_app in L. cbn [filter] in L.
      rewrite A,B,!Pos.eqb_refl, !map_app in L. cbn [map] in L.
      rewrite map_app in L. cbn [map] in L. symmetry in L.
      assert (op_rank (operation_id b) < op_rank (operation_id a))
        by (eapply sorted_rank_order; [exact LS | exact L]). lia.
    + apply Forall_forall with (x:=operation_id a) in VT as A; auto.
      pose proof (proj1 (Forall_forall _ _) VT (operation_id b) VB) as B.
      unfold in_thread in V. rewrite cut, filter_app in V. cbn [filter] in V.
      rewrite !filter_app in V. cbn [filter] in V.
      rewrite A,B,!Pos.eqb_refl, !map_app in V. cbn [map] in V.
      rewrite map_app in V. cbn [map] in V. symmetry in V.
      assert (op_rank (operation_id b) < op_rank (operation_id a))
        by (eapply sorted_rank_order; [exact VS | exact V]). lia.
Qed.
Local Definition eq_pipe p q :=
  match p,q with MTE2,MTE2 | Vector,Vector => true | _,_ => false end.
Local Lemma eq_pipe_true p q : eq_pipe p q = true <-> p = q.
Proof. destruct p,q; intuition discriminate. Qed.
Local Definition match_channel p q f p' q' f' :=
  eq_pipe p p' && eq_pipe q q' && Nat.eqb f f'.
Local Lemma match_channel_true p q f p' q' f' :
  match_channel p q f p' q' f' = true <-> p = p' /\ q = q' /\ f = f'.
Proof. unfold match_channel. rewrite !Bool.andb_true_iff, !eq_pipe_true, Nat.eqb_eq. tauto. Qed.

Local Definition mark p q f (b : Block) :=
  match start_label b, finish_label b with
  | LSetFlagStart src dst id, Some LSetFlagEnd =>
      if match_channel p q f src dst id then [FlagSet] else []
  | LWaitFlagStart src dst id, Some LWaitFlagEnd =>
      if match_channel p q f src dst id then [FlagWait] else []
  | _,_ => []
  end.

Local Lemma mark_spec p q f b letter :
  mark p q f b = [letter] <-> block_flag p q f b letter.
Proof.
  unfold mark, block_flag, last_event. destruct b as [o h start finish].
  destruct letter; cbn [start_label finish_label payload];
  split.
  all: try solve [intros [E K]; subst start; destruct finish as [[]|]; cbn in K;
    try discriminate; rewrite (proj2 (match_channel_true _ _ _ _ _ _) ltac:(auto)); reflexivity].
  all: destruct start, finish as [[]|]; cbn [start_label finish_label payload kind];
    try solve [intros H; discriminate | intros [H K]; discriminate].
  all: try (match goal with |- context [match_channel ?a ?b ?c ?d ?e ?f] =>
    destruct (match_channel a b c d e f) eqn:test end;
    try solve [intros H; discriminate | intros [H _]; discriminate];
    intros E; inversion E; apply match_channel_true in test as (P & Q & F); subst; auto).
  all: intros [same _]; injection same as -> -> ->;
    unfold match_channel; rewrite ! (proj2 (eq_pipe_true _ _) eq_refl), Nat.eqb_refl; reflexivity.
Qed.

Local Lemma marked_projection p q f blocks :
  projection (block_flag p q f) blocks (flat_map (mark p q f) blocks).
Proof.
  induction blocks as [|b blocks IH]; cbn [flat_map]; [constructor |].
  destruct (mark p q f b) as [|letter rest] eqn:M.
  - apply ProjectSkip; [ |exact IH]. intros [letter B]. apply mark_spec in B. congruence.
  - assert (rest = []) as ->.
    { unfold mark in M. destruct (start_label b), (finish_label b) as [[]|];
        try discriminate; destruct (match_channel _ _ _ _ _ _); congruence. }
    apply ProjectKeep; [now apply mark_spec | exact IH].
Qed.

Local Definition flag_pair := [FlagSet; FlagWait].
Local Definition reused_pair := [FlagWait; FlagSet].
Local Definition round_word p q f k :=
  match p,q with
  | MTE2,MTE2 => if Nat.eqb f 4 then flag_pair else []
  | Vector,Vector => if Nat.eqb f 4 then flag_pair ++ flag_pair ++ flag_pair else []
  | MTE2,Vector => if Nat.eqb f (ready_flag k) then flag_pair else []
  | Vector,MTE2 => if Nat.eqb f (free_flag k) then reused_pair else []
  end.

Local Lemma round_marks p q f count m v k :
  flat_map (mark p q f) (move_blocks count m k ++ vector_blocks v k) = round_word p q f k.
Proof.
  destruct p,q, f as [|[|[|[|[|f]]]]]; unfold move_blocks, vector_blocks, turn_prefix, round_word,
    ready_flag, free_flag; destruct (first_slot k); reflexivity.
Qed.
Local Lemma scheduled_round_marks p q f count indices :
  forall m v, flat_map (mark p q f) (paired_rounds count m v indices) =
    flat_map (round_word p q f) indices.
Proof.
  induction indices; intros; [reflexivity |].
  cbn [paired_rounds flat_map]. rewrite app_assoc, flat_map_app, round_marks, IHindices. reflexivity.
Qed.

Local Lemma prime_marks p q f count :
  flat_map (mark p q f) (priming count) =
    match p,q with
    | Vector,MTE2 =>
        if Nat.eqb f 2 then (if Nat.ltb 0 count then [FlagSet] else [])
        else if Nat.eqb f 3 then (if Nat.ltb 1 count then [FlagSet] else []) else []
    | _,_ => []
    end.
Proof. destruct p,q, f as [|[|[|[|[|f]]]]], count as [|[|count]]; reflexivity. Qed.

Local Lemma pair_word_star p q f indices :
  (p,q) <> (Vector,MTE2) ->
  star (fun block => block = flag_pair) (flat_map (round_word p q f) indices).
Proof.
  intros distinct. induction indices; cbn [flat_map]; [constructor |].
  destruct p,q; try congruence; cbn [round_word];
    repeat match goal with |- context [Nat.eqb ?a ?b] => destruct (Nat.eqb a b) end;
    cbn [app flag_pair]; try exact IHindices;
    repeat (change (_ :: _ :: ?tail) with (flag_pair ++ tail); apply StarCons; [reflexivity |]);
    exact IHindices.
Qed.

Local Lemma free_word_star f indices :
  star (fun block => block = reused_pair) (flat_map (round_word Vector MTE2 f) indices).
Proof.
  induction indices; cbn [flat_map]; [constructor |].
  cbn [round_word]. destruct (Nat.eqb f (free_flag a)); cbn [app]; auto.
  change (star (fun block => block = reused_pair)
    (reused_pair ++ flat_map (round_word Vector MTE2 f) indices)).
  now constructor.
Qed.

Local Lemma rotate_free_word word :
  star (fun b => b = reused_pair) word ->
  star (fun b => b = flag_pair) (FlagSet :: word ++ [FlagWait]).
Proof.
  induction 1 as [|block rest -> H IH].
  - change (star (fun b => b = flag_pair) (flag_pair ++ [])). repeat constructor.
  - change (star (fun b => b = flag_pair) (flag_pair ++ (FlagSet :: rest ++ [FlagWait]))). now constructor.
Qed.

Local Lemma scheduled_flags count p q f :
  prefix_language (star (fun block => block = [FlagSet; FlagWait]))
    (flat_map (mark p q f) (schedule count)).
Proof.
  unfold schedule. rewrite !flat_map_app, prime_marks, scheduled_round_marks.
  cbn [flat_map mark returning start_label finish_label app].
  rewrite (app_nil_r (flat_map (round_word p q f) (seq 0 count))).
  destruct p,q; cbn [app].
  all: try solve [match goal with |- prefix_language _ ?word => exists word end;
    split; [apply pair_word_star; discriminate | exists []; now rewrite app_nil_r]].
  destruct f as [|[|[|[|[|f]]]]]; cbn [Nat.eqb].
  all: try solve [
    match goal with |- context [flat_map (round_word Vector MTE2 ?flag_id) ?indices] =>
      assert (Z : forall k, round_word Vector MTE2 flag_id k = []) by
        (intros k; cbn [round_word]; unfold free_flag; destruct (first_slot k); reflexivity);
      assert (empty_word : forall ids, flat_map (round_word Vector MTE2 flag_id) ids = []) by
        (induction ids; cbn [flat_map]; now rewrite ?Z, ?IHids);
      rewrite empty_word; exists []; split; [constructor | exists []; reflexivity]
    end ].
  all: destruct count as [|[|count]]; cbn [Nat.ltb Nat.leb app];
    try solve [exists []; split; [constructor | exists []; reflexivity]].
  all: try (match goal with |- prefix_language _ (FlagSet :: ?rest) =>
    exists (FlagSet :: rest ++ [FlagWait]) end;
    split; [apply rotate_free_word, free_word_star | exists [FlagWait]; reflexivity]).
Qed.
Local Lemma schedule_shape count : Forall operation_shape (schedule count).
Proof. eapply Permutation_Forall; [apply schedule_permutation | apply original_shape]. Qed.

Local Lemma source_in_inputs count k : (k < count)%nat -> In (source k) (input_addresses count).
Proof. intros inside. unfold source, input_addresses. apply in_map_iff. exists k.
  split; [reflexivity | apply in_seq; lia]. Qed.
Local Lemma slot_is_buffer k : is_buffer layout (iteration_buffer layout k).
Proof. unfold iteration_buffer. destruct (Z.eqb _ _); [now left | now right]. Qed.

Local Lemma schedule_permissions count :
  Forall (fun b => target_allows (target layout count) (start_label b) /\
                    target_allows (target layout count) (payload (last_event b))) (schedule count).
Proof.
  eapply Permutation_Forall; [apply schedule_permutation |].
  unfold original_blocks, move_run, priming, vector_run.
  repeat rewrite Forall_app. repeat split.
  all: try (apply chunks_All; intros k depth member; apply in_seq in member;
    unfold move_blocks, vector_blocks, initial_blocks, turn_prefix).
  all: repeat first [solve [apply source_in_inputs; lia] | apply slot_is_buffer | constructor].
Qed.

(* 同一 tile 见证所有 GM 读取的候选取值。所有 UB 写入携带该 tile。 *)
Local Definition stored_at address (v : Val) :=
  address = output \/ (is_buffer layout address /\ v = VFloat input).

Local Lemma schedule_memory count :
  buffers_disjoint layout count ->
  Forall (operation_memory stored_at) (schedule count).
Proof.
  intros disjoint. eapply Permutation_Forall; [apply schedule_permutation |].
  unfold original_blocks, move_run, priming, vector_run. repeat rewrite Forall_app. repeat split.
  all: try (apply chunks_All; intros k depth member; apply in_seq in member;
    unfold move_blocks, vector_blocks, initial_blocks, turn_prefix).
  all: repeat first [apply Forall_nil | apply Forall_cons |
    solve [apply WriteMemory; unfold stored_at;
      first [left; reflexivity | right; split; [apply slot_is_buffer | reflexivity]]] |
    solve [apply OtherMemory; exact I] ].
  - apply ReadMemory. intros v [out | [buf _]].
    + unfold source, output in out; lia.
    + exfalso. eapply disjoint; [exact buf |]. right. apply source_in_inputs; lia.
  - apply ReadMemory. intros v [out | [_ ->]]; [ | reflexivity].
    exfalso. apply (disjoint (iteration_buffer layout k) (slot_is_buffer k)).
    left. symmetry. exact out.
Qed.

Local Lemma chunks_member {A B : Type} (f : nat -> nat -> list A) (g : nat -> nat -> list B)
    width indices depth a :
  In a (chunks width f depth indices) ->
  exists d k, In a (f d k) /\ incl (g d k) (chunks width g depth indices).
Proof.
  revert depth. induction indices as [|k rest IH]; intros depth member; [contradiction |].
  apply in_app_or in member as [direct | tail].
  - exists depth,k. split; auto. intros b present. cbn [chunks]. apply in_or_app; auto.
  - destruct (IH _ tail) as (d & index & found & included). exists d,index. split; auto.
    intros b present. cbn [chunks]. apply in_or_app; auto.
Qed.

Local Lemma schedule_producers count u :
  In u (original_uses count) ->
  exists b, In b (schedule count) /\ operation_id b = producer u /\
    (finish_label b = Some (LReadEnd (used_value u)) \/
     finish_label b = Some (LComputeEnd (used_value u))).
Proof.
  intros use_member. apply in_app_or in use_member as [move | vector].
  - destruct (@chunks_member Use Block (fun depth _ => move_uses depth) (move_blocks count)
      13 (seq 0 count) 3 u move) as (d & k & this_use & this_block).
    cbn [move_uses In] in this_use. destruct this_use as [<-|[]].
    exists (reading 1%positive (8+d) (Dispatch TransferEngine (Some MTE2)) (source k)).
    split.
    + eapply Permutation_in; [apply schedule_permutation |].
      unfold original_blocks, move_run. apply in_or_app; left. apply in_or_app; left.
      apply this_block. cbn [move_blocks turn_prefix app In]. intuition.
    + split; [reflexivity | now left].
  - destruct (@chunks_member Use Block (fun depth _ => vector_uses depth) vector_blocks
      17 (seq 0 count) (vector_base count) u vector) as (d & k & this_use & this_block).
    cbn [vector_uses In] in this_use. destruct this_use as [<-|[<-|[]]].
    + exists (reading 2%positive (7+d) (Dispatch VectorUnit (Some Vector)) (iteration_buffer layout k)).
      split.
      * eapply Permutation_in; [apply schedule_permutation |].
        unfold original_blocks, vector_run. apply in_or_app; right. apply in_or_app; right.
        apply in_or_app; left. apply this_block. cbn [vector_blocks turn_prefix app In]. intuition.
      * split; [reflexivity | now left].
    + exists (exponentiating 2%positive (10+d)). split.
      * eapply Permutation_in; [apply schedule_permutation |].
        unfold original_blocks, vector_run. apply in_or_app; right. apply in_or_app; right.
        apply in_or_app; left. apply this_block. cbn [vector_blocks turn_prefix app In]. intuition.
      * split; [reflexivity | now right].
Qed.

Local Lemma erase_labels (c : Cmd unit) (f : positive -> op_id) p q :
  label_paths (fun _ => tt) q (label_paths f p c) = c.
Proof.
  revert p q. induction c; intros initial_path erase_path; cbn [label_paths]; try reflexivity;
    try (destruct o); f_equal; auto.
Qed.

Local Lemma fully_annotated count : annotates (branches layout count) (annotated count).
Proof.
  split.
  - unfold annotated, annotate_program, branches, issue316, instantiate_shared, expand_program.
    cbn [length seq combine map]. unfold erase_annotations. rewrite !erase_labels. reflexivity.
  - split.
    + rewrite order_signatures, map_map. exact (original_unique count).
    + destruct (ids_properties count) as [L [V _]].
      intros [|[|j]] c eq o member; try (destruct j; discriminate).
      all: inversion eq; subst c.
      * exact (proj1 (Forall_forall _ _) L o member).
      * exact (proj1 (Forall_forall _ _) V o member).
Qed.

Local Lemma scheduled_trace count :
  buffers_disjoint layout count ->
  issue316_trace layout exp_f16 model count
    (event_indices 0 (schedule count)) (interpret_index (schedule count)).
Proof.
  intros disjoint.
  split; [auto |]. split; [apply issue316_well_formed |].
  exists (annotated count). split; [apply fully_annotated |].
  split.
  - exists (branches layout count). split; [apply issue316_well_formed |].
    exact (proj1 (fully_annotated count)).
  - split; [exact (proj2 (fully_annotated count)) |]. split.
    + exists (original_uses count). split.
      * exists (flat_map operation_records (original_blocks count)),
          (flat_map operation_records (schedule count)).
        split; [apply branch_candidates |]. split.
        -- apply serialized_records_unique; [apply original_shape | apply original_unique].
        -- split.
           ++ apply Permutation_flat_map, schedule_permutation.
           ++ rewrite serialized_records. exists []; now rewrite app_nil_r.
      * split.
        -- destruct (serialized_order (annotated count) (schedule_shape count) (blocks_unique count)
             (concrete_heads count) (edge_has_head count) (schedule_order count))
             as (a1 & a2 & a3 & a5).
           refine (conj a1 (conj a2 (conj a3 (conj _ a5)))).
           intros p q f. exists (flat_map (mark p q f) (schedule count)). split.
           ++ apply serialized_flags; auto using schedule_shape, blocks_unique, concrete_heads, marked_projection.
           ++ apply scheduled_flags.
        -- split.
           ++ apply serialized_results; auto using schedule_shape, blocks_unique, schedule_producers.
           ++ eapply serialized_memory. now apply schedule_memory.
    + apply serialized_permissions. apply schedule_permissions.
Qed.
Local Lemma round_addresses count m v indices :
  flat_map (fun e => transferred (payload e))
    (flat_map operation_records (paired_rounds count m v indices)) =
      map (iteration_buffer layout) indices /\
  flat_map (fun e => consumed (payload e))
    (flat_map operation_records (paired_rounds count m v indices)) =
      map (iteration_buffer layout) indices.
Proof.
  revert m v. induction indices as [|k indices IH]; intros m v; [split; reflexivity |].
  cbn [paired_rounds map]. repeat rewrite flat_map_app.
  destruct (IH (13+m) (17+v)) as [L V]. rewrite L,V.
  split; reflexivity.
Qed.

Local Lemma paired_accesses count :
  let t := event_indices 0 (schedule count) in
  let k := interpret_index (schedule count) in
  flat_map (fun e => transferred (payload (k e))) t = buffer_sequence layout count /\
  flat_map (fun e => consumed (payload (k e))) t = buffer_sequence layout count.
Proof.
  cbn zeta.
  rewrite <- (Issue316Safety.flat_after_map (interpret_index (schedule count)) (fun e => transferred (payload e))).
  rewrite <- (Issue316Safety.flat_after_map (interpret_index (schedule count)) (fun e => consumed (payload e))).
  rewrite serialized_records.
  unfold schedule. repeat rewrite flat_map_app.
  destruct (round_addresses count 3 (vector_base count) (seq 0 count)) as [L V].
  rewrite L,V. unfold priming, prime_count, buffer_sequence.
  destruct count as [|[|count]]; cbn; now rewrite ?app_nil_r.
Qed.

Theorem issue316_complete_trace_exists count :
  buffers_disjoint layout count ->
  exists t k,
    issue316_trace layout exp_f16 model count t k /\
    Forall (access_completed t k) t /\
    flat_map (fun e => transferred (payload (k e))) t = buffer_sequence layout count /\
    flat_map (fun e => consumed (payload (k e))) t = buffer_sequence layout count.
Proof.
  intros disjoint.
  exists (event_indices 0 (schedule count)), (interpret_index (schedule count)).
  refine (conj (scheduled_trace disjoint) (conj _ (paired_accesses count))).
  apply serialized_accesses_complete, schedule_shape.
Qed.
End Execution.

Local Lemma odd_layout_disjoint count : buffers_disjoint odd_allocation_layout count.
Proof.
  intros a [->| ->] member; destruct member as [out|member]; try discriminate;
    apply in_map_iff in member as (k & same & _);
    change (2 * S k = 1)%nat in same || change (2 * S k = 5)%nat in same; lia.
Qed.

Corollary issue316_complete_trace_for_all_counts {F16} (exp_f16 : F16 -> F16)
    (model : @computation_model (@Tile F16) nat issue_pipe issue_resource)
    (input : @Tile F16) (computes : implements_vexp exp_f16 model) count :
  exists layout t k,
    issue316_trace layout exp_f16 model count t k /\
    Forall (access_completed t k) t /\
    flat_map (fun e => transferred (payload (k e))) t = buffer_sequence layout count /\
    flat_map (fun e => consumed (payload (k e))) t = buffer_sequence layout count.
Proof. exists odd_allocation_layout. eapply issue316_complete_trace_exists; eauto using odd_layout_disjoint. Qed.

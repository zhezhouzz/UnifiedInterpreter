From Stdlib Require Import List ZArith Lia.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics.
Import ListNotations.
Set Implicit Arguments.

(* ========================================================================== *)
(* 1. 路径前缀性质与 annotate_program 的通用合法性证明                          *)
(* ========================================================================== *)

Section PathDisjointness.

Inductive path_ext (root : positive) : positive -> Prop :=
| PathSelf : path_ext root root
| PathLeft : forall p, path_ext (xO root) p -> path_ext root p
| PathRight : forall p, path_ext (xI root) p -> path_ext root p.

Lemma path_ext_trans a b c :
  path_ext a b -> path_ext b c -> path_ext a c.
Proof.
  intros H1. induction H1; intros H2; auto.
  - apply PathLeft; auto.
  - apply PathRight; auto.
Qed.

Lemma path_ext_xO_step a b : path_ext a b -> path_ext a (xO b).
Proof.
  induction 1.
  - apply PathLeft, PathSelf.
  - apply PathLeft; auto.
  - apply PathRight; auto.
Qed.

Lemma path_ext_xI_step a b : path_ext a b -> path_ext a (xI b).
Proof.
  induction 1.
  - apply PathRight, PathSelf.
  - apply PathLeft; auto.
  - apply PathRight; auto.
Qed.

Fixpoint pos_depth (p : positive) : nat :=
  match p with
  | xH => 0
  | xO q => S (pos_depth q)
  | xI q => S (pos_depth q)
  end.

Lemma path_ext_depth a b : path_ext a b -> (pos_depth a <= pos_depth b)%nat.
Proof.
  induction 1; cbn in *; lia.
Qed.

Lemma path_ext_strict_xO a b : path_ext (xO a) b -> b <> a.
Proof.
  intros H eq; subst. apply path_ext_depth in H; cbn in H; lia.
Qed.

Lemma path_ext_strict_xI a b : path_ext (xI a) b -> b <> a.
Proof.
  intros H eq; subst. apply path_ext_depth in H; cbn in H; lia.
Qed.

(* 判定一个路径是否由 root 经过左/右延伸得到：以 root 为最低位后缀。 *)
Fixpoint pos_bits (p : positive) : list bool :=
  match p with
  | xH => []
  | xO q => false :: pos_bits q
  | xI q => true :: pos_bits q
  end.

Lemma pos_bits_inj a b : pos_bits a = pos_bits b -> a = b.
Proof.
  revert b. induction a; destruct b; cbn; intro H; try discriminate; auto.
  - inversion H; f_equal; auto.
  - inversion H; f_equal; auto.
Qed.

Lemma path_ext_bits a b :
  path_ext a b -> exists pre, pos_bits b = pre ++ pos_bits a.
Proof.
  induction 1.
  - exists []; reflexivity.
  - destruct IHpath_ext as [pre Hpre]. exists (pre ++ [false]).
    rewrite Hpre, <- app_assoc. reflexivity.
  - destruct IHpath_ext as [pre Hpre]. exists (pre ++ [true]).
    rewrite Hpre, <- app_assoc. reflexivity.
Qed.

Lemma app_eq_suffix_head {A} (u v s : list A) (x y : A) :
  u ++ x :: s = v ++ y :: s -> x = y.
Proof.
  intros H.
  assert (Hrev : rev (u ++ x :: s) = rev (v ++ y :: s)) by congruence.
  rewrite !rev_app_distr in Hrev. cbn in Hrev.
  rewrite <- !app_assoc in Hrev.
  apply app_inv_head in Hrev. inversion Hrev. reflexivity.
Qed.

Lemma path_ext_disjoint_children r p :
  path_ext (xO r) p -> ~ path_ext (xI r) p.
Proof.
  intros H1 H2.
  apply path_ext_bits in H1 as [u Hu].
  apply path_ext_bits in H2 as [v Hv].
  cbn in Hu, Hv. rewrite Hu in Hv.
  apply app_eq_suffix_head in Hv. discriminate.
Qed.

End PathDisjointness.

(* ========================================================================== *)
(* 2. annotate_program 对任意源程序的通用标注合法性                             *)
(* ========================================================================== *)

Section AnnotationValidity.
Context {Float EventId Pipe Unit : Type}.
Local Notation RawCmd := (@command Float EventId Pipe Unit unit).
Local Notation AnnCmd := (@command Float EventId Pipe Unit op_id).

Lemma label_paths_ops_spec (tid path : positive) (c : RawCmd) :
  Forall (fun oh => thread (fst oh) = tid /\ path_ext path (snd (fst oh)))
    (operations (label_paths (pair tid) path c)).
Proof.
  revert path. induction c; intros path; cbn [label_paths operations];
    try constructor; try (split; [reflexivity | apply PathSelf]);
    try solve [exact (Forall_nil _)
      | eapply Forall_impl; [ | apply (IHc (xO path))];
        intros [[t0 p0] h0] [Ht Hp]; split; [exact Ht | apply PathLeft; exact Hp]].
  apply Forall_app; split.
  - eapply Forall_impl; [ | apply (IHc1 (xO path))].
    intros [[t0 p0] h0] [Ht Hp]; split; [exact Ht | apply PathLeft; exact Hp].
  - eapply Forall_impl; [ | apply (IHc2 (xI path))].
    intros [[t0 p0] h0] [Ht Hp]; split; [exact Ht | apply PathRight; exact Hp].
Qed.

Lemma label_paths_nodup (tid path : positive) (c : RawCmd) :
  NoDup (op_ids (label_paths (pair tid) path c)).
Proof.
  revert path. induction c; intros path; unfold op_ids in *; cbn [label_paths operations map];
    try apply IHc; try constructor; try apply IHc;
    try solve [cbn; tauto
      | constructor
      | intros Hin; apply in_map_iff in Hin as [[[t0 p0] h0] [Heq Hmem]]; cbn in Heq;
        inversion Heq; subst t0 p0;
        pose proof (proj1 (Forall_forall _ _) (label_paths_ops_spec tid (xO path) c) _ Hmem) as [_ Hext];
        exact (path_ext_strict_xO Hext eq_refl)].
  - rewrite map_app. intros Hin.
    apply in_app_or in Hin as [Hin | Hin];
      apply in_map_iff in Hin as [[[t0 p0] h0] [Heq Hmem]]; cbn in Heq;
      inversion Heq; subst t0 p0.
    + pose proof (proj1 (Forall_forall _ _) (label_paths_ops_spec tid (xO path) c1) _ Hmem) as [_ Hext].
      exact (path_ext_strict_xO Hext eq_refl).
    + pose proof (proj1 (Forall_forall _ _) (label_paths_ops_spec tid (xI path) c2) _ Hmem) as [_ Hext].
      exact (path_ext_strict_xI Hext eq_refl).
  - rewrite map_app.
    assert (Hdisj : forall o0,
      In o0 (map fst (operations (label_paths (pair tid) (xO path) c1))) ->
      ~ In o0 (map fst (operations (label_paths (pair tid) (xI path) c2)))).
    { intros [t0 p0] H1 H2.
      apply in_map_iff in H1 as [[[t1 p1] h1] [E1 M1]].
      apply in_map_iff in H2 as [[[t2 p2] h2] [E2 M2]].
      cbn in E1, E2. inversion E1; inversion E2; subst.
      pose proof (proj1 (Forall_forall _ _) (label_paths_ops_spec tid (xO path) c1) _ M1) as [_ X1].
      pose proof (proj1 (Forall_forall _ _) (label_paths_ops_spec tid (xI path) c2) _ M2) as [_ X2].
      exact (path_ext_disjoint_children X1 X2). }
    clear - IHc1 IHc2 Hdisj.
    specialize (IHc1 (xO path)). specialize (IHc2 (xI path)).
    unfold op_ids in IHc1, IHc2.
    induction (map fst (operations (label_paths (pair tid) (xO path) c1))) as [|x xs IH]; cbn.
    + exact IHc2.
    + inversion IHc1 as [|? ? Hnx Hnd]; subst.
      constructor.
      * intros Hin. apply in_app_or in Hin as [Hin | Hin]; [contradiction |].
        exact (Hdisj x (or_introl eq_refl) Hin).
      * apply IH; [exact Hnd |].
        intros o0 Ho; apply Hdisj; now right.
Qed.

Lemma erase_label_paths (tid path : positive) (c : RawCmd) :
  erase_annotations (label_paths (pair tid) path c) = c.
Proof.
  unfold erase_annotations.
  assert (H : forall (p1 p2 : positive) (c0 : RawCmd),
    label_paths (fun _ => tt) p1 (label_paths (pair tid) p2 c0) = c0).
  { intros p1 p2 c0. revert p1 p2.
    induction c0; intros p1 p2; cbn; f_equal; auto.
    destruct o; reflexivity.
    all: destruct o; reflexivity. }
  apply H.
Qed.

Local Lemma NoDup_app {A} (xs ys : list A) :
  NoDup xs -> NoDup ys -> (forall x, In x xs -> ~ In x ys) -> NoDup (xs ++ ys).
Proof.
  induction 1 as [|a xs Hna Hnd IH]; cbn; intros Hys Hdisj; [exact Hys |].
  constructor.
  - intros Hin. apply in_app_or in Hin as [Hin | Hin]; [contradiction |].
    exact (Hdisj a (or_introl eq_refl) Hin).
  - apply IH; [exact Hys |]. intros x Hx; apply Hdisj; now right.
Qed.

Local Lemma map_concat {A B} (f : A -> B) (xss : list (list A)) :
  map f (concat xss) = concat (map (map f) xss).
Proof. induction xss as [|xs xss IH]; cbn; [reflexivity | rewrite map_app, IH; reflexivity]. Qed.

Local Lemma nth_error_combine_seq {A} (k j : nat) (xs : list A) (j0 : nat) (x : A) :
  nth_error (combine (seq k (length xs)) xs) j = Some (j0, x) ->
  j0 = (k + j)%nat /\ nth_error xs j = Some x.
Proof.
  revert k j. induction xs as [|a xs IH]; intros k [|j] H; cbn in H; try discriminate.
  - inversion H; subst; split; [lia | reflexivity].
  - apply IH in H as [Hj Hnth]; split; [lia | exact Hnth].
Qed.

Lemma annotate_program_valid (raw : @program Float EventId Pipe Unit unit) :
  annotates raw (annotate_program raw).
Proof.
  unfold annotates, annotate_program. split.
  - rewrite map_map.
    assert (H : forall (k : nat) (cs : list RawCmd),
      map (fun jc => erase_annotations (label_paths (pair (Pos.of_succ_nat (fst jc))) 1%positive (snd jc)))
          (combine (seq k (length cs)) cs) = cs).
    { intros k cs. revert k. induction cs as [|c cs IH]; intros k;
        cbn [length seq combine map fst snd]; [reflexivity |].
      rewrite erase_label_paths, IH. reflexivity. }
    unfold expand_program.
    replace (length raw) with (length (expand_program raw)) by (unfold expand_program; apply length_map).
    apply H.
  - split.
    + unfold program_operations. rewrite map_concat, map_map.
      assert (H : forall (k : nat) (cs : list RawCmd),
        NoDup (concat (map (fun jc =>
          op_ids (label_paths (pair (Pos.of_succ_nat (fst jc))) 1%positive (snd jc)))
          (combine (seq k (length cs)) cs)))).
      { intros k cs. revert k. induction cs as [|c cs IH]; intros k; cbn; [constructor |].
        apply NoDup_app; [apply label_paths_nodup | apply IH |].
        intros [t p] H1 H2.
        unfold op_ids in H1. apply in_map_iff in H1 as [[[t1 p1] h1] [E1 M1]].
        cbn in E1; inversion E1; subst t1 p1.
        pose proof (proj1 (Forall_forall _ _)
          (label_paths_ops_spec (Pos.of_succ_nat k) 1%positive c) _ M1) as [Ht1 _].
        cbn in Ht1.
        apply in_concat in H2 as (xs & Hxs & Hmem).
        apply in_map_iff in Hxs as ([j cj] & <- & Hcomb).
        unfold op_ids in Hmem. apply in_map_iff in Hmem as [[[t2 p2] h2] [E2 M2]].
        cbn in E2; inversion E2; subst t2 p2.
        pose proof (proj1 (Forall_forall _ _)
          (label_paths_ops_spec (Pos.of_succ_nat j) 1%positive cj) _ M2) as [Ht2 _].
        cbn in Ht2.
        apply in_combine_l in Hcomb. apply in_seq in Hcomb.
        assert (Heq : Pos.of_succ_nat k = Pos.of_succ_nat j) by congruence.
        apply (f_equal Pos.to_nat) in Heq. rewrite !SuccNat2Pos.id_succ in Heq. lia. }
      rewrite map_map.
      replace (length raw) with (length (expand_program raw)) by (unfold expand_program; apply length_map).
      apply H.
    + intros j c Hnth o Ho.
      rewrite nth_error_map in Hnth.
      destruct (nth_error (combine (seq 0 (length raw)) (expand_program raw)) j) as [[j0 c0]|] eqn:Hcomb;
        try discriminate.
      inversion Hnth; subst c.
      replace (length raw) with (length (expand_program raw)) in Hcomb
        by (unfold expand_program; apply length_map).
      apply nth_error_combine_seq in Hcomb as [Hj0 _]. cbn in Hj0. subst j0.
      unfold op_ids in Ho. apply in_map_iff in Ho as [[o0 h0] [E0 M0]]. cbn in E0; subst o0.
      pose proof (proj1 (Forall_forall _ _)
        (label_paths_ops_spec (Pos.of_succ_nat j) 1%positive c0) _ M0) as [Ht _].
      exact Ht.
Qed.

End AnnotationValidity.

(* ========================================================================== *)
(* 3. 循环续体去函数化（Defunctionalized Loop Stack）与 Refocusing             *)
(* ========================================================================== *)

Section Refocusing.
Context {Float EventId Pipe Unit : Type}.
Local Notation Val := (@value Float EventId Pipe).
Local Notation RawCmd := (@command Float EventId Pipe Unit unit).
Local Notation AnnCmd := (@command Float EventId Pipe Unit op_id).
Local Notation Env := (@environment Float EventId Pipe).

(* 将 expand_loops 的第二参数 at_end（循环体结束时的续体）去函数化为一阶栈帧。 *)
Inductive loop_frame : Type :=
| KLoop (x : var) (next_i hi : nat) (body after : RawCmd).

Record thread_cursor : Type := ThreadCursor {
  cursor_tid : positive;
  cursor_path : positive;
  cursor_env : Env;
  cursor_cmd : RawCmd;
  cursor_stack : list loop_frame
}.

(* 重组函数：把一阶游标还原为静态展开的原始命令与带路径标注的命令。 *)
Fixpoint plug_stack (c : RawCmd) (k : list loop_frame) : RawCmd :=
  match k with
  | [] => expand_loops c LoopEnd
  | KLoop x next_i hi body after :: rest =>
      expand_loops c (plug_stack (For x next_i hi body after) rest)
  end.

Definition annotated_of (cur : thread_cursor) : AnnCmd :=
  label_paths (pair (cursor_tid cur)) (cursor_path cur)
    (plug_stack (cursor_cmd cur) (cursor_stack cur)).

Definition is_event_head (c : RawCmd) : bool :=
  match c with
  | Return _ _ | Alloc _ _ _ | LetAtomic _ _ _ _ _ | AssignPipe _ _ _ _
  | CCompute _ _ _ _ _ | Read _ _ _ _ _ | Write _ _ _ _ _
  | SetFlag _ _ _ _ _ | WaitFlag _ _ _ _ _ | If _ _ _ _ => true
  | CAlias _ _ _ | Select _ _ _ _ _ | For _ _ _ _ _ | LoopEnd => false
  end.

(* 行政重聚焦（Refocusing）：尾递归消除 CAlias、Select、For 与 LoopEnd，
   同时按 label_paths 的二叉树规则实时更新 cursor_path。 *)
Fixpoint refocus (budget : nat) (cur : thread_cursor) : option thread_cursor :=
  match budget with
  | 0 => None
  | S budget' =>
      let tid := cursor_tid cur in
      let path := cursor_path cur in
      let rho := cursor_env cur in
      let stk := cursor_stack cur in
      match cursor_cmd cur with
      | CAlias x v n =>
          match resolve rho v with
          | Some b =>
              refocus budget' (ThreadCursor tid (xO path) (bind rho x b) n stk)
          | None => None
          end
      | Select x cond yes no n =>
          match resolve rho cond with
          | Some (Known (VBool b)) =>
              match resolve rho (if b then yes else no) with
              | Some sel =>
                  refocus budget' (ThreadCursor tid (xO path) (bind rho x sel) n stk)
              | None => None
              end
          | _ => None
          end
      | For x lo hi body after =>
          if Nat.leb hi lo then
            refocus budget' (ThreadCursor tid path rho after stk)
          else
            refocus budget'
              (ThreadCursor tid (xO path) (bind rho x (Known (VInt (Z.of_nat lo))))
                body (KLoop x (S lo) hi body after :: stk))
      | LoopEnd =>
          match stk with
          | KLoop x next_i hi body after :: rest =>
              refocus budget' (ThreadCursor tid path rho (For x next_i hi body after) rest)
          | [] => None
          end
      | _ => Some cur
      end
  end.

Lemma plug_stack_for_empty x lo hi body after k :
  (hi <= lo)%nat ->
  plug_stack (For x lo hi body after) k = plug_stack after k.
Proof.
  intros Hle.
  destruct k as [|[x' ni' hi' b' a'] rest]; cbn [plug_stack expand_loops];
    rewrite (proj2 (Nat.sub_0_le hi lo) Hle); reflexivity.
Qed.

Lemma plug_stack_for_step x lo hi body after k :
  (lo < hi)%nat ->
  plug_stack (For x lo hi body after) k =
  CAlias x (Literal (VInt (Z.of_nat lo)))
    (plug_stack body (KLoop x (S lo) hi body after :: k)).
Proof.
  intros Hlt.
  assert (Hsub : (hi - lo = S (hi - S lo))%nat) by lia.
  destruct k as [|[x' ni' hi' b' a'] rest]; cbn [plug_stack expand_loops];
    rewrite Hsub; reflexivity.
Qed.

Lemma plug_stack_loop_end x next_i hi body after rest :
  plug_stack LoopEnd (KLoop x next_i hi body after :: rest) =
  plug_stack (For x next_i hi body after) rest.
Proof. reflexivity. Qed.

Lemma plug_stack_alias x v n k :
  plug_stack (CAlias x v n) k = CAlias x v (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_select x b y z n k :
  plug_stack (Select x b y z n) k = Select x b y z (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_alloc o x n k :
  plug_stack (Alloc o x n) k = Alloc o x (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_atomic o x f vs n k :
  plug_stack (LetAtomic o x f vs n) k = LetAtomic o x f vs (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_assign_pipe o x v n k :
  plug_stack (AssignPipe o x v n) k = AssignPipe o x v (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_compute o x d vs n k :
  plug_stack (CCompute o x d vs n) k = CCompute o x d vs (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_read o x d a n k :
  plug_stack (Read o x d a n) k = Read o x d a (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_write o d a v n k :
  plug_stack (Write o d a v n) k = Write o d a v (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_setflag o p q e n k :
  plug_stack (SetFlag o p q e n) k = SetFlag o p q e (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_waitflag o p q e n k :
  plug_stack (WaitFlag o p q e n) k = WaitFlag o p q e (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_if o cond y n k :
  plug_stack (If o cond y n) k = If o cond (plug_stack y k) (plug_stack n k).
Proof. destruct k as [|[]]; reflexivity. Qed.

Lemma plug_stack_return o vs k :
  plug_stack (Return o vs) k = Return o vs.
Proof. destruct k as [|[]]; reflexivity. Qed.

(* refocus 的三大核心定理：聚焦性、操作与程序顺序不变性、候选事件保持性。 *)

Lemma refocus_event_head budget cur cur' :
  refocus budget cur = Some cur' ->
  is_event_head (cursor_cmd cur') = true.
Proof.
  revert cur cur'. induction budget as [|budget IH]; intros cur cur' H; [discriminate |].
  destruct cur as [tid path rho cmd stk]. cbn in H.
  destruct cmd; try (inversion H; subst; reflexivity).
  - destruct (resolve rho v); [eapply IH; eassumption | discriminate].
  - destruct (resolve rho condition) as [[[]|]|]; try discriminate.
    destruct (resolve rho (if b then yes else no)); [eapply IH; eassumption | discriminate].
  - destruct (Nat.leb upper lower); eapply IH; eassumption.
  - destruct stk as [|[x ni hi b a] rest]; [discriminate | eapply IH; eassumption].
Qed.

Lemma refocus_preserves_ops_and_po budget cur cur' :
  refocus budget cur = Some cur' ->
  operations (annotated_of cur') = operations (annotated_of cur) /\
  program_order (annotated_of cur') = program_order (annotated_of cur).
Proof.
  revert cur cur'. induction budget as [|budget IH]; intros cur cur' H; [discriminate |].
  destruct cur as [tid path rho cmd stk]. cbn in H.
  destruct cmd; try (inversion H; subst; split; reflexivity).
  - destruct (resolve rho v) as [b|]; [| discriminate].
    apply IH in H as [Ho Hp]. unfold annotated_of in *; cbn in *.
    rewrite plug_stack_alias. cbn [label_paths operations program_order]. auto.
  - destruct (resolve rho condition) as [[[]|]|]; try discriminate.
    destruct (resolve rho (if b then yes else no)) as [sel|]; [| discriminate].
    apply IH in H as [Ho Hp]. unfold annotated_of in *; cbn in *.
    rewrite plug_stack_select. cbn [label_paths operations program_order]. auto.
  - destruct (Nat.leb upper lower) eqn:Hle.
    + apply Nat.leb_le in Hle.
      apply IH in H as [Ho Hp]. unfold annotated_of in *; cbn in *.
      rewrite plug_stack_for_empty by exact Hle. auto.
    + apply Nat.leb_gt in Hle.
      apply IH in H as [Ho Hp]. unfold annotated_of in *; cbn in *.
      rewrite plug_stack_for_step by exact Hle.
      cbn [label_paths operations program_order]. auto.
  - destruct stk as [|[x ni hi b a] rest]; [discriminate |].
    apply IH in H as [Ho Hp]. unfold annotated_of in *; cbn in *. auto.
Qed.

Lemma refocus_preserves_command_events layout model budget cur cur' events uses :
  refocus budget cur = Some cur' ->
  command_events layout model (cursor_env cur') (annotated_of cur') events uses ->
  command_events layout model (cursor_env cur) (annotated_of cur) events uses.
Proof.
  revert cur cur' events uses.
  induction budget as [|budget IH]; intros cur cur' events uses H Hce; [discriminate |].
  destruct cur as [tid path rho cmd stk]. cbn in H.
  destruct cmd; try (inversion H; subst; exact Hce).
  - destruct (resolve rho v) as [b|] eqn:Hr; [| discriminate].
    apply (IH _ _ _ _ H) in Hce.
    unfold annotated_of in *; cbn in *.
    rewrite plug_stack_alias. cbn [label_paths].
    eapply EventsAlias; eassumption.
  - destruct (resolve rho condition) as [[[]|]|] eqn:Hc; try discriminate.
    destruct (resolve rho (if b then yes else no)) as [sel|] eqn:Hs; [| discriminate].
    apply (IH _ _ _ _ H) in Hce.
    unfold annotated_of in *; cbn in *.
    rewrite plug_stack_select. cbn [label_paths].
    eapply EventsSelect; eassumption.
  - destruct (Nat.leb upper lower) eqn:Hle.
    + apply Nat.leb_le in Hle.
      apply (IH _ _ _ _ H) in Hce.
      unfold annotated_of in *; cbn in *.
      rewrite plug_stack_for_empty by exact Hle. exact Hce.
    + apply Nat.leb_gt in Hle.
      apply (IH _ _ _ _ H) in Hce.
      unfold annotated_of in *; cbn in *.
      rewrite plug_stack_for_step by exact Hle. cbn [label_paths].
      eapply EventsAlias; [reflexivity | exact Hce].
  - destruct stk as [|[x ni hi b a] rest]; [discriminate |].
    apply (IH _ _ _ _ H) in Hce.
    unfold annotated_of in *; cbn in *. exact Hce.
Qed.

Lemma events_stop_at_event_head layout model cur :
  is_event_head (cursor_cmd cur) = true ->
  command_events layout model (cursor_env cur) (annotated_of cur) [] [].
Proof.
  intros Hhead.
  destruct cur as [tid path rho cmd stk]. unfold annotated_of; cbn in *.
  destruct cmd; try discriminate;
    rewrite ?plug_stack_return, ?plug_stack_alloc, ?plug_stack_atomic,
            ?plug_stack_assign_pipe, ?plug_stack_compute, ?plug_stack_read,
            ?plug_stack_write, ?plug_stack_setflag, ?plug_stack_waitflag,
            ?plug_stack_if;
    cbn [label_paths]; apply EventsStop; exact I.
Qed.

End Refocusing.

From Stdlib Require Import List ZArith Bool Lia Sorting.Permutation.
From UnifiedInterpreter.Base Require Import Free Result.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics.
From UnifiedInterpreter.CoreLanguage.Derived Require Import
  Refocusing Automaton CoreEffects Handlers Soundness.
Import ListNotations.
Set Implicit Arguments.
Local Arguments ops_unique_head {_ _ _ _} _ {o h1 h2} _ _ _.

(* ========================================================================== *)
(* 1. 基础引理：强归纳、refocus 单调性与完备性、auto_steps 预算单调性             *)
(* ========================================================================== *)

Section BasicCompleteness.
Context {Float EventId Pipe Unit : Type}.
Local Notation Val := (@value Float EventId Pipe).
Local Notation RawCmd := (@command Float EventId Pipe Unit unit).
Local Notation AnnCmd := (@command Float EventId Pipe Unit op_id).
Local Notation Rec := (@event_record Float EventId Pipe Unit).
Local Notation Use := (@use_record Float EventId Pipe).
Local Notation Cursor := (@thread_cursor Float EventId Pipe Unit).
Local Notation Frame := (@loop_frame Float EventId Pipe Unit).
Local Notation TState := (@thread_state Float EventId Pipe Unit).
Local Notation PKind := (@pending_kind Float EventId Pipe Unit).
Local Notation MState := (@machine_state Float EventId Pipe Unit).
Local Notation Model := (@computation_model Float EventId Pipe Unit).

Lemma nat_strong_ind (P : nat -> Prop) :
  (forall n, (forall m, (m < n)%nat -> P m) -> P n) ->
  forall n, P n.
Proof.
  intros Hstep n.
  assert (H : forall k m, (m < k)%nat -> P m).
  { induction k as [|k IH]; intros m Hm; [lia |].
    apply Hstep. intros m' Hm'. apply IH; lia. }
  apply (H (S n)); lia.
Qed.

Fixpoint cmd_size {L : Type} (c : @command Float EventId Pipe Unit L) : nat :=
  match c with
  | Return _ _ | LoopEnd => 1
  | CAlias _ _ n | Alloc _ _ n | LetAtomic _ _ _ _ n | Select _ _ _ _ n
  | AssignPipe _ _ _ n | CCompute _ _ _ _ n | Read _ _ _ _ n | Write _ _ _ _ n
  | SetFlag _ _ _ _ n | WaitFlag _ _ _ _ n => S (cmd_size n)
  | For _ _ _ body after => S (cmd_size body + cmd_size after)
  | If _ _ y n => S (cmd_size y + cmd_size n)
  end.

Fixpoint stack_wf (stk : list Frame) : Prop :=
  match stk with
  | [] => True
  | KLoop _ _ _ body after :: rest =>
      ends_correctly true body /\
      ends_correctly (match rest with [] => false | _ => true end) after /\
      stack_wf rest
  end.

Definition cursor_wf (cur : Cursor) : Prop :=
  ends_correctly (match cursor_stack cur with [] => false | _ => true end) (cursor_cmd cur) /\
  stack_wf (cursor_stack cur).

Lemma refocus_mono {b1 b2} {cur cur' : Cursor} :
  (b1 <= b2)%nat ->
  refocus b1 cur = Some cur' ->
  refocus b2 cur = Some cur'.
Proof.
  revert b2 cur cur'. induction b1 as [|b1 IH]; intros [|b2] cur cur' Hle H;
    cbn in H; try discriminate; try lia.
  destruct cur as [tid path rho cmd stk]. cbn in *.
  destruct cmd; try exact H.
  - destruct (resolve rho v); [eapply IH; [lia | exact H] | discriminate].
  - destruct (resolve rho condition) as [[[]|]|]; try discriminate.
    destruct (resolve rho (if b then yes else no)); [eapply IH; [lia | exact H] | discriminate].
  - destruct (Nat.leb upper lower); eapply IH; [lia | exact H | lia | exact H].
  - destruct stk as [|[] rest]; [discriminate | eapply IH; [lia | exact H]].
Qed.

Lemma init_threads_aux_mono {b1 b2 idx} {branches : list RawCmd} {ts} :
  (b1 <= b2)%nat ->
  init_threads_aux b1 idx branches = Ok ts ->
  init_threads_aux b2 idx branches = Ok ts.
Proof.
  revert idx ts. induction branches as [|c rest IH]; intros idx ts Hle H; cbn in *; [exact H |].
  destruct (refocus b1 _) as [cur|] eqn:Href; [| discriminate].
  rewrite (refocus_mono Hle Href).
  destruct (init_threads_aux b1 (S idx) rest) as [ts'|] eqn:Hr; cbn [result_bind] in H; [| discriminate].
  rewrite (IH (S idx) ts' Hle Hr). exact H.
Qed.

Lemma init_machine_mono {b1 b2} {branches : list RawCmd} {st0} :
  (b1 <= b2)%nat ->
  init_machine b1 branches = Ok st0 ->
  init_machine b2 branches = Ok st0.
Proof.
  unfold init_machine. intros Hle H.
  destruct (init_threads_aux b1 0 branches) as [ts|] eqn:Ht; cbn [result_bind] in H; [| discriminate].
  rewrite (init_threads_aux_mono Hle Ht). exact H.
Qed.

Lemma auto_step_mono {layout cfg model Pe Ee b1 b2 st ev st'} :
  (b1 <= b2)%nat ->
  @auto_step Float EventId Pipe Unit layout cfg model Pe Ee b1 st ev st' ->
  @auto_step Float EventId Pipe Unit layout cfg model Pe Ee b2 st ev st'.
Proof.
  intros Hle H.
  destruct H;
    first [ eapply StepAlloc | eapply StepAtomic | eapply StepAssignPipe
          | eapply StepReadStart | eapply StepWriteStart | eapply StepComputeStart
          | eapply StepSetFlagStart | eapply StepWaitFlagStart | eapply StepIf
          | eapply StepReturn | eapply StepReadEnd | eapply StepWriteEnd
          | eapply StepComputeEnd | eapply StepSetFlagEnd | eapply StepWaitFlagEnd ];
    try eassumption; unfold advance_cursor in *; (eapply refocus_mono; [exact Hle | eassumption]).
Qed.

Lemma auto_steps_mono {layout cfg model Pe Ee b1 b2 st1 st2} :
  (b1 <= b2)%nat ->
  @auto_steps Float EventId Pipe Unit layout cfg model Pe Ee b1 st1 st2 ->
  @auto_steps Float EventId Pipe Unit layout cfg model Pe Ee b2 st1 st2.
Proof.
  intros Hle H. induction H; [constructor |].
  eapply StepsTrans; [eapply auto_step_mono; eassumption | exact IHauto_steps].
Qed.

(* 若游标满足 cursor_wf 且其展开命令有合法 command_events 推导，则 refocus 必在有限步内停在事件头上。 *)
Lemma command_events_refocus layout (model : Model) (cur : Cursor) events uses :
  cursor_wf cur ->
  command_events layout model (cursor_env cur) (annotated_of cur) events uses ->
  exists budget cur',
    refocus budget cur = Some cur' /\
    is_event_head (cursor_cmd cur') = true /\
    cursor_wf cur' /\
    cursor_tid cur' = cursor_tid cur /\
    command_events layout model (cursor_env cur') (annotated_of cur') events uses.
Proof.
  remember (cmd_size (plug_stack (cursor_cmd cur) (cursor_stack cur))) as n1 eqn:Hn1.
  remember (length (cursor_stack cur)) as n2 eqn:Hn2.
  remember (cmd_size (cursor_cmd cur)) as n3 eqn:Hn3.
  revert n2 n3 cur Hn1 Hn2 Hn3.
  induction n1 as [n1 IH1] using nat_strong_ind.
  intros n2. induction n2 as [n2 IH2] using nat_strong_ind.
  intros n3. induction n3 as [n3 IH3] using nat_strong_ind.
  intros [tid path rho cmd stk] Hn1 Hn2 Hn3 [Hec Hsw] Hce.
  cbn [cursor_cmd cursor_stack cursor_env cursor_tid] in *. subst n1 n2 n3.
  destruct (is_event_head cmd) eqn:Hhead.
  { exists 1%nat, (ThreadCursor tid path rho cmd stk).
    split; [destruct cmd; try discriminate Hhead; reflexivity |].
    split; [exact Hhead | split; [exact (conj Hec Hsw) | split; [reflexivity | exact Hce]]]. }
  destruct cmd as [| x v next | | | x cond yes no next | | | | | | | x lo hi body after | |];
    try discriminate Hhead.
  - (* CAlias *)
    unfold annotated_of in Hce; cbn [cursor_tid cursor_path cursor_cmd cursor_stack] in Hce.
    rewrite plug_stack_alias in Hce; cbn [label_paths] in Hce.
    inversion Hce as [| ? ? ? ? b ? ? Hres Hce' | | | | | | | | | | |]; subst; [contradiction |].
    set (cur1 := ThreadCursor tid (xO path) (bind rho x b) next stk).
    assert (Hlt : (cmd_size (plug_stack (cursor_cmd cur1) (cursor_stack cur1)) < cmd_size (plug_stack (CAlias x v next) stk))%nat).
    { unfold cur1; rewrite plug_stack_alias; cbn [cmd_size cursor_cmd cursor_stack]; lia. }
    destruct (IH1 _ Hlt (length (cursor_stack cur1)) (cmd_size (cursor_cmd cur1)) cur1
                  eq_refl eq_refl eq_refl (conj Hec Hsw) Hce')
      as [b1 [cur' [Href [Hhead' [Hwf' [Htid' Hce'']]]]]].
    exists (S b1), cur'; split; [| split; [exact Hhead' | split; [exact Hwf' | split; [exact Htid' | exact Hce'']]]].
    cbn [refocus cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    rewrite Hres. exact Href.
  - (* Select *)
    unfold annotated_of in Hce; cbn [cursor_tid cursor_path cursor_cmd cursor_stack] in Hce.
    rewrite plug_stack_select in Hce; cbn [label_paths] in Hce.
    inversion Hce as [| | ? ? ? ? ? ? b sel ? ? Hcond Hsel Hce' | | | | | | | | | |]; subst; [contradiction |].
    set (cur1 := ThreadCursor tid (xO path) (bind rho x sel) next stk).
    assert (Hlt : (cmd_size (plug_stack (cursor_cmd cur1) (cursor_stack cur1)) < cmd_size (plug_stack (Select x cond yes no next) stk))%nat).
    { unfold cur1; rewrite plug_stack_select; cbn [cmd_size cursor_cmd cursor_stack]; lia. }
    destruct (IH1 _ Hlt (length (cursor_stack cur1)) (cmd_size (cursor_cmd cur1)) cur1
                  eq_refl eq_refl eq_refl (conj Hec Hsw) Hce')
      as [b1 [cur' [Href [Hhead' [Hwf' [Htid' Hce'']]]]]].
    exists (S b1), cur'; split; [| split; [exact Hhead' | split; [exact Hwf' | split; [exact Htid' | exact Hce'']]]].
    cbn [refocus cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    rewrite Hcond, Hsel. exact Href.
  - (* For *)
    destruct Hec as [Hec_body Hec_after].
    destruct (Nat.leb hi lo) eqn:Hle.
    + apply Nat.leb_le in Hle.
      set (cur1 := ThreadCursor tid path rho after stk).
      assert (Hplug : plug_stack (For x lo hi body after) stk = plug_stack after stk)
        by (apply plug_stack_for_empty; exact Hle).
      assert (Hce1 : command_events layout model (cursor_env cur1) (annotated_of cur1) events uses).
      { unfold annotated_of, cur1 in *; cbn in *; rewrite <- Hplug; exact Hce. }
      assert (Hlt3 : (cmd_size (cursor_cmd cur1) < cmd_size (For x lo hi body after))%nat) by (unfold cur1; cbn; lia).
      assert (Hn1' : cmd_size (plug_stack (For x lo hi body after) stk) =
                     cmd_size (plug_stack (cursor_cmd cur1) (cursor_stack cur1)))
        by (unfold cur1; cbn; rewrite Hplug; reflexivity).
      destruct (IH3 _ Hlt3 cur1 Hn1' eq_refl eq_refl (conj Hec_after Hsw) Hce1)
        as [b1 [cur' [Href [Hhead' [Hwf' [Htid' Hce'']]]]]].
      exists (S b1), cur'; split; [| split; [exact Hhead' | split; [exact Hwf' | split; [exact Htid' | exact Hce'']]]].
      cbn [refocus cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
      rewrite (proj2 (Nat.leb_le _ _) Hle). exact Href.
    + apply Nat.leb_gt in Hle.
      set (stk1 := KLoop x (S lo) hi body after :: stk).
      set (cur1 := ThreadCursor tid (xO path) (bind rho x (Known (VInt (Z.of_nat lo)))) body stk1).
      assert (Hplug : plug_stack (For x lo hi body after) stk =
                      CAlias x (Literal (VInt (Z.of_nat lo))) (plug_stack body stk1))
        by (apply plug_stack_for_step; exact Hle).
      unfold annotated_of in Hce; cbn in Hce; rewrite Hplug in Hce; cbn [label_paths] in Hce.
      inversion Hce as [| ? ? ? ? b ? ? Hres Hce' | | | | | | | | | | |]; subst; [contradiction |].
      cbn [resolve] in Hres; inversion Hres; subst b.
      assert (Hlt1 : (cmd_size (plug_stack (cursor_cmd cur1) (cursor_stack cur1)) < cmd_size (plug_stack (For x lo hi body after) stk))%nat).
      { unfold cur1; rewrite Hplug; cbn [cmd_size cursor_cmd cursor_stack]; lia. }
      assert (Hwf1 : cursor_wf cur1) by (unfold cursor_wf, cur1, stk1; cbn; repeat split; assumption).
      destruct (IH1 _ Hlt1 (length (cursor_stack cur1)) (cmd_size (cursor_cmd cur1)) cur1
                    eq_refl eq_refl eq_refl Hwf1 Hce')
        as [b1 [cur' [Href [Hhead' [Hwf' [Htid' Hce'']]]]]].
      exists (S b1), cur'; split; [| split; [exact Hhead' | split; [exact Hwf' | split; [exact Htid' | exact Hce'']]]].
      cbn [refocus cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
      rewrite (proj2 (Nat.leb_gt _ _) Hle). exact Href.
  - (* LoopEnd *)
    destruct stk as [|[x ni hi body after] rest]; [cbn in Hec; discriminate |].
    destruct Hsw as [Hec_b [Hec_a Hsw_rest]].
    set (cur1 := ThreadCursor tid path rho (For x ni hi body after) rest).
    assert (Hlt2 : (length (cursor_stack cur1) < length (KLoop x ni hi body after :: rest))%nat) by (unfold cur1; cbn; lia).
    assert (Hwf1 : cursor_wf cur1) by (unfold cursor_wf, cur1; cbn; repeat split; assumption).
    destruct (IH2 _ Hlt2 (cmd_size (cursor_cmd cur1)) cur1 eq_refl eq_refl eq_refl Hwf1 Hce)
      as [b1 [cur' [Href [Hhead' [Hwf' [Htid' Hce'']]]]]].
    exists (S b1), cur'; split; [exact Href | split; [exact Hhead' | split; [exact Hwf' | split; [exact Htid' | exact Hce'']]]].
Qed.

Lemma init_threads_aux_complete layout (model : Model) idx (branches : list RawCmd)
    (br_evs : list (list Rec)) (br_uses : list (list Use)) :
  Forall (ends_correctly false) branches ->
  length br_evs = length branches ->
  length br_uses = length branches ->
  (forall k c evs us,
     nth_error branches k = Some c ->
     nth_error br_evs k = Some evs ->
     nth_error br_uses k = Some us ->
     command_events layout model empty_environment
       (label_paths (pair (Pos.of_succ_nat (idx + k))) 1%positive (expand_loops c LoopEnd))
       evs us) ->
  exists budget ts,
    (1 <= budget)%nat /\
    init_threads_aux budget idx branches = Ok ts /\
    length ts = length branches /\
    forall k t evs us,
      nth_error ts k = Some t ->
      nth_error br_evs k = Some evs ->
      nth_error br_uses k = Some us ->
      exists cur,
        t = TRunning cur /\
        cursor_wf cur /\
        is_event_head (cursor_cmd cur) = true /\
        cursor_tid cur = Pos.of_succ_nat (idx + k) /\
        command_events layout model (cursor_env cur) (annotated_of cur) evs us.
Proof.
  revert idx br_evs br_uses.
  induction branches as [|c rest IH]; intros idx br_evs br_uses Hec Hle Hlu Hall.
  - destruct br_evs; [| discriminate]. destruct br_uses; [| discriminate].
    exists 1%nat, []. repeat split; try lia; try reflexivity.
    intros k ? ? ? H; destruct k; discriminate H.
  - destruct br_evs as [|evs0 br_evs']; [discriminate |].
    destruct br_uses as [|us0 br_uses']; [discriminate |].
    inversion Hec as [|? ? Hec0 Hec_rest]; subst.
    cbn [length] in Hle, Hlu.
    set (cur0 := ThreadCursor (Pos.of_succ_nat idx) 1%positive empty_environment c []).
    assert (Hwf0 : cursor_wf cur0) by (unfold cursor_wf; cbn; split; [exact Hec0 | exact I]).
    assert (Hce0 : command_events layout model (cursor_env cur0) (annotated_of cur0) evs0 us0).
    { unfold annotated_of, cur0; cbn.
      pose proof (Hall 0%nat c evs0 us0 eq_refl eq_refl eq_refl) as H0.
      rewrite Nat.add_0_r in H0. exact H0. }
    destruct (command_events_refocus Hwf0 Hce0) as [b0 [cur' [Href0 [Hhead0 [Hwf' [Htid' Hce']]]]]].
    destruct (IH (S idx) br_evs' br_uses' Hec_rest ltac:(lia) ltac:(lia)) as [b1 [ts' [Hb1 [Hinit1 [Hlen1 Hall1]]]]].
    { intros k c' evs' us' Hc He Hu.
      replace (S idx + k)%nat with (idx + S k)%nat by lia.
      eapply Hall; eassumption. }
    exists (Nat.max (Nat.max 1 b0) b1), (TRunning cur' :: ts').
    repeat split; [lia | | cbn; lia |].
    + cbn [init_threads_aux]. fold cur0.
      rewrite (refocus_mono (b1 := b0) (b2 := Nat.max (Nat.max 1 b0) b1) ltac:(lia) Href0).
      rewrite (init_threads_aux_mono (b1 := b1) (b2 := Nat.max (Nat.max 1 b0) b1) ltac:(lia) Hinit1).
      reflexivity.
    + intros [|k] t evs us Ht He Hu; cbn in Ht, He, Hu.
      * inversion Ht; inversion He; inversion Hu; subst.
        exists cur'; split; [reflexivity | split; [exact Hwf' | split; [exact Hhead0 | split; [rewrite Htid', Nat.add_0_r; reflexivity | exact Hce']]]].
      * destruct (Hall1 k t evs us Ht He Hu) as [curk [Ht' [Hwfk [Hheadk [Htk Hcek]]]]].
        exists curk; split; [exact Ht' | split; [exact Hwfk | split; [exact Hheadk | split; [rewrite Htk; f_equal; lia | exact Hcek]]]].
Qed.

End BasicCompleteness.

(* ========================================================================== *)
(* 2. program_events / command_events 的结构化性质与 A4 投影禁用引理             *)
(* ========================================================================== *)

Section TraceStructure.
Context {Float EventId Pipe Unit : Type}.
Local Notation Val := (@value Float EventId Pipe).
Local Notation AnnCmd := (@command Float EventId Pipe Unit op_id).
Local Notation Rec := (@event_record Float EventId Pipe Unit).
Local Notation Use := (@use_record Float EventId Pipe).
Local Notation Model := (@computation_model Float EventId Pipe Unit).

Lemma program_events_split layout (model : Model) (ann : list AnnCmd) events uses :
  program_events layout model ann events uses ->
  exists (br_evs : list (list Rec)) (br_uses : list (list Use)),
    length br_evs = length ann /\
    length br_uses = length ann /\
    events = concat br_evs /\
    uses = concat br_uses /\
    forall j ann_j evs_j uses_j,
      nth_error ann j = Some ann_j ->
      nth_error br_evs j = Some evs_j ->
      nth_error br_uses j = Some uses_j ->
      command_events layout model empty_environment ann_j evs_j uses_j.
Proof.
  induction 1 as [|c p evs rem us rest Hc Hp [br_evs [br_uses [Hle [Hlu [He [Hu Hall]]]]]]].
  - exists [], []. repeat split; auto. intros [|j]; discriminate.
  - exists (evs :: br_evs), (us :: br_uses).
    cbn; repeat split; try lia; try (rewrite He; reflexivity); try (rewrite Hu; reflexivity).
    intros [|j] ann_j evs_j uses_j Ha Hej Huj; cbn in Ha, Hej, Huj.
    + inversion Ha; inversion Hej; inversion Huj; subst; exact Hc.
    + eapply Hall; eassumption.
Qed.

Lemma command_events_rec_spec layout (model : Model) rho (c : AnnCmd) evs us :
  command_events layout model rho c evs us ->
  forall {r}, In r evs ->
    exists h, In (owner r, h) (operations c) /\
      (kind (payload r) = start_kind h \/ kind (payload r) = end_kind h).
Proof.
  induction 1; intros r Hr; cbn [In operations] in *;
    try contradiction;
    try solve [exact (IHcommand_events r Hr)];
    try solve [destruct Hr as [<- | Hr];
      [eexists; split; [left; reflexivity | cbn; now left]
      | apply IHcommand_events in Hr as [h [Hh Hk]]; exists h; split; [now right | exact Hk]]];
    try solve [destruct Hr as [<- | [<- | Hr]];
      [eexists; split; [left; reflexivity | cbn; now left]
      | eexists; split; [left; reflexivity | cbn; now right]
      | apply IHcommand_events in Hr as [h [Hh Hk]]; exists h; split; [now right | exact Hk]]].
  - destruct Hr as [<- | Hr].
    + exists HIf; split; [now left | cbn; now left].
    + apply IHcommand_events in Hr as [h [Hh Hk]].
      exists h; split; [right; apply in_app_iff; destruct b; auto | exact Hk].
  - destruct Hr as [<- | []]. exists HReturn; split; [now left | cbn; now left].
Qed.

Lemma command_events_owners layout (model : Model) rho (c : AnnCmd) evs us {r} :
  command_events layout model rho c evs us ->
  In r evs ->
  In (owner r) (op_ids c).
Proof.
  intros Hce Hr. destruct (command_events_rec_spec Hce Hr) as [h [Hh _]].
  unfold op_ids; change (owner r) with (fst (owner r, h)); apply in_map; exact Hh.
Qed.

Lemma command_events_unique_phase layout (model : Model) rho (c : AnnCmd) evs us :
  command_events layout model rho c evs us ->
  NoDup (op_ids c) ->
  forall {r1 r2}, In r1 evs -> In r2 evs ->
    owner r1 = owner r2 ->
    kind (payload r1) = kind (payload r2) ->
    r1 = r2.
Proof.
  induction 1; intros Hnd r1 r2 Hin1 Hin2 Ho Hk; cbn [In op_ids operations map] in *;
    try contradiction; try solve [eapply IHcommand_events; eassumption].
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    destruct Hin1 as [<- | Hin1]; destruct Hin2 as [<- | Hin2]; cbn [owner] in Ho; try reflexivity.
    + exfalso; apply Hni. rewrite Ho. eapply command_events_owners; eassumption.
    + exfalso; apply Hni. rewrite <- Ho. eapply command_events_owners; eassumption.
    + eapply IHcommand_events; eassumption.
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    destruct Hin1 as [<- | Hin1]; destruct Hin2 as [<- | Hin2]; cbn [owner] in Ho; try reflexivity.
    + exfalso; apply Hni. rewrite Ho. eapply command_events_owners; eassumption.
    + exfalso; apply Hni. rewrite <- Ho. eapply command_events_owners; eassumption.
    + eapply IHcommand_events; eassumption.
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    destruct Hin1 as [<- | Hin1]; destruct Hin2 as [<- | Hin2]; cbn [owner] in Ho; try reflexivity.
    + exfalso; apply Hni. rewrite Ho. eapply command_events_owners; eassumption.
    + exfalso; apply Hni. rewrite <- Ho. eapply command_events_owners; eassumption.
    + eapply IHcommand_events; eassumption.
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    destruct Hin1 as [<- | [<- | Hin1]]; destruct Hin2 as [<- | [<- | Hin2]]; cbn [owner payload kind] in Ho, Hk; try reflexivity; try discriminate;
      try (exfalso; apply Hni; first [rewrite Ho | rewrite <- Ho]; eapply command_events_owners; eassumption);
      eapply IHcommand_events; eassumption.
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    destruct Hin1 as [<- | [<- | Hin1]]; destruct Hin2 as [<- | [<- | Hin2]]; cbn [owner payload kind] in Ho, Hk; try reflexivity; try discriminate;
      try (exfalso; apply Hni; first [rewrite Ho | rewrite <- Ho]; eapply command_events_owners; eassumption);
      eapply IHcommand_events; eassumption.
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    destruct Hin1 as [<- | [<- | Hin1]]; destruct Hin2 as [<- | [<- | Hin2]]; cbn [owner payload kind] in Ho, Hk; try reflexivity; try discriminate;
      try (exfalso; apply Hni; first [rewrite Ho | rewrite <- Ho]; eapply command_events_owners; eassumption);
      eapply IHcommand_events; eassumption.
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    destruct Hin1 as [<- | [<- | Hin1]]; destruct Hin2 as [<- | [<- | Hin2]]; cbn [owner payload kind] in Ho, Hk; try reflexivity; try discriminate;
      try (exfalso; apply Hni; first [rewrite Ho | rewrite <- Ho]; eapply command_events_owners; eassumption);
      eapply IHcommand_events; eassumption.
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    destruct Hin1 as [<- | [<- | Hin1]]; destruct Hin2 as [<- | [<- | Hin2]]; cbn [owner payload kind] in Ho, Hk; try reflexivity; try discriminate;
      try (exfalso; apply Hni; first [rewrite Ho | rewrite <- Ho]; eapply command_events_owners; eassumption);
      eapply IHcommand_events; eassumption.
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    rewrite map_app in Hni, Hnd'. apply NoDup_app_disjoint in Hnd' as [Hnd1 [Hnd2 _]].
    destruct Hin1 as [<- | Hin1]; destruct Hin2 as [<- | Hin2]; cbn [owner] in Ho; try reflexivity.
    + exfalso; apply Hni, in_app_iff; rewrite Ho; destruct b; [left | right]; eapply command_events_owners; eassumption.
    + exfalso; apply Hni, in_app_iff; rewrite <- Ho; destruct b; [left | right]; eapply command_events_owners; eassumption.
    + eapply IHcommand_events; [destruct b; assumption | | | |]; eassumption.
  - destruct Hin1 as [<- | []]; destruct Hin2 as [<- | []]; reflexivity.
Qed.

Lemma command_events_compute_comp layout (model : Model) rho (c : AnnCmd) evs us :
  command_events layout model rho c evs us ->
  NoDup (op_ids c) ->
  forall {o d args res},
    In (EventRecord o (LComputeStart d args)) evs ->
    In (EventRecord o (LComputeEnd res)) evs ->
    comp model (resource d) args res.
Proof.
  induction 1; intros Hnd o0 d0 args0 res0 Hin1 Hin2; cbn [In op_ids operations map] in *;
    try contradiction; try solve [eapply IHcommand_events; eassumption];
    try solve [inversion Hnd as [|? ? Hni Hnd']; subst;
      destruct Hin1 as [E1 | Hin1]; [discriminate E1 |];
      destruct Hin2 as [E2 | Hin2]; [discriminate E2 |];
      eapply IHcommand_events; eassumption];
    try solve [inversion Hnd as [|? ? Hni Hnd']; subst;
      destruct Hin1 as [E1 | [E1 | Hin1]]; try discriminate E1;
      destruct Hin2 as [E2 | [E2 | Hin2]]; try discriminate E2;
      eapply IHcommand_events; eassumption].
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    destruct Hin1 as [E1 | [E1 | Hin1]]; try discriminate E1.
    + inversion E1; subst o0 d0 args0.
      destruct Hin2 as [E2 | [E2 | Hin2]]; try discriminate E2.
      * inversion E2; subst res0; exact H0.
      * exfalso; apply Hni. exact (command_events_owners H1 Hin2).
    + destruct Hin2 as [E2 | [E2 | Hin2]]; try discriminate E2.
      * inversion E2; subst o0 res0.
        exfalso; apply Hni. exact (command_events_owners H1 Hin1).
      * eapply IHcommand_events; eassumption.
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    rewrite map_app in Hnd'. apply NoDup_app_disjoint in Hnd' as [Hnd1 [Hnd2 _]].
    destruct Hin1 as [E1 | Hin1]; [discriminate E1 |].
    destruct Hin2 as [E2 | Hin2]; [discriminate E2 |].
    eapply IHcommand_events; [destruct b; assumption | exact Hin1 | exact Hin2].
  - destruct Hin1 as [E1 | []]; discriminate E1.
Qed.

Lemma program_events_rec_spec layout (model : Model) (ann : list AnnCmd) evs us :
  program_events layout model ann evs us ->
  forall {r}, In r evs ->
    rec_is_start ann r \/ rec_is_end ann r.
Proof.
  intros Hpe r Hr.
  apply program_events_split in Hpe as [br_evs [br_uses [Hle [Hlu [-> [_ Hall]]]]]].
  apply in_concat in Hr as [evs_j [Hmem Hr]].
  apply In_nth_error in Hmem as [j Hj].
  destruct (nth_error ann j) as [ann_j|] eqn:Ha; [| apply nth_error_None in Ha; assert (j < length br_evs)%nat by (apply nth_error_Some; congruence); lia].
  destruct (nth_error br_uses j) as [us_j|] eqn:Hu; [| apply nth_error_None in Hu; assert (j < length br_evs)%nat by (apply nth_error_Some; congruence); lia].
  pose proof (Hall j ann_j evs_j us_j Ha Hj Hu) as Hce.
  destruct (command_events_rec_spec Hce Hr) as [h [Hh [Hk | Hk]]].
  - left; exists h; split; [eapply branch_ops_in_program; eassumption | exact Hk].
  - right; exists h; split; [eapply branch_ops_in_program; eassumption | exact Hk].
Qed.

Lemma program_events_unique_phase layout (model : Model) (ann : list AnnCmd) evs us :
  program_events layout model ann evs us ->
  annotations_valid ann ->
  forall {r1 r2}, In r1 evs -> In r2 evs ->
    owner r1 = owner r2 ->
    kind (payload r1) = kind (payload r2) ->
    r1 = r2.
Proof.
  intros Hpe Hval r1 r2 H1 H2 Ho Hk.
  apply program_events_split in Hpe as [br_evs [br_uses [Hle [Hlu [-> [_ Hall]]]]]].
  apply in_concat in H1 as [evs1 [Hm1 Hr1]].
  apply in_concat in H2 as [evs2 [Hm2 Hr2]].
  apply In_nth_error in Hm1 as [j1 Hj1].
  apply In_nth_error in Hm2 as [j2 Hj2].
  destruct (nth_error ann j1) as [a1|] eqn:Ha1; [| apply nth_error_None in Ha1; assert (j1 < length br_evs)%nat by (apply nth_error_Some; congruence); lia].
  destruct (nth_error ann j2) as [a2|] eqn:Ha2; [| apply nth_error_None in Ha2; assert (j2 < length br_evs)%nat by (apply nth_error_Some; congruence); lia].
  destruct (nth_error br_uses j1) as [u1|] eqn:Hu1; [| apply nth_error_None in Hu1; assert (j1 < length br_evs)%nat by (apply nth_error_Some; congruence); lia].
  destruct (nth_error br_uses j2) as [u2|] eqn:Hu2; [| apply nth_error_None in Hu2; assert (j2 < length br_evs)%nat by (apply nth_error_Some; congruence); lia].
  pose proof (Hall j1 a1 evs1 u1 Ha1 Hj1 Hu1) as Hce1.
  pose proof (Hall j2 a2 evs2 u2 Ha2 Hj2 Hu2) as Hce2.
  pose proof (command_events_owners Hce1 Hr1) as Ho1.
  pose proof (command_events_owners Hce2 Hr2) as Ho2.
  rewrite <- Ho in Ho2.
  assert (Heq : j1 = j2) by (eapply in_branch_ops_unique_index; eassumption). subst j2.
  rewrite Ha1 in Ha2; inversion Ha2; subst a2.
  rewrite Hj1 in Hj2; inversion Hj2; subst evs2.
  eapply command_events_unique_phase;
    [exact Hce1 | eapply branch_ops_nodup; [exact (proj1 Hval) | exact Ha1] | exact Hr1 | exact Hr2 | exact Ho | exact Hk].
Qed.

Lemma program_events_compute_comp layout (model : Model) (ann : list AnnCmd) evs us :
  program_events layout model ann evs us ->
  annotations_valid ann ->
  forall {o d args res},
    In (EventRecord o (LComputeStart d args)) evs ->
    In (EventRecord o (LComputeEnd res)) evs ->
    comp model (resource d) args res.
Proof.
  intros Hpe Hval o d args res H1 H2.
  apply program_events_split in Hpe as [br_evs [br_uses [Hle [Hlu [-> [_ Hall]]]]]].
  apply in_concat in H1 as [evs1 [Hm1 Hr1]].
  apply in_concat in H2 as [evs2 [Hm2 Hr2]].
  apply In_nth_error in Hm1 as [j1 Hj1].
  apply In_nth_error in Hm2 as [j2 Hj2].
  destruct (nth_error ann j1) as [a1|] eqn:Ha1; [| apply nth_error_None in Ha1; assert (j1 < length br_evs)%nat by (apply nth_error_Some; congruence); lia].
  destruct (nth_error ann j2) as [a2|] eqn:Ha2; [| apply nth_error_None in Ha2; assert (j2 < length br_evs)%nat by (apply nth_error_Some; congruence); lia].
  destruct (nth_error br_uses j1) as [u1|] eqn:Hu1; [| apply nth_error_None in Hu1; assert (j1 < length br_evs)%nat by (apply nth_error_Some; congruence); lia].
  destruct (nth_error br_uses j2) as [u2|] eqn:Hu2; [| apply nth_error_None in Hu2; assert (j2 < length br_evs)%nat by (apply nth_error_Some; congruence); lia].
  pose proof (Hall j1 a1 evs1 u1 Ha1 Hj1 Hu1) as Hce1.
  pose proof (Hall j2 a2 evs2 u2 Ha2 Hj2 Hu2) as Hce2.
  pose proof (command_events_owners Hce1 Hr1) as Ho1.
  pose proof (command_events_owners Hce2 Hr2) as Ho2.
  cbn [owner] in Ho1, Ho2.
  assert (Heq : j1 = j2) by (eapply in_branch_ops_unique_index; eassumption). subst j2.
  rewrite Ha1 in Ha2; inversion Ha2; subst a2.
  rewrite Hj1 in Hj2; inversion Hj2; subst evs2.
  eapply command_events_compute_comp;
    [exact Hce1 | eapply branch_ops_nodup; [exact (proj1 Hval) | exact Ha1] | exact Hr1 | exact Hr2].
Qed.

(* A4 投影禁用引理：合法交替前缀中不允许连续两个 FlagSet 或空/偶状态后紧跟 FlagWait。 *)

Lemma star_no_double_set w0 :
  star (fun b => b = [FlagSet; FlagWait]) w0 ->
  ~ prefix_language (star (fun b => b = [FlagSet; FlagWait])) (w0 ++ [FlagSet; FlagSet]).
Proof.
  induction 1 as [|blk rest Hblk Hrest IH]; intros [word [Hstar [suff Heq]]]; cbn in Heq.
  - destruct Hstar as [|b r Hb Hr]; [discriminate Heq |].
    subst b. cbn in Heq. inversion Heq.
  - subst blk. cbn in Heq.
    destruct Hstar as [|b r Hb Hr]; [discriminate Heq |].
    subst b. cbn in Heq. inversion Heq as [[Htail]].
    apply IH. exists r; split; [exact Hr | exists suff; exact Htail].
Qed.

Lemma star_no_leading_wait w0 :
  star (fun b => b = [FlagSet; FlagWait]) w0 ->
  ~ prefix_language (star (fun b => b = [FlagSet; FlagWait])) (w0 ++ [FlagWait]).
Proof.
  induction 1 as [|blk rest Hblk Hrest IH]; intros [word [Hstar [suff Heq]]]; cbn in Heq.
  - destruct Hstar as [|b r Hb Hr]; [discriminate Heq |].
    subst b. cbn in Heq. inversion Heq.
  - subst blk. cbn in Heq.
    destruct Hstar as [|b r Hb Hr]; [discriminate Heq |].
    subst b. cbn in Heq. inversion Heq as [[Htail]].
    apply IH. exists r; split; [exact Hr | exists suff; exact Htail].
Qed.

Lemma projection_app_inv {A B} (sel : A -> B -> Prop) (u v : list A) (w : list B) :
  projection sel (u ++ v) w ->
  exists w1 w2, w = w1 ++ w2 /\ projection sel u w1 /\ projection sel v w2.
Proof.
  revert w. induction u as [|a u IH]; intros w H; cbn in H.
  - exists [], w; repeat split; [constructor | exact H].
  - inversion H as [| ? ? l w' Hsel Hp | ? ? w' Hns Hp]; subst.
    + destruct (IH w' Hp) as [w1 [w2 [-> [Hp1 Hp2]]]].
      exists (l :: w1), w2; repeat split; [apply ProjectKeep; assumption | exact Hp2].
    + destruct (IH w Hp) as [w1 [w2 [-> [Hp1 Hp2]]]].
      exists w1, w2; repeat split; [apply ProjectSkip; assumption | exact Hp2].
Qed.

Lemma prefix_language_prefix {A} (L : list A -> Prop) u v :
  prefix u v ->
  prefix_language L v ->
  prefix_language L u.
Proof.
  intros [s1 H1] [w [Hw [s2 H2]]].
  exists w; split; [exact Hw | exists (s1 ++ s2); rewrite H2, H1, <- app_assoc; reflexivity].
Qed.

End TraceStructure.

(* ========================================================================== *)
(* 3. 自动机可达状态的反向辅助不变式（支持 A3/A5 与 WaitFlag 分支定位）          *)
(* ========================================================================== *)

Section ExtraAutoInv.
Context {Float EventId Pipe Unit : Type}.
Context (layout : allocation_layout).
Context (cfg : @configuration Pipe Unit).
Context (model : @computation_model Float EventId Pipe Unit).
Context (Pe : eq_dec_ops Pipe) (Ee : eq_dec_ops EventId).

Local Notation RawCmd := (@command Float EventId Pipe Unit unit).
Local Notation AnnCmd := (@command Float EventId Pipe Unit op_id).
Local Notation Rec := (@event_record Float EventId Pipe Unit).
Local Notation Cursor := (@thread_cursor Float EventId Pipe Unit).
Local Notation TState := (@thread_state Float EventId Pipe Unit).
Local Notation PKind := (@pending_kind Float EventId Pipe Unit).
Local Notation MState := (@machine_state Float EventId Pipe Unit).

Context (raw : list RawCmd).
Let ann : list AnnCmd := annotate_program raw.

Record extra_auto_inv (st : MState) : Prop := {
  eai_active_wait_bwd : forall q w,
    In (q, w) (sync_active_wait (ms_sync st)) ->
    exists p fl,
      In (EventRecord w (LWaitFlagStart p q fl)) (rev (ms_rev_trace st)) /\
      ~ rec_has_end ann (rev (ms_rev_trace st)) w;
  eai_deps_started : forall f p q fl deps d,
    In (f, PSetFlag p q fl deps) (sync_inflight (ms_sync st)) ->
    In d deps ->
    exists i1 i2 r1 r2,
      nth_error (rev (ms_rev_trace st)) i1 = Some r1 /\ owner r1 = d /\
      rec_is_start ann r1 /\ pipeline (payload r1) = Some p /\
      nth_error (rev (ms_rev_trace st)) i2 = Some r2 /\ owner r2 = f /\
      rec_is_start ann r2 /\ pipeline (payload r2) = Some p /\
      (i1 < i2)%nat;
  eai_wait_thread : forall w p q fl j,
    In (w, PWaitFlag p q fl j) (sync_inflight (ms_sync st)) ->
    exists cur, nth_error (ms_threads st) j = Some (TWaitingFlag w cur);
  eai_thread_wait_inflight : forall j w cur,
    nth_error (ms_threads st) j = Some (TWaitingFlag w cur) ->
    exists p q fl, In (w, PWaitFlag p q fl j) (sync_inflight (ms_sync st));
  eai_po_sub : forall j ann_j ts,
    nth_error ann j = Some ann_j ->
    nth_error (ms_threads st) j = Some ts ->
    incl (rem_po ts) (program_order ann_j);
  eai_wait_po : forall j ann_j w cur u,
    nth_error ann j = Some ann_j ->
    nth_error (ms_threads st) j = Some (TWaitingFlag w cur) ->
    In u (op_ids (annotated_of cur)) ->
    In (w, u) (program_order ann_j)
}.

Local Lemma init_machine_extra_inv budget st0 :
  init_machine budget raw = Ok st0 ->
  extra_auto_inv st0.
Proof.
  intros Hinit. unfold init_machine in Hinit.
  destruct (init_threads_aux budget 0 raw) as [ts|] eqn:Hts; cbn [result_bind] in Hinit; [| discriminate].
  inversion Hinit; subst st0.
  destruct (init_threads_aux_spec budget 0 raw Hts) as [Hlen Hall].
  constructor; cbn.
  - intros q w [].
  - intros f p q fl deps d [].
  - intros w p q fl j [].
  - intros j w cur Hth.
    assert (Hj : (j < length raw)%nat) by (rewrite <- Hlen; apply nth_error_Some; congruence).
    destruct (nth_error raw j) as [r|] eqn:Hr; [| apply nth_error_None in Hr; lia].
    destruct (Hall j r (TWaitingFlag w cur) Hr Hth) as [cur0 [Hdisc _]]. discriminate Hdisc.
  - intros j ann_j t Ha Ht.
    apply ann_nth_error in Ha as [r [Hr ->]].
    destruct (Hall j r t Hr Ht) as [cur [-> Href]].
    cbn [rem_po].
    destruct (refocus_preserves_ops_and_po _ _ Href) as [_ Hpo].
    rewrite Hpo. unfold annotated_of; cbn. intros x Hx; exact Hx.
  - intros j ann_j w cur u Ha Ht.
    apply ann_nth_error in Ha as [r [Hr ->]].
    destruct (Hall j r (TWaitingFlag w cur) Hr Ht) as [cur0 [Hdisc _]]. discriminate Hdisc.
Qed.

Local Lemma in_inflight_on_pipe (p : Pipe) (inf : list (op_id * PKind)) d :
  In d (inflight_on_pipe (eqb Pe) p inf) ->
  exists pk, In (d, pk) inf /\ pending_pipe pk = Some p.
Proof.
  unfold inflight_on_pipe. rewrite in_flat_map.
  intros [[o pk] [Hin Hd]].
  destruct (pending_pipe pk) as [q|] eqn:Hp; [| inversion Hd].
  destruct (eqb Pe p q) eqn:Eq; [| inversion Hd].
  apply (proj1 (eqb_spec Pe _ _)) in Eq; subst q.
  destruct Hd as [-> | []]. exists pk; split; [exact Hin | exact Hp].
Qed.

Local Lemma pk_start_rec_is_start o pk :
  In (o, pk_head pk) (program_operations ann) ->
  rec_is_start ann (pk_start_rec o pk) /\
  pipeline (payload (pk_start_rec o pk)) = pending_pipe pk.
Proof.
  intros Hin. destruct pk; cbn; split; try reflexivity; (eexists; split; [exact Hin | reflexivity]).
Qed.

Local Lemma auto_step_preserves_extra_inv budget st ev st' :
  machine_inv layout cfg model Pe Ee raw st ->
  extra_auto_inv st ->
  auto_step layout cfg model Pe Ee budget st ev st' ->
  extra_auto_inv st'.
Proof.
  intros [btraces Hmi] Heai Hstep.
  pose proof (annotate_program_valid raw) as [_ Hval].
  pose proof (proj1 Hval) as Hnd_all.
  fold ann in Hval, Hnd_all.
  destruct Hmi as [mi_len_threads0 mi_len_btraces0 mi_branches0 _ _ _ mi_records_valid0 mi_unique_phase0 mi_inflight_nodup0 mi_inflight_spec0 _ _ _ _ _ _ _ _ _ _ _ _].
  fold ann in mi_len_threads0, mi_len_btraces0, mi_branches0, mi_records_valid0, mi_inflight_spec0.
  destruct Heai as [eai_active_wait_bwd0 eai_deps_started0 eai_wait_thread0 eai_thread_wait_inflight0 eai_po_sub0 eai_wait_po0].
  inversion Hstep; subst;
    try match goal with
    | Hcur : ?cur = ThreadCursor ?tid ?path ?rho ?cmd _ |- _ =>
        rename Hcur into Ecur
    end;
    try match goal with
    | Hadv : advance_cursor _ _ _ _ _ _ _ |- _ =>
        rename Hadv into Hadv_cur
    end.
  all: cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses rev sync_inflight sync_flags sync_active_wait] in *.
  - (* StepAlloc *)
    assert (Hfresh : ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
    { assert (Hj : (j < length ann)%nat) by (rewrite <- mi_len_threads0; apply nth_error_Some; congruence).
      destruct (nth_error ann j) as [ann_j|] eqn:Ha; [| apply nth_error_None in Ha; lia].
      destruct (nth_error btraces j) as [bt|] eqn:Hb; [| apply nth_error_None in Hb; lia].
      pose proof (mi_branches0 j ann_j (TRunning cur) bt Ha H Hb) as Hbi.
      apply (bi_rem_fresh Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_alloc; cbn [label_paths operations map]. now left. }
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p [fl [Hws Hne]]].
      exists p, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w. exact (Hfresh (in_map owner _ _ Hws)).
    + intros f p q fl deps d Hf Hd.
      destruct (eai_deps_started0 f p q fl deps d Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p q fl k Hw. destruct (eai_wait_thread0 w p q fl k Hw) as [c0 Hk].
      destruct (Nat.eq_dec j k) as [-> | Hneq]; [rewrite H in Hk; discriminate |].
      rewrite nth_error_update_nth_neq by exact Hneq. exists c0; exact Hk.
    + intros k w c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_thread_wait_inflight0; exact Hk.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts. cbn [rem_po].
        destruct (refocus_preserves_ops_and_po _ _ Hadv_cur) as [_ Hpo]. rewrite Hpo.
        pose proof (eai_po_sub0 k ann_k (TRunning cur) Ha H) as Hsub.
        cbn [rem_po] in Hsub. rewrite Ecur in Hsub. unfold annotated_of in *; cbn in *.
        rewrite plug_stack_alloc in Hsub; cbn [label_paths program_order] in Hsub.
        intros e He; apply Hsub, in_app_iff; now right.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_po_sub0; eassumption.
    + intros k ann_k w c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_wait_po0; eassumption.
  - (* StepAtomic *)
    assert (Hfresh : ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
    { assert (Hj : (j < length ann)%nat) by (rewrite <- mi_len_threads0; apply nth_error_Some; congruence).
      destruct (nth_error ann j) as [ann_j|] eqn:Ha; [| apply nth_error_None in Ha; lia].
      destruct (nth_error btraces j) as [bt|] eqn:Hb; [| apply nth_error_None in Hb; lia].
      pose proof (mi_branches0 j ann_j (TRunning cur) bt Ha H Hb) as Hbi.
      apply (bi_rem_fresh Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_atomic; cbn [label_paths operations map]. now left. }
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p [fl [Hws Hne]]].
      exists p, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w. exact (Hfresh (in_map owner _ _ Hws)).
    + intros f0 p q fl deps d Hf Hd.
      destruct (eai_deps_started0 f0 p q fl deps d Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p q fl k Hw. destruct (eai_wait_thread0 w p q fl k Hw) as [c0 Hk].
      destruct (Nat.eq_dec j k) as [-> | Hneq]; [rewrite H in Hk; discriminate |].
      rewrite nth_error_update_nth_neq by exact Hneq. exists c0; exact Hk.
    + intros k w c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_thread_wait_inflight0; exact Hk.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts. cbn [rem_po].
        destruct (refocus_preserves_ops_and_po _ _ Hadv_cur) as [_ Hpo]. rewrite Hpo.
        pose proof (eai_po_sub0 k ann_k (TRunning cur) Ha H) as Hsub.
        cbn [rem_po] in Hsub. rewrite Ecur in Hsub. unfold annotated_of in *; cbn in *.
        rewrite plug_stack_atomic in Hsub; cbn [label_paths program_order] in Hsub.
        intros e He; apply Hsub, in_app_iff; now right.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_po_sub0; eassumption.
    + intros k ann_k w c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_wait_po0; eassumption.
  - (* StepAssignPipe *)
    assert (Hfresh : ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
    { assert (Hj : (j < length ann)%nat) by (rewrite <- mi_len_threads0; apply nth_error_Some; congruence).
      destruct (nth_error ann j) as [ann_j|] eqn:Ha; [| apply nth_error_None in Ha; lia].
      destruct (nth_error btraces j) as [bt|] eqn:Hb; [| apply nth_error_None in Hb; lia].
      pose proof (mi_branches0 j ann_j (TRunning cur) bt Ha H Hb) as Hbi.
      apply (bi_rem_fresh Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_assign_pipe; cbn [label_paths operations map]. now left. }
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p0 [fl [Hws Hne]]].
      exists p0, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w. exact (Hfresh (in_map owner _ _ Hws)).
    + intros f0 p0 q fl deps d Hf Hd.
      destruct (eai_deps_started0 f0 p0 q fl deps d Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q fl k Hw. destruct (eai_wait_thread0 w p0 q fl k Hw) as [c0 Hk].
      destruct (Nat.eq_dec j k) as [-> | Hneq]; [rewrite H in Hk; discriminate |].
      rewrite nth_error_update_nth_neq by exact Hneq. exists c0; exact Hk.
    + intros k w c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_thread_wait_inflight0; exact Hk.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts. cbn [rem_po].
        destruct (refocus_preserves_ops_and_po _ _ Hadv_cur) as [_ Hpo]. rewrite Hpo.
        pose proof (eai_po_sub0 k ann_k (TRunning cur) Ha H) as Hsub.
        cbn [rem_po] in Hsub. rewrite Ecur in Hsub. unfold annotated_of in *; cbn in *.
        rewrite plug_stack_assign_pipe in Hsub; cbn [label_paths program_order] in Hsub.
        intros e He; apply Hsub, in_app_iff; now right.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_po_sub0; eassumption.
    + intros k ann_k w c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_wait_po0; eassumption.
  - (* StepReadStart *)
    assert (Hfresh : ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
    { assert (Hj : (j < length ann)%nat) by (rewrite <- mi_len_threads0; apply nth_error_Some; congruence).
      destruct (nth_error ann j) as [ann_j|] eqn:Ha; [| apply nth_error_None in Ha; lia].
      destruct (nth_error btraces j) as [bt|] eqn:Hb; [| apply nth_error_None in Hb; lia].
      pose proof (mi_branches0 j ann_j (TRunning cur) bt Ha H Hb) as Hbi.
      apply (bi_rem_fresh Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_read; cbn [label_paths operations map]. now left. }
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p0 [fl [Hws Hne]]].
      exists p0, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w. exact (Hfresh (in_map owner _ _ Hws)).
    + intros f0 p0 q fl deps d0 [Hf | Hf] Hd; [discriminate |].
      destruct (eai_deps_started0 f0 p0 q fl deps d0 Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q fl k [Hw | Hw]; [discriminate |].
      destruct (eai_wait_thread0 w p0 q fl k Hw) as [c0 Hk].
      destruct (Nat.eq_dec j k) as [-> | Hneq]; [rewrite H in Hk; discriminate |].
      rewrite nth_error_update_nth_neq by exact Hneq. exists c0; exact Hk.
    + intros k w c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq.
        destruct (eai_thread_wait_inflight0 k w c0 Hk) as [p0 [q [fl Hw]]].
        exists p0, q, fl; now right.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts. cbn [rem_po].
        destruct (refocus_preserves_ops_and_po _ _ Hadv_cur) as [_ Hpo]. rewrite Hpo.
        pose proof (eai_po_sub0 k ann_k (TRunning cur) Ha H) as Hsub.
        cbn [rem_po] in Hsub. rewrite Ecur in Hsub. unfold annotated_of in *; cbn in *.
        rewrite plug_stack_read in Hsub; cbn [label_paths program_order] in Hsub.
        intros e He; apply Hsub, in_app_iff; now right.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_po_sub0; eassumption.
    + intros k ann_k w c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_wait_po0; eassumption.
  - (* StepWriteStart *)
    assert (Hfresh : ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
    { assert (Hj : (j < length ann)%nat) by (rewrite <- mi_len_threads0; apply nth_error_Some; congruence).
      destruct (nth_error ann j) as [ann_j|] eqn:Ha; [| apply nth_error_None in Ha; lia].
      destruct (nth_error btraces j) as [bt|] eqn:Hb; [| apply nth_error_None in Hb; lia].
      pose proof (mi_branches0 j ann_j (TRunning cur) bt Ha H Hb) as Hbi.
      apply (bi_rem_fresh Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_write; cbn [label_paths operations map]. now left. }
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p0 [fl [Hws Hne]]].
      exists p0, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w. exact (Hfresh (in_map owner _ _ Hws)).
    + intros f0 p0 q fl deps d0 [Hf | Hf] Hd; [discriminate |].
      destruct (eai_deps_started0 f0 p0 q fl deps d0 Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q fl k [Hw | Hw]; [discriminate |].
      destruct (eai_wait_thread0 w p0 q fl k Hw) as [c0 Hk].
      destruct (Nat.eq_dec j k) as [-> | Hneq]; [rewrite H in Hk; discriminate |].
      rewrite nth_error_update_nth_neq by exact Hneq. exists c0; exact Hk.
    + intros k w c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq.
        destruct (eai_thread_wait_inflight0 k w c0 Hk) as [p0 [q [fl Hw]]].
        exists p0, q, fl; now right.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts. cbn [rem_po].
        destruct (refocus_preserves_ops_and_po _ _ Hadv_cur) as [_ Hpo]. rewrite Hpo.
        pose proof (eai_po_sub0 k ann_k (TRunning cur) Ha H) as Hsub.
        cbn [rem_po] in Hsub. rewrite Ecur in Hsub. unfold annotated_of in *; cbn in *.
        rewrite plug_stack_write in Hsub; cbn [label_paths program_order] in Hsub.
        intros e He; apply Hsub, in_app_iff; now right.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_po_sub0; eassumption.
    + intros k ann_k w c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_wait_po0; eassumption.
  - (* StepComputeStart *)
    assert (Hfresh : ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
    { assert (Hj : (j < length ann)%nat) by (rewrite <- mi_len_threads0; apply nth_error_Some; congruence).
      destruct (nth_error ann j) as [ann_j|] eqn:Ha; [| apply nth_error_None in Ha; lia].
      destruct (nth_error btraces j) as [bt|] eqn:Hb; [| apply nth_error_None in Hb; lia].
      pose proof (mi_branches0 j ann_j (TRunning cur) bt Ha H Hb) as Hbi.
      apply (bi_rem_fresh Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_compute; cbn [label_paths operations map]. now left. }
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p0 [fl [Hws Hne]]].
      exists p0, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w. exact (Hfresh (in_map owner _ _ Hws)).
    + intros f0 p0 q fl deps d0 [Hf | Hf] Hd; [discriminate |].
      destruct (eai_deps_started0 f0 p0 q fl deps d0 Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q fl k [Hw | Hw]; [discriminate |].
      destruct (eai_wait_thread0 w p0 q fl k Hw) as [c0 Hk].
      destruct (Nat.eq_dec j k) as [-> | Hneq]; [rewrite H in Hk; discriminate |].
      rewrite nth_error_update_nth_neq by exact Hneq. exists c0; exact Hk.
    + intros k w c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq.
        destruct (eai_thread_wait_inflight0 k w c0 Hk) as [p0 [q [fl Hw]]].
        exists p0, q, fl; now right.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts. cbn [rem_po].
        destruct (refocus_preserves_ops_and_po _ _ Hadv_cur) as [_ Hpo]. rewrite Hpo.
        pose proof (eai_po_sub0 k ann_k (TRunning cur) Ha H) as Hsub.
        cbn [rem_po] in Hsub. rewrite Ecur in Hsub. unfold annotated_of in *; cbn in *.
        rewrite plug_stack_compute in Hsub; cbn [label_paths program_order] in Hsub.
        intros e He; apply Hsub, in_app_iff; now right.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_po_sub0; eassumption.
    + intros k ann_k w c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_wait_po0; eassumption.
  - (* StepSetFlagStart *)
    assert (Hj : (j < length ann)%nat) by (rewrite <- mi_len_threads0; apply nth_error_Some; congruence).
    destruct (nth_error ann j) as [ann_j|] eqn:Haj; [| apply nth_error_None in Haj; lia].
    destruct (nth_error btraces j) as [bt|] eqn:Hbj; [| apply nth_error_None in Hbj; lia].
    pose proof (mi_branches0 j ann_j (TRunning cur) bt Haj H Hbj) as Hbi.
    assert (Hhead_in : In ((tid, path), HSetFlag) (program_operations ann)).
    { eapply branch_ops_in_program; [exact Haj |].
      apply (bi_rem_sub Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_setflag; cbn [label_paths operations]. now left. }
    assert (Hfresh : ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
    { apply (bi_rem_fresh Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_setflag; cbn [label_paths operations map]. now left. }
    constructor; cbn.
    + intros q0 w Hin. destruct (eai_active_wait_bwd0 q0 w Hin) as [p0 [fl0 [Hws Hne]]].
      exists p0, fl0; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w. exact (Hfresh (in_map owner _ _ Hws)).
    + intros f0 p0 q0 fl0 deps' d0 [Hf | Hf] Hd.
      * inversion Hf; subst f0 p0 q0 fl0 deps'.
        apply in_inflight_on_pipe in Hd as [pk [Hinf Hp]].
        destruct (mi_inflight_spec0 d0 pk Hinf) as [Hd_ops [Hd_in _]].
        apply In_nth_error in Hd_in as [i1 Hi1].
        assert (Hi1_lt : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
        destruct (pk_start_rec_is_start d0 pk Hd_ops) as [Hs1 Hp1].
        exists i1, (length (rev (ms_rev_trace st))), (pk_start_rec d0 pk), (EventRecord (tid, path) (LSetFlagStart p q fl)).
        rewrite nth_error_app1 by exact Hi1_lt.
        rewrite nth_error_app2 by lia; rewrite Nat.sub_diag; cbn [nth_error].
        repeat split; try reflexivity; try assumption.
        -- destruct pk; reflexivity.
        -- rewrite Hp1; exact Hp.
        -- exists HSetFlag; split; [exact Hhead_in | reflexivity].
      * destruct (eai_deps_started0 f0 p0 q0 fl0 deps' d0 Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
        assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
        assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
        exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q0 fl0 k [Hw | Hw]; [discriminate |].
      destruct (eai_wait_thread0 w p0 q0 fl0 k Hw) as [c0 Hk].
      destruct (Nat.eq_dec j k) as [-> | Hneq]; [rewrite H in Hk; discriminate |].
      rewrite nth_error_update_nth_neq by exact Hneq. exists c0; exact Hk.
    + intros k w c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq.
        destruct (eai_thread_wait_inflight0 k w c0 Hk) as [p0 [q0 [fl0 Hw]]].
        exists p0, q0, fl0; now right.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts. cbn [rem_po].
        destruct (refocus_preserves_ops_and_po _ _ Hadv_cur) as [_ Hpo]. rewrite Hpo.
        pose proof (eai_po_sub0 k ann_k (TRunning cur) Ha H) as Hsub.
        cbn [rem_po] in Hsub. rewrite Ecur in Hsub. unfold annotated_of in *; cbn in *.
        rewrite plug_stack_setflag in Hsub; cbn [label_paths program_order] in Hsub.
        intros e He; apply Hsub, in_app_iff; now right.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_po_sub0; eassumption.
    + intros k ann_k w c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_wait_po0; eassumption.
  - (* StepWaitFlagStart *)
    assert (Hj : (j < length ann)%nat) by (rewrite <- mi_len_threads0; apply nth_error_Some; congruence).
    destruct (nth_error ann j) as [ann_j|] eqn:Haj; [| apply nth_error_None in Haj; lia].
    destruct (nth_error btraces j) as [bt|] eqn:Hbj; [| apply nth_error_None in Hbj; lia].
    pose proof (mi_branches0 j ann_j (TRunning cur) bt Haj H Hbj) as Hbi.
    assert (Hhead_in : In ((tid, path), HWaitFlag) (program_operations ann)).
    { eapply branch_ops_in_program; [exact Haj |].
      apply (bi_rem_sub Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_waitflag; cbn [label_paths operations]. now left. }
    assert (Hfresh : ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
    { apply (bi_rem_fresh Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_waitflag; cbn [label_paths operations map]. now left. }
    constructor; cbn.
    + intros q0 w [Heq | Hin].
      * inversion Heq; subst q0 w.
        exists p, fl; split; [apply in_app_iff; right; now left |].
        intros Hne. apply rec_has_phase_snoc_inv in Hne as [[r [Hr [Ho _]]] | [_ [h [Hh Hk]]]].
        -- apply Hfresh; unfold o in Ho; rewrite <- Ho; apply in_map; exact Hr.
        -- pose proof (ops_unique_head ann Hnd_all Hh Hhead_in) as ->. discriminate Hk.
      * destruct (eai_active_wait_bwd0 q0 w Hin) as [p0 [fl0 [Hws Hne]]].
        exists p0, fl0; split; [apply in_app_iff; now left |].
        intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
        cbn in Ho; subst w. exact (Hfresh (in_map owner _ _ Hws)).
    + intros f0 p0 q0 fl0 deps0 d0 [Hf | Hf] Hd; [discriminate |].
      destruct (eai_deps_started0 f0 p0 q0 fl0 deps0 d0 Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q0 fl0 k [Hw | Hw].
      * inversion Hw; subst w p0 q0 fl0 k.
        rewrite nth_error_update_nth_eq by (apply nth_error_Some; congruence).
        exists cur'; reflexivity.
      * destruct (eai_wait_thread0 w p0 q0 fl0 k Hw) as [c0 Hk].
        destruct (Nat.eq_dec j k) as [-> | Hneq]; [rewrite H in Hk; discriminate |].
        rewrite nth_error_update_nth_neq by exact Hneq. exists c0; exact Hk.
    + intros k w c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst w c0. exists p, q, fl; now left.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq.
        destruct (eai_thread_wait_inflight0 k w c0 Hk) as [p0 [q0 [fl0 Hw]]].
        exists p0, q0, fl0; now right.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts. cbn [rem_po].
        destruct (refocus_preserves_ops_and_po _ _ Hadv_cur) as [_ Hpo]. rewrite Hpo.
        pose proof (eai_po_sub0 k ann_k (TRunning cur) Ha H) as Hsub.
        cbn [rem_po] in Hsub. rewrite Ecur in Hsub. unfold annotated_of in *; cbn in *.
        rewrite plug_stack_waitflag in Hsub; cbn [label_paths program_order] in Hsub.
        intros e He; apply Hsub, in_app_iff; now right.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_po_sub0; eassumption.
    + intros k ann_k w c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst w c0.
        pose proof (eai_po_sub0 k ann_k (TRunning cur) Ha H) as Hsub.
        cbn [rem_po] in Hsub. rewrite Ecur in Hsub. unfold annotated_of in *; cbn in *.
        rewrite plug_stack_waitflag in Hsub; cbn [label_paths program_order] in Hsub.
        destruct (refocus_preserves_ops_and_po _ _ Hadv_cur) as [Hops _].
        apply Hsub, in_app_iff; left; apply in_map_iff.
        exists u; split; [reflexivity |]. unfold op_ids, annotated_of in *; cbn in *. rewrite <- Hops. exact Hu.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_wait_po0; eassumption.
  - (* StepIf *)
    assert (Hfresh : ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
    { assert (Hj : (j < length ann)%nat) by (rewrite <- mi_len_threads0; apply nth_error_Some; congruence).
      destruct (nth_error ann j) as [ann_j|] eqn:Ha; [| apply nth_error_None in Ha; lia].
      destruct (nth_error btraces j) as [bt|] eqn:Hb; [| apply nth_error_None in Hb; lia].
      pose proof (mi_branches0 j ann_j (TRunning cur) bt Ha H Hb) as Hbi.
      apply (bi_rem_fresh Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_if; cbn [label_paths operations map]. now left. }
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p0 [fl [Hws Hne]]].
      exists p0, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w. exact (Hfresh (in_map owner _ _ Hws)).
    + intros f0 p0 q fl deps d Hf Hd.
      destruct (eai_deps_started0 f0 p0 q fl deps d Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q fl k Hw. destruct (eai_wait_thread0 w p0 q fl k Hw) as [c0 Hk].
      destruct (Nat.eq_dec j k) as [-> | Hneq]; [rewrite H in Hk; discriminate |].
      rewrite nth_error_update_nth_neq by exact Hneq. exists c0; exact Hk.
    + intros k w c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_thread_wait_inflight0; exact Hk.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts. cbn [rem_po].
        destruct (refocus_preserves_ops_and_po _ _ Hadv_cur) as [_ Hpo]. rewrite Hpo.
        pose proof (eai_po_sub0 k ann_k (TRunning cur) Ha H) as Hsub.
        cbn [rem_po] in Hsub. rewrite Ecur in Hsub. unfold annotated_of in *; cbn in *.
        rewrite plug_stack_if in Hsub; cbn [label_paths program_order] in Hsub.
        intros e He; apply Hsub, in_app_iff; right; apply in_app_iff; destruct b; [left | right]; exact He.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_po_sub0; eassumption.
    + intros k ann_k w c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_wait_po0; eassumption.
  - (* StepReturn *)
    assert (Hfresh : ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
    { assert (Hj : (j < length ann)%nat) by (rewrite <- mi_len_threads0; apply nth_error_Some; congruence).
      destruct (nth_error ann j) as [ann_j|] eqn:Ha; [| apply nth_error_None in Ha; lia].
      destruct (nth_error btraces j) as [bt|] eqn:Hb; [| apply nth_error_None in Hb; lia].
      pose proof (mi_branches0 j ann_j (TRunning cur) bt Ha H Hb) as Hbi.
      apply (bi_rem_fresh Hbi). cbn [rem_ops]. rewrite Ecur. unfold annotated_of; cbn.
      rewrite plug_stack_return; cbn [label_paths operations map]. now left. }
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p0 [fl [Hws Hne]]].
      exists p0, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w. exact (Hfresh (in_map owner _ _ Hws)).
    + intros f0 p0 q fl deps d Hf Hd.
      destruct (eai_deps_started0 f0 p0 q fl deps d Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q fl k Hw. destruct (eai_wait_thread0 w p0 q fl k Hw) as [c0 Hk].
      destruct (Nat.eq_dec j k) as [-> | Hneq]; [rewrite H in Hk; discriminate |].
      rewrite nth_error_update_nth_neq by exact Hneq. exists c0; exact Hk.
    + intros k w c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_thread_wait_inflight0; exact Hk.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts. cbn [rem_po]. intros e [].
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_po_sub0; eassumption.
    + intros k ann_k w c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq. eapply eai_wait_po0; eassumption.
  - (* StepReadEnd *)
    apply (lookup_assoc_in op_id_eq_ops) in H.
    pose proof (mi_inflight_spec0 o (PRead d a) H) as [Hops_o _]. cbn [pk_head] in Hops_o.
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p0 [fl [Hws Hne]]].
      exists p0, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w.
      destruct (mi_records_valid0 _ Hws) as [[h [Hh Hk]] | [h [Hh Hk]]];
        cbn in Hh, Hk; pose proof (ops_unique_head ann Hnd_all Hh Hops_o) as ->; discriminate Hk.
    + intros f0 p0 q fl deps d0 Hf Hd.
      apply (in_remove_assoc_iff op_id_eq_ops) in Hf as [Hf _].
      destruct (eai_deps_started0 f0 p0 q fl deps d0 Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q fl k Hw. apply (in_remove_assoc_iff op_id_eq_ops) in Hw as [Hw _].
      eapply eai_wait_thread0; exact Hw.
    + intros k w c0 Hk. destruct (eai_thread_wait_inflight0 k w c0 Hk) as [p0 [q [fl Hw]]].
      exists p0, q, fl. apply (in_remove_assoc_iff op_id_eq_ops); split; [exact Hw |].
      cbn [fst]; intro Heq; subst w.
      pose proof (mi_inflight_spec0 o (PWaitFlag p0 q fl k) Hw) as [Hops_w _]. cbn [pk_head] in Hops_w.
      pose proof (ops_unique_head ann Hnd_all Hops_w Hops_o). discriminate.
    + exact eai_po_sub0.
    + exact eai_wait_po0.
  - (* StepWriteEnd *)
    apply (lookup_assoc_in op_id_eq_ops) in H.
    pose proof (mi_inflight_spec0 o (PWrite d a data) H) as [Hops_o _]. cbn [pk_head] in Hops_o.
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p0 [fl [Hws Hne]]].
      exists p0, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w.
      destruct (mi_records_valid0 _ Hws) as [[h [Hh Hk]] | [h [Hh Hk]]];
        cbn in Hh, Hk; pose proof (ops_unique_head ann Hnd_all Hh Hops_o) as ->; discriminate Hk.
    + intros f0 p0 q fl deps d0 Hf Hd.
      apply (in_remove_assoc_iff op_id_eq_ops) in Hf as [Hf _].
      destruct (eai_deps_started0 f0 p0 q fl deps d0 Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q fl k Hw. apply (in_remove_assoc_iff op_id_eq_ops) in Hw as [Hw _].
      eapply eai_wait_thread0; exact Hw.
    + intros k w c0 Hk. destruct (eai_thread_wait_inflight0 k w c0 Hk) as [p0 [q [fl Hw]]].
      exists p0, q, fl. apply (in_remove_assoc_iff op_id_eq_ops); split; [exact Hw |].
      cbn [fst]; intro Heq; subst w.
      pose proof (mi_inflight_spec0 o (PWaitFlag p0 q fl k) Hw) as [Hops_w _]. cbn [pk_head] in Hops_w.
      pose proof (ops_unique_head ann Hnd_all Hops_w Hops_o). discriminate.
    + exact eai_po_sub0.
    + exact eai_wait_po0.
  - (* StepComputeEnd *)
    apply (lookup_assoc_in op_id_eq_ops) in H.
    pose proof (mi_inflight_spec0 o (PCompute d args) H) as [Hops_o _]. cbn [pk_head] in Hops_o.
    constructor; cbn.
    + intros q w Hin. destruct (eai_active_wait_bwd0 q w Hin) as [p0 [fl [Hws Hne]]].
      exists p0, fl; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w.
      destruct (mi_records_valid0 _ Hws) as [[h [Hh Hk]] | [h [Hh Hk]]];
        cbn in Hh, Hk; pose proof (ops_unique_head ann Hnd_all Hh Hops_o) as ->; discriminate Hk.
    + intros f0 p0 q fl deps d0 Hf Hd.
      apply (in_remove_assoc_iff op_id_eq_ops) in Hf as [Hf _].
      destruct (eai_deps_started0 f0 p0 q fl deps d0 Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q fl k Hw. apply (in_remove_assoc_iff op_id_eq_ops) in Hw as [Hw _].
      eapply eai_wait_thread0; exact Hw.
    + intros k w c0 Hk. destruct (eai_thread_wait_inflight0 k w c0 Hk) as [p0 [q [fl Hw]]].
      exists p0, q, fl. apply (in_remove_assoc_iff op_id_eq_ops); split; [exact Hw |].
      cbn [fst]; intro Heq; subst w.
      pose proof (mi_inflight_spec0 o (PWaitFlag p0 q fl k) Hw) as [Hops_w _]. cbn [pk_head] in Hops_w.
      pose proof (ops_unique_head ann Hnd_all Hops_w Hops_o). discriminate.
    + exact eai_po_sub0.
    + exact eai_wait_po0.
  - (* StepSetFlagEnd *)
    apply (lookup_assoc_in op_id_eq_ops) in H.
    pose proof (mi_inflight_spec0 f (PSetFlag p q fl deps) H) as [Hops_f _]. cbn [pk_head] in Hops_f.
    constructor; cbn.
    + intros q0 w Hin. destruct (eai_active_wait_bwd0 q0 w Hin) as [p0 [fl0 [Hws Hne]]].
      exists p0, fl0; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w.
      destruct (mi_records_valid0 _ Hws) as [[h [Hh Hk]] | [h [Hh Hk]]];
        cbn in Hh, Hk; pose proof (ops_unique_head ann Hnd_all Hh Hops_f) as ->; discriminate Hk.
    + intros f0 p0 q0 fl0 deps0 d0 Hf Hd.
      apply (in_remove_assoc_iff op_id_eq_ops) in Hf as [Hf _].
      destruct (eai_deps_started0 f0 p0 q0 fl0 deps0 d0 Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w p0 q0 fl0 k Hw. apply (in_remove_assoc_iff op_id_eq_ops) in Hw as [Hw _].
      eapply eai_wait_thread0; exact Hw.
    + intros k w c0 Hk. destruct (eai_thread_wait_inflight0 k w c0 Hk) as [p0 [q0 [fl0 Hw]]].
      exists p0, q0, fl0. apply (in_remove_assoc_iff op_id_eq_ops); split; [exact Hw |].
      cbn [fst]; intro Heq; subst w.
      pose proof (mi_inflight_spec0 f (PWaitFlag p0 q0 fl0 k) Hw) as [Hops_w _]. cbn [pk_head] in Hops_w.
      pose proof (ops_unique_head ann Hnd_all Hops_w Hops_f). discriminate.
    + exact eai_po_sub0.
    + exact eai_wait_po0.
  - (* StepWaitFlagEnd *)
    apply (lookup_assoc_in op_id_eq_ops) in H.
    pose proof (mi_inflight_spec0 w (PWaitFlag p q fl j) H) as [Hops_w [Hws_w _]]. cbn in Hops_w, Hws_w.
    constructor; cbn.
    + intros q0 w0 Hin. apply (in_remove_assoc_iff Pe) in Hin as [Hin Hneq_q]. cbn [fst] in Hneq_q.
      destruct (eai_active_wait_bwd0 q0 w0 Hin) as [p0 [fl0 [Hws0 Hne0]]].
      exists p0, fl0; split; [apply in_app_iff; now left |].
      intros Hne2. apply rec_has_phase_snoc_inv in Hne2 as [Hne2 | [Ho _]]; [contradiction |].
      cbn in Ho; subst w0.
      apply In_nth_error in Hws0 as [i1 Hi1].
      apply In_nth_error in Hws_w as [i2 Hi2].
      pose proof (mi_unique_phase0 i1 i2 _ _ Hi1 Hi2 eq_refl eq_refl) as E. subst i2.
      rewrite Hi1 in Hi2; inversion Hi2; subst; contradiction.
    + intros f0 p0 q0 fl0 deps0 d0 Hf Hd.
      apply (in_remove_assoc_iff op_id_eq_ops) in Hf as [Hf _].
      destruct (eai_deps_started0 f0 p0 q0 fl0 deps0 d0 Hf Hd) as (i1 & i2 & r1 & r2 & H1' & Ho1 & Hs1 & Hp1 & H2' & Ho2 & Hs2 & Hp2 & Hlt).
      assert (Hi1 : (i1 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      assert (Hi2 : (i2 < length (rev (ms_rev_trace st)))%nat) by (apply nth_error_Some; congruence).
      exists i1, i2, r1, r2; rewrite !nth_error_app1 by assumption; repeat split; assumption.
    + intros w0 p0 q0 fl0 k Hw. apply (in_remove_assoc_iff op_id_eq_ops) in Hw as [Hw Hneq_w]. cbn [fst] in Hneq_w.
      destruct (eai_wait_thread0 w0 p0 q0 fl0 k Hw) as [c0 Hk].
      destruct (Nat.eq_dec j k) as [-> | Hneq_j].
      * rewrite H1 in Hk; inversion Hk; subst; contradiction.
      * rewrite nth_error_update_nth_neq by exact Hneq_j. exists c0; exact Hk.
    + intros k w0 c0 Hk. destruct (Nat.eq_dec j k) as [-> | Hneq_j].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq_j.
        destruct (eai_thread_wait_inflight0 k w0 c0 Hk) as [p0 [q0 [fl0 Hw]]].
        exists p0, q0, fl0. apply (in_remove_assoc_iff op_id_eq_ops); split; [exact Hw |].
        cbn [fst]; intro Heq; subst w0.
        pose proof (eai_wait_thread0 w p0 q0 fl0 k Hw) as [c1 Hk1].
        pose proof (proj2 (lookup_assoc_in_nodup op_id_eq_ops w _ _ mi_inflight_nodup0) Hw) as L1.
        pose proof (proj2 (lookup_assoc_in_nodup op_id_eq_ops w _ _ mi_inflight_nodup0) H) as L2.
        rewrite L1 in L2; inversion L2; subst; contradiction.
    + intros k ann_k ts Ha Hk. destruct (Nat.eq_dec j k) as [-> | Hneq_j].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence).
        inversion Hk; subst ts.
        exact (eai_po_sub0 k ann_k (TWaitingFlag w next_cur) Ha H1).
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq_j. eapply eai_po_sub0; eassumption.
    + intros k ann_k w0 c0 u Ha Hk Hu. destruct (Nat.eq_dec j k) as [-> | Hneq_j].
      * rewrite nth_error_update_nth_eq in Hk by (apply nth_error_Some; congruence). discriminate.
      * rewrite nth_error_update_nth_neq in Hk by exact Hneq_j. eapply eai_wait_po0; eassumption.
Qed.

Lemma auto_steps_preserves_extra_inv budget st1 st2 :
  auto_steps layout cfg model Pe Ee budget st1 st2 ->
  machine_inv layout cfg model Pe Ee raw st1 ->
  extra_auto_inv st1 ->
  extra_auto_inv st2.
Proof.
  induction 1; intros Hmi Heai; [exact Heai |].
  apply IHauto_steps.
  - eapply auto_step_preserves_inv; eassumption.
  - eapply auto_step_preserves_extra_inv; eassumption.
Qed.

End ExtraAutoInv.

(* ========================================================================== *)
(* 4. 关系型在线自动机完备性定理（automaton_complete 与双向精确等价）             *)
(* ========================================================================== *)

Section AutomatonCompleteness.
Context {Float EventId Pipe Unit : Type}.
Context (layout : allocation_layout).
Context (cfg : @configuration Pipe Unit).
Context (model : @computation_model Float EventId Pipe Unit).
Context (Pe : eq_dec_ops Pipe) (Ee : eq_dec_ops EventId).

Local Notation Val := (@value Float EventId Pipe).
Local Notation RawCmd := (@command Float EventId Pipe Unit unit).
Local Notation AnnCmd := (@command Float EventId Pipe Unit op_id).
Local Notation Rec := (@event_record Float EventId Pipe Unit).
Local Notation Use := (@use_record Float EventId Pipe).
Local Notation Cursor := (@thread_cursor Float EventId Pipe Unit).
Local Notation TState := (@thread_state Float EventId Pipe Unit).
Local Notation PKind := (@pending_kind Float EventId Pipe Unit).
Local Notation MState := (@machine_state Float EventId Pipe Unit).
Local Notation Kappa := (@interpretation Float EventId Pipe Unit).

Context (raw : list RawCmd).
Let ann : list AnnCmd := annotate_program raw.

(* 从 A_val（completed_result_values）与 mi_done_val 将 operand_value 升级为 resolve_operand_rel *)

Lemma operand_value_to_resolve (t : list EventId) (kappa : Kappa) (uses : list Use)
    (k : nat) (ek : EventId) (st : MState) (rho : @environment Float EventId Pipe)
    (o : op_id) (idx : nat) (v : @operand Float EventId Pipe) (a : Val) (us : list Use) :
  completed_result_values ann t kappa uses ->
  rev (ms_rev_trace st) = firstn k (map kappa t) ->
  (forall o0 res0, lookup_assoc op_id_eqb o0 (mem_done_val (ms_mem st)) = Some res0 <->
     In (EventRecord o0 (LReadEnd res0)) (rev (ms_rev_trace st)) \/
     In (EventRecord o0 (LComputeEnd res0)) (rev (ms_rev_trace st))) ->
  nth_error t k = Some ek ->
  starts ann t kappa o ek ->
  incl us uses ->
  operand_value rho o idx v a us ->
  resolve_operand_rel (mem_done_val (ms_mem st)) rho o idx v a us.
Proof.
  intros HAval Hpre Hdv Htk Hstart Hinc Hov.
  inversion Hov; subst.
  - apply ResKnown; assumption.
  - apply ResAsync; [assumption |].
    intros res Hlk.
    apply Hdv in Hlk. rewrite Hpre in Hlk.
    assert (Hin_res : exists i ed,
      (i < k)%nat /\ nth_error t i = Some ed /\ result_event kappa r ed res).
    { destruct Hlk as [Hlk | Hlk].
      - apply In_nth_error in Hlk as [i Hi].
        rewrite nth_error_firstn in Hi.
        destruct (Nat.ltb i k) eqn:Elt; [| discriminate].
        apply Nat.ltb_lt in Elt.
        rewrite nth_error_map in Hi.
        destruct (nth_error t i) as [ed|] eqn:Hed; [| discriminate].
        inversion Hi as [Hkap].
        exists i, ed; repeat split; try assumption; left; exact Hkap.
      - apply In_nth_error in Hlk as [i Hi].
        rewrite nth_error_firstn in Hi.
        destruct (Nat.ltb i k) eqn:Elt; [| discriminate].
        apply Nat.ltb_lt in Elt.
        rewrite nth_error_map in Hi.
        destruct (nth_error t i) as [ed|] eqn:Hed; [| discriminate].
        inversion Hi as [Hkap].
        exists i, ed; repeat split; try assumption; right; exact Hkap. }
    destruct Hin_res as [i [ed [Hlt [Hed Hre]]]].
    eapply (HAval (UseRecord o idx r a) ek ed res).
    + apply Hinc; now left.
    + exact Hstart.
    + eapply nth_error_In; exact Hed.
    + exact Hre.
    + exists i, k; auto.
Qed.

Lemma operand_values_to_resolve (t : list EventId) (kappa : Kappa) (uses : list Use)
    (k : nat) (ek : EventId) (st : MState) (rho : @environment Float EventId Pipe)
    (o : op_id) (idx : nat) (vs : list (@operand Float EventId Pipe)) (args : list Val) (us : list Use) :
  completed_result_values ann t kappa uses ->
  rev (ms_rev_trace st) = firstn k (map kappa t) ->
  (forall o0 res0, lookup_assoc op_id_eqb o0 (mem_done_val (ms_mem st)) = Some res0 <->
     In (EventRecord o0 (LReadEnd res0)) (rev (ms_rev_trace st)) \/
     In (EventRecord o0 (LComputeEnd res0)) (rev (ms_rev_trace st))) ->
  nth_error t k = Some ek ->
  starts ann t kappa o ek ->
  incl us uses ->
  operand_values rho o idx vs args us ->
  resolve_operands_rel (mem_done_val (ms_mem st)) rho o idx vs args us.
Proof.
  intros HAval Hpre Hdv Htk Hstart Hinc Hovs.
  induction Hovs.
  - constructor.
  - constructor.
    + eapply operand_value_to_resolve; try eassumption.
      intros u Hu; apply Hinc, in_app_iff; now left.
    + apply IHHovs. intros u Hu; apply Hinc, in_app_iff; now right.
Qed.

Lemma execution_values_to_resolve (t : list EventId) (kappa : Kappa) (uses : list Use)
    (k : nat) (ek : EventId) (st : MState) (rho : @environment Float EventId Pipe)
    (o : op_id) (vs : list (@operand Float EventId Pipe))
    (q : option (@operand Float EventId Pipe)) (p : option Pipe) (args : list Val) (us : list Use) :
  completed_result_values ann t kappa uses ->
  rev (ms_rev_trace st) = firstn k (map kappa t) ->
  (forall o0 res0, lookup_assoc op_id_eqb o0 (mem_done_val (ms_mem st)) = Some res0 <->
     In (EventRecord o0 (LReadEnd res0)) (rev (ms_rev_trace st)) \/
     In (EventRecord o0 (LComputeEnd res0)) (rev (ms_rev_trace st))) ->
  nth_error t k = Some ek ->
  starts ann t kappa o ek ->
  incl us uses ->
  execution_values rho o vs q p args us ->
  resolve_exec_rel (mem_done_val (ms_mem st)) rho o vs q p args us.
Proof.
  intros HAval Hpre Hdv Htk Hstart Hinc Hev.
  inversion Hev; subst; constructor; eapply operand_values_to_resolve; eassumption.
Qed.

(* 辅助：在长度 m 的前缀上，rec_flag_letter 与 TraceSemantics.flag_projection 精确等价（由 A1 保证）。 *)
Lemma rec_flag_letter_iff_trace_flag (t : list EventId) (kappa : Kappa) (m : nat)
    (p q : Pipe) (fl : EventId) :
  annotations_valid ann ->
  A1 ann t kappa ->
  NoDup (map kappa t) ->
  (forall e, In e t -> rec_is_start ann (kappa e) \/ rec_is_end ann (kappa e)) ->
  (forall r1 r2, In r1 (map kappa t) -> In r2 (map kappa t) ->
     owner r1 = owner r2 -> kind (payload r1) = kind (payload r2) -> r1 = r2) ->
  forall e l,
    In e (firstn m t) ->
    (rec_flag_letter p q fl (firstn m (map kappa t)) (kappa e) l <->
     flag_projection ann t kappa p q fl e l).
Proof.
  intros [Hnd_all _] HA1 Hnd_kt Hvalid_t Huniq e l He_pre.
  assert (Hnd_t : NoDup t) by (eapply NoDup_map_inv; exact Hnd_kt).
  assert (He_t : In e t) by (rewrite <- (firstn_skipn m t); apply in_app_iff; now left).
  apply In_nth_error in He_pre as [ie Hie].
  assert (Hie_lt : (ie < m)%nat).
  { assert (H1 : (ie < length (firstn m t))%nat) by (apply nth_error_Some; congruence).
    rewrite length_firstn in H1; lia. }
  rewrite nth_error_firstn, (proj2 (Nat.ltb_lt _ _) Hie_lt) in Hie.
  split.
  - intros Hrec. destruct l; cbn in Hrec; destruct Hrec as [Hpl Hsin].
    + apply In_nth_error in Hsin as [is0 His0].
      rewrite nth_error_firstn in His0.
      destruct (Nat.ltb is0 m) eqn:Elt_is; [| discriminate].
      apply Nat.ltb_lt in Elt_is.
      rewrite nth_error_map in His0.
      destruct (nth_error t is0) as [es|] eqn:Hes; [| discriminate].
      inversion His0 as [Hks].
      assert (Hes_t : In es t) by (eapply nth_error_In; exact Hes).
      destruct (Hvalid_t es Hes_t) as [[h [Hh Hk]] | [h [Hh Hk]]];
        rewrite Hks in Hh, Hk; cbn in Hh, Hk; destruct h; cbn in Hk; try discriminate Hk.
      exists (owner (kappa e)), es. repeat split; try assumption.
      * rewrite Hks; reflexivity.
      * exists HSetFlag; split; [exact Hh | rewrite Hks; reflexivity].
      * exists HSetFlag; split; [exact Hh | rewrite Hpl; reflexivity].
      * rewrite Hks; reflexivity.
      * rewrite Hpl; reflexivity.
    + apply In_nth_error in Hsin as [is0 His0].
      rewrite nth_error_firstn in His0.
      destruct (Nat.ltb is0 m) eqn:Elt_is; [| discriminate].
      apply Nat.ltb_lt in Elt_is.
      rewrite nth_error_map in His0.
      destruct (nth_error t is0) as [es|] eqn:Hes; [| discriminate].
      inversion His0 as [Hks].
      assert (Hes_t : In es t) by (eapply nth_error_In; exact Hes).
      destruct (Hvalid_t es Hes_t) as [[h [Hh Hk]] | [h [Hh Hk]]];
        rewrite Hks in Hh, Hk; cbn in Hh, Hk; destruct h; cbn in Hk; try discriminate Hk.
      exists (owner (kappa e)), es. repeat split; try assumption.
      * rewrite Hks; reflexivity.
      * exists HWaitFlag; split; [exact Hh | rewrite Hks; reflexivity].
      * exists HWaitFlag; split; [exact Hh | rewrite Hpl; reflexivity].
      * rewrite Hks; reflexivity.
      * rewrite Hpl; reflexivity.
  - intros [o [es [Hst [Hfin Hmatch]]]].
    destruct Hfin as [_ [Hoe [h [Hh Hke]]]].
    destruct Hst as [Hes_t [Hos [hs [Hhs Hks]]]].
    destruct l; cbn in Hmatch; destruct Hmatch as [Hps Hke2]; cbn [rec_flag_letter].
    + assert (Hpl : payload (kappa e) = LSetFlagEnd)
        by (destruct (payload (kappa e)); try discriminate Hke2; reflexivity).
      assert (Hh_eq : h = HSetFlag) by (destruct h; cbn in *; try congruence; discriminate).
      subst h.
      destruct (HA1 o HSetFlag Hh ltac:(discriminate) e
                    (conj He_t (conj Hoe (ex_intro _ HSetFlag (conj Hh Hke)))))
        as [es' [[Hes'_t [Hos' [hs' [Hhs' Hks']]]] [is0 [ie0 [His0 [Hie0 Hlt]]]]]].
      pose proof (proj1 (NoDup_nth_error t) Hnd_t ie ie0 (ltac:(apply nth_error_Some; congruence)) (eq_trans Hie (eq_sym Hie0))) as Eie.
      subst ie0.
      assert (Hhs'_eq : hs' = HSetFlag) by (eapply ops_unique_head; eassumption). subst hs'.
      assert (Hkap_eq : kappa es' = kappa es).
      { apply Huniq; try (apply in_map; assumption).
        - congruence.
        - rewrite Hks', Hps; reflexivity. }
      split; [exact Hpl |].
      rewrite Hoe.
      replace (EventRecord o (LSetFlagStart p q fl)) with (kappa es')
        by (rewrite Hkap_eq; destruct (kappa es); cbn in Hos, Hps; congruence).
      eapply nth_error_In.
      assert (His_m : (is0 < m)%nat) by lia.
      rewrite nth_error_firstn, (proj2 (Nat.ltb_lt _ _) His_m), nth_error_map, His0.
      reflexivity.
    + assert (Hpl : payload (kappa e) = LWaitFlagEnd)
        by (destruct (payload (kappa e)); try discriminate Hke2; reflexivity).
      assert (Hh_eq : h = HWaitFlag) by (destruct h; cbn in *; try congruence; discriminate).
      subst h.
      destruct (HA1 o HWaitFlag Hh ltac:(discriminate) e
                    (conj He_t (conj Hoe (ex_intro _ HWaitFlag (conj Hh Hke)))))
        as [es' [[Hes'_t [Hos' [hs' [Hhs' Hks']]]] [is0 [ie0 [His0 [Hie0 Hlt]]]]]].
      pose proof (proj1 (NoDup_nth_error t) Hnd_t ie ie0 (ltac:(apply nth_error_Some; congruence)) (eq_trans Hie (eq_sym Hie0))) as Eie.
      subst ie0.
      assert (Hhs'_eq : hs' = HWaitFlag) by (eapply ops_unique_head; eassumption). subst hs'.
      assert (Hkap_eq : kappa es' = kappa es).
      { apply Huniq; try (apply in_map; assumption).
        - congruence.
        - rewrite Hks', Hps; reflexivity. }
      split; [exact Hpl |].
      rewrite Hoe.
      replace (EventRecord o (LWaitFlagStart p q fl)) with (kappa es')
        by (rewrite Hkap_eq; destruct (kappa es); cbn in Hos, Hps; congruence).
      eapply nth_error_In.
      assert (His_m : (is0 < m)%nat) by lia.
      rewrite nth_error_firstn, (proj2 (Nat.ltb_lt _ _) His_m), nth_error_map, His0.
      reflexivity.
Qed.

Lemma firstn_S_nth_error {A} (xs : list A) (k : nat) (x : A) :
  nth_error xs k = Some x ->
  firstn (S k) xs = firstn k xs ++ [x].
Proof.
  revert k. induction xs as [|a xs IH]; intros [|k] H; cbn in H; try discriminate.
  - inversion H; subst; reflexivity.
  - cbn. f_equal. apply IH; exact H.
Qed.

Lemma firstn_map {A B} (f : A -> B) (n : nat) (xs : list A) :
  firstn n (map f xs) = map f (firstn n xs).
Proof.
  revert n. induction xs as [|a xs IH]; intros [|n]; cbn; [reflexivity | reflexivity | reflexivity | f_equal; auto].
Qed.

Lemma NoDup_firstn_not_in {A} (xs : list A) (k : nat) (x : A) :
  NoDup xs ->
  nth_error xs k = Some x ->
  ~ In x (firstn k xs).
Proof.
  revert k. induction xs as [|a xs IH]; intros [|k] Hnd H; cbn in H; try discriminate.
  - intros [].
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    intros [<- | Hin].
    + apply Hni. eapply nth_error_In; exact H.
    + eapply IH; eassumption.
Qed.

Lemma nth_error_combine_inv {A B} (xs : list A) (ys : list B) j a b :
  nth_error (combine xs ys) j = Some (a, b) ->
  nth_error xs j = Some a /\ nth_error ys j = Some b.
Proof.
  revert ys j. induction xs as [|x xs IH]; intros [|y ys] [|j] H; cbn in H; try discriminate.
  - inversion H; auto.
  - cbn; apply IH; exact H.
Qed.

Lemma nth_error_firstn_in {A} (xs : list A) (k i : nat) (x : A) :
  (i < k)%nat ->
  nth_error xs i = Some x ->
  In x (firstn k xs).
Proof.
  intros Hlt H. eapply nth_error_In.
  rewrite nth_error_firstn, (proj2 (Nat.ltb_lt _ _) Hlt). exact H.
Qed.

(* 重放不变式：追踪各分支剩余的 command_events 推导 *)
Record replay_inv (t : list EventId) (kappa : Kappa) (events : list Rec) (uses : list Use)
    (k : nat) (st : MState) (rem_list : list (list Rec * list Use)) : Prop := {
  ri_trace : rev (ms_rev_trace st) = firstn k (map kappa t);
  ri_len : length rem_list = length ann;
  ri_branches : forall j ts rem_evs rem_uses,
    nth_error (ms_threads st) j = Some ts ->
    nth_error rem_list j = Some (rem_evs, rem_uses) ->
    incl rem_uses uses /\
    match ts with
    | TRunning cur | TWaitingFlag _ cur =>
        cursor_wf cur /\
        is_event_head (cursor_cmd cur) = true /\
        cursor_tid cur = Pos.of_succ_nat j /\
        command_events layout model (cursor_env cur) (annotated_of cur) rem_evs rem_uses
    | TDone _ =>
        rem_evs = [] /\ rem_uses = []
    end;
  ri_start_covered : forall r,
    In r events ->
    rec_is_start ann r ->
    In r (firstn k (map kappa t)) \/ In r (concat (map fst rem_list))
}.

Local Lemma in_concat_map_fst_update {A B} (j : nat) (old new_pair : list A * B)
    (xs : list (list A * B)) (r : A) :
  nth_error xs j = Some old ->
  In r (concat (map fst xs)) ->
  (In r (fst old) -> In r (fst new_pair)) ->
  In r (concat (map fst (update_nth j new_pair xs))).
Proof.
  intros Hnth Hin Himpl.
  apply in_concat in Hin as [l [Hmap Hr]].
  apply in_map_iff in Hmap as [[evs us] [<- Hmem]].
  apply In_nth_error in Hmem as [k Hk].
  apply in_concat.
  destruct (Nat.eq_dec j k) as [-> | Hneq].
  - rewrite Hnth in Hk; inversion Hk; subst.
    exists (fst new_pair); split; [| apply Himpl; exact Hr].
    apply in_map. eapply nth_error_In.
    rewrite nth_error_update_nth_eq by (apply nth_error_Some; congruence). reflexivity.
  - exists evs; split; [| exact Hr].
    change evs with (fst (evs, us)). apply in_map. eapply nth_error_In.
    rewrite nth_error_update_nth_neq by exact Hneq. exact Hk.
Qed.

Local Lemma start_and_end_disjoint (r : Rec) :
  annotations_valid ann ->
  rec_is_start ann r ->
  rec_is_end ann r ->
  forall h, In (owner r, h) (program_operations ann) -> start_kind h = end_kind h.
Proof.
  intros [Hnd _] [h1 [H1 K1]] [h2 [H2 K2]] h Hh.
  pose proof (ops_unique_head ann Hnd H1 Hh) as ->.
  pose proof (ops_unique_head ann Hnd H2 Hh) as ->.
  congruence.
Qed.

Local Lemma strict_end_not_start (o : op_id) (l : @label Float EventId Pipe Unit) :
  annotations_valid ann ->
  (l = LWriteEnd \/ l = LSetFlagEnd \/ l = LWaitFlagEnd \/
   (exists v, l = LReadEnd v) \/ (exists v, l = LComputeEnd v)) ->
  ~ rec_is_start ann (EventRecord o l).
Proof.
  intros _ Hl [h [_ Hk]]. cbn in Hk.
  destruct Hl as [-> | [-> | [-> | [[v ->] | [v ->]]]]]; destruct h; discriminate Hk.
Qed.

Local Lemma start_record_not_strict_end (r : Rec) :
  rec_is_start ann r ->
  match payload r with
  | LReadEnd _ | LWriteEnd | LComputeEnd _ | LSetFlagEnd | LWaitFlagEnd => False
  | _ => True
  end.
Proof.
  intros [h [_ Hk]]. destruct (payload r); cbn in *; destruct h; try exact I; discriminate Hk.
Qed.

(* 为了避免重复代码，先抽取出单个 Start 步骤更新 replay_inv 的通用引理！ *)
Local Lemma update_replay_inv_issue (t : list EventId) (kappa : Kappa)
    (events : list Rec) (uses : list Use) (k j : nat) (st : MState)
    (rem_list : list (list Rec * list Use)) (old_evs : list Rec) (old_uses : list Use)
    (new_evs : list Rec) (new_uses : list Use) (rk : Rec) (new_ts : TState)
    (sync' : @sync_state Float EventId Pipe Unit) (mem' : @mem_state Float EventId Pipe)
    (extra_uses : list Use) :
  annotations_valid ann ->
  replay_inv t kappa events uses k st rem_list ->
  nth_error (ms_threads st) j <> None ->
  nth_error rem_list j = Some (old_evs, old_uses) ->
  firstn (S k) (map kappa t) = firstn k (map kappa t) ++ [rk] ->
  (forall r, In r old_evs -> rec_is_start ann r -> r = rk \/ In r new_evs) ->
  incl new_uses uses ->
  match new_ts with
  | TRunning cur | TWaitingFlag _ cur =>
      cursor_wf cur /\
      is_event_head (cursor_cmd cur) = true /\
      cursor_tid cur = Pos.of_succ_nat j /\
      command_events layout model (cursor_env cur) (annotated_of cur) new_evs new_uses
  | TDone _ => new_evs = [] /\ new_uses = []
  end ->
  replay_inv t kappa events uses (S k)
    (MachineState (update_nth j new_ts (ms_threads st)) sync' mem'
                  (rk :: ms_rev_trace st) (rev_append extra_uses (ms_rev_uses st)))
    (update_nth j (new_evs, new_uses) rem_list).
Proof.
  intros Hval Hri Hts_some Hrem_j Hfirstn_S Hold_split Hinc_new Hnew_br.
  assert (Hj_rem : (j < length rem_list)%nat) by (apply nth_error_Some; congruence).
  assert (Hj_th : (j < length (ms_threads st))%nat) by (apply nth_error_Some; exact Hts_some).
  constructor; cbn [ms_threads ms_rev_trace rev].
  - rewrite (ri_trace Hri), Hfirstn_S; reflexivity.
  - rewrite length_update_nth; exact (ri_len Hri).
  - intros m ts_m evs_m us_m Htm Hrm.
    destruct (Nat.eq_dec j m) as [-> | Hneq].
    + rewrite nth_error_update_nth_eq in Htm by exact Hj_th.
      rewrite nth_error_update_nth_eq in Hrm by exact Hj_rem.
      inversion Htm; inversion Hrm; subst. split; [exact Hinc_new | exact Hnew_br].
    + rewrite nth_error_update_nth_neq in Htm by exact Hneq.
      rewrite nth_error_update_nth_neq in Hrm by exact Hneq.
      eapply (ri_branches Hri); eassumption.
  - intros r Hr Hsr.
    destruct (ri_start_covered Hri Hr Hsr) as [Hin | Hin].
    + left; rewrite Hfirstn_S; apply in_app_iff; now left.
    + apply in_concat in Hin as [l [Hmap Hr_l]].
      apply in_map_iff in Hmap as [[evs_m us_m] [Heq_f Hmem_m]]. cbn [fst] in Heq_f; subst l.
      apply In_nth_error in Hmem_m as [m Hm].
      destruct (Nat.eq_dec j m) as [-> | Hneq].
      * rewrite Hrem_j in Hm; inversion Hm; subst.
        destruct (Hold_split r Hr_l Hsr) as [-> | Hnew].
        -- left; rewrite Hfirstn_S; apply in_app_iff; right; now left.
        -- right. apply in_concat. exists new_evs; split; [| exact Hnew].
           change new_evs with (fst (new_evs, new_uses)). apply in_map. eapply nth_error_In.
           rewrite nth_error_update_nth_eq by exact Hj_rem; reflexivity.
      * right. apply in_concat. exists evs_m; split; [| exact Hr_l].
        change evs_m with (fst (evs_m, us_m)). apply in_map. eapply nth_error_In.
        rewrite nth_error_update_nth_neq by exact Hneq; exact Hm.
Qed.

(* 辅助：利用当前游标头命令的 NoDup (op_ids)，说明续体事件中不可能再出现头操作 o0。 *)
Local Lemma tail_events_ne_head layout' (model' : @computation_model Float EventId Pipe Unit)
    rho (c_tail : AnnCmd) evs_t us_t (o0 : op_id) :
  ~ In o0 (op_ids c_tail) ->
  command_events layout' model' rho c_tail evs_t us_t ->
  forall r, In r evs_t -> owner r <> o0.
Proof.
  intros Hni Hce r Hr Heq. apply Hni. rewrite <- Heq. eapply command_events_owners; eassumption.
Qed.

(* 辅助判定：一条事件记录按 payload 语法直接区分“发起类”还是“严格二阶段完成类”。 *)
Local Definition is_strict_end_payload (l : @label Float EventId Pipe Unit) : bool :=
  match l with
  | LReadEnd _ | LWriteEnd | LComputeEnd _ | LSetFlagEnd | LWaitFlagEnd => true
  | _ => false
  end.

Local Lemma strict_end_or_start (r : Rec) :
  (rec_is_start ann r \/ rec_is_end ann r) ->
  if is_strict_end_payload (payload r) then
    exists h, In (owner r, h) (program_operations ann) /\
      start_kind h <> end_kind h /\ kind (payload r) = end_kind h
  else
    rec_is_start ann r.
Proof.
  destruct r as [o pl].
  intros [[h [Hh Hk]] | [h [Hh Hk]]];
    cbn in *; destruct pl, h; try discriminate Hk;
    try solve [eexists; split; [exact Hh | split; [discriminate | reflexivity]]];
    (eexists; split; [exact Hh | reflexivity]).
Qed.

Lemma replay_prefix_complete_main (t : list EventId) (kappa : Kappa) (events : list Rec) (uses : list Use) :
  well_formed cfg raw ->
  program_events layout model ann events uses ->
  NoDup events ->
  (exists ordered, Permutation events ordered /\ prefix (map kappa t) ordered) ->
  A_sync ann t kappa ->
  completed_result_values ann t kappa uses ->
  memory_values t kappa ->
  Forall (fun e => target_allows cfg (payload (kappa e))) t ->
  forall k, (k <= length t)%nat ->
  exists budget st0 st rem_list,
    (1 <= budget)%nat /\
    init_machine budget raw = Ok st0 /\
    auto_steps layout cfg model Pe Ee budget st0 st /\
    replay_inv t kappa events uses k st rem_list.
Proof.
  intros Hwf Hpe Hnd_ev [ordered [Hperm [suffix Hpref]]]
         [HA1 [HA2 [HA3 [HA4 HA5]]]] HAval Hmem Htgt.
  pose proof (annotate_program_valid raw) as [_ Hval].
  pose proof (proj1 Hval) as Hnd_all.
  fold ann in Hval, Hnd_all.
  assert (Hnd_kt : NoDup (map kappa t)).
  { apply (Permutation_NoDup Hperm) in Hnd_ev. rewrite Hpref in Hnd_ev.
    apply NoDup_app_disjoint in Hnd_ev as [H1 _]. exact H1. }
  assert (Hnd_t : NoDup t) by (eapply NoDup_map_inv; exact Hnd_kt).
  assert (Hincl_ev : forall r, In r (map kappa t) -> In r events).
  { intros r Hr. eapply Permutation_in; [apply Permutation_sym; exact Hperm |].
    rewrite Hpref; apply in_app_iff; now left. }
  assert (Hvalid_t : forall e, In e t -> rec_is_start ann (kappa e) \/ rec_is_end ann (kappa e)).
  { intros e He. eapply program_events_rec_spec; [exact Hpe | apply Hincl_ev, in_map; exact He]. }
  assert (Huniq_t : forall r1 r2, In r1 (map kappa t) -> In r2 (map kappa t) ->
            owner r1 = owner r2 -> kind (payload r1) = kind (payload r2) -> r1 = r2).
  { intros r1 r2 H1 H2 Ho Hk. eapply program_events_unique_phase; [exact Hpe | exact Hval | apply Hincl_ev; exact H1 | apply Hincl_ev; exact H2 | exact Ho | exact Hk]. }
  assert (Hec_raw : Forall (ends_correctly false) raw).
  { destruct Hwf as [_ Hall]. eapply Forall_impl; [| exact Hall]. intros c [_ [_ [Hec _]]]; exact Hec. }
  induction k as [|k IH]; intros Hkle.
  - (* Base case k = 0 *)
    destruct (program_events_split Hpe) as [br_evs [br_uses [Hle [Hlu [He_cat [Hu_cat Hall_br]]]]]].
    assert (Hlen_ann : length ann = length raw) by (unfold ann; apply length_ann).
    destruct (init_threads_aux_complete (layout := layout) (model := model) 0 br_evs br_uses Hec_raw
                (eq_trans Hle Hlen_ann) (eq_trans Hlu Hlen_ann))
      as [budget [ts [Hb1 [Hinit_ts [Hlen_ts Hall_ts]]]]].
    { intros j c evs us Hc He Hu.
      assert (Ha : nth_error ann j = Some (label_paths (pair (Pos.of_succ_nat j)) 1%positive (expand_loops c LoopEnd))).
      { unfold ann, annotate_program. rewrite nth_error_map.
        assert (Hj : (j < length raw)%nat) by (apply nth_error_Some; congruence).
        assert (Hcomb : nth_error (combine (seq 0 (length raw)) (expand_program raw)) j = Some (j, expand_loops c LoopEnd)).
        { apply nth_error_combine.
          - rewrite nth_error_seq by exact Hj; reflexivity.
          - unfold expand_program; rewrite nth_error_map, Hc; reflexivity. }
        rewrite Hcomb; reflexivity. }
      replace (0 + j)%nat with j by lia.
      eapply Hall_br; eassumption. }
    set (st0 := MachineState ts empty_sync_state empty_mem_state [] []).
    exists budget, st0, st0, (combine br_evs br_uses).
    split; [exact Hb1 | split; [unfold init_machine; rewrite Hinit_ts; reflexivity | split; [constructor | constructor]]].
    + reflexivity.
    + rewrite length_combine, Hle, Hlu; lia.
    + intros j0 ts_j rem_evs rem_uses Hts Hrem.
      apply nth_error_combine_inv in Hrem as [He_j Hu_j].
      destruct (Hall_ts j0 ts_j rem_evs rem_uses Hts He_j Hu_j) as [cur [-> [Hwf_c [Hhead [Htid Hce]]]]].
      split.
      * intros u Hu. rewrite Hu_cat. apply in_concat. exists rem_uses; split; [eapply nth_error_In; exact Hu_j | exact Hu].
      * split; [exact Hwf_c | split; [exact Hhead | split; [exact Htid | exact Hce]]].
    + intros r Hr _. right.
      replace (map fst (combine br_evs br_uses)) with br_evs.
      * rewrite <- He_cat; exact Hr.
      * assert (Hlen_eq : length br_evs = length br_uses) by lia.
        clear - Hlen_eq. revert br_uses Hlen_eq.
        induction br_evs as [|e es IHbr]; intros [|u us] H1; cbn in *; try reflexivity; try lia.
        f_equal; apply IHbr; lia.
  - (* Inductive step k -> S k *)
    destruct (IH ltac:(lia)) as [budget1 [st0 [st [rem_list [Hb1 [Hinit1 [Hsteps1 Hri]]]]]]].
    assert (Hk_lt : (k < length t)%nat) by lia.
    destruct (nth_error t k) as [ek|] eqn:Htk; [| apply nth_error_None in Htk; lia].
    set (rk := kappa ek).
    assert (Hek_in : In ek t) by (eapply nth_error_In; exact Htk).
    assert (Hrk_nth : nth_error (map kappa t) k = Some rk) by (rewrite nth_error_map, Htk; reflexivity).
    assert (Hrk_in_kt : In rk (map kappa t)) by (eapply nth_error_In; exact Hrk_nth).
    assert (Hrk_in_ev : In rk events) by (apply Hincl_ev; exact Hrk_in_kt).
    assert (Hrk_fresh : ~ In rk (firstn k (map kappa t))) by (eapply NoDup_firstn_not_in; eassumption).
    assert (Hfirstn_S : firstn (S k) (map kappa t) = firstn k (map kappa t) ++ [rk])
      by (apply firstn_S_nth_error; exact Hrk_nth).
    assert (Htgt_k : target_allows cfg (payload rk))
      by (exact (proj1 (Forall_forall _ _) Htgt ek Hek_in)).
    pose proof (init_machine_inv layout cfg model Pe Ee raw budget1 Hinit1) as Hmi0.
    pose proof (auto_steps_preserves_inv Hsteps1 Hmi0) as Hmi.
    pose proof (auto_steps_preserves_extra_inv Hsteps1 Hmi0 (init_machine_extra_inv raw budget1 Hinit1)) as Heai.
    assert (Hmem_step : memory_step_ok (rev (firstn k (map kappa t))) rk).
    { unfold memory_values in Hmem.
      rewrite <- (firstn_skipn (S k) (map kappa t)) in Hmem.
      assert (Hpref_mh : forall (xs ys : list Rec), TraceSemantics.memory_history [] (xs ++ ys) -> TraceSemantics.memory_history [] xs).
      { intros xs ys.
        assert (Hg : forall (p xs ys : list Rec), TraceSemantics.memory_history p (xs ++ ys) -> TraceSemantics.memory_history p xs).
        { intros p xs0. revert p. induction xs0 as [|x xs0 IHxs]; intros p ys0 H; [exact I |].
          cbn in H. destruct H as [Hx Hrest]. split; [exact Hx | eapply IHxs; exact Hrest]. }
        apply Hg. }
      apply Hpref_mh in Hmem. rewrite Hfirstn_S in Hmem.
      apply memory_history_snoc in Hmem as [_ Hstep_m].
      rewrite app_nil_r in Hstep_m. exact Hstep_m. }
    destruct Hmi as [btraces Hmia].
    pose proof (strict_end_or_start (program_events_rec_spec Hpe Hrk_in_ev)) as Hclass.
    destruct (is_strict_end_payload (payload rk)) eqn:Estrict.
    + (* ==================== Case A: rk 是严格二阶段 End 记录 ==================== *)
      destruct Hclass as [h_end [Hh_end [Hne_h Hk_end]]].
      set (o := owner rk).
      assert (Hfin_k : finishes ann t kappa o ek)
        by (split; [exact Hek_in | split; [reflexivity | exists h_end; split; assumption]]).
      destruct (HA1 o h_end Hh_end Hne_h ek Hfin_k)
        as [es [[Hes_t [Hos [hs [Hhs Hks]]]] [is0 [ik [His0 [Hik Hlt]]]]]].
      pose proof (proj1 (NoDup_nth_error t) Hnd_t k ik ltac:(apply nth_error_Some; congruence) (eq_trans Htk (eq_sym Hik))) as Eik.
      subst ik.
      pose proof (ops_unique_head ann Hnd_all Hhs Hh_end) as ->.
      assert (Hstart_in_pre : In (kappa es) (rev (ms_rev_trace st))).
      { rewrite (ri_trace Hri). eapply nth_error_firstn_in; [exact Hlt | rewrite nth_error_map, His0; reflexivity]. }
      assert (Hno_end_pre : ~ rec_has_end ann (rev (ms_rev_trace st)) o).
      { intros [r0 [Hr0 [Ho0 [h0 [Hh0 Hk0]]]]].
        rewrite Ho0 in Hh0.
        pose proof (ops_unique_head ann Hnd_all Hh0 Hh_end) as ->.
        rewrite (ri_trace Hri) in Hr0.
        assert (Hr0_kt : In r0 (map kappa t)).
        { rewrite <- (firstn_skipn k (map kappa t)); apply in_app_iff; now left. }
        assert (Hr0_eq : r0 = rk).
        { apply Huniq_t; [exact Hr0_kt | exact Hrk_in_kt | exact Ho0 | rewrite Hk0, Hk_end; reflexivity]. }
        subst r0; contradiction. }
      destruct (mi_started_2phase Hmia (kappa es) h_end Hstart_in_pre (ltac:(rewrite Hos; exact Hh_end)) Hne_h Hks)
        as [Hend_bad | [pk [Hinf_o _]]].
      { rewrite Hos in Hend_bad; contradiction. }
      rewrite Hos in Hinf_o.
      assert (Hlk_inf : lookup_inflight o (ms_sync st) = Some pk)
        by (apply (proj2 (lookup_assoc_in_nodup op_id_eq_ops o pk _ (mi_inflight_nodup Hmia))); exact Hinf_o).
      destruct (mi_inflight_spec Hmia o pk Hinf_o) as [Hops_pk [Hstart_pk [_ Hspec_pk]]].
      pose proof (ops_unique_head ann Hnd_all Hops_pk Hh_end) as Hhead_pk.
      assert (Hflag_a4_step : forall p q fl l,
        rec_flag_letter p q fl (firstn (S k) (map kappa t)) rk l ->
        forall w_pre,
          projection (rec_flag_letter p q fl (firstn k (map kappa t))) (firstn k (map kappa t)) w_pre ->
          prefix_language (star (fun b => b = [FlagSet; FlagWait])) (w_pre ++ [l])).
      { intros p q fl l Hrk_fl w_pre Hproj_pre.
        destruct (HA4 p q fl) as [w_full [Hproj_full Hlang_full]].
        rewrite <- (firstn_skipn (S k) t) in Hproj_full at 2.
        apply projection_app_inv in Hproj_full as [w_sk [w_rest [-> [Hproj_sk _]]]].
        assert (Hlang_sk : prefix_language (star (fun b => b = [FlagSet; FlagWait])) w_sk)
          by (eapply prefix_language_prefix; [exists w_rest; reflexivity | exact Hlang_full]).
        assert (Hproj_pre_Sk : projection (rec_flag_letter p q fl (firstn (S k) (map kappa t))) (firstn k (map kappa t)) w_pre).
        { eapply projection_ext; [| exact Hproj_pre].
          intros r l0 Hr0. destruct l0; cbn [rec_flag_letter]; split; intros [Hp Hin]; split; try exact Hp.
          - rewrite Hfirstn_S; apply in_app_iff; now left.
          - rewrite Hfirstn_S in Hin; apply in_app_iff in Hin as [Hin | [Heq_r | []]]; [exact Hin |].
            exfalso.
            assert (Hrk_s : payload rk = LSetFlagStart p q fl) by (rewrite Heq_r; reflexivity).
            rewrite Hrk_s in Estrict; discriminate Estrict.
          - rewrite Hfirstn_S; apply in_app_iff; now left.
          - rewrite Hfirstn_S in Hin; apply in_app_iff in Hin as [Hin | [Heq_r | []]]; [exact Hin |].
            exfalso.
            assert (Hrk_s : payload rk = LWaitFlagStart p q fl) by (rewrite Heq_r; reflexivity).
            rewrite Hrk_s in Estrict; discriminate Estrict. }
        assert (Hproj_S_rec : projection (rec_flag_letter p q fl (firstn (S k) (map kappa t))) (firstn (S k) (map kappa t)) (w_pre ++ [l])).
        { rewrite Hfirstn_S at 2. apply projection_snoc_keep; [exact Hproj_pre_Sk | exact Hrk_fl]. }
        assert (Hproj_S_tr : projection (flag_projection ann t kappa p q fl) (firstn (S k) t) (w_pre ++ [l])).
        { eapply projection_map_iff with (f := kappa).
          - intros e l0 He0. symmetry.
            eapply rec_flag_letter_iff_trace_flag; try assumption. exact He0.
          - rewrite <- firstn_map. exact Hproj_S_rec. }
        assert (Heq_w : w_pre ++ [l] = w_sk).
        { eapply projection_unique; [| exact Hproj_S_tr | exact Hproj_sk].
          intros e a b (o1 & s1 & _ & _ & Ha) (o2 & s2 & _ & _ & Hb).
          destruct a, b; cbn in *; intuition congruence. }
        rewrite Heq_w; exact Hlang_sk. }
      assert (Hfinish_ri_preserved : forall threads' sync' mem',
        (forall j ts' rem_evs rem_uses,
           nth_error threads' j = Some ts' ->
           nth_error rem_list j = Some (rem_evs, rem_uses) ->
           incl rem_uses uses /\
           match ts' with
           | TRunning cur | TWaitingFlag _ cur =>
               cursor_wf cur /\
               is_event_head (cursor_cmd cur) = true /\
               cursor_tid cur = Pos.of_succ_nat j /\
               command_events layout model (cursor_env cur) (annotated_of cur) rem_evs rem_uses
           | TDone _ => rem_evs = [] /\ rem_uses = []
           end) ->
        replay_inv t kappa events uses (S k)
          (MachineState threads' sync' mem' (rk :: ms_rev_trace st) (ms_rev_uses st)) rem_list).
      { intros threads' sync' mem' Hbr'.
        constructor; cbn [ms_threads ms_rev_trace rev].
        - rewrite (ri_trace Hri), Hfirstn_S; reflexivity.
        - exact (ri_len Hri).
        - exact Hbr'.
        - intros r Hr Hsr. destruct (ri_start_covered Hri Hr Hsr) as [Hin | Hin].
          + left; rewrite Hfirstn_S; apply in_app_iff; now left.
          + right; exact Hin. }
      destruct pk as [d a | d a data | d args | p q fl deps | p q fl j_wait]; cbn [pk_head] in Hhead_pk; subst h_end.
      * (* PRead *)
        destruct rk as [o' pl]; cbn [owner payload] in o, Hk_end, Hmem_step |- *.
        destruct pl as [|res | | | | | | | | | | | | |]; try discriminate Hk_end.
        assert (Hmem_eq : forall v0, mem_lookup a (ms_mem st) = Some v0 -> res = v0).
        { intros v0 Hv0.
          rewrite (mi_mem_writes Hmia) in Hv0.
          replace (ms_rev_trace st) with (rev (firstn k (map kappa t))) in Hv0, Hspec_pk
            by (rewrite <- (ri_trace Hri), rev_involutive; reflexivity).
          cbn [memory_step_ok owner payload] in Hmem_step.
          unfold o in Hspec_pk. rewrite Hspec_pk, Hv0 in Hmem_step. symmetry; exact Hmem_step. }
        set (sync' := SyncState (remove_assoc op_id_eqb o (sync_inflight (ms_sync st)))
                                (sync_flags (ms_sync st)) (sync_active_wait (ms_sync st))).
        set (mem' := MemState (mem_writes (ms_mem st)) ((o, res) :: mem_done_val (ms_mem st))).
        set (st' := MachineState (ms_threads st) sync' mem' (EventRecord o (LReadEnd res) :: ms_rev_trace st) (ms_rev_uses st)).
        assert (Hstep : auto_step layout cfg model Pe Ee budget1 st (EventRecord o (LReadEnd res)) st')
          by (eapply StepReadEnd; [exact Hlk_inf | exact Hmem_eq]).
        exists budget1, st0, st', rem_list.
        split; [exact Hb1 | split; [exact Hinit1 | split; [eapply auto_steps_snoc; eassumption |]]].
        apply Hfinish_ri_preserved; exact (ri_branches Hri).
      * (* PWrite *)
        destruct rk as [o' pl]; cbn [owner payload] in o, Hk_end |- *.
        destruct pl; try discriminate Hk_end.
        set (sync' := SyncState (remove_assoc op_id_eqb o (sync_inflight (ms_sync st)))
                                (sync_flags (ms_sync st)) (sync_active_wait (ms_sync st))).
        set (mem' := MemState ((a, data) :: mem_writes (ms_mem st)) (mem_done_val (ms_mem st))).
        set (st' := MachineState (ms_threads st) sync' mem' (EventRecord o LWriteEnd :: ms_rev_trace st) (ms_rev_uses st)).
        assert (Hstep : auto_step layout cfg model Pe Ee budget1 st (EventRecord o LWriteEnd) st')
          by (eapply StepWriteEnd; exact Hlk_inf).
        exists budget1, st0, st', rem_list.
        split; [exact Hb1 | split; [exact Hinit1 | split; [eapply auto_steps_snoc; eassumption |]]].
        apply Hfinish_ri_preserved; exact (ri_branches Hri).
      * (* PCompute *)
        destruct rk as [o' pl]; cbn [owner payload] in o, Hk_end |- *.
        destruct pl as [| | | | |res | | | | | | | | |]; try discriminate Hk_end.
        assert (Hcomp : comp model (resource d) args res).
        { eapply program_events_compute_comp; [exact Hpe | exact Hval | | exact Hrk_in_ev].
          apply Hincl_ev. rewrite <- (firstn_skipn k (map kappa t)). apply in_app_iff; left.
          rewrite <- (ri_trace Hri). exact Hstart_pk. }
        set (sync' := SyncState (remove_assoc op_id_eqb o (sync_inflight (ms_sync st)))
                                (sync_flags (ms_sync st)) (sync_active_wait (ms_sync st))).
        set (mem' := MemState (mem_writes (ms_mem st)) ((o, res) :: mem_done_val (ms_mem st))).
        set (st' := MachineState (ms_threads st) sync' mem' (EventRecord o (LComputeEnd res) :: ms_rev_trace st) (ms_rev_uses st)).
        assert (Hstep : auto_step layout cfg model Pe Ee budget1 st (EventRecord o (LComputeEnd res)) st')
          by (eapply StepComputeEnd; [exact Hlk_inf | exact Hcomp]).
        exists budget1, st0, st', rem_list.
        split; [exact Hb1 | split; [exact Hinit1 | split; [eapply auto_steps_snoc; eassumption |]]].
        apply Hfinish_ri_preserved; exact (ri_branches Hri).
      * (* PSetFlag *)
        destruct rk as [o' pl]; cbn [owner payload] in o, Hk_end |- *.
        destruct pl; try discriminate Hk_end.
        assert (Hdrained : deps_drained deps (sync_inflight (ms_sync st)) = true).
        { unfold deps_drained. apply forallb_forall. intros d Hd.
          destruct (lookup_assoc op_id_eqb d (sync_inflight (ms_sync st))) as [pk_d|] eqn:Hlk_d; [| reflexivity].
          exfalso.
          apply (lookup_assoc_in op_id_eq_ops) in Hlk_d.
          destruct (mi_inflight_spec Hmia d pk_d Hlk_d) as [_ [_ [Hne_d _]]].
          destruct (eai_deps_started Heai o p q fl deps d Hinf_o Hd)
            as (i1 & i2 & r1 & r2 & H1 & Ho1 & Hs1 & Hp1 & H2 & Ho2 & Hs2 & Hp2 & Hlt12).
          rewrite (ri_trace Hri) in H1, H2, Hne_d.
          rewrite nth_error_firstn in H1, H2.
          destruct (Nat.ltb i1 k) eqn:Elt1; [| discriminate]. apply Nat.ltb_lt in Elt1.
          destruct (Nat.ltb i2 k) eqn:Elt2; [| discriminate]. apply Nat.ltb_lt in Elt2.
          rewrite nth_error_map in H1, H2.
          destruct (nth_error t i1) as [e1|] eqn:He1; [| discriminate].
          destruct (nth_error t i2) as [e2|] eqn:He2; [| discriminate].
          inversion H1 as [Hk1]; inversion H2 as [Hk2].
          assert (Hpb : pipeline_before ann t kappa p d o).
          { exists e1, e2; repeat split.
            - eapply nth_error_In; exact He1.
            - rewrite Hk1; exact Ho1.
            - destruct Hs1 as [h1 [Hh1 Hks1]]; exists h1; rewrite Hk1; split; [rewrite <- Ho1; exact Hh1 | exact Hks1].
            - eapply nth_error_In; exact He2.
            - rewrite Hk2; exact Ho2.
            - destruct Hs2 as [h2 [Hh2 Hks2]]; exists h2; rewrite Hk2; split; [rewrite <- Ho2; exact Hh2 | exact Hks2].
            - rewrite Hk1; exact Hp1.
            - rewrite Hk2; exact Hp2.
            - exists i1, i2; auto. }
          destruct (HA3 o d p Hh_end Hpb ek Hfin_k) as [ed [Hfin_d [id [ik' [Hid [Hik' Hlt_dk]]]]]].
          pose proof (proj1 (NoDup_nth_error t) Hnd_t k ik' ltac:(apply nth_error_Some; congruence) (eq_trans Htk (eq_sym Hik'))) as Eik.
          subst ik'.
          apply Hne_d. destruct Hfin_d as [_ [Hod [hd [Hhd Hkd]]]].
          exists (kappa ed); repeat split.
          - eapply nth_error_firstn_in; [exact Hlt_dk | rewrite nth_error_map, Hid; reflexivity].
          - exact Hod.
          - exists hd; rewrite Hod; split; assumption. }
        assert (Hflag_false : flag_is_set (eqb Pe) (eqb Ee) p q fl (sync_flags (ms_sync st)) = false).
        { destruct (flag_is_set (eqb Pe) (eqb Ee) p q fl (sync_flags (ms_sync st))) eqn:Hfl; [| reflexivity].
          exfalso.
          destruct (mi_flags Hmia p q fl) as [w_pre [Hproj_pre Hw_pre]].
          rewrite Hfl in Hw_pre. destruct Hw_pre as [w0 [-> Hstar0]].
          rewrite (ri_trace Hri) in Hproj_pre.
          assert (Hrk_fl : rec_flag_letter p q fl (firstn (S k) (map kappa t)) (EventRecord o LSetFlagEnd) FlagSet).
          { split; [reflexivity |]. rewrite Hfirstn_S; apply in_app_iff; left. rewrite <- (ri_trace Hri); exact Hstart_pk. }
          pose proof (Hflag_a4_step p q fl FlagSet Hrk_fl _ Hproj_pre) as Hlang.
          rewrite <- app_assoc in Hlang. exact (star_no_double_set Hstar0 Hlang). }
        set (sync' := SyncState (remove_assoc op_id_eqb o (sync_inflight (ms_sync st)))
                                (flag_set_true p q fl (sync_flags (ms_sync st)))
                                (sync_active_wait (ms_sync st))).
        set (st' := MachineState (ms_threads st) sync' (ms_mem st) (EventRecord o LSetFlagEnd :: ms_rev_trace st) (ms_rev_uses st)).
        assert (Hstep : auto_step layout cfg model Pe Ee budget1 st (EventRecord o LSetFlagEnd) st')
          by (eapply StepSetFlagEnd; [exact Hlk_inf | exact Hdrained | exact Hflag_false]).
        exists budget1, st0, st', rem_list.
        split; [exact Hb1 | split; [exact Hinit1 | split; [eapply auto_steps_snoc; eassumption |]]].
        apply Hfinish_ri_preserved; exact (ri_branches Hri).
      * (* PWaitFlag *)
        destruct rk as [o' pl]; cbn [owner payload] in o, Hk_end |- *.
        destruct pl; try discriminate Hk_end.
        assert (Hflag_true : flag_is_set (eqb Pe) (eqb Ee) p q fl (sync_flags (ms_sync st)) = true).
        { destruct (flag_is_set (eqb Pe) (eqb Ee) p q fl (sync_flags (ms_sync st))) eqn:Hfl; [reflexivity |].
          exfalso.
          destruct (mi_flags Hmia p q fl) as [w_pre [Hproj_pre Hstar_pre]].
          rewrite Hfl in Hstar_pre.
          rewrite (ri_trace Hri) in Hproj_pre.
          assert (Hrk_fl : rec_flag_letter p q fl (firstn (S k) (map kappa t)) (EventRecord o LWaitFlagEnd) FlagWait).
          { split; [reflexivity |]. rewrite Hfirstn_S; apply in_app_iff; left. rewrite <- (ri_trace Hri); exact Hstart_pk. }
          pose proof (Hflag_a4_step p q fl FlagWait Hrk_fl _ Hproj_pre) as Hlang.
          exact (star_no_leading_wait Hstar_pre Hlang). }
        destruct (eai_wait_thread Heai o p q fl j_wait Hinf_o) as [next_cur Hth_wait].
        set (sync' := SyncState (remove_assoc op_id_eqb o (sync_inflight (ms_sync st)))
                                (flag_set_false (eqb Pe) (eqb Ee) p q fl (sync_flags (ms_sync st)))
                                (active_wait_clear (eqb Pe) q (sync_active_wait (ms_sync st)))).
        set (st' := MachineState (update_nth j_wait (TRunning next_cur) (ms_threads st)) sync' (ms_mem st)
                      (EventRecord o LWaitFlagEnd :: ms_rev_trace st) (ms_rev_uses st)).
        assert (Hstep : auto_step layout cfg model Pe Ee budget1 st (EventRecord o LWaitFlagEnd) st')
          by (eapply StepWaitFlagEnd; [exact Hlk_inf | exact Hflag_true | exact Hth_wait]).
        exists budget1, st0, st', rem_list.
        split; [exact Hb1 | split; [exact Hinit1 | split; [eapply auto_steps_snoc; eassumption |]]].
        apply Hfinish_ri_preserved.
        intros m ts_m evs_m us_m Htm Hrm.
        destruct (Nat.eq_dec j_wait m) as [-> | Hneq].
        -- rewrite nth_error_update_nth_eq in Htm by (apply nth_error_Some; congruence).
           inversion Htm; subst ts_m.
           exact (ri_branches Hri m Hth_wait Hrm).
        -- rewrite nth_error_update_nth_neq in Htm by exact Hneq.
           eapply (ri_branches Hri); eassumption.
    + (* ==================== Case B: rk 是 Start 记录 ==================== *)
      rename Hclass into Hrk_start.
      destruct (ri_start_covered Hri Hrk_in_ev Hrk_start) as [Hcontra | Hrk_rem]; [contradiction |].
      apply in_concat in Hrk_rem as [rem_evs_j [Hmap Hrk_in_j]].
      apply in_map_iff in Hmap as [[evs_j uses_j] [Heq_f Hmem_j]]. cbn [fst] in Heq_f; subst evs_j.
      apply In_nth_error in Hmem_j as [j Hrem_j].
      assert (Hj_lt : (j < length ann)%nat) by (rewrite <- (ri_len Hri); apply nth_error_Some; congruence).
      destruct (nth_error (ms_threads st) j) as [ts_j|] eqn:Hts_j;
        [| apply nth_error_None in Hts_j; rewrite (mi_len_threads Hmia) in Hts_j; fold ann in Hts_j; lia].
      destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
        [| apply nth_error_None in Hann_j; lia].
      destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
        [| apply nth_error_None in Hbt_j; rewrite (mi_len_btraces Hmia) in Hbt_j; fold ann in Hbt_j; lia].
      pose proof (ri_branches Hri j Hts_j Hrem_j) as [Hinc_uses_j Hbr_j].
      pose proof (mi_branches Hmia j Hann_j Hts_j Hbt_j) as Hbi_j.
      destruct ts_j as [cur | w_wait cur | res_done].
      * (* ts_j = TRunning cur *)
        destruct Hbr_j as [Hwf_cur [Hhead_cur [Htid_cur Hce_cur]]].
        destruct cur as [tid path rho cmd stk].
        cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack] in *.
        set (o0 := (tid, path)).
        pose proof (bi_rem_nodup Hbi_j) as Hnd_rem. cbn [rem_ops] in Hnd_rem.
        assert (Ho_eq : owner rk = o0).
        { assert (Ho0_or_po : owner rk = o0 \/ In (o0, owner rk) (program_order (annotated_of (ThreadCursor tid path rho cmd stk)))).
          { unfold annotated_of in *; cbn in *.
            destruct cmd; try discriminate Hhead_cur;
              rewrite ?plug_stack_return, ?plug_stack_alloc, ?plug_stack_atomic,
                      ?plug_stack_assign_pipe, ?plug_stack_compute, ?plug_stack_read,
                      ?plug_stack_write, ?plug_stack_setflag, ?plug_stack_waitflag,
                      ?plug_stack_if in Hce_cur |- *;
              cbn [label_paths program_order] in Hce_cur |- *;
              inversion Hce_cur; subst; try contradiction;
              try (destruct Hrk_in_j as [<- | []]; left; reflexivity);
              try (destruct Hrk_in_j as [<- | Htail]; [left; reflexivity | right; apply in_app_iff; left; apply in_map; eapply command_events_owners; eassumption]);
              try (destruct Hrk_in_j as [<- | [<- | Htail]]; [left; reflexivity | left; reflexivity | right; apply in_app_iff; left; apply in_map; eapply command_events_owners; eassumption]).
            destruct Hrk_in_j as [<- | Htail]; [left; reflexivity |].
            right; apply in_app_iff; left; apply in_map; apply in_app_iff; destruct b; [left | right]; eapply command_events_owners; eassumption. }
          destruct Ho0_or_po as [Heq | Hpo0]; [exact Heq |].
          exfalso.
          pose proof (eai_po_sub Heai j Hann_j Hts_j (o0, owner rk) Hpo0) as Hpo_j.
          assert (Hpo_ann : In (o0, owner rk) (po ann))
            by (eapply branch_po_in_program; [exact Hann_j | exact Hpo_j]).
          destruct Hrk_start as [hk [Hhk Hkk]].
          assert (Hst_k : starts ann t kappa (owner rk) ek)
            by (split; [exact Hek_in | split; [reflexivity | exists hk; split; assumption]]).
          destruct (proj1 (HA2 o0 (owner rk) Hpo_ann) ek Hst_k) as [e0 [[He0_t [Ho0_eq _]] [i0 [ik [Hi0 [Hik Hlt]]]]]].
          pose proof (proj1 (NoDup_nth_error t) Hnd_t k ik ltac:(apply nth_error_Some; congruence) (eq_trans Htk (eq_sym Hik))) as Eik.
          subst ik.
          assert (Hin_pre : In (kappa e0) (firstn k (map kappa t))).
          { eapply nth_error_firstn_in; [exact Hlt | rewrite nth_error_map, Hi0; reflexivity]. }
          assert (Ho0_in_rem : In o0 (map fst (rem_ops (TRunning (ThreadCursor tid path rho cmd stk))))).
          { cbn [rem_ops]. destruct (program_order_in_op_ids _ _ _ Hpo0) as [H1 _]. exact H1. }
          destruct (bi_rem_fresh Hbi_j o0 Ho0_in_rem) as [Hni_pre _].
          apply Hni_pre. rewrite (ri_trace Hri), <- Ho0_eq. apply in_map; exact Hin_pre. }
        assert (Hrk_start_at : starts ann t kappa o0 ek).
        { destruct Hrk_start as [hk [Hhk Hkk]].
          split; [exact Hek_in | split; [exact Ho_eq | exists hk; rewrite <- Ho_eq; split; assumption]]. }
        assert (Hpipe_ready_helper : forall p0,
          declared_pipeline cfg p0 ->
          pipeline (payload rk) = Some p0 ->
          pipe_ready cfg Pe (sync_active_wait (ms_sync st)) (Some p0)).
        { intros p0 Hdecl Hpl_p0. split; [exact Hdecl |].
          destruct (active_wait_of (eqb Pe) p0 (sync_active_wait (ms_sync st))) as [w0|] eqn:Haw; [| reflexivity].
          exfalso. apply (lookup_assoc_in Pe) in Haw.
          destruct (eai_active_wait_bwd Heai p0 w0 Haw) as [pw [flw [Hws Hne]]].
          rewrite (ri_trace Hri) in Hws, Hne.
          apply In_nth_error in Hws as [iw Hiw].
          rewrite nth_error_firstn in Hiw.
          destruct (Nat.ltb iw k) eqn:Elt_iw; [| discriminate]. apply Nat.ltb_lt in Elt_iw.
          rewrite nth_error_map in Hiw.
          destruct (nth_error t iw) as [ew|] eqn:Hew; [| discriminate].
          inversion Hiw as [Hkw].
          assert (Hew_t : In ew t) by (eapply nth_error_In; exact Hew).
          destruct (Hvalid_t ew Hew_t) as [[hw [Hhw Hkw']] | [hw [Hhw Hkw']]];
            rewrite Hkw in Hhw, Hkw'; cbn in Hhw, Hkw'; destruct hw; cbn in Hkw'; try discriminate Hkw'.
          assert (Hpb : pipeline_before ann t kappa p0 w0 o0).
          { exists ew, ek.
            split; [split; [exact Hew_t | split; [rewrite Hkw; reflexivity | exists HWaitFlag; split; [exact Hhw | rewrite Hkw; reflexivity]]] |].
            split; [exact Hrk_start_at |].
            split; [rewrite Hkw; reflexivity |].
            split; [exact Hpl_p0 |].
            exists iw, k; auto. }
          destruct (HA5 w0 o0 p0 Hhw Hpb ek Hrk_start_at) as [ew_end [Hfin_w [iwe [ik [Hiwe [Hik Hlt]]]]]].
          pose proof (proj1 (NoDup_nth_error t) Hnd_t k ik ltac:(apply nth_error_Some; congruence) (eq_trans Htk (eq_sym Hik))) as Eik.
          subst ik.
          apply Hne. exists (kappa ew_end).
          destruct Hfin_w as [_ [Hwo [hw' [Hhw' Hkwe]]]].
          repeat split.
          - eapply nth_error_firstn_in; [exact Hlt | rewrite nth_error_map, Hiwe; reflexivity].
          - exact Hwo.
          - exists hw'; rewrite Hwo; split; assumption. }
        destruct Hwf_cur as [Hec_cmd Hsw_stk].
        destruct cmd as [u vs | | u x n | u x f vs n | | u x v n
                        | u x d vs n | u x d v n | u d v1 v2 n | u src dst v n | u src dst v n
                        | | | u cond y n]; try discriminate Hhead_cur; try destruct u.
        -- (* Return *)
           unfold annotated_of in Hce_cur; cbn in Hce_cur; rewrite plug_stack_return in Hce_cur; cbn [label_paths] in Hce_cur.
           inversion Hce_cur; subst; [contradiction |].
           destruct Hrk_in_j as [Hrk_eq | []].
           match goal with
           | Hops : operand_values _ _ _ _ ?args_v _ |- _ =>
               rename Hops into Hops_r; set (args_v0 := args_v)
           end.
           assert (Hres : resolve_operands_rel (mem_done_val (ms_mem st)) rho (Pos.of_succ_nat j, path) 0 vs args_v0 uses_j)
             by (eapply operand_values_to_resolve; [exact HAval | exact (ri_trace Hri) | exact (mi_done_val Hmia) | exact Htk | exact Hrk_start_at | exact Hinc_uses_j | exact Hops_r]).
           set (st' := MachineState (update_nth j (TDone args_v0) (ms_threads st)) (ms_sync st) (ms_mem st)
                         (rk :: ms_rev_trace st) (rev_append uses_j (ms_rev_uses st))).
           assert (Hstep : auto_step layout cfg model Pe Ee budget1 st rk st').
           { unfold st'; rewrite <- Hrk_eq. eapply StepReturn; [exact Hts_j | reflexivity | exact Hres]. }
           exists budget1, st0, st', (update_nth j ([], []) rem_list).
           split; [exact Hb1 | split; [exact Hinit1 | split; [eapply auto_steps_snoc; eassumption |]]].
           eapply update_replay_inv_issue; [exact Hval | exact Hri | congruence | exact Hrem_j | exact Hfirstn_S | | intros ? [] | split; reflexivity].
           intros r [<- | []] _; left; exact Hrk_eq.
        -- (* Alloc *)
           unfold annotated_of in Hce_cur, Hnd_rem; cbn in Hce_cur, Hnd_rem;
             rewrite plug_stack_alloc in Hce_cur, Hnd_rem; cbn [label_paths operations map] in Hce_cur, Hnd_rem.
           inversion Hnd_rem as [|? ? Hni_tail _]; subst.
           inversion Hce_cur; subst; [contradiction |].
           match goal with
           | Hce_n : command_events layout model _ (label_paths _ _ (plug_stack n stk)) ?evs_n ?us_n |- _ =>
               rename Hce_n into Hce_next; set (evs_n0 := evs_n); set (us_n0 := us_n)
           end.
           destruct Hrk_in_j as [Hrk_eq | Htail];
             [| exfalso; eapply tail_events_ne_head; [exact Hni_tail | exact Hce_next | exact Htail | exact Ho_eq]].
           set (addr := address_at layout (InBranch o0)).
           set (cur_next := ThreadCursor (Pos.of_succ_nat j) (xO path) (bind rho x (Known (VMemory addr))) n stk).
           assert (Hwf_next : cursor_wf cur_next) by (split; assumption).
           destruct (command_events_refocus Hwf_next Hce_next) as [b_step [cur' [Href [Hhead' [Hwf' [Htid' Hce']]]]]].
           set (budget := Nat.max budget1 b_step).
           assert (Hm_none : mem_lookup addr (ms_mem st) = None).
           { rewrite (mi_mem_writes Hmia).
             replace (ms_rev_trace st) with (rev (firstn k (map kappa t)))
               by (rewrite <- (ri_trace Hri), rev_involutive; reflexivity).
             rewrite <- Hrk_eq in Hmem_step; exact Hmem_step. }
           set (st' := MachineState (update_nth j (TRunning cur') (ms_threads st)) (ms_sync st) (ms_mem st)
                         (rk :: ms_rev_trace st) (ms_rev_uses st)).
           assert (Hstep : auto_step layout cfg model Pe Ee budget st rk st').
           { unfold st'; rewrite <- Hrk_eq. eapply StepAlloc; [exact Hts_j | reflexivity | reflexivity | exact Hm_none | (eapply refocus_mono; [| exact Href]; unfold budget; lia)]. }
           exists budget, st0, st', (update_nth j (evs_n0, us_n0) rem_list).
           split; [unfold budget; lia | split; [eapply init_machine_mono; [| exact Hinit1]; unfold budget; lia
                         | split; [eapply auto_steps_snoc; [eapply auto_steps_mono; [| exact Hsteps1]; unfold budget; lia | exact Hstep] |]]].
           unfold st'; change (ms_rev_uses st) with (rev_append [] (ms_rev_uses st)).
           eapply update_replay_inv_issue;
             [exact Hval | exact Hri | congruence | exact Hrem_j | exact Hfirstn_S | | exact Hinc_uses_j |].
           ++ intros r [<- | Hr] _; [left; exact Hrk_eq | right; exact Hr].
           ++ split; [exact Hwf' | split; [exact Hhead' | split; [exact Htid' | exact Hce']]].
        -- (* LetAtomic *)
           unfold annotated_of in Hce_cur, Hnd_rem; cbn in Hce_cur, Hnd_rem;
             rewrite plug_stack_atomic in Hce_cur, Hnd_rem; cbn [label_paths operations map] in Hce_cur, Hnd_rem.
           inversion Hnd_rem as [|? ? Hni_tail _]; subst.
           inversion Hce_cur; subst; [contradiction |].
           match goal with
           | Hops : operand_values _ _ _ _ ?args_v ?u1,
             Heval : eval_atomic f ?args_v = Some ?res_v,
             Hce_n : command_events layout model _ (label_paths _ _ (plug_stack n stk)) ?evs_n ?u2 |- _ =>
               rename Hops into Hops_r; rename Heval into Heval_r; rename Hce_n into Hce_next;
               set (args_v0 := args_v); set (res_v0 := res_v); set (u1_0 := u1); set (u2_0 := u2); set (evs_n0 := evs_n)
           end.
           destruct Hrk_in_j as [Hrk_eq | Htail];
             [| exfalso; eapply tail_events_ne_head; [exact Hni_tail | exact Hce_next | exact Htail | exact Ho_eq]].
           assert (Hinc_u1 : incl u1_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now left).
           assert (Hinc_u2 : incl u2_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now right).
           assert (Hres : resolve_operands_rel (mem_done_val (ms_mem st)) rho (Pos.of_succ_nat j, path) 0 vs args_v0 u1_0)
             by (eapply operand_values_to_resolve; [exact HAval | exact (ri_trace Hri) | exact (mi_done_val Hmia) | exact Htk | exact Hrk_start_at | exact Hinc_u1 | exact Hops_r]).
           set (cur_next := ThreadCursor (Pos.of_succ_nat j) (xO path) (bind rho x (Known res_v0)) n stk).
           assert (Hwf_next : cursor_wf cur_next) by (split; assumption).
           destruct (command_events_refocus Hwf_next Hce_next) as [b_step [cur' [Href [Hhead' [Hwf' [Htid' Hce']]]]]].
           set (budget := Nat.max budget1 b_step).
           set (st' := MachineState (update_nth j (TRunning cur') (ms_threads st)) (ms_sync st) (ms_mem st)
                         (rk :: ms_rev_trace st) (rev_append u1_0 (ms_rev_uses st))).
           assert (Hstep : auto_step layout cfg model Pe Ee budget st rk st').
           { unfold st'; rewrite <- Hrk_eq. eapply StepAtomic; [exact Hts_j | reflexivity | exact Hres | exact Heval_r | (eapply refocus_mono; [| exact Href]; unfold budget; lia)]. }
           exists budget, st0, st', (update_nth j (evs_n0, u2_0) rem_list).
           split; [unfold budget; lia | split; [eapply init_machine_mono; [| exact Hinit1]; unfold budget; lia
                         | split; [eapply auto_steps_snoc; [eapply auto_steps_mono; [| exact Hsteps1]; unfold budget; lia | exact Hstep] |]]].
           eapply update_replay_inv_issue;
             [exact Hval | exact Hri | congruence | exact Hrem_j | exact Hfirstn_S | | exact Hinc_u2 |].
           ++ intros r [<- | Hr] _; [left; exact Hrk_eq | right; exact Hr].
           ++ split; [exact Hwf' | split; [exact Hhead' | split; [exact Htid' | exact Hce']]].
        -- (* AssignPipe *)
           unfold annotated_of in Hce_cur, Hnd_rem; cbn in Hce_cur, Hnd_rem;
             rewrite plug_stack_assign_pipe in Hce_cur, Hnd_rem; cbn [label_paths operations map] in Hce_cur, Hnd_rem.
           inversion Hnd_rem as [|? ? Hni_tail _]; subst.
           inversion Hce_cur; subst; [contradiction |].
           match goal with
           | Hop : operand_value _ _ _ _ (VPipe ?p_v) ?u1,
             Hce_n : command_events layout model _ (label_paths _ _ (plug_stack n stk)) ?evs_n ?u2 |- _ =>
               rename Hop into Hop_r; rename Hce_n into Hce_next;
               set (p_v0 := p_v); set (u1_0 := u1); set (u2_0 := u2); set (evs_n0 := evs_n)
           end.
           destruct Hrk_in_j as [Hrk_eq | Htail];
             [| exfalso; eapply tail_events_ne_head; [exact Hni_tail | exact Hce_next | exact Htail | exact Ho_eq]].
           assert (Hinc_u1 : incl u1_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now left).
           assert (Hinc_u2 : incl u2_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now right).
           assert (Hres : resolve_operand_rel (mem_done_val (ms_mem st)) rho (Pos.of_succ_nat j, path) 0 v (VPipe p_v0) u1_0)
             by (eapply operand_value_to_resolve; [exact HAval | exact (ri_trace Hri) | exact (mi_done_val Hmia) | exact Htk | exact Hrk_start_at | exact Hinc_u1 | exact Hop_r]).
           rewrite <- Hrk_eq in Htgt_k; cbn in Htgt_k.
           set (cur_next := ThreadCursor (Pos.of_succ_nat j) (xO path) (bind rho x (Known (VPipe p_v0))) n stk).
           assert (Hwf_next : cursor_wf cur_next) by (split; assumption).
           destruct (command_events_refocus Hwf_next Hce_next) as [b_step [cur' [Href [Hhead' [Hwf' [Htid' Hce']]]]]].
           set (budget := Nat.max budget1 b_step).
           set (st' := MachineState (update_nth j (TRunning cur') (ms_threads st)) (ms_sync st) (ms_mem st)
                         (rk :: ms_rev_trace st) (rev_append u1_0 (ms_rev_uses st))).
           assert (Hstep : auto_step layout cfg model Pe Ee budget st rk st').
           { unfold st'; rewrite <- Hrk_eq. eapply StepAssignPipe; [exact Hts_j | reflexivity | exact Hres | exact Htgt_k | (eapply refocus_mono; [| exact Href]; unfold budget; lia)]. }
           exists budget, st0, st', (update_nth j (evs_n0, u2_0) rem_list).
           split; [unfold budget; lia | split; [eapply init_machine_mono; [| exact Hinit1]; unfold budget; lia
                         | split; [eapply auto_steps_snoc; [eapply auto_steps_mono; [| exact Hsteps1]; unfold budget; lia | exact Hstep] |]]].
           eapply update_replay_inv_issue;
             [exact Hval | exact Hri | congruence | exact Hrem_j | exact Hfirstn_S | | exact Hinc_u2 |].
           ++ intros r [<- | Hr] _; [left; exact Hrk_eq | right; exact Hr].
           ++ split; [exact Hwf' | split; [exact Hhead' | split; [exact Htid' | exact Hce']]].
        -- (* CCompute *)
           unfold annotated_of in Hce_cur, Hnd_rem; cbn in Hce_cur, Hnd_rem;
             rewrite plug_stack_compute in Hce_cur, Hnd_rem; cbn [label_paths operations map] in Hce_cur, Hnd_rem.
           inversion Hnd_rem as [|? ? Hni_tail _]; subst.
           inversion Hce_cur; subst; [contradiction |].
           match goal with
           | Hev : execution_values _ _ _ _ ?p_v ?args_v ?u1,
             Hce_n : command_events layout model _ (label_paths _ _ (plug_stack n stk)) ?evs_n ?u2 |- _ =>
               rename Hev into Hev_r; rename Hce_n into Hce_next; rename p_v into p_v0;
               set (args_v0 := args_v); set (u1_0 := u1); set (u2_0 := u2); set (evs_n0 := evs_n)
           end.
           destruct Hrk_in_j as [Hrk_eq | [Hrk_end_bad | Htail]].
           2: { exfalso; rewrite <- Hrk_end_bad in Hrk_start;
                eapply strict_end_not_start; [exact Hval | right; right; right; right; eexists; reflexivity | exact Hrk_start]. }
           2: { exfalso; eapply tail_events_ne_head; [exact Hni_tail | exact Hce_next | exact Htail | exact Ho_eq]. }
           assert (Hinc_u1 : incl u1_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now left).
           assert (Hinc_u2 : incl u2_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now right).
           assert (Hres : resolve_exec_rel (mem_done_val (ms_mem st)) rho (Pos.of_succ_nat j, path) vs (queue d) p_v0 args_v0 u1_0)
             by (eapply execution_values_to_resolve; [exact HAval | exact (ri_trace Hri) | exact (mi_done_val Hmia) | exact Htk | exact Hrk_start_at | exact Hinc_u1 | exact Hev_r]).
           assert (Htgt_c : declared_resource cfg (resource d) /\ match p_v0 with Some q => declared_pipeline cfg q | None => True end)
             by (rewrite <- Hrk_eq in Htgt_k; exact Htgt_k).
           destruct Htgt_c as [Hdecl_r Hdecl_p].
           assert (Hpr : pipe_ready cfg Pe (sync_active_wait (ms_sync st)) p_v0).
           { destruct p_v0 as [q0|]; [apply Hpipe_ready_helper; [exact Hdecl_p | rewrite <- Hrk_eq; reflexivity] | exact I]. }
           set (cur_next := ThreadCursor (Pos.of_succ_nat j) (xO path) (bind rho x (Async o0)) n stk).
           assert (Hwf_next : cursor_wf cur_next) by (split; assumption).
           destruct (command_events_refocus Hwf_next Hce_next) as [b_step [cur' [Href [Hhead' [Hwf' [Htid' Hce']]]]]].
           set (budget := Nat.max budget1 b_step).
           set (sync' := SyncState ((o0, PCompute (Dispatch (resource d) p_v0) args_v0) :: sync_inflight (ms_sync st))
                                   (sync_flags (ms_sync st)) (sync_active_wait (ms_sync st))).
           set (st' := MachineState (update_nth j (TRunning cur') (ms_threads st)) sync' (ms_mem st)
                         (rk :: ms_rev_trace st) (rev_append u1_0 (ms_rev_uses st))).
           assert (Hstep : auto_step layout cfg model Pe Ee budget st rk st').
           { unfold st'; rewrite <- Hrk_eq. eapply StepComputeStart; [exact Hts_j | reflexivity | exact Hres | exact Hdecl_r | exact Hpr | (eapply refocus_mono; [| exact Href]; unfold budget; lia)]. }
           exists budget, st0, st', (update_nth j (evs_n0, u2_0) rem_list).
           split; [unfold budget; lia | split; [eapply init_machine_mono; [| exact Hinit1]; unfold budget; lia
                         | split; [eapply auto_steps_snoc; [eapply auto_steps_mono; [| exact Hsteps1]; unfold budget; lia | exact Hstep] |]]].
           eapply update_replay_inv_issue;
             [exact Hval | exact Hri | congruence | exact Hrem_j | exact Hfirstn_S | | exact Hinc_u2 |].
           ++ intros r [<- | [<- | Hr]] Hsr;
                [left; exact Hrk_eq
                | exfalso; eapply strict_end_not_start; [exact Hval | right; right; right; right; eexists; reflexivity | exact Hsr]
                | right; exact Hr].
           ++ split; [exact Hwf' | split; [exact Hhead' | split; [exact Htid' | exact Hce']]].
        -- (* Read *)
           unfold annotated_of in Hce_cur, Hnd_rem; cbn in Hce_cur, Hnd_rem;
             rewrite plug_stack_read in Hce_cur, Hnd_rem; cbn [label_paths operations map] in Hce_cur, Hnd_rem.
           inversion Hnd_rem as [|? ? Hni_tail _]; subst.
           inversion Hce_cur; subst; [contradiction |].
           match goal with
           | Hev : execution_values _ _ _ _ ?p_v [VMemory ?a_v] ?u1,
             Hce_n : command_events layout model _ (label_paths _ _ (plug_stack n stk)) ?evs_n ?u2 |- _ =>
               rename Hev into Hev_r; rename Hce_n into Hce_next; rename p_v into p_v0;
               set (a_v0 := a_v); set (u1_0 := u1); set (u2_0 := u2); set (evs_n0 := evs_n)
           end.
           destruct Hrk_in_j as [Hrk_eq | [Hrk_end_bad | Htail]].
           2: { exfalso; rewrite <- Hrk_end_bad in Hrk_start;
                eapply strict_end_not_start; [exact Hval | right; right; right; left; eexists; reflexivity | exact Hrk_start]. }
           2: { exfalso; eapply tail_events_ne_head; [exact Hni_tail | exact Hce_next | exact Htail | exact Ho_eq]. }
           assert (Hinc_u1 : incl u1_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now left).
           assert (Hinc_u2 : incl u2_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now right).
           assert (Hres : resolve_exec_rel (mem_done_val (ms_mem st)) rho (Pos.of_succ_nat j, path) [v] (queue d) p_v0 [VMemory a_v0] u1_0)
             by (eapply execution_values_to_resolve; [exact HAval | exact (ri_trace Hri) | exact (mi_done_val Hmia) | exact Htk | exact Hrk_start_at | exact Hinc_u1 | exact Hev_r]).
           assert (Htgt_r : (declared_resource cfg (resource d) /\ match p_v0 with Some q => declared_pipeline cfg q | None => True end) /\ can_read cfg (resource d) a_v0)
             by (rewrite <- Hrk_eq in Htgt_k; exact Htgt_k).
           destruct Htgt_r as [[Hdecl_r Hdecl_p] Hcan_r].
           assert (Hpr : pipe_ready cfg Pe (sync_active_wait (ms_sync st)) p_v0).
           { destruct p_v0 as [q0|]; [apply Hpipe_ready_helper; [exact Hdecl_p | rewrite <- Hrk_eq; reflexivity] | exact I]. }
           set (cur_next := ThreadCursor (Pos.of_succ_nat j) (xO path) (bind rho x (Async o0)) n stk).
           assert (Hwf_next : cursor_wf cur_next) by (split; assumption).
           destruct (command_events_refocus Hwf_next Hce_next) as [b_step [cur' [Href [Hhead' [Hwf' [Htid' Hce']]]]]].
           set (budget := Nat.max budget1 b_step).
           set (sync' := SyncState ((o0, PRead (Dispatch (resource d) p_v0) a_v0) :: sync_inflight (ms_sync st))
                                   (sync_flags (ms_sync st)) (sync_active_wait (ms_sync st))).
           set (st' := MachineState (update_nth j (TRunning cur') (ms_threads st)) sync' (ms_mem st)
                         (rk :: ms_rev_trace st) (rev_append u1_0 (ms_rev_uses st))).
           assert (Hstep : auto_step layout cfg model Pe Ee budget st rk st').
           { unfold st'; rewrite <- Hrk_eq. eapply StepReadStart; [exact Hts_j | reflexivity | exact Hres | exact Hdecl_r | exact Hcan_r | exact Hpr | (eapply refocus_mono; [| exact Href]; unfold budget; lia)]. }
           exists budget, st0, st', (update_nth j (evs_n0, u2_0) rem_list).
           split; [unfold budget; lia | split; [eapply init_machine_mono; [| exact Hinit1]; unfold budget; lia
                         | split; [eapply auto_steps_snoc; [eapply auto_steps_mono; [| exact Hsteps1]; unfold budget; lia | exact Hstep] |]]].
           eapply update_replay_inv_issue;
             [exact Hval | exact Hri | congruence | exact Hrem_j | exact Hfirstn_S | | exact Hinc_u2 |].
           ++ intros r [<- | [<- | Hr]] Hsr;
                [left; exact Hrk_eq
                | exfalso; eapply strict_end_not_start; [exact Hval | right; right; right; left; eexists; reflexivity | exact Hsr]
                | right; exact Hr].
           ++ split; [exact Hwf' | split; [exact Hhead' | split; [exact Htid' | exact Hce']]].
        -- (* Write *)
           unfold annotated_of in Hce_cur, Hnd_rem; cbn in Hce_cur, Hnd_rem;
             rewrite plug_stack_write in Hce_cur, Hnd_rem; cbn [label_paths operations map] in Hce_cur, Hnd_rem.
           inversion Hnd_rem as [|? ? Hni_tail _]; subst.
           inversion Hce_cur; subst; [contradiction |].
           match goal with
           | Hev : execution_values _ _ _ _ ?p_v [VMemory ?addr_v; ?data_v] ?u1,
             Hce_n : command_events layout model _ (label_paths _ _ (plug_stack n stk)) ?evs_n ?u2 |- _ =>
               rename Hev into Hev_r; rename Hce_n into Hce_next; rename p_v into p_v0;
               set (addr_v0 := addr_v); set (data_v0 := data_v); set (u1_0 := u1); set (u2_0 := u2); set (evs_n0 := evs_n)
           end.
           destruct Hrk_in_j as [Hrk_eq | [Hrk_end_bad | Htail]].
           2: { exfalso; rewrite <- Hrk_end_bad in Hrk_start;
                eapply strict_end_not_start; [exact Hval | left; reflexivity | exact Hrk_start]. }
           2: { exfalso; eapply tail_events_ne_head; [exact Hni_tail | exact Hce_next | exact Htail | exact Ho_eq]. }
           assert (Hinc_u1 : incl u1_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now left).
           assert (Hinc_u2 : incl u2_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now right).
           assert (Hres : resolve_exec_rel (mem_done_val (ms_mem st)) rho (Pos.of_succ_nat j, path) [v1; v2] (queue d) p_v0 [VMemory addr_v0; data_v0] u1_0)
             by (eapply execution_values_to_resolve; [exact HAval | exact (ri_trace Hri) | exact (mi_done_val Hmia) | exact Htk | exact Hrk_start_at | exact Hinc_u1 | exact Hev_r]).
           assert (Htgt_w : (declared_resource cfg (resource d) /\ match p_v0 with Some q => declared_pipeline cfg q | None => True end) /\ can_write cfg (resource d) addr_v0)
             by (rewrite <- Hrk_eq in Htgt_k; exact Htgt_k).
           destruct Htgt_w as [[Hdecl_r Hdecl_p] Hcan_w].
           assert (Hpr : pipe_ready cfg Pe (sync_active_wait (ms_sync st)) p_v0).
           { destruct p_v0 as [q0|]; [apply Hpipe_ready_helper; [exact Hdecl_p | rewrite <- Hrk_eq; reflexivity] | exact I]. }
           set (cur_next := ThreadCursor (Pos.of_succ_nat j) (xO path) rho n stk).
           assert (Hwf_next : cursor_wf cur_next) by (split; assumption).
           destruct (command_events_refocus Hwf_next Hce_next) as [b_step [cur' [Href [Hhead' [Hwf' [Htid' Hce']]]]]].
           set (budget := Nat.max budget1 b_step).
           set (sync' := SyncState ((o0, PWrite (Dispatch (resource d) p_v0) addr_v0 data_v0) :: sync_inflight (ms_sync st))
                                   (sync_flags (ms_sync st)) (sync_active_wait (ms_sync st))).
           set (st' := MachineState (update_nth j (TRunning cur') (ms_threads st)) sync' (ms_mem st)
                         (rk :: ms_rev_trace st) (rev_append u1_0 (ms_rev_uses st))).
           assert (Hstep : auto_step layout cfg model Pe Ee budget st rk st').
           { unfold st'; rewrite <- Hrk_eq. eapply StepWriteStart; [exact Hts_j | reflexivity | exact Hres | exact Hdecl_r | exact Hcan_w | exact Hpr | (eapply refocus_mono; [| exact Href]; unfold budget; lia)]. }
           exists budget, st0, st', (update_nth j (evs_n0, u2_0) rem_list).
           split; [unfold budget; lia | split; [eapply init_machine_mono; [| exact Hinit1]; unfold budget; lia
                         | split; [eapply auto_steps_snoc; [eapply auto_steps_mono; [| exact Hsteps1]; unfold budget; lia | exact Hstep] |]]].
           eapply update_replay_inv_issue;
             [exact Hval | exact Hri | congruence | exact Hrem_j | exact Hfirstn_S | | exact Hinc_u2 |].
           ++ intros r [<- | [<- | Hr]] Hsr;
                [left; exact Hrk_eq
                | exfalso; eapply strict_end_not_start; [exact Hval | left; reflexivity | exact Hsr]
                | right; exact Hr].
           ++ split; [exact Hwf' | split; [exact Hhead' | split; [exact Htid' | exact Hce']]].
        -- (* SetFlag *)
           unfold annotated_of in Hce_cur, Hnd_rem; cbn in Hce_cur, Hnd_rem;
             rewrite plug_stack_setflag in Hce_cur, Hnd_rem; cbn [label_paths operations map] in Hce_cur, Hnd_rem.
           inversion Hnd_rem as [|? ? Hni_tail _]; subst.
           inversion Hce_cur; subst; [contradiction |].
           match goal with
           | Hops : operand_values _ _ _ _ [VPipe ?p_v; VPipe ?q_v; VEvent ?fl_v] ?u1,
             Hce_n : command_events layout model _ (label_paths _ _ (plug_stack n stk)) ?evs_n ?u2 |- _ =>
               rename Hops into Hops_r; rename Hce_n into Hce_next;
               set (p_v0 := p_v); set (q_v0 := q_v); set (fl_v0 := fl_v); set (u1_0 := u1); set (u2_0 := u2); set (evs_n0 := evs_n)
           end.
           destruct Hrk_in_j as [Hrk_eq | [Hrk_end_bad | Htail]].
           2: { exfalso; rewrite <- Hrk_end_bad in Hrk_start;
                eapply strict_end_not_start; [exact Hval | right; left; reflexivity | exact Hrk_start]. }
           2: { exfalso; eapply tail_events_ne_head; [exact Hni_tail | exact Hce_next | exact Htail | exact Ho_eq]. }
           assert (Hinc_u1 : incl u1_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now left).
           assert (Hinc_u2 : incl u2_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now right).
           assert (Hres : resolve_operands_rel (mem_done_val (ms_mem st)) rho (Pos.of_succ_nat j, path) 0 [src; dst; v] [VPipe p_v0; VPipe q_v0; VEvent fl_v0] u1_0)
             by (eapply operand_values_to_resolve; [exact HAval | exact (ri_trace Hri) | exact (mi_done_val Hmia) | exact Htk | exact Hrk_start_at | exact Hinc_u1 | exact Hops_r]).
           assert (Htgt_sf : declared_pipeline cfg p_v0 /\ declared_pipeline cfg q_v0)
             by (rewrite <- Hrk_eq in Htgt_k; exact Htgt_k).
           destruct Htgt_sf as [Hdecl_p Hdecl_q].
           assert (Hpr : pipe_ready cfg Pe (sync_active_wait (ms_sync st)) (Some p_v0))
             by (apply Hpipe_ready_helper; [exact Hdecl_p | rewrite <- Hrk_eq; reflexivity]).
           set (cur_next := ThreadCursor (Pos.of_succ_nat j) (xO path) rho n stk).
           assert (Hwf_next : cursor_wf cur_next) by (split; assumption).
           destruct (command_events_refocus Hwf_next Hce_next) as [b_step [cur' [Href [Hhead' [Hwf' [Htid' Hce']]]]]].
           set (budget := Nat.max budget1 b_step).
           set (deps := inflight_on_pipe (eqb Pe) p_v0 (sync_inflight (ms_sync st))).
           set (sync' := SyncState ((o0, PSetFlag p_v0 q_v0 fl_v0 deps) :: sync_inflight (ms_sync st))
                                   (sync_flags (ms_sync st)) (sync_active_wait (ms_sync st))).
           set (st' := MachineState (update_nth j (TRunning cur') (ms_threads st)) sync' (ms_mem st)
                         (rk :: ms_rev_trace st) (rev_append u1_0 (ms_rev_uses st))).
           assert (Hstep : auto_step layout cfg model Pe Ee budget st rk st').
           { unfold st'; rewrite <- Hrk_eq. eapply StepSetFlagStart; [exact Hts_j | reflexivity | exact Hres | exact Hdecl_p | exact Hdecl_q | exact Hpr | (eapply refocus_mono; [| exact Href]; unfold budget; lia)]. }
           exists budget, st0, st', (update_nth j (evs_n0, u2_0) rem_list).
           split; [unfold budget; lia | split; [eapply init_machine_mono; [| exact Hinit1]; unfold budget; lia
                         | split; [eapply auto_steps_snoc; [eapply auto_steps_mono; [| exact Hsteps1]; unfold budget; lia | exact Hstep] |]]].
           eapply update_replay_inv_issue;
             [exact Hval | exact Hri | congruence | exact Hrem_j | exact Hfirstn_S | | exact Hinc_u2 |].
           ++ intros r [<- | [<- | Hr]] Hsr;
                [left; exact Hrk_eq
                | exfalso; eapply strict_end_not_start; [exact Hval | right; left; reflexivity | exact Hsr]
                | right; exact Hr].
           ++ split; [exact Hwf' | split; [exact Hhead' | split; [exact Htid' | exact Hce']]].
        -- (* WaitFlag *)
           unfold annotated_of in Hce_cur, Hnd_rem; cbn in Hce_cur, Hnd_rem;
             rewrite plug_stack_waitflag in Hce_cur, Hnd_rem; cbn [label_paths operations map] in Hce_cur, Hnd_rem.
           inversion Hnd_rem as [|? ? Hni_tail _]; subst.
           inversion Hce_cur; subst; [contradiction |].
           match goal with
           | Hops : operand_values _ _ _ _ [VPipe ?p_v; VPipe ?q_v; VEvent ?fl_v] ?u1,
             Hce_n : command_events layout model _ (label_paths _ _ (plug_stack n stk)) ?evs_n ?u2 |- _ =>
               rename Hops into Hops_r; rename Hce_n into Hce_next;
               set (p_v0 := p_v); set (q_v0 := q_v); set (fl_v0 := fl_v); set (u1_0 := u1); set (u2_0 := u2); set (evs_n0 := evs_n)
           end.
           destruct Hrk_in_j as [Hrk_eq | [Hrk_end_bad | Htail]].
           2: { exfalso; rewrite <- Hrk_end_bad in Hrk_start;
                eapply strict_end_not_start; [exact Hval | right; right; left; reflexivity | exact Hrk_start]. }
           2: { exfalso; eapply tail_events_ne_head; [exact Hni_tail | exact Hce_next | exact Htail | exact Ho_eq]. }
           assert (Hinc_u1 : incl u1_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now left).
           assert (Hinc_u2 : incl u2_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now right).
           assert (Hres : resolve_operands_rel (mem_done_val (ms_mem st)) rho (Pos.of_succ_nat j, path) 0 [src; dst; v] [VPipe p_v0; VPipe q_v0; VEvent fl_v0] u1_0)
             by (eapply operand_values_to_resolve; [exact HAval | exact (ri_trace Hri) | exact (mi_done_val Hmia) | exact Htk | exact Hrk_start_at | exact Hinc_u1 | exact Hops_r]).
           assert (Htgt_wf : declared_pipeline cfg p_v0 /\ declared_pipeline cfg q_v0)
             by (rewrite <- Hrk_eq in Htgt_k; exact Htgt_k).
           destruct Htgt_wf as [Hdecl_p Hdecl_q].
           assert (Hpr : pipe_ready cfg Pe (sync_active_wait (ms_sync st)) (Some q_v0))
             by (apply Hpipe_ready_helper; [exact Hdecl_q | rewrite <- Hrk_eq; reflexivity]).
           set (cur_next := ThreadCursor (Pos.of_succ_nat j) (xO path) rho n stk).
           assert (Hwf_next : cursor_wf cur_next) by (split; assumption).
           destruct (command_events_refocus Hwf_next Hce_next) as [b_step [cur' [Href [Hhead' [Hwf' [Htid' Hce']]]]]].
           set (budget := Nat.max budget1 b_step).
           set (sync' := SyncState ((o0, PWaitFlag p_v0 q_v0 fl_v0 j) :: sync_inflight (ms_sync st))
                                   (sync_flags (ms_sync st)) (active_wait_set q_v0 o0 (sync_active_wait (ms_sync st)))).
           set (st' := MachineState (update_nth j (TWaitingFlag o0 cur') (ms_threads st)) sync' (ms_mem st)
                         (rk :: ms_rev_trace st) (rev_append u1_0 (ms_rev_uses st))).
           assert (Hstep : auto_step layout cfg model Pe Ee budget st rk st').
           { unfold st'; rewrite <- Hrk_eq. eapply StepWaitFlagStart; [exact Hts_j | reflexivity | exact Hres | exact Hdecl_p | exact Hdecl_q | exact Hpr | (eapply refocus_mono; [| exact Href]; unfold budget; lia)]. }
           exists budget, st0, st', (update_nth j (evs_n0, u2_0) rem_list).
           split; [unfold budget; lia | split; [eapply init_machine_mono; [| exact Hinit1]; unfold budget; lia
                         | split; [eapply auto_steps_snoc; [eapply auto_steps_mono; [| exact Hsteps1]; unfold budget; lia | exact Hstep] |]]].
           eapply update_replay_inv_issue;
             [exact Hval | exact Hri | congruence | exact Hrem_j | exact Hfirstn_S | | exact Hinc_u2 |].
           ++ intros r [<- | [<- | Hr]] Hsr;
                [left; exact Hrk_eq
                | exfalso; eapply strict_end_not_start; [exact Hval | right; right; left; reflexivity | exact Hsr]
                | right; exact Hr].
           ++ split; [exact Hwf' | split; [exact Hhead' | split; [exact Htid' | exact Hce']]].
        -- (* If *)
           unfold annotated_of in Hce_cur, Hnd_rem; cbn in Hce_cur, Hnd_rem;
             rewrite plug_stack_if in Hce_cur, Hnd_rem; cbn [label_paths operations map] in Hce_cur, Hnd_rem.
           inversion Hnd_rem as [|? ? Hni_tail _]; subst.
           rewrite map_app in Hni_tail.
           inversion Hce_cur; subst; [contradiction |].
           match goal with
           | Hop : operand_value _ _ _ _ (VBool ?b_v) ?u1,
             Hce_n : command_events layout model _ (if ?b_v then _ else _) ?evs_n ?u2 |- _ =>
               rename Hop into Hop_r; rename Hce_n into Hce_next_raw; rename b_v into b_v0;
               set (u1_0 := u1); set (u2_0 := u2); set (evs_n0 := evs_n)
           end.
           destruct Hrk_in_j as [Hrk_eq | Htail].
           2: { exfalso.
                assert (Hni_b : ~ In o0 (op_ids (if b_v0 then label_paths (pair (Pos.of_succ_nat j)) (xO path) (plug_stack y stk)
                                                 else label_paths (pair (Pos.of_succ_nat j)) (xI path) (plug_stack n stk))))
                  by (intros Hin_b; apply Hni_tail, in_app_iff; destruct b_v0; [left | right]; exact Hin_b).
                eapply tail_events_ne_head; [exact Hni_b | exact Hce_next_raw | exact Htail | exact Ho_eq]. }
           assert (Hinc_u1 : incl u1_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now left).
           assert (Hinc_u2 : incl u2_0 uses) by (intros z Hz; apply Hinc_uses_j, in_app_iff; now right).
           assert (Hres : resolve_operand_rel (mem_done_val (ms_mem st)) rho (Pos.of_succ_nat j, path) 0 cond (VBool b_v0) u1_0)
             by (eapply operand_value_to_resolve; [exact HAval | exact (ri_trace Hri) | exact (mi_done_val Hmia) | exact Htk | exact Hrk_start_at | exact Hinc_u1 | exact Hop_r]).
           set (cur_next := ThreadCursor (Pos.of_succ_nat j) (if b_v0 then xO path else xI path) rho (if b_v0 then y else n) stk).
           destruct Hec_cmd as [Hec_y Hec_n].
           assert (Hwf_next : cursor_wf cur_next) by (split; [destruct b_v0; assumption | exact Hsw_stk]).
           assert (Hce_next : command_events layout model (cursor_env cur_next) (annotated_of cur_next) evs_n0 u2_0)
             by (unfold annotated_of, cur_next; cbn; destruct b_v0; exact Hce_next_raw).
           destruct (command_events_refocus Hwf_next Hce_next) as [b_step [cur' [Href [Hhead' [Hwf' [Htid' Hce']]]]]].
           set (budget := Nat.max budget1 b_step).
           set (st' := MachineState (update_nth j (TRunning cur') (ms_threads st)) (ms_sync st) (ms_mem st)
                         (rk :: ms_rev_trace st) (rev_append u1_0 (ms_rev_uses st))).
           assert (Hstep : auto_step layout cfg model Pe Ee budget st rk st').
           { unfold st'; rewrite <- Hrk_eq. eapply StepIf; [exact Hts_j | reflexivity | exact Hres | (eapply refocus_mono; [| exact Href]; unfold budget; lia)]. }
           exists budget, st0, st', (update_nth j (evs_n0, u2_0) rem_list).
           split; [unfold budget; lia | split; [eapply init_machine_mono; [| exact Hinit1]; unfold budget; lia
                         | split; [eapply auto_steps_snoc; [eapply auto_steps_mono; [| exact Hsteps1]; unfold budget; lia | exact Hstep] |]]].
           eapply update_replay_inv_issue;
             [exact Hval | exact Hri | congruence | exact Hrem_j | exact Hfirstn_S | | exact Hinc_u2 |].
           ++ intros r [<- | Hr] _; [left; exact Hrk_eq | right; exact Hr].
           ++ split; [exact Hwf' | split; [exact Hhead' | split; [exact Htid' | exact Hce']]].
      * (* ts_j = TWaitingFlag w_wait cur -> 与 A2 矛盾！ *)
        exfalso.
        destruct Hbr_j as [_ [_ [_ Hce_cur]]].
        pose proof (command_events_owners Hce_cur Hrk_in_j) as Ho_cur.
        assert (Hpo_j : In (w_wait, owner rk) (program_order ann_j))
          by (eapply eai_wait_po; [exact Heai | exact Hann_j | exact Hts_j | exact Ho_cur]).
        assert (Hpo_ann : In (w_wait, owner rk) (po ann))
          by (eapply branch_po_in_program; [exact Hann_j | exact Hpo_j]).
        destruct Hrk_start as [hk [Hhk Hkk]].
        assert (Hst_k : starts ann t kappa (owner rk) ek)
          by (split; [exact Hek_in | split; [reflexivity | exists hk; split; assumption]]).
        destruct (proj2 (HA2 w_wait (owner rk) Hpo_ann) ek Hst_k)
          as [ew [[Hew_t [How [hw [Hhw Hkw]]]] [iw [ik [Hiw [Hik Hlt]]]]]].
        pose proof (proj1 (NoDup_nth_error t) Hnd_t k ik ltac:(apply nth_error_Some; congruence) (eq_trans Htk (eq_sym Hik))) as Eik.
        subst ik.
        destruct (eai_thread_wait_inflight Heai j Hts_j) as [pw [qw [flw Hinf_w]]].
        destruct (mi_inflight_spec Hmia w_wait (PWaitFlag pw qw flw j) Hinf_w) as [Hops_w [_ [Hne_w _]]]. cbn [pk_head] in Hops_w.
        pose proof (ops_unique_head ann Hnd_all Hhw Hops_w) as ->.
        cbn [gate_kind nonblocking] in Hkw.
        apply Hne_w. exists (kappa ew). repeat split.
        -- rewrite (ri_trace Hri). eapply nth_error_firstn_in; [exact Hlt | rewrite nth_error_map, Hiw; reflexivity].
        -- exact How.
        -- exists HWaitFlag; rewrite How; split; [exact Hops_w | exact Hkw].
      * (* ts_j = TDone res_done -> rem_evs_j = [] 矛盾！ *)
        destruct Hbr_j as [Hnil _]; subst rem_evs_j; inversion Hrk_in_j.
Qed.

(* 顶层定理 1：公理化 Trace 语义到在线状态自动机的完备性（无额外确定性假设） *)
Theorem automaton_complete (t : list EventId) (kappa : Kappa) :
  well_formed cfg raw ->
  program_semantics layout cfg model ann t kappa ->
  exists budget st0 st,
    (1 <= budget)%nat /\
    init_machine budget raw = Ok st0 /\
    auto_steps layout cfg model Pe Ee budget st0 st /\
    rev (ms_rev_trace st) = map kappa t.
Proof.
  intros Hwf [_ [_ [(uses & (events & ordered & Hpe & Hnd & Hperm & Hpref) & Hsync & Hval & Hmem) Htgt]]].
  destruct (replay_prefix_complete_main Hwf Hpe Hnd (ex_intro _ ordered (conj Hperm Hpref))
              Hsync Hval Hmem Htgt (Nat.le_refl _))
    as [budget [st0 [st [rem_list [Hb [Hinit [Hsteps Hri]]]]]]].
  exists budget, st0, st; repeat split; try assumption.
  rewrite (ri_trace Hri), firstn_all2 by (rewrite length_map; lia). reflexivity.
Qed.

(* 顶层定理 2：公理化语义与在线前缀自动机的精确双向等价（Soundness + Completeness） *)
Theorem automaton_iff_program_semantics (ti : trace_indexer EventId) (records : list Rec) :
  well_formed cfg raw ->
  (exists budget st0 st,
     init_machine budget raw = Ok st0 /\
     auto_steps layout cfg model Pe Ee budget st0 st /\
     rev (ms_rev_trace st) = records)
  <->
  program_semantics layout cfg model ann
    (trace_of_records ti records) (kappa_of_records ti records).
Proof.
  intros Hwf. split.
  - intros [budget [st0 [st [Hinit [Hsteps Hrec]]]]].
    pose proof (auto_steps_preserves_inv Hsteps (init_machine_inv layout cfg model Pe Ee raw budget Hinit)) as Hinv.
    destruct (machine_inv_implies_trace_semantics ti Hinv) as [Hts Htgt].
    pose proof (annotate_program_valid raw) as [Herase Hvalid].
    rewrite Hrec in Hts, Htgt.
    split; [exists raw; split; [exact Hwf | exact Herase] |].
    split; [exact Hvalid | split; [exact Hts | exact Htgt]].
  - intros Hsem.
    destruct (automaton_complete Hwf Hsem) as [budget [st0 [st [_ [Hinit [Hsteps Hrec]]]]]].
    exists budget, st0, st; repeat split; try assumption.
    rewrite Hrec. apply map_kappa_trace.
Qed.

End AutomatonCompleteness.

(* ========================================================================== *)
(* 5. 可执行脚本重放完备性（run_derived_interpreter & run_free_interpreter）    *)
(* ========================================================================== *)

Section ExecutableReplayCompleteness.
Context {Float EventId Pipe Unit : Type}.
Context (layout : allocation_layout).
Context (tgt : @executable_target Float EventId Pipe Unit).
Context (model : @computation_model Float EventId Pipe Unit).
Context (emodel : executable_model model).

Local Notation Val := (@value Float EventId Pipe).
Local Notation RawCmd := (@command Float EventId Pipe Unit unit).
Local Notation Rec := (@event_record Float EventId Pipe Unit).
Local Notation Use := (@use_record Float EventId Pipe).
Local Notation MState := (@machine_state Float EventId Pipe Unit).
Local Notation Kappa := (@interpretation Float EventId Pipe Unit).

(* 目标判定器与计算模型的完备性假设（用于把关系型 auto_step 逐一编译为脚本动作） *)
Record target_complete : Prop := {
  tc_pipe : forall p, declared_pipeline (exec_cfg tgt) p -> check_declared_pipe tgt p = true;
  tc_resource : forall r, declared_resource (exec_cfg tgt) r -> check_declared_resource tgt r = true;
  tc_read : forall r a, can_read (exec_cfg tgt) r a -> check_can_read tgt r a = true;
  tc_write : forall r a, can_write (exec_cfg tgt) r a -> check_can_write tgt r a = true
}.

Definition model_complete : Prop :=
  forall r args res, comp model r args res -> exec_comp emodel r args = Some res.

(* 从目标轨迹构造早用异步结果 oracle：按 (consumer, operand_index, producer) 精确查表 *)
Fixpoint lookup_use_oracle (uses : list Use) (c : op_id) (idx : nat) (p : op_id) : option Val :=
  match uses with
  | [] => None
  | UseRecord c' idx' p' v :: rest =>
      if op_id_eqb c c' && Nat.eqb idx idx' && op_id_eqb p p' then Some v
      else lookup_use_oracle rest c idx p
  end.

Local Lemma lookup_use_oracle_hit (uses : list Use) (c p : op_id) (idx : nat) (v : Val) :
  In (UseRecord c idx p v) uses ->
  (forall v', In (UseRecord c idx p v') uses -> v' = v) ->
  lookup_use_oracle uses c idx p = Some v.
Proof.
  induction uses as [|[c' idx' p' v'] rest IH]; intros Hin Huniq; cbn in *; [inversion Hin |].
  destruct (op_id_eqb c c' && Nat.eqb idx idx' && op_id_eqb p p') eqn:E.
  - rewrite !andb_true_iff, !op_id_eqb_spec, Nat.eqb_eq in E.
    destruct E as [[<- <-] <-]. f_equal. apply Huniq; now left.
  - destruct Hin as [Heq | Hin].
    + inversion Heq; subst.
      exfalso. rewrite (proj2 (op_id_eqb_spec c c) eq_refl), (proj2 (op_id_eqb_spec p p) eq_refl), Nat.eqb_refl in E.
      discriminate E.
    + apply IH; [exact Hin | intros v'' Hv''; apply Huniq; now right].
Qed.

Local Lemma resolve_operand_rel_exec {all_uses : list Use} (init_mem : memory_resource -> option Val)
    dv rho o idx v a us :
  resolve_operand_rel dv rho o idx v a us ->
  incl us all_uses ->
  (forall c i p v1 v2, In (UseRecord c i p v1) all_uses -> In (UseRecord c i p v2) all_uses -> v1 = v2) ->
  exec_resolve_operand (ChoicePolicy (lookup_use_oracle all_uses) init_mem) dv rho o idx v = Ok (a, us).
Proof.
  intros Hrel Hinc Huniq.
  inversion Hrel; subst; unfold exec_resolve_operand; rewrite H; [reflexivity |].
  destruct (lookup_assoc op_id_eqb r dv) as [res|] eqn:Hlk.
  - rewrite (H0 res eq_refl). reflexivity.
  - cbn [pick_early_async].
    assert (Hin : In (UseRecord o idx r a) all_uses) by (apply Hinc; now left).
    rewrite (lookup_use_oracle_hit all_uses o r idx Hin (fun v' Hv' => Huniq o idx r v' a Hv' Hin)).
    reflexivity.
Qed.

Local Lemma resolve_operands_rel_exec {all_uses : list Use} (init_mem : memory_resource -> option Val)
    dv rho o idx vs args us :
  resolve_operands_rel dv rho o idx vs args us ->
  incl us all_uses ->
  (forall c i p v1 v2, In (UseRecord c i p v1) all_uses -> In (UseRecord c i p v2) all_uses -> v1 = v2) ->
  exec_resolve_operands (ChoicePolicy (lookup_use_oracle all_uses) init_mem) dv rho o idx vs = Ok (args, us).
Proof.
  intros Hrel; induction Hrel; intros Hinc Huniq; cbn; [reflexivity |].
  rewrite (resolve_operand_rel_exec init_mem H (fun z Hz => Hinc z (in_or_app _ _ _ (or_introl Hz))) Huniq).
  cbn [result_bind].
  rewrite (IHHrel (fun z Hz => Hinc z (in_or_app _ _ _ (or_intror Hz))) Huniq).
  reflexivity.
Qed.

Local Lemma resolve_exec_rel_exec {all_uses : list Use} (init_mem : memory_resource -> option Val)
    dv rho o vs q p args us :
  resolve_exec_rel dv rho o vs q p args us ->
  incl us all_uses ->
  (forall c i p0 v1 v2, In (UseRecord c i p0 v1) all_uses -> In (UseRecord c i p0 v2) all_uses -> v1 = v2) ->
  exec_resolve_exec (ChoicePolicy (lookup_use_oracle all_uses) init_mem) dv rho o vs q = Ok (p, args, us).
Proof.
  intros Hrel Hinc Huniq. inversion Hrel; subst; unfold exec_resolve_exec;
    rewrite (resolve_operands_rel_exec init_mem H Hinc Huniq); reflexivity.
Qed.

Local Lemma pipe_ready_check (Htc : target_complete) {aw} o {p} :
  pipe_ready (exec_cfg tgt) (pipe_eq tgt) aw p ->
  check_pipe_ready tgt aw o p = Ok tt.
Proof.
  destruct p as [q|]; cbn; [| reflexivity].
  intros [Hdecl Haw]. rewrite (tc_pipe Htc _ Hdecl), Haw; reflexivity.
Qed.

(* 辅助：单次 resolve_operands_rel 产生的 UseRecord 键 (consumer, operand_index) 互不相同且 consumer = o *)
Local Lemma resolve_operands_rel_keys dv rho o idx vs args us :
  resolve_operands_rel dv rho o idx vs args us ->
  (forall (u : Use), In u us -> consumer u = o /\ (idx <= operand_index u)%nat) /\
  (forall (u1 u2 : Use), In u1 us -> In u2 us -> operand_index u1 = operand_index u2 -> u1 = u2).
Proof.
  induction 1 as [i | i v vs a args u1 u2 H1 H2 [IH1 IH2]].
  - split; intros; contradiction.
  - assert (Hu1 : (forall (u : Use), In u u1 -> consumer u = o /\ operand_index u = i) /\
                  (forall (x y : Use), In x u1 -> In y u1 -> x = y)).
    { inversion H1; subst; split.
      - intros u [].
      - intros x y [].
      - intros u [<- | []]; cbn; auto.
      - intros x y [<- | []] [<- | []]; reflexivity. }
    destruct Hu1 as [Hu1_a Hu1_b].
    split.
    + intros u Hu. apply in_app_iff in Hu as [Hu | Hu].
      * destruct (Hu1_a u Hu) as [Hc Hi]; split; [exact Hc | lia].
      * destruct (IH1 u Hu) as [Hc Hi]; split; [exact Hc | lia].
    + intros x y Hx Hy Hei.
      apply in_app_iff in Hx as [Hx | Hx]; apply in_app_iff in Hy as [Hy | Hy].
      * exact (Hu1_b x y Hx Hy).
      * destruct (Hu1_a x Hx) as [_ Hix]; destruct (IH1 y Hy) as [_ Hiy]; lia.
      * destruct (IH1 x Hx) as [_ Hix]; destruct (Hu1_a y Hy) as [_ Hiy]; lia.
      * exact (IH2 x y Hx Hy Hei).
Qed.

Local Lemma resolve_exec_rel_keys dv rho o vs q p args us :
  resolve_exec_rel dv rho o vs q p args us ->
  (forall (u : Use), In u us -> consumer u = o) /\
  (forall (u1 u2 : Use), In u1 us -> In u2 us -> operand_index u1 = operand_index u2 -> u1 = u2).
Proof.
  intros H; inversion H; subst;
    destruct (resolve_operands_rel_keys H0) as [Ha Hb];
    (split; [intros u Hu; exact (proj1 (Ha u Hu)) | exact Hb]).
Qed.

(* 任何从 init_machine 经 auto_steps 可达的状态，其 ms_rev_uses 中相同的 (consumer, operand_index, producer) 必对应唯一的 used_value *)
Local Lemma auto_step_uses_unique raw budget st ev st' :
  machine_inv layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) raw st ->
  (forall c i p v1 v2, In (UseRecord c i p v1) (ms_rev_uses st) ->
                       In (UseRecord c i p v2) (ms_rev_uses st) -> v1 = v2) ->
  auto_step layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st ev st' ->
  forall c i p v1 v2, In (UseRecord c i p v1) (ms_rev_uses st') ->
                      In (UseRecord c i p v2) (ms_rev_uses st') -> v1 = v2.
Proof.
  intros [btraces Hmia] Huniq Hstep.
  assert (Hcombine : forall (o : op_id) (us : list Use),
    ~ In o (map owner (rev (ms_rev_trace st))) ->
    (forall u, In u us -> consumer u = o) ->
    (forall u1 u2, In u1 us -> In u2 us -> operand_index u1 = operand_index u2 -> u1 = u2) ->
    forall c i p v1 v2,
      In (UseRecord c i p v1) (rev_append us (ms_rev_uses st)) ->
      In (UseRecord c i p v2) (rev_append us (ms_rev_uses st)) -> v1 = v2).
  { intros o us Hfresh Hcons Hloc c i p v1 v2 H1 H2.
    apply in_rev_append in H1; apply in_rev_append in H2.
    destruct H1 as [H1 | H1]; destruct H2 as [H2 | H2].
    - pose proof (Hloc _ _ H1 H2 eq_refl) as E; inversion E; reflexivity.
    - exfalso. apply Hfresh. pose proof (Hcons _ H1) as Ec; cbn in Ec; subst c.
      destruct (mi_uses_started Hmia _ H2) as [r [Hr [Ho _]]]. cbn in Ho; rewrite <- Ho; apply in_map; exact Hr.
    - exfalso. apply Hfresh. pose proof (Hcons _ H2) as Ec; cbn in Ec; subst c.
      destruct (mi_uses_started Hmia _ H1) as [r [Hr [Ho _]]]. cbn in Ho; rewrite <- Ho; apply in_map; exact Hr.
    - eapply Huniq; eassumption. }
  assert (Hfresh_of : forall j cur tid path rho cmd stk,
    nth_error (ms_threads st) j = Some (TRunning cur) ->
    cur = ThreadCursor tid path rho cmd stk ->
    In (tid, path) (map fst (rem_ops (TRunning cur))) ->
    ~ In (tid, path) (map owner (rev (ms_rev_trace st)))).
  { intros j cur tid path rho cmd stk Hth -> Hin.
    assert (Hj : (j < length (annotate_program raw))%nat)
      by (rewrite <- (mi_len_threads Hmia); apply nth_error_Some; congruence).
    destruct (nth_error (annotate_program raw) j) as [ann_j|] eqn:Ha; [| apply nth_error_None in Ha; lia].
    destruct (nth_error btraces j) as [bt|] eqn:Hb;
      [| apply nth_error_None in Hb; rewrite (mi_len_btraces Hmia) in Hb; lia].
    exact (proj1 (bi_rem_fresh (mi_branches Hmia j Ha Hth Hb) _ Hin)). }
  inversion Hstep; subst; cbn [ms_rev_uses]; try exact Huniq.
  - (* StepAtomic *)
    destruct (resolve_operands_rel_keys H1) as [Ha Hb].
    eapply Hcombine; [| intros u Hu; exact (proj1 (Ha u Hu)) | exact Hb].
    eapply Hfresh_of; [exact H | exact H0 |]. cbn [rem_ops]; rewrite H0; unfold annotated_of; cbn; rewrite plug_stack_atomic; now left.
  - (* StepAssignPipe *)
    assert (H1' : resolve_operands_rel (mem_done_val (ms_mem st)) rho (tid, path) 0 [v] [VPipe p] uses)
      by (rewrite <- (app_nil_r uses); econstructor; [exact H1 | constructor]).
    destruct (resolve_operands_rel_keys H1') as [Ha Hb].
    eapply Hcombine; [| intros u Hu; exact (proj1 (Ha u Hu)) | exact Hb].
    eapply Hfresh_of; [exact H | exact H0 |]. cbn [rem_ops]; rewrite H0; unfold annotated_of; cbn; rewrite plug_stack_assign_pipe; now left.
  - (* StepReadStart *)
    destruct (resolve_exec_rel_keys H1) as [Ha Hb].
    eapply Hcombine; [| exact Ha | exact Hb].
    eapply Hfresh_of; [exact H | exact H0 |]. cbn [rem_ops]; rewrite H0; unfold annotated_of; cbn; rewrite plug_stack_read; now left.
  - (* StepWriteStart *)
    destruct (resolve_exec_rel_keys H1) as [Ha Hb].
    eapply Hcombine; [| exact Ha | exact Hb].
    eapply Hfresh_of; [exact H | exact H0 |]. cbn [rem_ops]; rewrite H0; unfold annotated_of; cbn; rewrite plug_stack_write; now left.
  - (* StepComputeStart *)
    destruct (resolve_exec_rel_keys H1) as [Ha Hb].
    eapply Hcombine; [| exact Ha | exact Hb].
    eapply Hfresh_of; [exact H | exact H0 |]. cbn [rem_ops]; rewrite H0; unfold annotated_of; cbn; rewrite plug_stack_compute; now left.
  - (* StepSetFlagStart *)
    destruct (resolve_operands_rel_keys H1) as [Ha Hb].
    eapply Hcombine; [| intros u Hu; exact (proj1 (Ha u Hu)) | exact Hb].
    eapply Hfresh_of; [exact H | exact H0 |]. cbn [rem_ops]; rewrite H0; unfold annotated_of; cbn; rewrite plug_stack_setflag; now left.
  - (* StepWaitFlagStart *)
    destruct (resolve_operands_rel_keys H1) as [Ha Hb].
    eapply Hcombine; [| intros u Hu; exact (proj1 (Ha u Hu)) | exact Hb].
    eapply Hfresh_of; [exact H | exact H0 |]. cbn [rem_ops]; rewrite H0; unfold annotated_of; cbn; rewrite plug_stack_waitflag; now left.
  - (* StepIf *)
    assert (H1' : resolve_operands_rel (mem_done_val (ms_mem st)) rho (tid, path) 0 [cond] [VBool b] uses)
      by (rewrite <- (app_nil_r uses); econstructor; [exact H1 | constructor]).
    destruct (resolve_operands_rel_keys H1') as [Ha Hb].
    eapply Hcombine; [| intros u Hu; exact (proj1 (Ha u Hu)) | exact Hb].
    eapply Hfresh_of; [exact H | exact H0 |]. cbn [rem_ops]; rewrite H0; unfold annotated_of; cbn; rewrite plug_stack_if; now left.
  - (* StepReturn *)
    destruct (resolve_operands_rel_keys H1) as [Ha Hb].
    eapply Hcombine; [| intros u Hu; exact (proj1 (Ha u Hu)) | exact Hb].
    eapply Hfresh_of; [exact H | exact H0 |]. cbn [rem_ops]; rewrite H0; unfold annotated_of; cbn; rewrite plug_stack_return; now left.
Qed.

Local Lemma auto_steps_uses_unique {raw budget st0 st} :
  machine_inv layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) raw st0 ->
  (forall c i p v1 v2, In (UseRecord c i p v1) (ms_rev_uses st0) ->
                       In (UseRecord c i p v2) (ms_rev_uses st0) -> v1 = v2) ->
  auto_steps layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st0 st ->
  forall c i p v1 v2, In (UseRecord c i p v1) (ms_rev_uses st) ->
                      In (UseRecord c i p v2) (ms_rev_uses st) -> v1 = v2.
Proof.
  intros Hmi Huniq Hsteps.
  induction Hsteps; [exact Huniq |].
  apply IHHsteps.
  - eapply auto_step_preserves_inv; eassumption.
  - eapply auto_step_uses_unique; eassumption.
Qed.

Local Lemma auto_step_uses_incl budget st ev st' :
  auto_step layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st ev st' ->
  incl (ms_rev_uses st) (ms_rev_uses st').
Proof.
  intros H; inversion H; subst; cbn [ms_rev_uses]; intros u Hu;
    try exact Hu; apply in_rev_append; now right.
Qed.

Local Lemma auto_steps_uses_incl budget st1 st2 :
  auto_steps layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st1 st2 ->
  incl (ms_rev_uses st1) (ms_rev_uses st2).
Proof.
  induction 1; [intros ? H; exact H |].
  intros u Hu; apply IHauto_steps; eapply auto_step_uses_incl; eassumption.
Qed.

(* 单步 auto_step 在完整目标、完整模型与兼容初始内存下，必由某个 schedule_action 精确重放。 *)
Local Lemma auto_step_to_action (Htc : target_complete) (Hmc : model_complete)
    (init_mem : memory_resource -> option Val) {all_uses : list Use} {budget st ev st'} :
  incl (ms_rev_uses st') all_uses ->
  (forall c i p v1 v2, In (UseRecord c i p v1) all_uses -> In (UseRecord c i p v2) all_uses -> v1 = v2) ->
  (forall o d a res,
     ev = EventRecord o (LReadEnd res) ->
     lookup_inflight o (ms_sync st) = Some (PRead d a) ->
     mem_lookup a (ms_mem st) = None ->
     init_mem a = Some res) ->
  auto_step layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st ev st' ->
  let cpol := ChoicePolicy (lookup_use_oracle all_uses) init_mem in
  exists act : schedule_action,
    match act with
    | ActIssue j => exec_issue_branch layout tgt cpol budget j st = Ok (ev, st')
    | ActFinish o => exec_finish_op tgt emodel cpol o st = Ok (ev, st')
    end.
Proof.
  intros Hinc_all Huniq_all Hinit_rd Hstep cpol. unfold cpol.
  inversion Hstep; subst; try unfold o in *.
  - (* StepAlloc *)
    exists (ActIssue j). unfold exec_issue_branch. rewrite H, H0; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    rewrite H2. unfold exec_advance; rewrite H3. reflexivity.
  - (* StepAtomic *)
    exists (ActIssue j). unfold exec_issue_branch. rewrite H, H0; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    assert (Hu : incl uses all_uses) by (intros z Hz; apply Hinc_all; cbn; apply in_rev_append; now left).
    rewrite (resolve_operands_rel_exec init_mem H1 Hu Huniq_all); cbn [result_bind].
    rewrite H2. unfold exec_advance; rewrite H3. reflexivity.
  - (* StepAssignPipe *)
    exists (ActIssue j). unfold exec_issue_branch. rewrite H, H0; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    assert (Hu : incl uses all_uses) by (intros z Hz; apply Hinc_all; cbn; apply in_rev_append; now left).
    rewrite (resolve_operand_rel_exec init_mem H1 Hu Huniq_all); cbn [result_bind].
    rewrite (tc_pipe Htc _ H2). unfold exec_advance; rewrite H3. reflexivity.
  - (* StepReadStart *)
    exists (ActIssue j). unfold exec_issue_branch. rewrite H, H0; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    assert (Hu : incl uses all_uses) by (intros z Hz; apply Hinc_all; cbn; apply in_rev_append; now left).
    rewrite (resolve_exec_rel_exec init_mem H1 Hu Huniq_all); cbn [result_bind].
    rewrite (tc_resource Htc _ H2), (tc_read Htc _ _ H3); cbn [andb].
    rewrite (pipe_ready_check Htc _ H4); cbn [result_bind].
    unfold exec_advance; rewrite H5. reflexivity.
  - (* StepWriteStart *)
    exists (ActIssue j). unfold exec_issue_branch. rewrite H, H0; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    assert (Hu : incl uses all_uses) by (intros z Hz; apply Hinc_all; cbn; apply in_rev_append; now left).
    rewrite (resolve_exec_rel_exec init_mem H1 Hu Huniq_all); cbn [result_bind].
    rewrite (tc_resource Htc _ H2), (tc_write Htc _ _ H3); cbn [andb].
    rewrite (pipe_ready_check Htc _ H4); cbn [result_bind].
    unfold exec_advance; rewrite H5. reflexivity.
  - (* StepComputeStart *)
    exists (ActIssue j). unfold exec_issue_branch. rewrite H, H0; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    assert (Hu : incl uses all_uses) by (intros z Hz; apply Hinc_all; cbn; apply in_rev_append; now left).
    rewrite (resolve_exec_rel_exec init_mem H1 Hu Huniq_all); cbn [result_bind].
    rewrite (tc_resource Htc _ H2).
    rewrite (pipe_ready_check Htc _ H3); cbn [result_bind].
    unfold exec_advance; rewrite H4. reflexivity.
  - (* StepSetFlagStart *)
    exists (ActIssue j). unfold exec_issue_branch. rewrite H, H0; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    assert (Hu : incl uses all_uses) by (intros z Hz; apply Hinc_all; cbn; apply in_rev_append; now left).
    rewrite (resolve_operands_rel_exec init_mem H1 Hu Huniq_all); cbn [result_bind].
    rewrite (tc_pipe Htc _ H2), (tc_pipe Htc _ H3); cbn [andb].
    rewrite (pipe_ready_check Htc _ H4); cbn [result_bind].
    unfold exec_advance; rewrite H5. reflexivity.
  - (* StepWaitFlagStart *)
    exists (ActIssue j). unfold exec_issue_branch. rewrite H, H0; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    assert (Hu : incl uses all_uses) by (intros z Hz; apply Hinc_all; cbn; apply in_rev_append; now left).
    rewrite (resolve_operands_rel_exec init_mem H1 Hu Huniq_all); cbn [result_bind].
    rewrite (tc_pipe Htc _ H2), (tc_pipe Htc _ H3); cbn [andb].
    rewrite (pipe_ready_check Htc _ H4); cbn [result_bind].
    unfold exec_advance; rewrite H5. reflexivity.
  - (* StepIf *)
    exists (ActIssue j). unfold exec_issue_branch. rewrite H, H0; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    assert (Hu : incl uses all_uses) by (intros z Hz; apply Hinc_all; cbn; apply in_rev_append; now left).
    rewrite (resolve_operand_rel_exec init_mem H1 Hu Huniq_all); cbn [result_bind].
    unfold exec_advance; rewrite H2. reflexivity.
  - (* StepReturn *)
    exists (ActIssue j). unfold exec_issue_branch. rewrite H, H0; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
    assert (Hu : incl uses all_uses) by (intros z Hz; apply Hinc_all; cbn; apply in_rev_append; now left).
    rewrite (resolve_operands_rel_exec init_mem H1 Hu Huniq_all); cbn [result_bind].
    reflexivity.
  - (* StepReadEnd *)
    exists (ActFinish o). unfold exec_finish_op. rewrite H.
    destruct (mem_lookup a (ms_mem st)) as [v0|] eqn:Hm.
    + rewrite <- (H0 v0 eq_refl). reflexivity.
    + cbn [pick_uninit_mem]. rewrite (Hinit_rd o d a res eq_refl H Hm). reflexivity.
  - (* StepWriteEnd *)
    exists (ActFinish o). unfold exec_finish_op. rewrite H. reflexivity.
  - (* StepComputeEnd *)
    exists (ActFinish o). unfold exec_finish_op. rewrite H.
    rewrite (Hmc _ _ _ H0). reflexivity.
  - (* StepSetFlagEnd *)
    exists (ActFinish f). unfold exec_finish_op. rewrite H, H0, H1. reflexivity.
  - (* StepWaitFlagEnd *)
    exists (ActFinish w). unfold exec_finish_op. rewrite H, H0, H1.
    rewrite (proj2 (op_id_eqb_spec _ _) eq_refl). reflexivity.
Qed.

(* 初始内存一致性条件：轨迹中每次对尚未被任何 WriteEnd 写入地址的 ReadEnd，其读值与 init_mem 一致 *)
Definition init_mem_consistent (init_mem : memory_resource -> option Val) (records : list Rec) : Prop :=
  forall pre o d a res,
    prefix (pre ++ [EventRecord o (LReadEnd res)]) records ->
    TraceSemantics.prior_start ReadStart o (rev pre) = Some (LReadStart d a) ->
    TraceSemantics.latest_write a (rev pre) = None ->
    init_mem a = Some res.

Local Lemma auto_step_trace_snoc budget st ev st' :
  auto_step layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st ev st' ->
  rev (ms_rev_trace st') = rev (ms_rev_trace st) ++ [ev].
Proof.
  intros H; inversion H; subst; reflexivity.
Qed.

Local Lemma auto_steps_trace_prefix budget st1 st2 :
  auto_steps layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st1 st2 ->
  prefix (rev (ms_rev_trace st1)) (rev (ms_rev_trace st2)).
Proof.
  induction 1 as [st | st1 ev st2 st3 Hstep Hrest [suff Hsuff]].
  - exists []; rewrite app_nil_r; reflexivity.
  - rewrite (auto_step_trace_snoc Hstep) in Hsuff.
    exists (ev :: suff). rewrite Hsuff, <- app_assoc; reflexivity.
Qed.

Local Lemma auto_steps_to_script (Htc : target_complete) (Hmc : model_complete)
    {raw : list RawCmd} {init_mem : memory_resource -> option Val} {all_uses : list Use}
    {budget st1 st2} :
  machine_inv layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) raw st1 ->
  incl (ms_rev_uses st2) all_uses ->
  (forall c i p v1 v2, In (UseRecord c i p v1) all_uses -> In (UseRecord c i p v2) all_uses -> v1 = v2) ->
  init_mem_consistent init_mem (rev (ms_rev_trace st2)) ->
  auto_steps layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) budget st1 st2 ->
  let cpol := ChoicePolicy (lookup_use_oracle all_uses) init_mem in
  exists script : list schedule_action,
    forall s0 : list schedule_action,
      run_derived_loop layout tgt emodel cpol (scripted_policy s0) (S (length script)) budget script st1 = Ok st2.
Proof.
  intros Hmi1 Hinc_end Huniq_all Hinit_cons Hsteps cpol.
  induction Hsteps as [st | st1 ev st2 st3 Hstep Hrest IH].
  - exists []. intros s0; reflexivity.
  - pose proof (auto_step_preserves_inv Hstep Hmi1) as Hmi2.
    destruct (IH Hmi2 Hinc_end Hinit_cons) as [script_rest Hloop_rest].
    assert (Hinc2 : incl (ms_rev_uses st2) all_uses).
    { intros u Hu. apply Hinc_end. eapply auto_steps_uses_incl; eassumption. }
    assert (Hrd : forall o d a res,
      ev = EventRecord o (LReadEnd res) ->
      lookup_inflight o (ms_sync st1) = Some (PRead d a) ->
      mem_lookup a (ms_mem st1) = None ->
      init_mem a = Some res).
    { intros o d a res -> Hlk Hm.
      destruct Hmi1 as [bt1 Hmia1].
      apply (lookup_assoc_in op_id_eq_ops) in Hlk.
      destruct (mi_inflight_spec Hmia1 o (PRead d a) Hlk) as [_ [_ [_ Hprior]]].
      rewrite (mi_mem_writes Hmia1) in Hm.
      pose proof (auto_steps_trace_prefix Hrest) as Hpref.
      rewrite (auto_step_trace_snoc Hstep) in Hpref.
      eapply Hinit_cons; [exact Hpref | |].
      - rewrite rev_involutive; exact Hprior.
      - rewrite rev_involutive; exact Hm. }
    destruct (auto_step_to_action Htc Hmc init_mem Hinc2 Huniq_all Hrd Hstep) as [act Hact].
    exists (act :: script_rest). intros s0.
    cbn [length run_derived_loop pol_next scripted_policy].
    fold cpol in Hact.
    destruct act as [j | o]; rewrite Hact; cbn [result_bind snd]; exact (Hloop_rest s0).
Qed.

(* 顶层定理 3：可执行一阶派生解释器的脚本重放完备性 *)
Theorem derived_interpreter_complete (prog : @shared_program Float EventId Pipe Unit)
    (t : list EventId) (kappa : Kappa) (init_mem : memory_resource -> option Val) :
  target_complete ->
  model_complete ->
  well_formed (exec_cfg tgt) (instantiate_shared layout 0 prog) ->
  program_semantics layout (exec_cfg tgt) model
    (annotate_program (instantiate_shared layout 0 prog)) t kappa ->
  init_mem_consistent init_mem (map kappa t) ->
  exists cpol script budget res,
    (1 <= budget)%nat /\
    run_derived_interpreter layout tgt emodel cpol (scripted_policy script)
      (S (length script)) budget prog = Ok res /\
    rr_events res = map kappa t.
Proof.
  intros Htc Hmc Hwf Hsem Hinit_cons.
  set (raw := instantiate_shared layout 0 prog).
  destruct (automaton_complete (pipe_eq tgt) (event_eq tgt) Hwf Hsem)
    as [budget [st0 [st [Hb [Hinit [Hsteps Hrec]]]]]].
  pose proof (init_machine_inv layout (exec_cfg tgt) model (pipe_eq tgt) (event_eq tgt) raw budget Hinit) as Hmi0.
  assert (Huniq0 : forall c i p v1 v2, In (UseRecord c i p v1) (ms_rev_uses st0) ->
                                       In (UseRecord c i p v2) (ms_rev_uses st0) -> v1 = v2).
  { unfold init_machine in Hinit. fold raw in Hinit.
    destruct (init_threads_aux budget 0 raw) as [ts|e]; cbn [result_bind] in Hinit; [| discriminate].
    inversion Hinit; subst st0; intros; contradiction. }
  pose proof (auto_steps_uses_unique Hmi0 Huniq0 Hsteps) as Huniq_end.
  assert (Hinit_cons' : init_mem_consistent init_mem (rev (ms_rev_trace st)))
    by (rewrite Hrec; exact Hinit_cons).
  destruct (auto_steps_to_script Htc Hmc Hmi0 (fun z Hz => Hz) Huniq_end Hinit_cons' Hsteps)
    as [script Hloop].
  set (cpol := ChoicePolicy (lookup_use_oracle (ms_rev_uses st)) init_mem).
  exists cpol, script, budget, (machine_state_to_result st).
  repeat split; [exact Hb | | cbn [rr_events machine_state_to_result]; exact Hrec].
  unfold run_derived_interpreter, run_derived_state.
  rewrite Hinit; cbn [result_bind].
  unfold scripted_policy at 2; cbn [pol_init].
  unfold cpol. rewrite (Hloop script); reflexivity.
Qed.

(* 顶层定理 4：高阶 Free Monad 解释器同样具备脚本重放完备性（由双向等价直接推出） *)
Corollary free_interpreter_complete (prog : @shared_program Float EventId Pipe Unit)
    (t : list EventId) (kappa : Kappa) (init_mem : memory_resource -> option Val) :
  target_complete ->
  model_complete ->
  well_formed (exec_cfg tgt) (instantiate_shared layout 0 prog) ->
  program_semantics layout (exec_cfg tgt) model
    (annotate_program (instantiate_shared layout 0 prog)) t kappa ->
  init_mem_consistent init_mem (map kappa t) ->
  exists cpol script budget res,
    (1 <= budget)%nat /\
    run_free_interpreter layout tgt emodel cpol (scripted_policy script)
      (S (length script)) (S (length script)) budget prog = Ok res /\
    rr_events res = map kappa t.
Proof.
  intros Htc Hmc Hwf Hsem Hinit_cons.
  destruct (derived_interpreter_complete prog Htc Hmc Hwf Hsem Hinit_cons)
    as [cpol [script [budget [res [Hb [Hrun Hrec]]]]]].
  exists cpol, script, budget, res; repeat split; [exact Hb | | exact Hrec].
  rewrite free_and_derived_equivalent; [exact Hrun | exact Hb | apply Nat.le_refl].
Qed.

End ExecutableReplayCompleteness.

From Stdlib Require Import List ZArith Bool Lia Sorting.Permutation.
From UnifiedInterpreter.Base Require Import Free Result.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics.
From UnifiedInterpreter.CoreLanguage.Derived Require Import Refocusing Automaton CoreEffects Handlers.
Import ListNotations.
Set Implicit Arguments.

(* ========================================================================== *)
(* 1. 轨迹索引器：将自动机输出的事件记录列表映射为 TraceSemantics 的 (t, kappa)  *)
(* ========================================================================== *)

Record trace_indexer (EventId : Type) : Type := TraceIndexer {
  idx_to_eid : nat -> EventId;
  eid_to_idx : EventId -> nat;
  eid_idx_cancel : forall n, eid_to_idx (idx_to_eid n) = n
}.

Definition nat_trace_indexer : trace_indexer nat :=
  TraceIndexer (fun n => n) (fun n => n) (fun _ => eq_refl).

Section TraceEncoding.
Context {Float EventId Pipe Unit : Type}.
Local Notation Rec := (@event_record Float EventId Pipe Unit).

Definition default_event_record : Rec :=
  EventRecord (1%positive, 1%positive) (LReturn []).

Definition trace_of_records (ti : trace_indexer EventId) (records : list Rec) : list EventId :=
  map (idx_to_eid ti) (seq 0 (length records)).

Definition kappa_of_records (ti : trace_indexer EventId) (records : list Rec) (e : EventId) : Rec :=
  nth (eid_to_idx ti e) records default_event_record.

Lemma idx_to_eid_inj (ti : trace_indexer EventId) n1 n2 :
  idx_to_eid ti n1 = idx_to_eid ti n2 -> n1 = n2.
Proof.
  intros H. apply (f_equal (eid_to_idx ti)) in H. rewrite !eid_idx_cancel in H. exact H.
Qed.

Lemma nth_error_seq start len i :
  (i < len)%nat -> nth_error (seq start len) i = Some (start + i)%nat.
Proof.
  revert start i. induction len as [|len IH]; intros start [|i] Hlt; cbn in *; try lia.
  - f_equal; lia.
  - rewrite IH by lia. f_equal; lia.
Qed.

Lemma nth_error_trace_some (ti : trace_indexer EventId) records i e :
  nth_error (trace_of_records ti records) i = Some e <->
  (i < length records)%nat /\ e = idx_to_eid ti i.
Proof.
  unfold trace_of_records. rewrite nth_error_map. split.
  - intros H. destruct (nth_error (seq 0 (length records)) i) as [k|] eqn:Hs; [| discriminate].
    assert (Hi : (i < length records)%nat).
    { rewrite <- (length_seq (length records) 0). apply nth_error_Some. congruence. }
    rewrite nth_error_seq in Hs by exact Hi. inversion Hs; subst k.
    inversion H; subst. split; [exact Hi | reflexivity].
  - intros [Hi ->]. rewrite nth_error_seq by exact Hi. reflexivity.
Qed.

Lemma in_trace_iff (ti : trace_indexer EventId) records e :
  In e (trace_of_records ti records) <->
  exists i, (i < length records)%nat /\ e = idx_to_eid ti i.
Proof.
  split.
  - intros H. apply In_nth_error in H as [i Hi].
    apply nth_error_trace_some in Hi. exists i; exact Hi.
  - intros [i Hi]. eapply nth_error_In. apply nth_error_trace_some; exact Hi.
Qed.

Lemma kappa_of_idx (ti : trace_indexer EventId) records i r :
  nth_error records i = Some r ->
  kappa_of_records ti records (idx_to_eid ti i) = r.
Proof.
  intros H. unfold kappa_of_records. rewrite eid_idx_cancel.
  apply nth_error_nth; exact H.
Qed.

Lemma map_kappa_trace (ti : trace_indexer EventId) records :
  map (kappa_of_records ti records) (trace_of_records ti records) = records.
Proof.
  apply nth_error_ext. intros i.
  rewrite nth_error_map.
  destruct (nth_error (trace_of_records ti records) i) as [e|] eqn:Ht.
  - apply nth_error_trace_some in Ht as [Hi ->].
    destruct (nth_error records i) as [r|] eqn:Hr.
    + cbn. f_equal. eapply kappa_of_idx; exact Hr.
    + apply nth_error_None in Hr. lia.
  - apply nth_error_None in Ht. unfold trace_of_records in Ht.
    rewrite length_map, length_seq in Ht.
    symmetry. apply nth_error_None. exact Ht.
Qed.

Lemma earlier_trace_iff (ti : trace_indexer EventId) records i j :
  (i < length records)%nat ->
  (j < length records)%nat ->
  (earlier (trace_of_records ti records) (idx_to_eid ti i) (idx_to_eid ti j) <-> (i < j)%nat).
Proof.
  intros Hi Hj. unfold earlier. split.
  - intros [i' [j' [H1 [H2 Hlt]]]].
    apply nth_error_trace_some in H1 as [_ E1].
    apply nth_error_trace_some in H2 as [_ E2].
    apply idx_to_eid_inj in E1; apply idx_to_eid_inj in E2. lia.
  - intros Hlt. exists i, j. rewrite !nth_error_trace_some. repeat split; auto.
Qed.

End TraceEncoding.

(* ========================================================================== *)
(* 2. 通用列表、排列、投影、星号闭包与 memory_history 增量引理                  *)
(* ========================================================================== *)

Section AuxLemmas.

Lemma nth_error_app_snoc {A} (xs : list A) (x : A) i y :
  nth_error (xs ++ [x]) i = Some y <->
  (nth_error xs i = Some y /\ (i < length xs)%nat) \/
  (i = length xs /\ y = x).
Proof.
  split.
  - intros H. destruct (Nat.lt_ge_cases i (length xs)) as [Hlt | Hge].
    + left. rewrite nth_error_app1 in H by exact Hlt. split; assumption.
    + right. rewrite nth_error_app2 in H by exact Hge.
      destruct (i - length xs)%nat as [|[|k]] eqn:E; cbn in H; try discriminate.
      inversion H; subst. split; [lia | reflexivity].
  - intros [[H Hlt] | [-> ->]].
    + rewrite nth_error_app1 by exact Hlt. exact H.
    + rewrite nth_error_app2 by lia. replace (length xs - length xs)%nat with 0%nat by lia. reflexivity.
Qed.

Lemma in_rev_append {A} (l1 l2 : list A) x :
  In x (rev_append l1 l2) <-> In x l1 \/ In x l2.
Proof.
  rewrite rev_append_rev, in_app_iff, <- in_rev. reflexivity.
Qed.

Lemma star_snoc {A} (L : list A -> Prop) w b :
  star L w -> L b -> star L (w ++ b).
Proof.
  intros Hw Hb. induction Hw as [|u rest Hu Hrest IH].
  - cbn. rewrite <- (app_nil_r b). eapply StarCons; [exact Hb | constructor].
  - rewrite <- app_assoc. eapply StarCons; [exact Hu | exact IH].
Qed.

Lemma projection_snoc_keep {A B} (sel : A -> B -> Prop) xs x word l :
  projection sel xs word ->
  sel x l ->
  projection sel (xs ++ [x]) (word ++ [l]).
Proof.
  intros H Hs. induction H; cbn.
  - apply ProjectKeep; [exact Hs | constructor].
  - apply ProjectKeep; assumption.
  - apply ProjectSkip; assumption.
Qed.

Lemma projection_snoc_skip {A B} (sel : A -> B -> Prop) xs x word :
  projection sel xs word ->
  (~ exists l, sel x l) ->
  projection sel (xs ++ [x]) word.
Proof.
  intros H Hns. induction H; cbn.
  - apply ProjectSkip; [exact Hns | constructor].
  - apply ProjectKeep; assumption.
  - apply ProjectSkip; assumption.
Qed.

Lemma projection_ext {A B} (sel1 sel2 : A -> B -> Prop) xs word :
  (forall x l, In x xs -> (sel1 x l <-> sel2 x l)) ->
  projection sel1 xs word ->
  projection sel2 xs word.
Proof.
  intros Hext H. induction H.
  - constructor.
  - apply ProjectKeep.
    + apply (Hext e letter); [now left | assumption].
    + apply IHprojection. intros x l Hx. apply Hext; now right.
  - apply ProjectSkip.
    + intros [l Hl]. apply H. exists l. apply (Hext e l); [now left | exact Hl].
    + apply IHprojection. intros x l Hx. apply Hext; now right.
Qed.

Lemma projection_map_iff {A A' B} (f : A -> A') (sel : A -> B -> Prop) (sel' : A' -> B -> Prop) xs word :
  (forall x l, In x xs -> (sel x l <-> sel' (f x) l)) ->
  projection sel' (map f xs) word ->
  projection sel xs word.
Proof.
  revert word. induction xs as [|x xs IH]; intros word Hext Hp; cbn in Hp.
  - inversion Hp; constructor.
  - inversion Hp; subst.
    + apply ProjectKeep.
      * apply (Hext x letter); [now left | assumption].
      * apply IH; [intros y l Hy; apply Hext; now right | assumption].
    + apply ProjectSkip.
      * intros [l Hl]. apply H1. exists l. apply (Hext x l); [now left | exact Hl].
      * apply IH; [intros y l Hy; apply Hext; now right | assumption].
Qed.

Lemma remove_assoc_not_in {K V} (D : eq_dec_ops K) k (xs : list (K * V)) :
  ~ In k (map fst xs) ->
  remove_assoc (eqb D) k xs = xs.
Proof.
  induction xs as [|[k' v] xs IH]; intros Hni; cbn in *; [reflexivity |].
  destruct (eqb D k k') eqn:E.
  - apply (proj1 (eqb_spec D _ _)) in E; subst. exfalso; apply Hni; now left.
  - f_equal. apply IH. intro Hin; apply Hni; now right.
Qed.

Lemma remove_assoc_perm {K V} (D : eq_dec_ops K) k v (xs : list (K * V)) :
  NoDup (map fst xs) ->
  In (k, v) xs ->
  Permutation xs ((k, v) :: remove_assoc (eqb D) k xs).
Proof.
  induction xs as [|[k' v'] xs IH]; intros Hnd Hin; [inversion Hin |].
  cbn in Hnd. inversion Hnd as [|? ? Hni Hnd']; subst.
  destruct Hin as [Heq | Hin].
  - inversion Heq; subst k' v'. cbn. rewrite eqb_refl.
    rewrite remove_assoc_not_in by exact Hni. apply Permutation_refl.
  - cbn. destruct (eqb D k k') eqn:E.
    + apply (proj1 (eqb_spec D _ _)) in E; subst k'.
      exfalso. apply Hni. change k with (fst (k, v)). apply in_map; exact Hin.
    + eapply perm_trans; [apply perm_skip; apply IH; assumption | apply perm_swap].
Qed.

Lemma NoDup_remove_assoc {K V} (D : eq_dec_ops K) k (xs : list (K * V)) :
  NoDup (map fst xs) ->
  NoDup (map fst (remove_assoc (eqb D) k xs)).
Proof.
  induction xs as [|[k' v'] xs IH]; intros Hnd; cbn in *; [constructor |].
  inversion Hnd as [|? ? Hni Hnd']; subst.
  destruct (eqb D k k') eqn:E; [apply IH; exact Hnd' |].
  cbn; constructor; [| apply IH; exact Hnd'].
  intros Hin. apply Hni. clear -Hin.
  induction xs as [|[k0 v0] xs IH]; cbn in *; [exact Hin |].
  destruct (eqb D k k0); [right; auto |].
  cbn in Hin; destruct Hin as [-> | Hin]; [left; reflexivity | right; auto].
Qed.

Lemma in_remove_assoc_iff {K V} (D : eq_dec_ops K) k p (xs : list (K * V)) :
  In p (remove_assoc (eqb D) k xs) <-> In p xs /\ fst p <> k.
Proof.
  induction xs as [|[k' v'] xs IH]; cbn; [tauto |].
  destruct (eqb D k k') eqn:E.
  - apply (proj1 (eqb_spec D _ _)) in E; subst k'.
    rewrite IH. split; [intros [Hin Hneq]; split; [right; exact Hin | exact Hneq] |].
    intros [[Heq | Hin] Hneq]; [subst p; cbn in Hneq; contradiction | split; assumption].
  - apply (proj1 (eqb_neq D _ _)) in E. cbn. rewrite IH.
    split.
    + intros [<- | [Hin Hneq]]; [split; [left; reflexivity | cbn; congruence] | split; [right; exact Hin | exact Hneq]].
    + intros [[-> | Hin] Hneq]; [left; reflexivity | right; split; assumption].
Qed.

Lemma lookup_assoc_in_nodup {K V} (D : eq_dec_ops K) k v (xs : list (K * V)) :
  NoDup (map fst xs) ->
  (lookup_assoc (eqb D) k xs = Some v <-> In (k, v) xs).
Proof.
  intros Hnd; split; [apply lookup_assoc_in |].
  induction xs as [|[k' v'] xs IH]; intros Hin; [inversion Hin |].
  cbn in Hnd. inversion Hnd as [|? ? Hni Hnd']; subst.
  cbn. destruct (eqb D k k') eqn:E.
  - apply (proj1 (eqb_spec D _ _)) in E; subst k'.
    destruct Hin as [Heq | Hin]; [inversion Heq; reflexivity |].
    exfalso. apply Hni. change k with (fst (k, v)). apply in_map; exact Hin.
  - destruct Hin as [Heq | Hin].
    + inversion Heq; subst. rewrite eqb_refl in E. discriminate.
    + apply IH; assumption.
Qed.

Lemma lookup_assoc_none_iff {K V} (D : eq_dec_ops K) k (xs : list (K * V)) :
  lookup_assoc (eqb D) k xs = None <-> ~ In k (map fst xs).
Proof.
  induction xs as [|[k' v'] xs IH]; cbn; [tauto |].
  destruct (eqb D k k') eqn:E.
  - apply (proj1 (eqb_spec D _ _)) in E; subst k'. split; [discriminate | intros H; exfalso; apply H; now left].
  - apply (proj1 (eqb_neq D _ _)) in E. rewrite IH.
    split; [intros Hni [-> | Hin]; [contradiction | auto] | intros Hni Hin; apply Hni; now right].
Qed.

Lemma concat_map_update_nth_app_perm {A B} (f : A -> list B) j (x old : A) (extra : list B) (xs : list A) :
  nth_error xs j = Some old ->
  Permutation (f x) (f old ++ extra) ->
  Permutation (concat (map f (update_nth j x xs))) (concat (map f xs) ++ extra).
Proof.
  revert j. induction xs as [|a xs IH]; intros [|j] Hnth Hfx; cbn in Hnth; try discriminate.
  - inversion Hnth; subst old. cbn.
    eapply perm_trans; [apply Permutation_app_tail; exact Hfx |].
    rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
  - cbn. rewrite <- app_assoc. apply Permutation_app_head. apply IH; assumption.
Qed.

Lemma in_concat_update_nth_list_iff {A B} (f : A -> list B) j (x old : A) (extra : list B) (xs : list A) :
  nth_error xs j = Some old ->
  (forall z, In z (f x) <-> In z (f old) \/ In z extra) ->
  forall z, In z (concat (map f (update_nth j x xs))) <-> In z (concat (map f xs)) \/ In z extra.
Proof.
  revert j. induction xs as [|a xs IH]; intros [|j] Hnth Hfx z; cbn in Hnth; try discriminate.
  - inversion Hnth; subst old. cbn. rewrite !in_app_iff, Hfx. tauto.
  - cbn. rewrite !in_app_iff, (IH j Hnth Hfx z). tauto.
Qed.

End AuxLemmas.

(* ========================================================================== *)
(* 3. memory_history 增量引理（直接对接 TraceSemantics.memory_history）        *)
(* ========================================================================== *)

Section MemoryHistoryLemmas.
Context {Float EventId Pipe Unit : Type}.
Local Notation Rec := (@event_record Float EventId Pipe Unit).

Definition memory_step_ok (past : list Rec) (e : Rec) : Prop :=
  match payload e with
  | LReadEnd result =>
      match TraceSemantics.prior_start ReadStart (owner e) past with
      | Some (LReadStart _ address) =>
          match TraceSemantics.latest_write address past with
          | Some data => data = result
          | None => True
          end
      | _ => False
      end
  | LWriteEnd =>
      match TraceSemantics.prior_start WriteStart (owner e) past with
      | Some (LWriteStart _ _ _) => True
      | _ => False
      end
  | LAlloc address => TraceSemantics.latest_write address past = None
  | _ => True
  end.

Lemma memory_history_snoc past events e :
  TraceSemantics.memory_history past (events ++ [e]) <->
  TraceSemantics.memory_history past events /\ memory_step_ok (rev events ++ past) e.
Proof.
  revert past. induction events as [|x xs IH]; intros past; cbn [app rev TraceSemantics.memory_history].
  - unfold memory_step_ok; tauto.
  - rewrite IH, <- app_assoc. cbn [app]. tauto.
Qed.

Lemma prior_start_cons_other phase o (e : Rec) (past : list Rec) :
  (owner e <> o \/
   match phase, kind (payload e) with
   | ReadStart, ReadStart | WriteStart, WriteStart => False
   | _, _ => True
   end) ->
  TraceSemantics.prior_start phase o (e :: past) =
  TraceSemantics.prior_start phase o past.
Proof.
  intros H. unfold TraceSemantics.prior_start; cbn [find].
  destruct (TraceSemantics.operation_eq_dec (owner e) o) as [Heq | Hneq].
  - destruct H as [Hneq | Hk]; [contradiction |].
    destruct phase, (kind (payload e)); try contradiction; reflexivity.
  - reflexivity.
Qed.

Lemma prior_start_cons_read o d a (past : list Rec) :
  TraceSemantics.prior_start ReadStart o (EventRecord o (LReadStart d a) :: past) =
  Some (LReadStart d a).
Proof.
  unfold TraceSemantics.prior_start; cbn [find owner payload kind].
  destruct (TraceSemantics.operation_eq_dec o o); [reflexivity | contradiction].
Qed.

Lemma prior_start_cons_write o d a data (past : list Rec) :
  TraceSemantics.prior_start WriteStart o (EventRecord o (LWriteStart d a data) :: past) =
  Some (LWriteStart d a data).
Proof.
  unfold TraceSemantics.prior_start; cbn [find owner payload kind].
  destruct (TraceSemantics.operation_eq_dec o o); [reflexivity | contradiction].
Qed.

Lemma latest_write_cons_non_write_end addr (e : Rec) (past : list Rec) :
  payload e <> LWriteEnd ->
  TraceSemantics.latest_write addr (e :: past) = TraceSemantics.latest_write addr past.
Proof.
  intros H. cbn [TraceSemantics.latest_write].
  destruct (payload e); try reflexivity; contradiction.
Qed.

Lemma latest_write_cons_write_end addr o d a data (past : list Rec) :
  TraceSemantics.prior_start WriteStart o past = Some (LWriteStart d a data) ->
  TraceSemantics.latest_write addr (EventRecord o LWriteEnd :: past) =
  if Nat.eqb addr a then Some data else TraceSemantics.latest_write addr past.
Proof.
  intros Hp. cbn [TraceSemantics.latest_write owner payload].
  rewrite Hp, Nat.eqb_sym. reflexivity.
Qed.

End MemoryHistoryLemmas.

(* ========================================================================== *)
(* 4. 自动机不变式 machine_inv 与操作位置/程序顺序辅助引理                       *)
(* ========================================================================== *)

Section SoundnessProof.
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

(* 单分支已发起操作的历史项，用于参数化地重构 command_events 与多集合排列 *)
Inductive branch_step : Type :=
| BSAlloc (o : op_id) (addr : memory_resource)
| BSAtomic (o : op_id) (f : atomic_op) (args : list Val) (res : Val)
| BSAssignPipe (o : op_id) (x : var) (p : Pipe)
| BSRead (o : op_id) (d : execution Unit Pipe) (addr : memory_resource)
| BSWrite (o : op_id) (d : execution Unit Pipe) (addr : memory_resource) (data : Val)
| BSCompute (o : op_id) (d : execution Unit Pipe) (args : list Val)
| BSSetFlag (o : op_id) (p q : Pipe) (fl : EventId)
| BSWaitFlag (o : op_id) (p q : Pipe) (fl : EventId)
| BSIf (o : op_id) (b : bool)
| BSReturn (o : op_id) (args : list Val).

Definition step_events (end_of : op_id -> Val) (s : branch_step) : list Rec :=
  match s with
  | BSAlloc o a => [EventRecord o (LAlloc a)]
  | BSAtomic o f args res => [EventRecord o (LAtomic f args res)]
  | BSAssignPipe o x p => [EventRecord o (LPipeAssignment x p)]
  | BSRead o d a => [EventRecord o (LReadStart d a); EventRecord o (LReadEnd (end_of o))]
  | BSWrite o d a data => [EventRecord o (LWriteStart d a data); EventRecord o LWriteEnd]
  | BSCompute o d args => [EventRecord o (LComputeStart d args); EventRecord o (LComputeEnd (end_of o))]
  | BSSetFlag o p q fl => [EventRecord o (LSetFlagStart p q fl); EventRecord o LSetFlagEnd]
  | BSWaitFlag o p q fl => [EventRecord o (LWaitFlagStart p q fl); EventRecord o LWaitFlagEnd]
  | BSIf o b => [EventRecord o (LBranch b)]
  | BSReturn o args => [EventRecord o (LReturn args)]
  end.

Definition step_comp_ok (end_of : op_id -> Val) (s : branch_step) : Prop :=
  match s with
  | BSCompute o d args => comp model (resource d) args (end_of o)
  | _ => True
  end.

Definition pending_end_event (end_of : op_id -> Val) (entry : op_id * PKind) : Rec :=
  let '(o, pk) := entry in
  match pk with
  | PRead _ _ => EventRecord o (LReadEnd (end_of o))
  | PWrite _ _ _ => EventRecord o LWriteEnd
  | PCompute _ _ => EventRecord o (LComputeEnd (end_of o))
  | PSetFlag _ _ _ _ => EventRecord o LSetFlagEnd
  | PWaitFlag _ _ _ _ => EventRecord o LWaitFlagEnd
  end.

Definition pk_head (pk : PKind) : head :=
  match pk with
  | PRead _ _ => HRead
  | PWrite _ _ _ => HWrite
  | PCompute _ _ => HCompute
  | PSetFlag _ _ _ _ => HSetFlag
  | PWaitFlag _ _ _ _ => HWaitFlag
  end.

Definition pk_start_rec (o : op_id) (pk : PKind) : Rec :=
  match pk with
  | PRead d a => EventRecord o (LReadStart d a)
  | PWrite d a data => EventRecord o (LWriteStart d a data)
  | PCompute d args => EventRecord o (LComputeStart d args)
  | PSetFlag p q fl _ => EventRecord o (LSetFlagStart p q fl)
  | PWaitFlag p q fl _ => EventRecord o (LWaitFlagStart p q fl)
  end.

Record branch_trace : Type := BranchTrace {
  bt_steps : list branch_step;
  bt_uses : list Use
}.

Definition rem_ops (ts : TState) : list (op_id * head) :=
  match ts with
  | TRunning cur | TWaitingFlag _ cur => operations (annotated_of cur)
  | TDone _ => []
  end.

Definition rem_po (ts : TState) : list (op_id * op_id) :=
  match ts with
  | TRunning cur | TWaitingFlag _ cur => program_order (annotated_of cur)
  | TDone _ => []
  end.

(* 记录级别的事件分类与存在性谓词 *)
Definition rec_is_phase (ann : list AnnCmd) (phase : head -> event_kind) (r : Rec) : Prop :=
  exists h, In (owner r, h) (program_operations ann) /\ kind (payload r) = phase h.

Definition rec_is_start ann := rec_is_phase ann start_kind.
Definition rec_is_end ann := rec_is_phase ann end_kind.
Definition rec_is_gate ann := rec_is_phase ann gate_kind.

Definition rec_has_phase (ann : list AnnCmd) (phase : head -> event_kind) (records : list Rec) (o : op_id) : Prop :=
  exists r, In r records /\ owner r = o /\ rec_is_phase ann phase r.

Definition rec_has_start ann := rec_has_phase ann start_kind.
Definition rec_has_end ann := rec_has_phase ann end_kind.
Definition rec_has_gate ann := rec_has_phase ann gate_kind.

Definition rec_result_event (o : op_id) (r : Rec) (res : Val) : Prop :=
  r = EventRecord o (LReadEnd res) \/ r = EventRecord o (LComputeEnd res).

Definition rec_flag_letter (p q : Pipe) (fl : EventId) (records : list Rec) (r : Rec) (l : flag_letter) : Prop :=
  match l with
  | FlagSet =>
      payload r = LSetFlagEnd /\ In (EventRecord (owner r) (LSetFlagStart p q fl)) records
  | FlagWait =>
      payload r = LWaitFlagEnd /\ In (EventRecord (owner r) (LWaitFlagStart p q fl)) records
  end.

Definition valid_end_of (records : list Rec) (inflight : list (op_id * PKind))
    (end_of : op_id -> Val) : Prop :=
  (forall o res, In (EventRecord o (LReadEnd res)) records -> end_of o = res) /\
  (forall o res, In (EventRecord o (LComputeEnd res)) records -> end_of o = res) /\
  (forall o d args, In (o, PCompute d args) inflight -> comp model (resource d) args (end_of o)).

(* --- 针对操作数求值关系与 Events.v 的直接桥接 --- *)

Lemma resolve_operand_rel_to_events dv rho o idx v a (uses : list Use) :
  resolve_operand_rel dv rho o idx v a uses ->
  operand_value rho o idx v a uses /\
  forall u, In u uses ->
    consumer u = o /\
    (forall res, lookup_assoc op_id_eqb (producer u) dv = Some res -> used_value u = res).
Proof.
  intros H; inversion H; subst.
  - split; [apply UseKnown; assumption | intros u []].
  - split; [apply UseAsync; assumption | intros u [<- | []]; cbn; auto].
Qed.

Lemma resolve_operands_rel_to_events dv rho o idx vs args (uses : list Use) :
  resolve_operands_rel dv rho o idx vs args uses ->
  operand_values rho o idx vs args uses /\
  forall u, In u uses ->
    consumer u = o /\
    (forall res, lookup_assoc op_id_eqb (producer u) dv = Some res -> used_value u = res).
Proof.
  induction 1 as [i | i v vs a args u1 u2 H1 H2 [IHev IHuse]].
  - split; [constructor | intros u []].
  - apply resolve_operand_rel_to_events in H1 as [H1ev H1use].
    split; [econstructor; eassumption |].
    intros u Hin. apply in_app_iff in Hin as [Hin | Hin]; auto.
Qed.

Lemma resolve_exec_rel_to_events dv rho o vs q p args (uses : list Use) :
  resolve_exec_rel dv rho o vs q p args uses ->
  execution_values rho o vs q p args uses /\
  forall u, In u uses ->
    consumer u = o /\
    (forall res, lookup_assoc op_id_eqb (producer u) dv = Some res -> used_value u = res).
Proof.
  intros H; inversion H; subst;
    apply resolve_operands_rel_to_events in H0 as [Hev Huse];
    split; [constructor; exact Hev | exact Huse | constructor; exact Hev | exact Huse].
Qed.

(* --- 关于 operations 与 program_order 的基础性质 --- *)

Lemma program_order_in_op_ids (c : AnnCmd) o u :
  In (o, u) (program_order c) ->
  In o (op_ids c) /\ In u (op_ids c).
Proof.
  induction c; cbn [program_order op_ids operations]; intros H; cbn [In] in H; try contradiction;
    try exact (IHc H);
    rewrite ?map_app, ?in_app_iff, ?in_map_iff in H.
  - destruct H as [[w [Heq Hw]] | Hpo]; [inversion Heq; subst; split; [now left | now right] |].
    apply IHc in Hpo as [Ho Hu]; split; now right.
  - destruct H as [[w [Heq Hw]] | Hpo]; [inversion Heq; subst; split; [now left | now right] |].
    apply IHc in Hpo as [Ho Hu]; split; now right.
  - destruct H as [[w [Heq Hw]] | Hpo]; [inversion Heq; subst; split; [now left | now right] |].
    apply IHc in Hpo as [Ho Hu]; split; now right.
  - destruct H as [[w [Heq Hw]] | Hpo]; [inversion Heq; subst; split; [now left | now right] |].
    apply IHc in Hpo as [Ho Hu]; split; now right.
  - destruct H as [[w [Heq Hw]] | Hpo]; [inversion Heq; subst; split; [now left | now right] |].
    apply IHc in Hpo as [Ho Hu]; split; now right.
  - destruct H as [[w [Heq Hw]] | Hpo]; [inversion Heq; subst; split; [now left | now right] |].
    apply IHc in Hpo as [Ho Hu]; split; now right.
  - destruct H as [[w [Heq Hw]] | Hpo]; [inversion Heq; subst; split; [now left | now right] |].
    apply IHc in Hpo as [Ho Hu]; split; now right.
  - destruct H as [[w [Heq Hw]] | Hpo]; [inversion Heq; subst; split; [now left | now right] |].
    apply IHc in Hpo as [Ho Hu]; split; now right.
  - destruct H as [[[w [Heq Hw]] | [w [Heq Hw]]] | [Hpo1 | Hpo2]].
    + inversion Heq; subst. split; [left; reflexivity | right; rewrite map_app, in_app_iff; left; exact Hw].
    + inversion Heq; subst. split; [left; reflexivity | right; rewrite map_app, in_app_iff; right; exact Hw].
    + apply IHc1 in Hpo1 as [Ho Hu]. split; right; rewrite map_app, in_app_iff; left; assumption.
    + apply IHc2 in Hpo2 as [Ho Hu]. split; right; rewrite map_app, in_app_iff; right; assumption.
Qed.

Lemma NoDup_app_disjoint {A} (l1 l2 : list A) :
  NoDup (l1 ++ l2) ->
  NoDup l1 /\ NoDup l2 /\ forall x, In x l1 -> ~ In x l2.
Proof.
  induction l1 as [|a l1 IH]; cbn; intros Hnd.
  - repeat split; [constructor | exact Hnd | tauto].
  - inversion Hnd as [|? ? Hni Hnd']; subst.
    apply IH in Hnd' as [H1 [H2 Hdisj]].
    rewrite in_app_iff in Hni.
    repeat split.
    + constructor; [intro; apply Hni; now left | exact H1].
    + exact H2.
    + intros x [<- | Hx] Hx2; [apply Hni; now right | eapply Hdisj; eassumption].
Qed.

Lemma ops_unique_head (ann : list AnnCmd) o h1 h2 :
  NoDup (map fst (program_operations ann)) ->
  In (o, h1) (program_operations ann) ->
  In (o, h2) (program_operations ann) ->
  h1 = h2.
Proof.
  intros Hnd H1 H2.
  generalize dependent (program_operations ann).
  intros ops Hnd H1 H2.
  induction ops as [|[o' h'] ops IH]; [inversion H1 |].
  cbn in Hnd. inversion Hnd as [|? ? Hni Hnd']; subst.
  destruct H1 as [E1 | H1]; destruct H2 as [E2 | H2].
  - inversion E1; inversion E2; congruence.
  - inversion E1; subst o' h'. exfalso. apply Hni.
    change o with (fst (o, h2)). apply in_map; exact H2.
  - inversion E2; subst o' h'. exfalso. apply Hni.
    change o with (fst (o, h1)). apply in_map; exact H1.
  - apply IH; assumption.
Qed.
Arguments ops_unique_head _ {o h1 h2} _ _ _.

Lemma branch_ops_in_program (ann : list AnnCmd) j c oh :
  nth_error ann j = Some c ->
  In oh (operations c) ->
  In oh (program_operations ann).
Proof.
  intros Hnth Hin. unfold program_operations.
  apply in_concat. exists (operations c). split; [| exact Hin].
  apply in_map. eapply nth_error_In; exact Hnth.
Qed.

Lemma branch_ops_nodup (ann : list AnnCmd) j c :
  NoDup (map fst (program_operations ann)) ->
  nth_error ann j = Some c ->
  NoDup (map fst (operations c)).
Proof.
  intros Hnd Hnth.
  revert j Hnth. induction ann as [|a rest IH]; intros [|j] Hnth; cbn in Hnth; try discriminate.
  - inversion Hnth; subst a. unfold program_operations in Hnd; cbn in Hnd.
    rewrite map_app in Hnd. apply NoDup_app_disjoint in Hnd as [H1 _]. exact H1.
  - unfold program_operations in Hnd; cbn in Hnd.
    rewrite map_app in Hnd. apply NoDup_app_disjoint in Hnd as [_ [H2 _]].
    eapply IH; eassumption.
Qed.

Lemma branch_po_in_program (ann : list AnnCmd) j c edge :
  nth_error ann j = Some c ->
  In edge (program_order c) ->
  In edge (po ann).
Proof.
  intros Hnth Hin. unfold po.
  apply in_concat. exists (program_order c). split; [| exact Hin].
  apply in_map. eapply nth_error_In; exact Hnth.
Qed.

Lemma po_same_branch (ann : list AnnCmd) o u :
  In (o, u) (po ann) ->
  exists j c, nth_error ann j = Some c /\ In (o, u) (program_order c).
Proof.
  unfold po. intros Hin. apply in_concat in Hin as [po_c [Hmap Hmem]].
  apply in_map_iff in Hmap as [c [<- Hinc]].
  apply In_nth_error in Hinc as [j Hj].
  exists j, c; split; assumption.
Qed.

Lemma in_branch_ops_unique_index (ann : list AnnCmd) j1 j2 c1 c2 o :
  annotations_valid ann ->
  nth_error ann j1 = Some c1 ->
  nth_error ann j2 = Some c2 ->
  In o (op_ids c1) ->
  In o (op_ids c2) ->
  j1 = j2.
Proof.
  intros [_ Htid] H1 H2 Ho1 Ho2.
  pose proof (Htid j1 c1 H1 o Ho1) as E1.
  pose proof (Htid j2 c2 H2 o Ho2) as E2.
  assert (Ep : Pos.of_succ_nat j1 = Pos.of_succ_nat j2) by congruence.
  apply (f_equal Pos.to_nat) in Ep. rewrite !SuccNat2Pos.id_succ in Ep. lia.
Qed.

(* --- 核心不变式：单分支不变式与全局自动机不变式 --- *)

Section Invariant.
Context (raw : list RawCmd).
Let ann : list AnnCmd := annotate_program raw.

Record branch_inv (records : list Rec) (inflight : list (op_id * PKind))
    (j : nat) (ann_j : AnnCmd) (ts : TState) (bt : branch_trace) : Prop := {
  bi_head :
    match ts with
    | TRunning cur | TWaitingFlag _ cur => is_event_head (cursor_cmd cur) = true
    | TDone _ => True
    end;
  bi_rem_sub : forall oh, In oh (rem_ops ts) -> In oh (operations ann_j);
  bi_rem_nodup : NoDup (map fst (rem_ops ts));
  bi_rem_fresh : forall o, In o (map fst (rem_ops ts)) ->
    ~ In o (map owner records) /\ ~ In o (map fst inflight);
  bi_po_closed : forall o u, In (o, u) (program_order ann_j) ->
    In u (map fst (rem_ops ts)) ->
    In (o, u) (rem_po ts) \/
    (rec_has_start ann records o /\
     (rec_has_gate ann records o \/ exists cur, ts = TWaitingFlag o cur));
  bi_cps : forall end_of,
    Forall (step_comp_ok end_of) (bt_steps bt) ->
    match ts with
    | TRunning cur | TWaitingFlag _ cur =>
        forall tev tuses,
          command_events layout model (cursor_env cur) (annotated_of cur) tev tuses ->
          command_events layout model empty_environment ann_j
            (flat_map (step_events end_of) (bt_steps bt) ++ tev)
            (bt_uses bt ++ tuses)
    | TDone _ =>
        command_events layout model empty_environment ann_j
          (flat_map (step_events end_of) (bt_steps bt))
          (bt_uses bt)
    end;
  bi_steps_comp : forall o d args,
    In (BSCompute o d args) (bt_steps bt) ->
    In (o, PCompute d args) inflight \/
    exists res, In (EventRecord o (LComputeEnd res)) records /\ comp model (resource d) args res
}.

(* 记录级公理表述：一旦在 records 上成立，通过 trace_of_records/kappa_of_records 立即得到 A1..A5/A_val *)

Definition rec_A1 (records : list Rec) : Prop :=
  forall o h, In (o, h) (program_operations ann) -> start_kind h <> end_kind h ->
    forall j r2, nth_error records j = Some r2 ->
      owner r2 = o -> kind (payload r2) = end_kind h ->
      exists i r1, nth_error records i = Some r1 /\ owner r1 = o /\
        kind (payload r1) = start_kind h /\ (i < j)%nat.

Definition rec_A2 (records : list Rec) : Prop :=
  forall o u, In (o, u) (po ann) ->
    forall j ru, nth_error records j = Some ru ->
      owner ru = u -> rec_is_start ann ru ->
      (exists i ro, nth_error records i = Some ro /\ owner ro = o /\ rec_is_start ann ro /\ (i < j)%nat) /\
      (exists i ro, nth_error records i = Some ro /\ owner ro = o /\ rec_is_gate ann ro /\ (i < j)%nat).

Definition rec_A3 (records : list Rec) : Prop :=
  forall f o src,
    In (f, HSetFlag) (program_operations ann) ->
    (exists i1 i2 r1 r2,
       nth_error records i1 = Some r1 /\ owner r1 = o /\ rec_is_start ann r1 /\ pipeline (payload r1) = Some src /\
       nth_error records i2 = Some r2 /\ owner r2 = f /\ rec_is_start ann r2 /\ pipeline (payload r2) = Some src /\
       (i1 < i2)%nat) ->
    forall jf rf, nth_error records jf = Some rf ->
      owner rf = f -> kind (payload rf) = SetFlagEnd ->
      exists io ro, nth_error records io = Some ro /\ owner ro = o /\ rec_is_end ann ro /\ (io < jf)%nat.

Definition rec_A5 (records : list Rec) : Prop :=
  forall w u dst,
    In (w, HWaitFlag) (program_operations ann) ->
    (exists i1 i2 r1 r2,
       nth_error records i1 = Some r1 /\ owner r1 = w /\ rec_is_start ann r1 /\ pipeline (payload r1) = Some dst /\
       nth_error records i2 = Some r2 /\ owner r2 = u /\ rec_is_start ann r2 /\ pipeline (payload r2) = Some dst /\
       (i1 < i2)%nat) ->
    forall ju ru, nth_error records ju = Some ru ->
      owner ru = u -> rec_is_start ann ru ->
      exists iw rw, nth_error records iw = Some rw /\ owner rw = w /\ kind (payload rw) = WaitFlagEnd /\ (iw < ju)%nat.

Definition rec_Aval (records : list Rec) (uses : list Use) : Prop :=
  forall u ie id re rd res,
    In u uses ->
    nth_error records ie = Some re -> owner re = consumer u -> rec_is_start ann re ->
    nth_error records id = Some rd -> rec_result_event (producer u) rd res ->
    (id < ie)%nat ->
    used_value u = res.

Definition flags_inv (records : list Rec) (flags : list (Pipe * Pipe * EventId)) : Prop :=
  forall p q fl,
    exists word,
      projection (rec_flag_letter p q fl records) records word /\
      if flag_is_set (eqb Pe) (eqb Ee) p q fl flags then
        exists w0, word = w0 ++ [FlagSet] /\ star (fun b => b = [FlagSet; FlagWait]) w0
      else
        star (fun b => b = [FlagSet; FlagWait]) word.

Record machine_inv_at (btraces : list branch_trace) (st : MState) : Prop := {
  mi_len_threads : length (ms_threads st) = length ann;
  mi_len_btraces : length btraces = length ann;
  mi_branches : forall j ann_j ts bt,
    nth_error ann j = Some ann_j ->
    nth_error (ms_threads st) j = Some ts ->
    nth_error btraces j = Some bt ->
    branch_inv (rev (ms_rev_trace st)) (sync_inflight (ms_sync st)) j ann_j ts bt;
  mi_perm_nodup : forall end_of,
    valid_end_of (rev (ms_rev_trace st)) (sync_inflight (ms_sync st)) end_of ->
    Permutation
      (concat (map (fun bt => flat_map (step_events end_of) (bt_steps bt)) btraces))
      (rev (ms_rev_trace st) ++ map (pending_end_event end_of) (sync_inflight (ms_sync st))) /\
    NoDup (rev (ms_rev_trace st) ++ map (pending_end_event end_of) (sync_inflight (ms_sync st)));
  mi_uses_equiv : forall u,
    In u (concat (map bt_uses btraces)) <-> In u (ms_rev_uses st);
  mi_uses_started : forall u,
    In u (ms_rev_uses st) -> rec_has_start ann (rev (ms_rev_trace st)) (consumer u);
  mi_records_valid : forall r,
    In r (rev (ms_rev_trace st)) ->
    rec_is_start ann r \/ rec_is_end ann r;
  mi_unique_phase : forall i1 i2 r1 r2,
    nth_error (rev (ms_rev_trace st)) i1 = Some r1 ->
    nth_error (rev (ms_rev_trace st)) i2 = Some r2 ->
    owner r1 = owner r2 ->
    kind (payload r1) = kind (payload r2) ->
    i1 = i2;
  mi_inflight_nodup : NoDup (map fst (sync_inflight (ms_sync st)));
  mi_inflight_spec : forall o pk,
    In (o, pk) (sync_inflight (ms_sync st)) ->
    In (o, pk_head pk) (program_operations ann) /\
    In (pk_start_rec o pk) (rev (ms_rev_trace st)) /\
    ~ rec_has_end ann (rev (ms_rev_trace st)) o /\
    match pk with
    | PRead d a => TraceSemantics.prior_start ReadStart o (ms_rev_trace st) = Some (LReadStart d a)
    | PWrite d a data => TraceSemantics.prior_start WriteStart o (ms_rev_trace st) = Some (LWriteStart d a data)
    | PSetFlag p q fl deps =>
        forall o' i1 i2 r1 r2,
          nth_error (rev (ms_rev_trace st)) i1 = Some r1 ->
          owner r1 = o' -> rec_is_start ann r1 -> pipeline (payload r1) = Some p ->
          nth_error (rev (ms_rev_trace st)) i2 = Some r2 ->
          owner r2 = o -> rec_is_start ann r2 ->
          (i1 < i2)%nat ->
          rec_has_end ann (rev (ms_rev_trace st)) o' \/ In o' deps
    | _ => True
    end;
  mi_started_2phase : forall r h,
    In r (rev (ms_rev_trace st)) ->
    In (owner r, h) (program_operations ann) ->
    start_kind h <> end_kind h ->
    kind (payload r) = start_kind h ->
    rec_has_end ann (rev (ms_rev_trace st)) (owner r) \/
    exists pk, In (owner r, pk) (sync_inflight (ms_sync st)) /\ pending_pipe pk = pipeline (payload r);
  mi_active_wait_fwd : forall w p q fl,
    In (EventRecord w (LWaitFlagStart p q fl)) (rev (ms_rev_trace st)) ->
    ~ rec_has_end ann (rev (ms_rev_trace st)) w ->
    active_wait_of (eqb Pe) q (sync_active_wait (ms_sync st)) = Some w;
  mi_flags : flags_inv (rev (ms_rev_trace st)) (sync_flags (ms_sync st));
  mi_done_val : forall o res,
    lookup_assoc op_id_eqb o (mem_done_val (ms_mem st)) = Some res <->
    (In (EventRecord o (LReadEnd res)) (rev (ms_rev_trace st)) \/
     In (EventRecord o (LComputeEnd res)) (rev (ms_rev_trace st)));
  mi_mem_history : TraceSemantics.memory_history [] (rev (ms_rev_trace st));
  mi_mem_writes : forall a,
    mem_lookup a (ms_mem st) = TraceSemantics.latest_write a (ms_rev_trace st);
  mi_target : Forall (fun r => target_allows cfg (payload r)) (rev (ms_rev_trace st));
  mi_A1 : rec_A1 (rev (ms_rev_trace st));
  mi_A2 : rec_A2 (rev (ms_rev_trace st));
  mi_A3 : rec_A3 (rev (ms_rev_trace st));
  mi_A5 : rec_A5 (rev (ms_rev_trace st));
  mi_Aval : rec_Aval (rev (ms_rev_trace st)) (ms_rev_uses st)
}.

Definition machine_inv (st : MState) : Prop :=
  exists btraces, machine_inv_at btraces st.

(* ========================================================================== *)
(* 5. 初始化不变式：init_machine 满足 machine_inv                               *)
(* ========================================================================== *)

Lemma nth_error_combine {A B} (l1 : list A) (l2 : list B) j a b :
  nth_error l1 j = Some a ->
  nth_error l2 j = Some b ->
  nth_error (combine l1 l2) j = Some (a, b).
Proof.
  revert l2 j. induction l1 as [|x l1 IH]; intros [|y l2] [|j] H1 H2; cbn in *; try discriminate; auto.
  inversion H1; inversion H2; reflexivity.
Qed.

Lemma ann_nth_error j c :
  nth_error ann j = Some c <->
  exists r, nth_error raw j = Some r /\
    c = label_paths (pair (Pos.of_succ_nat j)) 1%positive (expand_loops r LoopEnd).
Proof.
  unfold ann, annotate_program, expand_program.
  rewrite nth_error_map. split.
  - intros H.
    destruct (nth_error (combine (seq 0 (length raw)) (map (fun c0 => expand_loops c0 LoopEnd) raw)) j)
      as [[j0 c0]|] eqn:Hc; [| discriminate].
    inversion H; subst c.
    assert (Hj : (j < length raw)%nat).
    { pose proof (nth_error_Some (combine (seq 0 (length raw)) (map (fun c1 => expand_loops c1 LoopEnd) raw)) j) as Hs.
      rewrite length_combine, length_seq, length_map, Nat.min_id in Hs. apply Hs; congruence. }
    destruct (nth_error raw j) as [r|] eqn:Hr; [| apply nth_error_None in Hr; lia].
    assert (Hcomb : nth_error (combine (seq 0 (length raw)) (map (fun c1 => expand_loops c1 LoopEnd) raw)) j
                    = Some (j, expand_loops r LoopEnd)).
    { apply nth_error_combine; [rewrite nth_error_seq by exact Hj; reflexivity | rewrite nth_error_map, Hr; reflexivity]. }
    rewrite Hcomb in Hc. inversion Hc; subst. exists r; split; auto.
  - intros [r [Hr ->]].
    assert (Hj : (j < length raw)%nat) by (apply nth_error_Some; congruence).
    rewrite (@nth_error_combine _ _ (seq 0 (length raw)) (map (fun c1 => expand_loops c1 LoopEnd) raw) j j (expand_loops r LoopEnd)).
    + reflexivity.
    + rewrite nth_error_seq by exact Hj; reflexivity.
    + rewrite nth_error_map, Hr; reflexivity.
Qed.

Lemma length_ann : length ann = length raw.
Proof.
  unfold ann, annotate_program, expand_program.
  rewrite length_map, length_combine, length_seq, length_map, Nat.min_id. reflexivity.
Qed.

Lemma init_threads_aux_spec budget idx (bs : list RawCmd) (ts : list TState) :
  init_threads_aux budget idx bs = Ok ts ->
  length ts = length bs /\
  forall k r t,
    nth_error bs k = Some r ->
    nth_error ts k = Some t ->
    exists cur,
      t = TRunning cur /\
      refocus budget (ThreadCursor (Pos.of_succ_nat (idx + k)) 1%positive empty_environment r []) = Some cur.
Proof.
  revert idx ts. induction bs as [|c rest IH]; intros idx ts H; cbn in H.
  - inversion H; subst. split; [reflexivity | intros k; destruct k; discriminate].
  - destruct (refocus budget _) as [cur|] eqn:Href; [| discriminate].
    destruct (init_threads_aux budget (S idx) rest) as [ts'|] eqn:Hrest;
      cbn [result_bind] in H; [| discriminate].
    inversion H; subst ts.
    destruct (IH (S idx) ts' Hrest) as [Hlen Hall].
    split; [cbn; lia |].
    intros [|k] r t H1 H2; cbn in H1, H2.
    + inversion H1; inversion H2; subst. exists cur; rewrite Nat.add_0_r; split; auto.
    + replace (idx + S k)%nat with (S idx + k)%nat by lia. eapply Hall; eassumption.
Qed.

Lemma init_machine_inv budget st0 :
  init_machine budget raw = Ok st0 ->
  machine_inv st0.
Proof.
  intros Hinit. unfold init_machine in Hinit.
  destruct (init_threads_aux budget 0 raw) as [ts|] eqn:Hts; cbn [result_bind] in Hinit; [| discriminate].
  inversion Hinit; subst st0.
  destruct (init_threads_aux_spec budget 0 raw Hts) as [Hlen Hall].
  pose proof (annotate_program_valid raw) as [_ [Hnd_all Htid_all]].
  set (bts := repeat (BranchTrace [] []) (length ann)).
  exists bts.
  refine (@Build_machine_inv_at bts _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _); cbn.
  - rewrite Hlen, length_ann. reflexivity.
  - unfold bts. apply repeat_length.
  - intros j ann_j t bt Hann Ht Hbt.
    apply ann_nth_error in Hann as [r [Hr ->]].
    destruct (Hall j r t Hr Ht) as [cur [-> Href]].
    cbn [Nat.add] in Href.
    pose proof (refocus_event_head _ _ Href) as Hhead.
    pose proof (refocus_preserves_ops_and_po _ _ Href) as [Hops Hpo].
    unfold annotated_of in Hops, Hpo; cbn in Hops, Hpo.
    assert (Hbt_eq : bt = BranchTrace [] []).
    { unfold bts in Hbt. apply nth_error_In in Hbt. apply repeat_spec in Hbt. exact Hbt. }
    subst bt.
    constructor; cbn.
    + exact Hhead.
    + intros oh Hin. unfold annotated_of in Hin; rewrite Hops in Hin. exact Hin.
    + unfold annotated_of; rewrite Hops. eapply branch_ops_nodup with (j := j); [exact Hnd_all | apply (proj2 (ann_nth_error j _)); exists r; split; [exact Hr | reflexivity]].
    + intros o _. tauto.
    + intros o u Hpou _. left. unfold annotated_of; rewrite Hpo. exact Hpou.
    + intros end_of _ tev tuses Hce.
      exact (refocus_preserves_command_events _ _ Href Hce).
    + intros o d args [].
  - intros end_of _. split; [| constructor].
    assert (Hnil : concat (map (fun bt => flat_map (step_events end_of) (bt_steps bt)) bts) = []).
    { unfold bts. generalize (length ann). induction n; cbn; auto. }
    rewrite Hnil. apply Permutation_refl.
  - intros u. split; [| intros []].
    assert (Hnil : concat (map bt_uses bts) = []).
    { unfold bts. generalize (length ann). induction n; cbn; auto. }
    rewrite Hnil. intros [].
  - intros u [].
  - intros r [].
  - intros i1 i2 r1 r2 H1; destruct i1; discriminate H1.
  - constructor.
  - intros o pk [].
  - intros r h [].
  - intros w p q fl [].
  - intros p q fl. exists []. split; [constructor | constructor].
  - intros o res; cbn; split; [discriminate | intros [[] | []]].
  - exact I.
  - intros a; reflexivity.
  - constructor.
  - intros o h _ _ j r2 Hj; destruct j; discriminate Hj.
  - intros o u _ j ru Hj; destruct j; discriminate Hj.
  - intros f o src _ _ jf rf Hj; destruct jf; discriminate Hj.
  - intros w u dst _ _ ju ru Hj; destruct ju; discriminate Hj.
  - intros u ie id re rd res [].
Qed.

(* ========================================================================== *)
(* 6. 自动机不变式保持定理：每一条 auto_step 规则都保持 machine_inv              *)
(* ========================================================================== *)

Lemma non_wait_gate_eq_start (h : head) :
  h <> HWaitFlag -> gate_kind h = start_kind h.
Proof.
  destruct h; intros H; try reflexivity; contradiction.
Qed.

Lemma start_ne_end_not_single (h : head) :
  start_kind h <> end_kind h ->
  h = HRead \/ h = HWrite \/ h = HCompute \/ h = HSetFlag \/ h = HWaitFlag.
Proof.
  destruct h; cbn; intros H; try (exfalso; apply H; reflexivity); auto 10.
Qed.

Lemma rec_has_phase_snoc phase records ev o :
  rec_has_phase ann phase records o ->
  rec_has_phase ann phase (records ++ [ev]) o.
Proof.
  intros [r [Hr [Ho Hp]]]. exists r; repeat split; [apply in_app_iff; now left | exact Ho | exact Hp].
Qed.

Lemma rec_has_phase_snoc_inv phase records ev o :
  rec_has_phase ann phase (records ++ [ev]) o ->
  rec_has_phase ann phase records o \/ (owner ev = o /\ rec_is_phase ann phase ev).
Proof.
  intros [r [Hr [Ho Hp]]]. apply in_app_iff in Hr as [Hr | [<- | []]].
  - left. exists r; auto.
  - right; auto.
Qed.

(* 通用引理：若 o_new 属于分支 j 且 k <> j，则 o_new 不在分支 k 的 rem_ops 中 *)
Lemma op_from_branch_not_in_other_rem records inflight j k ann_j ann_k ts_k bt_k o :
  annotations_valid ann ->
  j <> k ->
  nth_error ann j = Some ann_j ->
  nth_error ann k = Some ann_k ->
  In o (op_ids ann_j) ->
  branch_inv records inflight k ann_k ts_k bt_k ->
  ~ In o (map fst (rem_ops ts_k)).
Proof.
  intros Hval Hneq Hj Hk Ho Hbi Hink.
  apply in_map_iff in Hink as [[o' h'] [E Hin']]. cbn in E; subst o'.
  apply (bi_rem_sub Hbi) in Hin'.
  assert (Ho_k : In o (op_ids ann_k)) by (unfold op_ids; change o with (fst (o, h')); apply in_map; exact Hin').
  apply Hneq. eapply in_branch_ops_unique_index; eassumption.
Qed.

(* 通用引理：在 records 末尾追加 ev，并在 inflight 中（可选地）新增 o_new 时，保持其他分支 k <> j 的 branch_inv *)
Lemma preserve_other_branch_inv_issue records inflight inflight' j k ann_j ann_k ts_k bt_k ev :
  annotations_valid ann ->
  j <> k ->
  nth_error ann j = Some ann_j ->
  nth_error ann k = Some ann_k ->
  In (owner ev) (op_ids ann_j) ->
  (forall o, In o (map fst inflight') -> In o (map fst inflight) \/ o = owner ev) ->
  (forall o pk, In (o, pk) inflight -> In (o, pk) inflight') ->
  branch_inv records inflight k ann_k ts_k bt_k ->
  branch_inv (records ++ [ev]) inflight' k ann_k ts_k bt_k.
Proof.
  intros Hval Hneq Hj Hk Hov Hinf_sub Hinf_mono Hbi.
  assert (Hnotk : ~ In (owner ev) (map fst (rem_ops ts_k)))
    by (eapply op_from_branch_not_in_other_rem; eassumption).
  constructor.
  - exact (bi_head Hbi).
  - exact (bi_rem_sub Hbi).
  - exact (bi_rem_nodup Hbi).
  - intros u Hu. destruct (bi_rem_fresh Hbi u Hu) as [Hnr Hni]. split.
    + rewrite map_app, in_app_iff. intros [Hin | [Heq | []]]; [contradiction |].
      cbn in Heq; subst u; contradiction.
    + intros Hin. apply Hinf_sub in Hin as [Hin | ->]; contradiction.
  - intros o u Hpo Hu. destruct (bi_po_closed Hbi o u Hpo Hu) as [Hrem | [Hs [Hg | Hw]]].
    + left; exact Hrem.
    + right; split; [apply rec_has_phase_snoc; exact Hs | left; apply rec_has_phase_snoc; exact Hg].
    + right; split; [apply rec_has_phase_snoc; exact Hs | right; exact Hw].
  - exact (bi_cps Hbi).
  - intros o d args Hin. destruct (bi_steps_comp Hbi o d args Hin) as [Hinf | [res [Hrec Hc]]].
    + left; apply Hinf_mono; exact Hinf.
    + right; exists res; split; [apply in_app_iff; now left | exact Hc].
Qed.

(* 通用引理：完成在途操作 (o, pk) 发射 ev_end，保持非唤醒分支的 branch_inv *)
Lemma preserve_branch_inv_finish records inflight o_fin pk_fin ev_end k ann_k ts_k bt_k :
  In (o_fin, pk_fin) inflight ->
  owner ev_end = o_fin ->
  (forall d args, pk_fin = PCompute d args ->
     exists res, ev_end = EventRecord o_fin (LComputeEnd res) /\ comp model (resource d) args res) ->
  NoDup (map fst inflight) ->
  branch_inv records inflight k ann_k ts_k bt_k ->
  branch_inv (records ++ [ev_end]) (remove_assoc op_id_eqb o_fin inflight) k ann_k ts_k bt_k.
Proof.
  intros Hinf Hov Hcomp Hnd Hbi.
  constructor.
  - exact (bi_head Hbi).
  - exact (bi_rem_sub Hbi).
  - exact (bi_rem_nodup Hbi).
  - intros u Hu. destruct (bi_rem_fresh Hbi u Hu) as [Hnr Hni]. split.
    + rewrite map_app, in_app_iff. intros [Hin | [Heq | []]]; [contradiction |].
      cbn in Heq; rewrite Hov in Heq; subst u.
      apply Hni. change o_fin with (fst (o_fin, pk_fin)). apply in_map; exact Hinf.
    + intros Hin. apply in_map_iff in Hin as [[u' pk'] [Eu Hin']]. cbn in Eu; subst u'.
      apply (proj1 (in_remove_assoc_iff op_id_eq_ops o_fin (u, pk') inflight)) in Hin' as [Hin' _].
      apply Hni. change u with (fst (u, pk')). apply in_map; exact Hin'.
  - intros o u Hpo Hu. destruct (bi_po_closed Hbi o u Hpo Hu) as [Hrem | [Hs [Hg | Hw]]].
    + left; exact Hrem.
    + right; split; [apply rec_has_phase_snoc; exact Hs | left; apply rec_has_phase_snoc; exact Hg].
    + right; split; [apply rec_has_phase_snoc; exact Hs | right; exact Hw].
  - exact (bi_cps Hbi).
  - intros o d args Hin. destruct (bi_steps_comp Hbi o d args Hin) as [Hoi | [res [Hrec Hc]]].
    + destruct (op_id_eqb o o_fin) eqn:E.
      * apply op_id_eqb_spec in E; subst o.
        assert (Hpk : pk_fin = PCompute d args).
        { apply (lookup_assoc_in_nodup op_id_eq_ops o_fin pk_fin inflight Hnd) in Hinf.
          apply (lookup_assoc_in_nodup op_id_eq_ops o_fin (PCompute d args) inflight Hnd) in Hoi.
          congruence. }
        destruct (Hcomp d args Hpk) as [res [Hev Hc]].
        right; exists res; split; [apply in_app_iff; right; left; exact Hev | exact Hc].
      * apply (proj1 (eqb_neq op_id_eq_ops o o_fin)) in E.
        left. apply (proj2 (in_remove_assoc_iff op_id_eq_ops o_fin (o, PCompute d args) inflight)).
        split; [exact Hoi | exact E].
    + right; exists res; split; [apply in_app_iff; now left | exact Hc].
Qed.

(* 辅助引理：从单分支的 TRunning cur 发出头命令 o，得到 A2 中关于 o 的前提 *)
Lemma head_op_po_satisfied records inflight j ann_j cur bt o h :
  annotations_valid ann ->
  nth_error ann j = Some ann_j ->
  branch_inv records inflight j ann_j (TRunning cur) bt ->
  In (o, h) (rem_ops (TRunning cur)) ->
  (forall o0, ~ In (o0, o) (rem_po (TRunning cur))) ->
  forall o0, In (o0, o) (po ann) ->
    rec_has_start ann records o0 /\ rec_has_gate ann records o0.
Proof.
  intros Hval Hj Hbi Hhead Hnotpo o0 Hpo.
  apply po_same_branch in Hpo as [k [ann_k [Hk Hpo_k]]].
  pose proof (program_order_in_op_ids ann_k o0 o Hpo_k) as [_ Ho_k].
  assert (Ho_j : In o (op_ids ann_j)).
  { apply (bi_rem_sub Hbi) in Hhead. unfold op_ids; change o with (fst (o, h)); apply in_map; exact Hhead. }
  assert (Heqjk : k = j) by (eapply in_branch_ops_unique_index; eassumption).
  subst k. rewrite Hj in Hk. inversion Hk; subst ann_k.
  assert (Ho_rem : In o (map fst (rem_ops (TRunning cur))))
    by (change o with (fst (o, h)); apply in_map; exact Hhead).
  destruct (bi_po_closed Hbi o0 o Hpo_k Ho_rem) as [Hrem | [Hs [Hg | [cur0 Hw]]]].
  - exfalso; eapply Hnotpo; exact Hrem.
  - split; assumption.
  - discriminate Hw.
Qed.

(* 辅助引理：在 records 末尾追加一个新发起事件 ev（其 owner 未出现过），保持 rec_A2 *)
Lemma rec_A2_snoc_start records ev :
  rec_A2 records ->
  ~ In (owner ev) (map owner records) ->
  (forall o0, In (o0, owner ev) (po ann) -> rec_has_start ann records o0 /\ rec_has_gate ann records o0) ->
  rec_A2 (records ++ [ev]).
Proof.
  intros HA2 Hfresh Hsat o u Hpo j ru Hj Ho Hst.
  apply nth_error_app_snoc in Hj as [[Hj Hlt] | [-> ->]].
  - destruct (HA2 o u Hpo j ru Hj Ho Hst) as [[i1 [r1 [H1 [Ho1 [Hs1 Hlt1]]]]] [i2 [r2 [H2 [Ho2 [Hg2 Hlt2]]]]]].
    split.
    + exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 |].
      apply nth_error_Some; congruence.
    + exists i2, r2; repeat split; auto. rewrite nth_error_app1; [exact H2 |].
      apply nth_error_Some; congruence.
  - subst u. destruct (Hsat o Hpo) as [[r1 [Hr1 [Ho1 Hs1]]] [r2 [Hr2 [Ho2 Hg2]]]].
    apply In_nth_error in Hr1 as [i1 Hi1].
    apply In_nth_error in Hr2 as [i2 Hi2].
    assert (Hlt1 : (i1 < length records)%nat) by (apply nth_error_Some; congruence).
    assert (Hlt2 : (i2 < length records)%nat) by (apply nth_error_Some; congruence).
    split.
    + exists i1, r1; repeat split; auto. rewrite nth_error_app1 by exact Hlt1; exact Hi1.
    + exists i2, r2; repeat split; auto. rewrite nth_error_app1 by exact Hlt2; exact Hi2.
Qed.

(* 辅助引理：在 records 末尾追加一个结束事件 ev_end（start_kind <> end_kind，故非 start），保持 rec_A2 *)
Lemma rec_A2_snoc_non_start records ev :
  rec_A2 records ->
  ~ rec_is_start ann ev ->
  rec_A2 (records ++ [ev]).
Proof.
  intros HA2 Hns o u Hpo j ru Hj Ho Hst.
  apply nth_error_app_snoc in Hj as [[Hj Hlt] | [-> ->]]; [| contradiction].
  destruct (HA2 o u Hpo j ru Hj Ho Hst) as [[i1 [r1 [H1 [Ho1 [Hs1 Hlt1]]]]] [i2 [r2 [H2 [Ho2 [Hg2 Hlt2]]]]]].
  split.
  - exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
  - exists i2, r2; repeat split; auto. rewrite nth_error_app1; [exact H2 | apply nth_error_Some; congruence].
Qed.

(* 辅助引理：在 records 末尾追加事件 ev（若不是 SetFlagEnd），保持 rec_A3 *)
Lemma rec_A3_snoc_non_setflag_end records ev :
  NoDup (map fst (program_operations ann)) ->
  rec_A1 records ->
  (forall i1 i2 r1 r2,
     nth_error records i1 = Some r1 -> nth_error records i2 = Some r2 ->
     owner r1 = owner r2 -> kind (payload r1) = kind (payload r2) -> i1 = i2) ->
  ~ In (owner ev) (map owner records) \/ ~ rec_is_start ann ev ->
  rec_A3 records ->
  kind (payload ev) <> SetFlagEnd ->
  rec_A3 (records ++ [ev]).
Proof.
  intros Hnd HA1 Huniq Hfresh HA3 Hne f o src Hf Hpb jf rf Hjf Hof Hkf.
  apply nth_error_app_snoc in Hjf as [[Hjf Hltf] | [-> ->]]; [| contradiction].
  destruct Hpb as [i1 [i2 [r1 [r2 [H1 [Ho1 [Hs1 [Hp1 [H2 [Ho2 [Hs2 [Hp2 Hlt12]]]]]]]]]]]].
  apply nth_error_app_snoc in H2 as [[H2 Hlt2] | [Hi2 Hr2]].
  - assert (Hlt1 : (i1 < length records)%nat) by lia.
    rewrite nth_error_app1 in H1 by exact Hlt1.
    assert (Hpb0 : exists i1 i2 r1 r2,
      nth_error records i1 = Some r1 /\ owner r1 = o /\ rec_is_start ann r1 /\ pipeline (payload r1) = Some src /\
      nth_error records i2 = Some r2 /\ owner r2 = f /\ rec_is_start ann r2 /\ pipeline (payload r2) = Some src /\
      (i1 < i2)%nat) by (exists i1, i2, r1, r2; repeat split; assumption).
    destruct (HA3 f o src Hf Hpb0 jf rf Hjf Hof Hkf) as [io [ro [Hio [Hoo [Heo Hlt]]]]].
    exists io, ro; repeat split; auto.
    rewrite nth_error_app1; [exact Hio | apply nth_error_Some; congruence].
  - subst i2 r2. destruct Hfresh as [Hni | Hns]; [| contradiction].
    exfalso. apply Hni. rewrite Ho2, <- Hof.
    apply in_map. eapply nth_error_In; exact Hjf.
Qed.

(* 辅助引理：在 records 末尾追加一个非 start 事件，保持 rec_A5 *)
Lemma rec_A5_snoc_non_start records ev :
  rec_A5 records ->
  ~ rec_is_start ann ev ->
  rec_A5 (records ++ [ev]).
Proof.
  intros HA5 Hns w u dst Hw Hpb ju ru Hju Hou Hsu.
  apply nth_error_app_snoc in Hju as [[Hju Hltu] | [-> ->]]; [| contradiction].
  destruct Hpb as [i1 [i2 [r1 [r2 [H1 [Ho1 [Hs1 [Hp1 [H2 [Ho2 [Hs2 [Hp2 Hlt12]]]]]]]]]]]].
  apply nth_error_app_snoc in H2 as [[H2 Hlt2] | [-> ->]]; [| contradiction].
  assert (Hlt1 : (i1 < length records)%nat) by lia.
  rewrite nth_error_app1 in H1 by exact Hlt1.
  assert (Hpb0 : exists i1 i2 r1 r2,
    nth_error records i1 = Some r1 /\ owner r1 = w /\ rec_is_start ann r1 /\ pipeline (payload r1) = Some dst /\
    nth_error records i2 = Some r2 /\ owner r2 = u /\ rec_is_start ann r2 /\ pipeline (payload r2) = Some dst /\
    (i1 < i2)%nat) by (exists i1, i2, r1, r2; repeat split; assumption).
  destruct (HA5 w u dst Hw Hpb0 ju ru Hju Hou Hsu) as [iw [rw [Hiw [How [Hkw Hlt]]]]].
  exists iw, rw; repeat split; auto.
  rewrite nth_error_app1; [exact Hiw | apply nth_error_Some; congruence].
Qed.

(* 辅助引理：在 records 末尾追加一个新发起事件 ev（其 owner 未出现过），若满足 A5 门控条件则保持 rec_A5 *)
Lemma rec_A5_snoc_start records ev :
  rec_A5 records ->
  ~ In (owner ev) (map owner records) ->
  (forall w dst,
     In (w, HWaitFlag) (program_operations ann) ->
     pipeline (payload ev) = Some dst ->
     (exists r1, In r1 records /\ owner r1 = w /\ rec_is_start ann r1 /\ pipeline (payload r1) = Some dst) ->
     exists rw, In rw records /\ owner rw = w /\ kind (payload rw) = WaitFlagEnd) ->
  rec_A5 (records ++ [ev]).
Proof.
  intros HA5 Hfresh Hgate w u dst Hw Hpb ju ru Hju Hou Hsu.
  apply nth_error_app_snoc in Hju as [[Hju Hltu] | [-> ->]].
  - destruct Hpb as [i1 [i2 [r1 [r2 [H1 [Ho1 [Hs1 [Hp1 [H2 [Ho2 [Hs2 [Hp2 Hlt12]]]]]]]]]]]].
    apply nth_error_app_snoc in H2 as [[H2 Hlt2] | [-> ->]].
    + assert (Hlt1 : (i1 < length records)%nat) by lia.
      rewrite nth_error_app1 in H1 by exact Hlt1.
      assert (Hpb0 : exists i1 i2 r1 r2,
        nth_error records i1 = Some r1 /\ owner r1 = w /\ rec_is_start ann r1 /\ pipeline (payload r1) = Some dst /\
        nth_error records i2 = Some r2 /\ owner r2 = u /\ rec_is_start ann r2 /\ pipeline (payload r2) = Some dst /\
        (i1 < i2)%nat) by (exists i1, i2, r1, r2; repeat split; assumption).
      destruct (HA5 w u dst Hw Hpb0 ju ru Hju Hou Hsu) as [iw [rw [Hiw [How [Hkw Hlt]]]]].
      exists iw, rw; repeat split; auto.
      rewrite nth_error_app1; [exact Hiw | apply nth_error_Some; congruence].
    + exfalso. apply Hfresh. rewrite Ho2, <- Hou. apply in_map; eapply nth_error_In; exact Hju.
  - subst u. destruct Hpb as [i1 [i2 [r1 [r2 [H1 [Ho1 [Hs1 [Hp1 [H2 [Ho2 [Hs2 [Hp2 Hlt12]]]]]]]]]]]].
    apply nth_error_app_snoc in H2 as [[H2 Hlt2] | [-> ->]].
    + exfalso. apply Hfresh. rewrite <- Ho2. apply in_map; eapply nth_error_In; exact H2.
    + rewrite nth_error_app1 in H1 by exact Hlt12.
      destruct (Hgate w dst Hw Hp2) as [rw [Hrw [How Hkw]]].
      * exists r1; repeat split; [eapply nth_error_In; exact H1 | exact Ho1 | exact Hs1 | exact Hp1].
      * apply In_nth_error in Hrw as [iw Hiw].
        assert (Hltw : (iw < length records)%nat) by (apply nth_error_Some; congruence).
        exists iw, rw; repeat split; auto. rewrite nth_error_app1 by exact Hltw; exact Hiw.
Qed.

(* 辅助引理：在 records 末尾追加新发起事件 ev，并将 new_uses 加入 uses，保持 rec_Aval *)
Lemma rec_Aval_snoc_issue records uses ev new_uses dv :
  rec_Aval records uses ->
  (forall u, In u uses -> rec_has_start ann records (consumer u)) ->
  (forall o res, lookup_assoc op_id_eqb o dv = Some res <->
     In (EventRecord o (LReadEnd res)) records \/ In (EventRecord o (LComputeEnd res)) records) ->
  ~ In (owner ev) (map owner records) ->
  (forall u, In u new_uses ->
     consumer u = owner ev /\
     forall res, lookup_assoc op_id_eqb (producer u) dv = Some res -> used_value u = res) ->
  rec_Aval (records ++ [ev]) (rev_append new_uses uses).
Proof.
  intros HAval Hstarted Hdv Hfresh Hnew u ie id re rd res Hu Hie Hoe Hse Hid Hrd Hlt.
  apply in_rev_append in Hu as [Hu | Hu].
  - destruct (Hnew u Hu) as [Hcons Hval].
    apply nth_error_app_snoc in Hie as [[Hie Hlte] | [-> ->]].
    + exfalso. apply Hfresh. rewrite <- Hcons, <- Hoe. apply in_map; eapply nth_error_In; exact Hie.
    + rewrite nth_error_app1 in Hid by exact Hlt.
      apply Hval. apply (proj2 (Hdv (producer u) res)).
      destruct Hrd as [-> | ->]; [left | right]; eapply nth_error_In; exact Hid.
  - apply nth_error_app_snoc in Hie as [[Hie Hlte] | [-> ->]].
    + assert (Hltd : (id < length records)%nat) by lia.
      rewrite nth_error_app1 in Hid by exact Hltd.
      exact (HAval u ie id re rd res Hu Hie Hoe Hse Hid Hrd Hlt).
    + exfalso. destruct (Hstarted u Hu) as [r0 [Hr0 [Ho0 _]]].
      apply Hfresh. rewrite Hoe, <- Ho0. apply in_map; exact Hr0.
Qed.

Lemma rec_Aval_snoc_non_start records uses ev :
  rec_Aval records uses ->
  ~ rec_is_start ann ev ->
  rec_Aval (records ++ [ev]) uses.
Proof.
  intros HAval Hns u ie id re rd res Hu Hie Hoe Hse Hid Hrd Hlt.
  apply nth_error_app_snoc in Hie as [[Hie Hlte] | [-> ->]]; [| contradiction].
  assert (Hltd : (id < length records)%nat) by lia.
  rewrite nth_error_app1 in Hid by exact Hltd.
  exact (HAval u ie id re rd res Hu Hie Hoe Hse Hid Hrd Hlt).
Qed.

(* 辅助引理：追加非 SetFlagEnd/WaitFlagEnd 事件，保持 flags_inv *)
Lemma flags_inv_snoc_other records flags ev :
  flags_inv records flags ->
  payload ev <> LSetFlagEnd ->
  payload ev <> LWaitFlagEnd ->
  (forall o p q fl, ev = EventRecord o (LSetFlagStart p q fl) -> ~ In o (map owner records)) ->
  (forall o p q fl, ev = EventRecord o (LWaitFlagStart p q fl) -> ~ In o (map owner records)) ->
  flags_inv (records ++ [ev]) flags.
Proof.
  intros Hfl Hns Hnw Hfs Hfw p q fl.
  destruct (Hfl p q fl) as [word [Hproj Hst]].
  exists word; split; [| exact Hst].
  apply projection_snoc_skip.
  - eapply projection_ext; [| exact Hproj].
    intros r l Hr. destruct l; cbn; rewrite in_app_iff; split; try tauto.
    + intros [Hp [Hin | [Heq | []]]]; [auto |].
      exfalso. apply (Hfs (owner r) p q fl Heq). apply in_map; exact Hr.
    + intros [Hp [Hin | [Heq | []]]]; [auto |].
      exfalso. apply (Hfw (owner r) p q fl Heq). apply in_map; exact Hr.
  - intros [[|] [Hp _]]; contradiction.
Qed.

(* 辅助引理：唯一性更新（新发起事件，owner 未出现过） *)
Lemma unique_phase_snoc_fresh (records : list Rec) (ev : Rec) :
  (forall i1 i2 r1 r2,
     nth_error records i1 = Some r1 -> nth_error records i2 = Some r2 ->
     owner r1 = owner r2 -> kind (payload r1) = kind (payload r2) -> i1 = i2) ->
  ~ In (owner ev) (map owner records) ->
  forall i1 i2 r1 r2,
    nth_error (records ++ [ev]) i1 = Some r1 ->
    nth_error (records ++ [ev]) i2 = Some r2 ->
    owner r1 = owner r2 ->
    kind (payload r1) = kind (payload r2) ->
    i1 = i2.
Proof.
  intros Huniq Hfresh i1 i2 r1 r2 H1 H2 Ho Hk.
  apply nth_error_app_snoc in H1 as [[H1 _] | [-> ->]];
  apply nth_error_app_snoc in H2 as [[H2 _] | [-> ->]]; auto.
  - eapply Huniq; eassumption.
  - exfalso. apply Hfresh. rewrite <- Ho. apply in_map; eapply nth_error_In; exact H1.
  - exfalso. apply Hfresh. rewrite Ho. apply in_map; eapply nth_error_In; exact H2.
Qed.

(* 辅助引理：唯一性更新（结束事件，该 owner 尚无 end 事件且 start_kind <> end_kind） *)
Lemma unique_phase_snoc_end records ev h :
  NoDup (map fst (program_operations ann)) ->
  (forall i1 i2 r1 r2,
     nth_error records i1 = Some r1 -> nth_error records i2 = Some r2 ->
     owner r1 = owner r2 -> kind (payload r1) = kind (payload r2) -> i1 = i2) ->
  (forall r, In r records -> rec_is_start ann r \/ rec_is_end ann r) ->
  In (owner ev, h) (program_operations ann) ->
  start_kind h <> end_kind h ->
  kind (payload ev) = end_kind h ->
  ~ rec_has_end ann records (owner ev) ->
  forall i1 i2 r1 r2,
    nth_error (records ++ [ev]) i1 = Some r1 ->
    nth_error (records ++ [ev]) i2 = Some r2 ->
    owner r1 = owner r2 ->
    kind (payload r1) = kind (payload r2) ->
    i1 = i2.
Proof.
  intros Hnd Huniq Hval Hh Hne Hke Hnend i1 i2 r1 r2 H1 H2 Ho Hk.
  apply nth_error_app_snoc in H1 as [[H1 _] | [-> ->]];
  apply nth_error_app_snoc in H2 as [[H2 _] | [-> ->]]; auto.
  - eapply Huniq; eassumption.
  - exfalso. apply nth_error_In in H1.
    destruct (Hval r1 H1) as [[h1 [Hh1 Hk1]] | [h1 [Hh1 Hk1]]].
    + rewrite Ho in Hh1. pose proof (ops_unique_head ann Hnd Hh1 Hh) as ->. congruence.
    + apply Hnend. exists r1; repeat split; [exact H1 | exact Ho | exists h1; auto].
  - exfalso. apply nth_error_In in H2.
    destruct (Hval r2 H2) as [[h2 [Hh2 Hk2]] | [h2 [Hh2 Hk2]]].
    + rewrite <- Ho in Hh2. pose proof (ops_unique_head ann Hnd Hh2 Hh) as ->. congruence.
    + apply Hnend. exists r2; repeat split; [exact H2 | symmetry; exact Ho | exists h2; auto].
Qed.

(* 辅助引理：单一顺序后继命令的分支游标推进（Alloc/Atomic/AssignPipe/Read/Write/Compute/SetFlag/WaitFlag 共用） *)
Lemma branch_inv_linear_step records inflight inflight' j ann_j cur cur' bt
    (o : op_id) (h : head) (s : branch_step) (new_uses : list Use)
    (ev_start : Rec) (ts' : TState) :
  NoDup (map fst (program_operations ann)) ->
  branch_inv records inflight j ann_j (TRunning cur) bt ->
  (ts' = TRunning cur' \/ ts' = TWaitingFlag o cur') ->
  is_event_head (cursor_cmd cur') = true ->
  operations (annotated_of cur) = (o, h) :: operations (annotated_of cur') ->
  program_order (annotated_of cur) =
    map (fun u => (o, u)) (op_ids (annotated_of cur')) ++ program_order (annotated_of cur') ->
  owner ev_start = o ->
  kind (payload ev_start) = start_kind h ->
  (ts' = TRunning cur' -> h <> HWaitFlag) ->
  (forall u, In u (map fst inflight') -> In u (map fst inflight) \/ u = o) ->
  (forall u pk, In (u, pk) inflight -> In (u, pk) inflight') ->
  (forall end_of,
     step_comp_ok end_of s ->
     forall tev tuses,
       command_events layout model (cursor_env cur') (annotated_of cur') tev tuses ->
       command_events layout model (cursor_env cur) (annotated_of cur)
         (step_events end_of s ++ tev) (new_uses ++ tuses)) ->
  (forall d args, s = BSCompute o d args -> In (o, PCompute d args) inflight') ->
  (forall o0 d args, s = BSCompute o0 d args -> o0 = o) ->
  nth_error ann j = Some ann_j ->
  branch_inv (records ++ [ev_start]) inflight' j ann_j ts'
    (BranchTrace (bt_steps bt ++ [s]) (bt_uses bt ++ new_uses)).
Proof.
  intros Hnd Hbi Hts' Hhead' Hops Hpo Hov Hks Hnwait Hinf_sub Hinf_mono Hstep_ev Hs_comp Hs_eq Hj.
  pose proof (bi_rem_nodup Hbi) as Hnd_rem. cbn [rem_ops] in Hnd_rem. rewrite Hops in Hnd_rem.
  cbn [map fst] in Hnd_rem. inversion Hnd_rem as [|? ? Ho_notin_rem' Hnd_rem']; clear Hnd_rem.
  assert (Hoh_ann : In (o, h) (operations ann_j)).
  { apply (bi_rem_sub Hbi). cbn [rem_ops]. rewrite Hops. now left. }
  assert (Hoh_prog : In (o, h) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
  assert (Hrem'_eq : rem_ops ts' = operations (annotated_of cur'))
    by (destruct Hts' as [-> | ->]; reflexivity).
  assert (Hpo'_eq : rem_po ts' = program_order (annotated_of cur'))
    by (destruct Hts' as [-> | ->]; reflexivity).
  constructor.
  - destruct Hts' as [-> | ->]; exact Hhead'.
  - intros oh Hin. rewrite Hrem'_eq in Hin. apply (bi_rem_sub Hbi). cbn [rem_ops]. rewrite Hops. now right.
  - rewrite Hrem'_eq. exact Hnd_rem'.
  - intros u Hu. rewrite Hrem'_eq in Hu.
    assert (Hu_old : In u (map fst (rem_ops (TRunning cur)))) by (cbn; rewrite Hops; now right).
    destruct (bi_rem_fresh Hbi u Hu_old) as [Hnr Hni].
    assert (Huo : u <> o) by (intro Heq; subst; contradiction).
    split.
    + rewrite map_app, in_app_iff. intros [Hin | [Heq | []]]; [contradiction |].
      cbn in Heq; congruence.
    + intros Hin. apply Hinf_sub in Hin as [Hin | Heq]; [contradiction | congruence].
  - intros o1 u Hpou Hu. rewrite Hrem'_eq in Hu.
    assert (Hu_old : In u (map fst (rem_ops (TRunning cur)))) by (cbn; rewrite Hops; now right).
    destruct (bi_po_closed Hbi o1 u Hpou Hu_old) as [Hrem | [Hs [Hg | [cur0 Hw]]]].
    + cbn [rem_po] in Hrem. rewrite Hpo, in_app_iff, in_map_iff in Hrem.
      destruct Hrem as [[u' [Heq _]] | Hrem'].
      * inversion Heq; subst o1 u'.
        right; split.
        -- exists ev_start; repeat split; [apply in_app_iff; right; now left | exact Hov | exists h; rewrite Hov; auto].
        -- destruct Hts' as [Hrun | Hwait].
           ++ left. exists ev_start; repeat split; [apply in_app_iff; right; now left | exact Hov |].
              exists h; rewrite Hov; split; [exact Hoh_prog | rewrite non_wait_gate_eq_start by (apply Hnwait; exact Hrun); exact Hks].
           ++ right; exists cur'; exact Hwait.
      * left. rewrite Hpo'_eq. exact Hrem'.
    + right; split; [apply rec_has_phase_snoc; exact Hs | left; apply rec_has_phase_snoc; exact Hg].
    + discriminate Hw.
  - intros end_of Hall.
    apply Forall_app in Hall as [Hall1 Hall2].
    inversion Hall2 as [|? ? Hsok _]; subst.
    assert (Hrun_or_wait :
      forall tev tuses,
        command_events layout model (cursor_env cur') (annotated_of cur') tev tuses ->
        command_events layout model empty_environment ann_j
          (flat_map (step_events end_of) (bt_steps bt ++ [s]) ++ tev)
          ((bt_uses bt ++ new_uses) ++ tuses)).
    { intros tev tuses Hce'.
      rewrite flat_map_app. cbn [flat_map]. rewrite app_nil_r, <- !app_assoc.
      apply (bi_cps Hbi Hall1). apply Hstep_ev; assumption. }
    destruct Hts' as [-> | ->]; exact Hrun_or_wait.
  - intros o0 d args Hin. apply in_app_iff in Hin as [Hin | [Heq | []]].
    + destruct (bi_steps_comp Hbi o0 d args Hin) as [Hi | [res [Hr Hc]]].
      * left; apply Hinf_mono; exact Hi.
      * right; exists res; split; [apply in_app_iff; now left | exact Hc].
    + pose proof (Hs_eq o0 d args Heq) as ->.
      left; apply Hs_comp; exact Heq.
Qed.

(* 主保持定理：auto_step 保持 machine_inv *)
Theorem auto_step_preserves_inv budget st ev st' :
  auto_step layout cfg model Pe Ee budget st ev st' ->
  machine_inv st ->
  machine_inv st'.
Proof.
  intros Hstep Hinv.
  pose proof (annotate_program_valid raw) as [_ Hval_ann].
  pose proof Hval_ann as [Hnd_all Htid_all].
  destruct Hinv as [btraces Hinv].
  destruct Hinv as
    [Hlen_th Hlen_bt Hbr Hpn Huses_eq Huses_st Hrec_val Huniq
     Hinf_nd Hinf_sp H2ph Haw_fwd Hfl Hdv Hmh Hmw Htgt HA1 HA2 HA3 HA5 HAval].
  set (records := rev (ms_rev_trace st)) in *.
  set (inflight := sync_inflight (ms_sync st)) in *.
  destruct Hstep;
    cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val] in *;
    rewrite ?rev_involutive.
  - (* 1. StepAlloc *)
    rename H into Hth, H0 into Hcur, H1 into Haddr, H2 into Hmlook, H3 into Hadv.
    destruct cur as [tid0 path0 rho0 cmd0 stk]; cbn [cursor_stack] in Hcur, Hadv;
      inversion Hcur; subst tid0 path0 rho0 cmd0; clear Hcur. destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
      [| exfalso; apply nth_error_None in Hann_j;
         assert (Hjlt : (j < length (ms_threads st))%nat) by (apply nth_error_Some; congruence); lia].
    destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
      [| exfalso; apply nth_error_None in Hbt_j;
         assert (Hjlt : (j < length (ms_threads st))%nat) by (apply nth_error_Some; congruence); lia].
    pose proof (Hbr j ann_j _ bt_j Hann_j Hth Hbt_j) as Hbi.
    pose proof (refocus_event_head _ _ Hadv) as Hhead'.
    pose proof (refocus_preserves_ops_and_po _ _ Hadv) as [Hops' Hpo'].
    assert (Hops_eq : operations (annotated_of (ThreadCursor tid path rho (Alloc tt x n) stk)) =
                      ((tid, path), HAlloc) :: operations (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_alloc. cbn [label_paths operations].
      f_equal; symmetry; exact Hops'. }
    assert (Hpo_eq : program_order (annotated_of (ThreadCursor tid path rho (Alloc tt x n) stk)) =
                     map (fun u => ((tid, path), u)) (op_ids (annotated_of cur')) ++ program_order (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_alloc. cbn [label_paths program_order]. unfold op_ids. rewrite Hops', Hpo'. reflexivity. }
    assert (Ho_in_rem : In ((tid, path), HAlloc) (rem_ops (TRunning (ThreadCursor tid path rho (Alloc tt x n) stk))))
      by (cbn [rem_ops]; rewrite Hops_eq; now left).
    assert (Ho_in_annj : In ((tid, path), HAlloc) (operations ann_j)) by (apply (bi_rem_sub Hbi); exact Ho_in_rem).
    assert (Ho_in_prog : In ((tid, path), HAlloc) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
    assert (Ho_fresh : ~ In (tid, path) (map owner records) /\ ~ In (tid, path) (map fst inflight)).
    { apply (bi_rem_fresh Hbi). change (tid, path) with (fst ((tid, path), HAlloc)); apply in_map; exact Ho_in_rem. }
    destruct Ho_fresh as [Ho_nrec Ho_ninf].
    set (s := BSAlloc (tid, path) addr).
    set (bt_j' := BranchTrace (bt_steps bt_j ++ [s]) (bt_uses bt_j ++ [])).
    set (btraces' := update_nth j bt_j' btraces).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces'.
    refine (@Build_machine_inv_at btraces' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + unfold btraces'; rewrite length_update_nth; exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite Hann_j in Hann_k; inversion Hann_k; subst ann_k.
        assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        unfold btraces' in Hbt_k; rewrite nth_error_update_nth_eq in Hbt_k by lia.
        inversion Hts_k; inversion Hbt_k; subst ts_k bt_k.
        eapply branch_inv_linear_step with (h := HAlloc);
          try eassumption; try (left; reflexivity); try reflexivity; try discriminate; try auto.
        intros end_of _ tev tuses Hce'.
        unfold annotated_of; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
        rewrite plug_stack_alloc. cbn [label_paths step_events app].
        subst addr. apply EventsAlloc.
        exact (refocus_preserves_command_events _ _ Hadv Hce').
      * unfold btraces' in Hbt_k; rewrite nth_error_update_nth_neq in Hts_k by exact Hneq; rewrite nth_error_update_nth_neq in Hbt_k by exact Hneq.
        eapply preserve_other_branch_inv_issue with (j := j) (ann_j := ann_j);
          try eassumption; try (eapply Hbr; eassumption); auto.
        unfold op_ids; change (owner ev) with (fst ((tid, path), HAlloc)); apply in_map; exact Ho_in_annj.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split; auto.
        - intros o0 res Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 res Hin; apply Hc; apply in_app_iff; now left. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_all_ev]. split.
      * unfold btraces'. eapply perm_trans.
        -- eapply concat_map_update_nth_app_perm with (old := bt_j) (extra := [ev]); [exact Hbt_j |].
           unfold bt_j'; cbn [bt_steps]. rewrite flat_map_app. cbn [flat_map step_events app].
           rewrite app_nil_r. apply Permutation_refl.
        -- eapply perm_trans; [apply Permutation_app_tail; exact Hperm |].
           rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
      * apply (Permutation_NoDup (l := ev :: (records ++ map (pending_end_event end_of) inflight))).
        -- eapply perm_trans; [apply Permutation_cons_append |].
           rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
        -- constructor; [| exact Hnd_all_ev].
           rewrite in_app_iff. intros [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev). apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0. change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
    + intros u. unfold btraces'.
      rewrite (in_concat_update_nth_list_iff bt_uses j bt_j' [] btraces Hbt_j).
      * rewrite Huses_eq; cbn; tauto.
      * intros z; unfold bt_j'; cbn; rewrite app_nil_r; tauto.
    + intros u Hu. apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin. apply in_app_iff in Hin as [Hin | [<- | []]]; [auto |].
      left; exists HAlloc; auto.
    + eapply unique_phase_snoc_fresh; [exact Huniq | exact Ho_nrec].
    + exact Hinf_nd.
    + intros o0 pk0 Hin. destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
      repeat split; [exact H1 | apply in_app_iff; now left | |].
      * intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov [h' [Hh' Hk']]]]; [contradiction |].
        cbn [owner] in Hov; subst o0. apply Ho_ninf.
        change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin.
      * destruct pk0 as [d a | d a data | d args0 | p q fl deps | p q fl bj]; auto.
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
           ++ assert (Hlt1 : (i1 < length records)%nat) by lia.
              rewrite nth_error_app1 in H1' by exact Hlt1.
              destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12); [left; apply rec_has_phase_snoc; auto | right; auto].
           ++ exfalso. cbn [owner] in Ho2; subst o0.
              apply Ho_ninf. exact (in_map fst _ _ Hin).
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (H2ph r h Hin Hh Hne Hk) as [Hend | Hinf]; [left; apply rec_has_phase_snoc; auto | right; exact Hinf].
      * cbn [owner] in Hh. pose proof (ops_unique_head ann Hnd_all Hh Ho_in_prog) as ->. exfalso; apply Hne; reflexivity.
    + intros w p q fl Hw Hnend. apply Haw_fwd with (p := p) (fl := fl).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 res. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc. split; [exact Hmh |].
      unfold memory_step_ok, ev; cbn [payload]. unfold records; rewrite rev_involutive, app_nil_r.
      rewrite <- Hmw. exact Hmlook.
    + intros a. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_in_prog) as ->.
        exfalso; apply Hne0; reflexivity.
    + eapply rec_A2_snoc_start; [exact HA2 | exact Ho_nrec |].
      eapply head_op_po_satisfied; [split; assumption | exact Hann_j | exact Hbi | exact Ho_in_rem |].
      intros o0 Hpo0. cbn [rem_po] in Hpo0. rewrite Hpo_eq, in_app_iff, in_map_iff in Hpo0.
      pose proof (bi_rem_nodup Hbi) as Hnd_r. cbn [rem_ops] in Hnd_r. rewrite Hops_eq in Hnd_r.
      inversion Hnd_r as [|? ? Hni_o _]; subst.
      destruct Hpo0 as [[u [Heq Hu]] | Hpo1].
      * inversion Heq; subst u. contradiction.
      * apply program_order_in_op_ids in Hpo1 as [_ Hu]. contradiction.
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | left; exact Ho_nrec | exact HA3 | discriminate].
    + eapply rec_A5_snoc_start; [exact HA5 | exact Ho_nrec | intros w dst _ Hp; discriminate Hp].
    + change (ms_rev_uses st) with (rev_append [] (ms_rev_uses st)).
      eapply rec_Aval_snoc_issue; [exact HAval | exact Huses_st | exact Hdv | exact Ho_nrec | intros u []].
  - (* 2. StepAtomic *)
    rename H into Hth, H0 into Hcur, H1 into Hres, H2 into Heval, H3 into Hadv.
    destruct cur as [tid0 path0 rho0 cmd0 stk]; cbn [cursor_stack] in Hcur, Hadv;
      inversion Hcur; subst tid0 path0 rho0 cmd0; clear Hcur. destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
      [| exfalso; apply nth_error_None in Hann_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
      [| exfalso; apply nth_error_None in Hbt_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    pose proof (Hbr j ann_j _ bt_j Hann_j Hth Hbt_j) as Hbi.
    pose proof (refocus_event_head _ _ Hadv) as Hhead'.
    pose proof (refocus_preserves_ops_and_po _ _ Hadv) as [Hops' Hpo'].
    apply resolve_operands_rel_to_events in Hres as [Hev_ops Huse_ops].
    assert (Hops_eq : operations (annotated_of (ThreadCursor tid path rho (LetAtomic tt x f vs n) stk)) =
                      ((tid, path), HAtomic) :: operations (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_atomic. cbn [label_paths operations].
      f_equal; symmetry; exact Hops'. }
    assert (Hpo_eq : program_order (annotated_of (ThreadCursor tid path rho (LetAtomic tt x f vs n) stk)) =
                     map (fun u => ((tid, path), u)) (op_ids (annotated_of cur')) ++ program_order (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_atomic. cbn [label_paths program_order]. unfold op_ids. rewrite Hops', Hpo'. reflexivity. }
    assert (Ho_in_rem : In ((tid, path), HAtomic) (rem_ops (TRunning (ThreadCursor tid path rho (LetAtomic tt x f vs n) stk))))
      by (cbn [rem_ops]; rewrite Hops_eq; now left).
    assert (Ho_in_annj : In ((tid, path), HAtomic) (operations ann_j)) by (apply (bi_rem_sub Hbi); exact Ho_in_rem).
    assert (Ho_in_prog : In ((tid, path), HAtomic) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
    assert (Ho_fresh : ~ In (tid, path) (map owner records) /\ ~ In (tid, path) (map fst inflight)).
    { apply (bi_rem_fresh Hbi). change (tid, path) with (fst ((tid, path), HAtomic)); apply in_map; exact Ho_in_rem. }
    destruct Ho_fresh as [Ho_nrec Ho_ninf].
    set (s := BSAtomic (tid, path) f args res).
    set (bt_j' := BranchTrace (bt_steps bt_j ++ [s]) (bt_uses bt_j ++ uses)).
    set (btraces' := update_nth j bt_j' btraces).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces'.
    refine (@Build_machine_inv_at btraces' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + unfold btraces'; rewrite length_update_nth; exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite Hann_j in Hann_k; inversion Hann_k; subst ann_k.
        assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        unfold btraces' in Hbt_k; rewrite nth_error_update_nth_eq in Hbt_k by lia.
        inversion Hts_k; inversion Hbt_k; subst ts_k bt_k.
        eapply branch_inv_linear_step with (h := HAtomic);
          try eassumption; try (left; reflexivity); try reflexivity; try discriminate; try auto.
        intros end_of _ tev tuses Hce'.
        unfold annotated_of; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
        rewrite plug_stack_atomic. cbn [label_paths step_events app].
        eapply EventsAtomic; [exact Hev_ops | exact Heval |].
        exact (refocus_preserves_command_events _ _ Hadv Hce').
      * unfold btraces' in Hbt_k; rewrite nth_error_update_nth_neq in Hts_k by exact Hneq; rewrite nth_error_update_nth_neq in Hbt_k by exact Hneq.
        eapply preserve_other_branch_inv_issue with (j := j) (ann_j := ann_j);
          try eassumption; try (eapply Hbr; eassumption); auto.
        unfold op_ids; change (owner ev) with (fst ((tid, path), HAtomic)); apply in_map; exact Ho_in_annj.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split; auto;
          intros o0 r0 Hin; [apply Hr | apply Hc]; apply in_app_iff; now left. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_all_ev]. split.
      * unfold btraces'. eapply perm_trans.
        -- eapply concat_map_update_nth_app_perm with (old := bt_j) (extra := [ev]); [exact Hbt_j |].
           unfold bt_j'; cbn [bt_steps]. rewrite flat_map_app. cbn [flat_map step_events app].
           rewrite app_nil_r. apply Permutation_refl.
        -- eapply perm_trans; [apply Permutation_app_tail; exact Hperm |].
           rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
      * apply (Permutation_NoDup (l := ev :: (records ++ map (pending_end_event end_of) inflight))).
        -- eapply perm_trans; [apply Permutation_cons_append |].
           rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
        -- constructor; [| exact Hnd_all_ev].
           rewrite in_app_iff. intros [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev). apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0. change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
    + intros u. unfold btraces'.
      rewrite (in_concat_update_nth_list_iff bt_uses j bt_j' uses btraces Hbt_j).
      * rewrite Huses_eq, in_rev_append; tauto.
      * intros z; unfold bt_j'; cbn; rewrite in_app_iff; tauto.
    + intros u Hu. apply in_rev_append in Hu as [Hu | Hu].
      * apply Huse_ops in Hu as [Hcons _].
        exists ev; repeat split; [apply in_app_iff; right; now left | symmetry; exact Hcons | exists HAtomic; auto].
      * apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin. apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | left; exists HAtomic; auto].
    + eapply unique_phase_snoc_fresh; [exact Huniq | exact Ho_nrec].
    + exact Hinf_nd.
    + intros o0 pk0 Hin. destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
      repeat split; [exact H1 | apply in_app_iff; now left | |].
      * intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction |].
        cbn [owner] in Hov; subst o0. apply Ho_ninf.
        change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin.
      * destruct pk0 as [d a | d a data | d args0 | p q fl deps | p q fl bj]; auto.
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
           ++ assert (Hlt1 : (i1 < length records)%nat) by lia.
              rewrite nth_error_app1 in H1' by exact Hlt1.
              destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12); [left; apply rec_has_phase_snoc; auto | right; auto].
           ++ exfalso. cbn [owner] in Ho2; subst o0.
              apply Ho_ninf. exact (in_map fst _ _ Hin).
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (H2ph r h Hin Hh Hne Hk) as [Hend | Hinf]; [left; apply rec_has_phase_snoc; auto | right; exact Hinf].
      * cbn [owner] in Hh. pose proof (ops_unique_head ann Hnd_all Hh Ho_in_prog) as ->. exfalso; apply Hne; reflexivity.
    + intros w p q fl Hw Hnend. apply Haw_fwd with (p := p) (fl := fl).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_in_prog) as ->.
        exfalso; apply Hne0; reflexivity.
    + eapply rec_A2_snoc_start; [exact HA2 | exact Ho_nrec |].
      eapply head_op_po_satisfied; [split; assumption | exact Hann_j | exact Hbi | exact Ho_in_rem |].
      intros o0 Hpo0. cbn [rem_po] in Hpo0. rewrite Hpo_eq, in_app_iff, in_map_iff in Hpo0.
      pose proof (bi_rem_nodup Hbi) as Hnd_r. cbn [rem_ops] in Hnd_r. rewrite Hops_eq in Hnd_r.
      inversion Hnd_r as [|? ? Hni_o _]; subst.
      destruct Hpo0 as [[u [Heq Hu]] | Hpo1]; [inversion Heq; subst u; contradiction |].
      apply program_order_in_op_ids in Hpo1 as [_ Hu]; contradiction.
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | left; exact Ho_nrec | exact HA3 | discriminate].
    + eapply rec_A5_snoc_start; [exact HA5 | exact Ho_nrec | intros w dst _ Hp; discriminate Hp].
    + eapply rec_Aval_snoc_issue; [exact HAval | exact Huses_st | exact Hdv | exact Ho_nrec | exact Huse_ops].
  - (* 3. StepAssignPipe *)
    rename H into Hth, H0 into Hcur, H1 into Hres, H2 into Hdecl, H3 into Hadv.
    destruct cur as [tid0 path0 rho0 cmd0 stk]; cbn [cursor_stack] in Hcur, Hadv;
      inversion Hcur; subst tid0 path0 rho0 cmd0; clear Hcur. destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
      [| exfalso; apply nth_error_None in Hann_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
      [| exfalso; apply nth_error_None in Hbt_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    pose proof (Hbr j ann_j _ bt_j Hann_j Hth Hbt_j) as Hbi.
    pose proof (refocus_event_head _ _ Hadv) as Hhead'.
    pose proof (refocus_preserves_ops_and_po _ _ Hadv) as [Hops' Hpo'].
    apply resolve_operand_rel_to_events in Hres as [Hev_op Huse_op].
    assert (Hops_eq : operations (annotated_of (ThreadCursor tid path rho (AssignPipe tt x v n) stk)) =
                      ((tid, path), HAssignPipe) :: operations (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_assign_pipe. cbn [label_paths operations].
      f_equal; symmetry; exact Hops'. }
    assert (Hpo_eq : program_order (annotated_of (ThreadCursor tid path rho (AssignPipe tt x v n) stk)) =
                     map (fun u => ((tid, path), u)) (op_ids (annotated_of cur')) ++ program_order (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_assign_pipe. cbn [label_paths program_order]. unfold op_ids. rewrite Hops', Hpo'. reflexivity. }
    assert (Ho_in_rem : In ((tid, path), HAssignPipe) (rem_ops (TRunning (ThreadCursor tid path rho (AssignPipe tt x v n) stk))))
      by (cbn [rem_ops]; rewrite Hops_eq; now left).
    assert (Ho_in_annj : In ((tid, path), HAssignPipe) (operations ann_j)) by (apply (bi_rem_sub Hbi); exact Ho_in_rem).
    assert (Ho_in_prog : In ((tid, path), HAssignPipe) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
    assert (Ho_fresh : ~ In (tid, path) (map owner records) /\ ~ In (tid, path) (map fst inflight)).
    { apply (bi_rem_fresh Hbi). change (tid, path) with (fst ((tid, path), HAssignPipe)); apply in_map; exact Ho_in_rem. }
    destruct Ho_fresh as [Ho_nrec Ho_ninf].
    set (s := BSAssignPipe (tid, path) x p).
    set (bt_j' := BranchTrace (bt_steps bt_j ++ [s]) (bt_uses bt_j ++ uses)).
    set (btraces' := update_nth j bt_j' btraces).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces'.
    refine (@Build_machine_inv_at btraces' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + unfold btraces'; rewrite length_update_nth; exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite Hann_j in Hann_k; inversion Hann_k; subst ann_k.
        assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        unfold btraces' in Hbt_k; rewrite nth_error_update_nth_eq in Hbt_k by lia.
        inversion Hts_k; inversion Hbt_k; subst ts_k bt_k.
        eapply branch_inv_linear_step with (h := HAssignPipe);
          try eassumption; try (left; reflexivity); try reflexivity; try discriminate; try auto.
        intros end_of _ tev tuses Hce'.
        unfold annotated_of; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
        rewrite plug_stack_assign_pipe. cbn [label_paths step_events app].
        eapply EventsAssignPipe; [exact Hev_op |].
        exact (refocus_preserves_command_events _ _ Hadv Hce').
      * unfold btraces' in Hbt_k; rewrite nth_error_update_nth_neq in Hts_k by exact Hneq; rewrite nth_error_update_nth_neq in Hbt_k by exact Hneq.
        eapply preserve_other_branch_inv_issue with (j := j) (ann_j := ann_j);
          try eassumption; try (eapply Hbr; eassumption); auto.
        unfold op_ids; change (owner ev) with (fst ((tid, path), HAssignPipe)); apply in_map; exact Ho_in_annj.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split; auto;
          intros o0 r0 Hin; [apply Hr | apply Hc]; apply in_app_iff; now left. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_all_ev]. split.
      * unfold btraces'. eapply perm_trans.
        -- eapply concat_map_update_nth_app_perm with (old := bt_j) (extra := [ev]); [exact Hbt_j |].
           unfold bt_j'; cbn [bt_steps]. rewrite flat_map_app. cbn [flat_map step_events app].
           rewrite app_nil_r. apply Permutation_refl.
        -- eapply perm_trans; [apply Permutation_app_tail; exact Hperm |].
           rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
      * apply (Permutation_NoDup (l := ev :: (records ++ map (pending_end_event end_of) inflight))).
        -- eapply perm_trans; [apply Permutation_cons_append |].
           rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
        -- constructor; [| exact Hnd_all_ev].
           rewrite in_app_iff. intros [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev). apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0. change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
    + intros u. unfold btraces'.
      rewrite (in_concat_update_nth_list_iff bt_uses j bt_j' uses btraces Hbt_j).
      * rewrite Huses_eq, in_rev_append; tauto.
      * intros z; unfold bt_j'; cbn; rewrite in_app_iff; tauto.
    + intros u Hu. apply in_rev_append in Hu as [Hu | Hu].
      * apply Huse_op in Hu as [Hcons _].
        exists ev; repeat split; [apply in_app_iff; right; now left | symmetry; exact Hcons | exists HAssignPipe; auto].
      * apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin. apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | left; exists HAssignPipe; auto].
    + eapply unique_phase_snoc_fresh; [exact Huniq | exact Ho_nrec].
    + exact Hinf_nd.
    + intros o0 pk0 Hin. destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
      repeat split; [exact H1 | apply in_app_iff; now left | |].
      * intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction |].
        cbn [owner] in Hov; subst o0. apply Ho_ninf.
        change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin.
      * destruct pk0 as [d a | d a data | d args | p0 q fl deps | p0 q fl bj]; auto.
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
           ++ assert (Hlt1 : (i1 < length records)%nat) by lia.
              rewrite nth_error_app1 in H1' by exact Hlt1.
              destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12); [left; apply rec_has_phase_snoc; auto | right; auto].
           ++ exfalso. cbn [owner] in Ho2; subst o0.
              apply Ho_ninf. exact (in_map fst _ _ Hin).
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (H2ph r h Hin Hh Hne Hk) as [Hend | Hinf]; [left; apply rec_has_phase_snoc; auto | right; exact Hinf].
      * cbn [owner] in Hh. pose proof (ops_unique_head ann Hnd_all Hh Ho_in_prog) as ->. exfalso; apply Hne; reflexivity.
    + intros w p0 q fl Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor; exact Hdecl].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_in_prog) as ->.
        exfalso; apply Hne0; reflexivity.
    + eapply rec_A2_snoc_start; [exact HA2 | exact Ho_nrec |].
      eapply head_op_po_satisfied; [split; assumption | exact Hann_j | exact Hbi | exact Ho_in_rem |].
      intros o0 Hpo0. cbn [rem_po] in Hpo0. rewrite Hpo_eq, in_app_iff, in_map_iff in Hpo0.
      pose proof (bi_rem_nodup Hbi) as Hnd_r. cbn [rem_ops] in Hnd_r. rewrite Hops_eq in Hnd_r.
      inversion Hnd_r as [|? ? Hni_o _]; subst.
      destruct Hpo0 as [[u [Heq Hu]] | Hpo1]; [inversion Heq; subst u; contradiction |].
      apply program_order_in_op_ids in Hpo1 as [_ Hu]; contradiction.
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | left; exact Ho_nrec | exact HA3 | discriminate].
    + eapply rec_A5_snoc_start; [exact HA5 | exact Ho_nrec | intros w dst _ Hp; discriminate Hp].
    + eapply rec_Aval_snoc_issue; [exact HAval | exact Huses_st | exact Hdv | exact Ho_nrec | exact Huse_op].
  - (* 4. StepReadStart *)
    rename H into Hth, H0 into Hcur, H1 into Hres, H2 into Hdecl, H3 into Hread, H4 into Hpr, H5 into Hadv.
    destruct cur as [tid0 path0 rho0 cmd0 stk]; cbn [cursor_stack] in Hcur, Hadv;
      inversion Hcur; subst tid0 path0 rho0 cmd0; clear Hcur. destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
      [| exfalso; apply nth_error_None in Hann_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
      [| exfalso; apply nth_error_None in Hbt_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    pose proof (Hbr j ann_j _ bt_j Hann_j Hth Hbt_j) as Hbi.
    pose proof (refocus_event_head _ _ Hadv) as Hhead'.
    pose proof (refocus_preserves_ops_and_po _ _ Hadv) as [Hops' Hpo'].
    apply resolve_exec_rel_to_events in Hres as [Hev_ex Huse_ex].
    assert (Hops_eq : operations (annotated_of (ThreadCursor tid path rho (Read tt x d v n) stk)) =
                      ((tid, path), HRead) :: operations (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_read. cbn [label_paths operations].
      f_equal; symmetry; exact Hops'. }
    assert (Hpo_eq : program_order (annotated_of (ThreadCursor tid path rho (Read tt x d v n) stk)) =
                     map (fun u => ((tid, path), u)) (op_ids (annotated_of cur')) ++ program_order (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_read. cbn [label_paths program_order]. unfold op_ids. rewrite Hops', Hpo'. reflexivity. }
    assert (Ho_in_rem : In ((tid, path), HRead) (rem_ops (TRunning (ThreadCursor tid path rho (Read tt x d v n) stk))))
      by (cbn [rem_ops]; rewrite Hops_eq; now left).
    assert (Ho_in_annj : In ((tid, path), HRead) (operations ann_j)) by (apply (bi_rem_sub Hbi); exact Ho_in_rem).
    assert (Ho_in_prog : In ((tid, path), HRead) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
    assert (Ho_fresh : ~ In (tid, path) (map owner records) /\ ~ In (tid, path) (map fst inflight)).
    { apply (bi_rem_fresh Hbi). change (tid, path) with (fst ((tid, path), HRead)); apply in_map; exact Ho_in_rem. }
    destruct Ho_fresh as [Ho_nrec Ho_ninf].
    set (s := BSRead (tid, path) disp a).
    set (bt_j' := BranchTrace (bt_steps bt_j ++ [s]) (bt_uses bt_j ++ uses)).
    set (btraces' := update_nth j bt_j' btraces).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces'.
    refine (@Build_machine_inv_at btraces' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + unfold btraces'; rewrite length_update_nth; exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite Hann_j in Hann_k; inversion Hann_k; subst ann_k.
        assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        unfold btraces' in Hbt_k; rewrite nth_error_update_nth_eq in Hbt_k by lia.
        inversion Hts_k; inversion Hbt_k; subst ts_k bt_k.
        eapply branch_inv_linear_step with (h := HRead);
          try eassumption; try (left; reflexivity); try reflexivity; try discriminate; try (intros; discriminate).
        -- intros u Hin; cbn in Hin; destruct Hin as [<- | Hin]; [right; reflexivity | left; exact Hin].
        -- intros u pk Hin; cbn; right; exact Hin.
        -- intros end_of _ tev tuses Hce'.
           unfold annotated_of; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
           rewrite plug_stack_read. cbn [label_paths step_events app].
           eapply EventsRead; [exact Hev_ex |].
           exact (refocus_preserves_command_events _ _ Hadv Hce').
      * unfold btraces' in Hbt_k; rewrite nth_error_update_nth_neq in Hts_k by exact Hneq; rewrite nth_error_update_nth_neq in Hbt_k by exact Hneq.
        eapply preserve_other_branch_inv_issue with (j := j) (ann_j := ann_j);
          try eassumption; try (eapply Hbr; eassumption); auto.
        -- unfold op_ids; change (owner ev) with (fst ((tid, path), HRead)); apply in_map; exact Ho_in_annj.
        -- intros u Hin; cbn in Hin; destruct Hin as [<- | Hin]; [right; reflexivity | left; exact Hin].
        -- intros u pk Hin; cbn; right; exact Hin.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split.
        - intros o0 res Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 res Hin; apply Hc; apply in_app_iff; now left.
        - intros o0 d0 args0 Hin; apply Hinfc; now right. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_all_ev].
      set (ev_end := @EventRecord Float EventId Pipe Unit (tid, path) (LReadEnd (end_of (tid, path)))).
      assert (Hperm_rhs :
        Permutation ((records ++ [ev]) ++ ev_end :: map (pending_end_event end_of) inflight)
                    (ev :: ev_end :: (records ++ map (pending_end_event end_of) inflight))).
      { rewrite <- app_assoc.
        eapply perm_trans; [apply Permutation_app_comm |].
        cbn [app]. apply perm_skip. apply perm_skip. apply Permutation_app_comm. }
      split.
      * unfold btraces'. eapply perm_trans.
        -- eapply concat_map_update_nth_app_perm with (old := bt_j) (extra := [ev; ev_end]); [exact Hbt_j |].
           unfold bt_j'; cbn [bt_steps]. rewrite flat_map_app. cbn [flat_map step_events app].
           rewrite app_nil_r. apply Permutation_refl.
        -- eapply perm_trans; [apply Permutation_app_tail; exact Hperm |].
           eapply perm_trans; [apply Permutation_app_comm |].
           apply Permutation_sym; exact Hperm_rhs.
      * apply (Permutation_NoDup (Permutation_sym Hperm_rhs)).
        constructor.
        -- intros [Heq | Hin]; [discriminate Heq |].
           rewrite in_app_iff in Hin. destruct Hin as [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
        -- constructor; [| exact Hnd_all_ev].
           rewrite in_app_iff. intros [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev_end); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
    + intros u. unfold btraces'.
      rewrite (in_concat_update_nth_list_iff bt_uses j bt_j' uses btraces Hbt_j).
      * rewrite Huses_eq, in_rev_append; tauto.
      * intros z; unfold bt_j'; cbn; rewrite in_app_iff; tauto.
    + intros u Hu. apply in_rev_append in Hu as [Hu | Hu].
      * apply Huse_ex in Hu as [Hcons _].
        exists ev; repeat split; [apply in_app_iff; right; now left | symmetry; exact Hcons | exists HRead; auto].
      * apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin. apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | left; exists HRead; auto].
    + eapply unique_phase_snoc_fresh; [exact Huniq | exact Ho_nrec].
    + cbn; constructor; assumption.
    + intros o0 pk0 [Heq | Hin].
      * inversion Heq; subst o0 pk0. repeat split.
        -- exact Ho_in_prog.
        -- apply in_app_iff; right; now left.
        -- intros Hend. apply rec_has_phase_snoc_inv in Hend as [[r [Hr [Hor _]]] | [_ [h' [Hh' Hk']]]].
           ++ apply Ho_nrec. change (tid, path) with o; rewrite <- Hor; apply in_map; exact Hr.
           ++ pose proof (ops_unique_head ann Hnd_all Hh' Ho_in_prog) as ->. discriminate Hk'.
        -- apply prior_start_cons_read.
      * destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
        assert (Hne_o : (tid, path) <> o0).
        { intro E; subst o0; apply Ho_ninf; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin. }
        repeat split; [exact H1 | apply in_app_iff; now left | |].
        -- intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction |].
           cbn [owner] in Hov; contradiction.
        -- destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
           ++ rewrite prior_start_cons_other; [exact H4 | left; exact Hne_o].
           ++ rewrite prior_start_cons_other; [exact H4 | left; exact Hne_o].
           ++ intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
              apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
              ** assert (Hlt1 : (i1 < length records)%nat) by lia.
                 rewrite nth_error_app1 in H1' by exact Hlt1.
                 destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12);
                   [left; apply rec_has_phase_snoc; auto | right; auto].
              ** exfalso; cbn [owner] in Ho2; contradiction.
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (H2ph r h Hin Hh Hne Hk) as [Hend | [pk [Hpk Hpp]]];
          [left; apply rec_has_phase_snoc; auto | right; exists pk; split; [now right | exact Hpp]].
      * right. exists (PRead disp a). split; [now left | reflexivity].
    + intros w p0 q0 fl0 Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl0).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor; auto].
      destruct p as [q|]; [exact (proj1 Hpr) | exact I].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_in_prog) as ->.
        discriminate Hk0.
    + eapply rec_A2_snoc_start; [exact HA2 | exact Ho_nrec |].
      eapply head_op_po_satisfied; [split; assumption | exact Hann_j | exact Hbi | exact Ho_in_rem |].
      intros o0 Hpo0. cbn [rem_po] in Hpo0. rewrite Hpo_eq, in_app_iff, in_map_iff in Hpo0.
      pose proof (bi_rem_nodup Hbi) as Hnd_r. cbn [rem_ops] in Hnd_r. rewrite Hops_eq in Hnd_r.
      inversion Hnd_r as [|? ? Hni_o _]; subst.
      destruct Hpo0 as [[u [Heq Hu]] | Hpo1]; [inversion Heq; subst u; contradiction |].
      apply program_order_in_op_ids in Hpo1 as [_ Hu]; contradiction.
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | left; exact Ho_nrec | exact HA3 | discriminate].
    + eapply rec_A5_snoc_start; [exact HA5 | exact Ho_nrec |].
      intros w dst Hw Hpe [r1 [Hr1 [How [[h1 [Hh1 Hk1]] Hp1]]]].
      unfold ev, disp in Hpe; cbn [payload pipeline queue] in Hpe. subst p.
      destruct Hpr as [_ Haw_none].
      rewrite How in Hh1. pose proof (ops_unique_head ann Hnd_all Hh1 Hw) as ->.
      destruct r1 as [o1 pl1]; cbn in *; subst o1.
      destruct pl1; try discriminate Hk1. cbn in Hp1; inversion Hp1; subst q.
      destruct (H2ph (EventRecord w (LWaitFlagStart p dst flag)) HWaitFlag Hr1 Hw ltac:(discriminate) eq_refl)
        as [[rw [Hrw [Horw [hw [Hhw Hkw]]]]] | [pk [Hpk _]]].
      * rewrite Horw in Hhw. pose proof (ops_unique_head ann Hnd_all Hhw Hw) as ->.
        exists rw; repeat split; assumption.
      * exfalso. destruct (Hinf_sp w pk Hpk) as [_ [_ [Hnend _]]].
        pose proof (Haw_fwd w p dst flag Hr1 Hnend) as Hsome. congruence.
    + eapply rec_Aval_snoc_issue; [exact HAval | exact Huses_st | exact Hdv | exact Ho_nrec | exact Huse_ex].
  - (* 5. StepWriteStart *)
    rename H into Hth, H0 into Hcur, H1 into Hres, H2 into Hdecl, H3 into Hwrite, H4 into Hpr, H5 into Hadv.
    destruct cur as [tid0 path0 rho0 cmd0 stk]; cbn [cursor_stack] in Hcur, Hadv;
      inversion Hcur; subst tid0 path0 rho0 cmd0; clear Hcur. destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
      [| exfalso; apply nth_error_None in Hann_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
      [| exfalso; apply nth_error_None in Hbt_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    pose proof (Hbr j ann_j _ bt_j Hann_j Hth Hbt_j) as Hbi.
    pose proof (refocus_event_head _ _ Hadv) as Hhead'.
    pose proof (refocus_preserves_ops_and_po _ _ Hadv) as [Hops' Hpo'].
    apply resolve_exec_rel_to_events in Hres as [Hev_ex Huse_ex].
    assert (Hops_eq : operations (annotated_of (ThreadCursor tid path rho (Write tt d v1 v2 n) stk)) =
                      ((tid, path), HWrite) :: operations (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_write. cbn [label_paths operations].
      f_equal; symmetry; exact Hops'. }
    assert (Hpo_eq : program_order (annotated_of (ThreadCursor tid path rho (Write tt d v1 v2 n) stk)) =
                     map (fun u => ((tid, path), u)) (op_ids (annotated_of cur')) ++ program_order (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_write. cbn [label_paths program_order]. unfold op_ids. rewrite Hops', Hpo'. reflexivity. }
    assert (Ho_in_rem : In ((tid, path), HWrite) (rem_ops (TRunning (ThreadCursor tid path rho (Write tt d v1 v2 n) stk))))
      by (cbn [rem_ops]; rewrite Hops_eq; now left).
    assert (Ho_in_annj : In ((tid, path), HWrite) (operations ann_j)) by (apply (bi_rem_sub Hbi); exact Ho_in_rem).
    assert (Ho_in_prog : In ((tid, path), HWrite) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
    assert (Ho_fresh : ~ In (tid, path) (map owner records) /\ ~ In (tid, path) (map fst inflight)).
    { apply (bi_rem_fresh Hbi). change (tid, path) with (fst ((tid, path), HWrite)); apply in_map; exact Ho_in_rem. }
    destruct Ho_fresh as [Ho_nrec Ho_ninf].
    set (s := BSWrite (tid, path) disp a data).
    set (bt_j' := BranchTrace (bt_steps bt_j ++ [s]) (bt_uses bt_j ++ uses)).
    set (btraces' := update_nth j bt_j' btraces).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces'.
    refine (@Build_machine_inv_at btraces' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + unfold btraces'; rewrite length_update_nth; exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite Hann_j in Hann_k; inversion Hann_k; subst ann_k.
        assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        unfold btraces' in Hbt_k; rewrite nth_error_update_nth_eq in Hbt_k by lia.
        inversion Hts_k; inversion Hbt_k; subst ts_k bt_k.
        eapply branch_inv_linear_step with (h := HWrite);
          try eassumption; try (left; reflexivity); try reflexivity; try discriminate; try (intros; discriminate).
        -- intros u Hin; cbn in Hin; destruct Hin as [<- | Hin]; [right; reflexivity | left; exact Hin].
        -- intros u pk Hin; cbn; right; exact Hin.
        -- intros end_of _ tev tuses Hce'.
           unfold annotated_of; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
           rewrite plug_stack_write. cbn [label_paths step_events app].
           eapply EventsWrite; [exact Hev_ex |].
           exact (refocus_preserves_command_events _ _ Hadv Hce').
      * unfold btraces' in Hbt_k; rewrite nth_error_update_nth_neq in Hts_k by exact Hneq; rewrite nth_error_update_nth_neq in Hbt_k by exact Hneq.
        eapply preserve_other_branch_inv_issue with (j := j) (ann_j := ann_j);
          try eassumption; try (eapply Hbr; eassumption); auto.
        -- unfold op_ids; change (owner ev) with (fst ((tid, path), HWrite)); apply in_map; exact Ho_in_annj.
        -- intros u Hin; cbn in Hin; destruct Hin as [<- | Hin]; [right; reflexivity | left; exact Hin].
        -- intros u pk Hin; cbn; right; exact Hin.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split.
        - intros o0 res Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 res Hin; apply Hc; apply in_app_iff; now left.
        - intros o0 d0 args0 Hin; apply Hinfc; now right. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_all_ev].
      set (ev_end := @EventRecord Float EventId Pipe Unit (tid, path) LWriteEnd).
      assert (Hperm_rhs :
        Permutation ((records ++ [ev]) ++ ev_end :: map (pending_end_event end_of) inflight)
                    (ev :: ev_end :: (records ++ map (pending_end_event end_of) inflight))).
      { rewrite <- app_assoc.
        eapply perm_trans; [apply Permutation_app_comm |].
        cbn [app]. apply perm_skip. apply perm_skip. apply Permutation_app_comm. }
      split.
      * unfold btraces'. eapply perm_trans.
        -- eapply concat_map_update_nth_app_perm with (old := bt_j) (extra := [ev; ev_end]); [exact Hbt_j |].
           unfold bt_j'; cbn [bt_steps]. rewrite flat_map_app. cbn [flat_map step_events app].
           rewrite app_nil_r. apply Permutation_refl.
        -- eapply perm_trans; [apply Permutation_app_tail; exact Hperm |].
           eapply perm_trans; [apply Permutation_app_comm |].
           apply Permutation_sym; exact Hperm_rhs.
      * apply (Permutation_NoDup (Permutation_sym Hperm_rhs)).
        constructor.
        -- intros [Heq | Hin]; [discriminate Heq |].
           rewrite in_app_iff in Hin. destruct Hin as [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
        -- constructor; [| exact Hnd_all_ev].
           rewrite in_app_iff. intros [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev_end); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
    + intros u. unfold btraces'.
      rewrite (in_concat_update_nth_list_iff bt_uses j bt_j' uses btraces Hbt_j).
      * rewrite Huses_eq, in_rev_append; tauto.
      * intros z; unfold bt_j'; cbn; rewrite in_app_iff; tauto.
    + intros u Hu. apply in_rev_append in Hu as [Hu | Hu].
      * apply Huse_ex in Hu as [Hcons _].
        exists ev; repeat split; [apply in_app_iff; right; now left | symmetry; exact Hcons | exists HWrite; auto].
      * apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin. apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | left; exists HWrite; auto].
    + eapply unique_phase_snoc_fresh; [exact Huniq | exact Ho_nrec].
    + cbn; constructor; assumption.
    + intros o0 pk0 [Heq | Hin].
      * inversion Heq; subst o0 pk0. repeat split.
        -- exact Ho_in_prog.
        -- apply in_app_iff; right; now left.
        -- intros Hend. apply rec_has_phase_snoc_inv in Hend as [[r [Hr [Hor _]]] | [_ [h' [Hh' Hk']]]].
           ++ apply Ho_nrec. change (tid, path) with o; rewrite <- Hor; apply in_map; exact Hr.
           ++ pose proof (ops_unique_head ann Hnd_all Hh' Ho_in_prog) as ->. discriminate Hk'.
        -- apply prior_start_cons_write.
      * destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
        assert (Hne_o : (tid, path) <> o0).
        { intro E; subst o0; apply Ho_ninf; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin. }
        repeat split; [exact H1 | apply in_app_iff; now left | |].
        -- intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction |].
           cbn [owner] in Hov; contradiction.
        -- destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
           ++ rewrite prior_start_cons_other; [exact H4 | left; exact Hne_o].
           ++ rewrite prior_start_cons_other; [exact H4 | left; exact Hne_o].
           ++ intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
              apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
              ** assert (Hlt1 : (i1 < length records)%nat) by lia.
                 rewrite nth_error_app1 in H1' by exact Hlt1.
                 destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12);
                   [left; apply rec_has_phase_snoc; auto | right; auto].
              ** exfalso; cbn [owner] in Ho2; contradiction.
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (H2ph r h Hin Hh Hne Hk) as [Hend | [pk [Hpk Hpp]]];
          [left; apply rec_has_phase_snoc; auto | right; exists pk; split; [now right | exact Hpp]].
      * right. exists (PWrite disp a data). split; [now left | reflexivity].
    + intros w p0 q0 fl0 Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl0).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor; auto].
      destruct p as [q|]; [exact (proj1 Hpr) | exact I].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_in_prog) as ->.
        discriminate Hk0.
    + eapply rec_A2_snoc_start; [exact HA2 | exact Ho_nrec |].
      eapply head_op_po_satisfied; [split; assumption | exact Hann_j | exact Hbi | exact Ho_in_rem |].
      intros o0 Hpo0. cbn [rem_po] in Hpo0. rewrite Hpo_eq, in_app_iff, in_map_iff in Hpo0.
      pose proof (bi_rem_nodup Hbi) as Hnd_r. cbn [rem_ops] in Hnd_r. rewrite Hops_eq in Hnd_r.
      inversion Hnd_r as [|? ? Hni_o _]; subst.
      destruct Hpo0 as [[u [Heq Hu]] | Hpo1]; [inversion Heq; subst u; contradiction |].
      apply program_order_in_op_ids in Hpo1 as [_ Hu]; contradiction.
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | left; exact Ho_nrec | exact HA3 | discriminate].
    + eapply rec_A5_snoc_start; [exact HA5 | exact Ho_nrec |].
      intros w dst Hw Hpe [r1 [Hr1 [How [[h1 [Hh1 Hk1]] Hp1]]]].
      unfold ev, disp in Hpe; cbn [payload pipeline queue] in Hpe. subst p.
      destruct Hpr as [_ Haw_none].
      rewrite How in Hh1. pose proof (ops_unique_head ann Hnd_all Hh1 Hw) as ->.
      destruct r1 as [o1 pl1]; cbn in *; subst o1.
      destruct pl1; try discriminate Hk1. cbn in Hp1; inversion Hp1; subst q.
      destruct (H2ph (EventRecord w (LWaitFlagStart p dst flag)) HWaitFlag Hr1 Hw ltac:(discriminate) eq_refl)
        as [[rw [Hrw [Horw [hw [Hhw Hkw]]]]] | [pk [Hpk _]]].
      * rewrite Horw in Hhw. pose proof (ops_unique_head ann Hnd_all Hhw Hw) as ->.
        exists rw; repeat split; assumption.
      * exfalso. destruct (Hinf_sp w pk Hpk) as [_ [_ [Hnend _]]].
        pose proof (Haw_fwd w p dst flag Hr1 Hnend) as Hsome. congruence.
    + eapply rec_Aval_snoc_issue; [exact HAval | exact Huses_st | exact Hdv | exact Ho_nrec | exact Huse_ex].
  - (* 6. StepComputeStart *)
    rename H into Hth, H0 into Hcur, H1 into Hres, H2 into Hdecl, H3 into Hpr, H4 into Hadv.
    destruct cur as [tid0 path0 rho0 cmd0 stk]; cbn [cursor_stack] in Hcur, Hadv;
      inversion Hcur; subst tid0 path0 rho0 cmd0; clear Hcur. destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
      [| exfalso; apply nth_error_None in Hann_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
      [| exfalso; apply nth_error_None in Hbt_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    pose proof (Hbr j ann_j _ bt_j Hann_j Hth Hbt_j) as Hbi.
    pose proof (refocus_event_head _ _ Hadv) as Hhead'.
    pose proof (refocus_preserves_ops_and_po _ _ Hadv) as [Hops' Hpo'].
    apply resolve_exec_rel_to_events in Hres as [Hev_ex Huse_ex].
    assert (Hops_eq : operations (annotated_of (ThreadCursor tid path rho (CCompute tt x d vs n) stk)) =
                      ((tid, path), HCompute) :: operations (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_compute. cbn [label_paths operations].
      f_equal; symmetry; exact Hops'. }
    assert (Hpo_eq : program_order (annotated_of (ThreadCursor tid path rho (CCompute tt x d vs n) stk)) =
                     map (fun u => ((tid, path), u)) (op_ids (annotated_of cur')) ++ program_order (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_compute. cbn [label_paths program_order]. unfold op_ids. rewrite Hops', Hpo'. reflexivity. }
    assert (Ho_in_rem : In ((tid, path), HCompute) (rem_ops (TRunning (ThreadCursor tid path rho (CCompute tt x d vs n) stk))))
      by (cbn [rem_ops]; rewrite Hops_eq; now left).
    assert (Ho_in_annj : In ((tid, path), HCompute) (operations ann_j)) by (apply (bi_rem_sub Hbi); exact Ho_in_rem).
    assert (Ho_in_prog : In ((tid, path), HCompute) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
    assert (Ho_fresh : ~ In (tid, path) (map owner records) /\ ~ In (tid, path) (map fst inflight)).
    { apply (bi_rem_fresh Hbi). change (tid, path) with (fst ((tid, path), HCompute)); apply in_map; exact Ho_in_rem. }
    destruct Ho_fresh as [Ho_nrec Ho_ninf].
    set (s := BSCompute (tid, path) disp args).
    set (bt_j' := BranchTrace (bt_steps bt_j ++ [s]) (bt_uses bt_j ++ uses)).
    set (btraces' := update_nth j bt_j' btraces).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces'.
    refine (@Build_machine_inv_at btraces' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + unfold btraces'; rewrite length_update_nth; exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite Hann_j in Hann_k; inversion Hann_k; subst ann_k.
        assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        unfold btraces' in Hbt_k; rewrite nth_error_update_nth_eq in Hbt_k by lia.
        inversion Hts_k; inversion Hbt_k; subst ts_k bt_k.
        eapply branch_inv_linear_step with (h := HCompute);
          try eassumption; try (left; reflexivity); try reflexivity; try discriminate.
        -- intros u Hin; cbn in Hin; destruct Hin as [<- | Hin]; [right; reflexivity | left; exact Hin].
        -- intros u pk Hin; cbn; right; exact Hin.
        -- intros end_of Hcomp tev tuses Hce'.
           unfold annotated_of; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
           rewrite plug_stack_compute. cbn [label_paths step_events app].
           eapply EventsCompute; [exact Hev_ex | exact Hcomp |].
           exact (refocus_preserves_command_events _ _ Hadv Hce').
        -- intros d0 args0 Heq; unfold s in Heq; inversion Heq; subst; now left.
        -- intros o0 d0 args0 Heq; unfold s in Heq; inversion Heq; reflexivity.
      * unfold btraces' in Hbt_k; rewrite nth_error_update_nth_neq in Hts_k by exact Hneq; rewrite nth_error_update_nth_neq in Hbt_k by exact Hneq.
        eapply preserve_other_branch_inv_issue with (j := j) (ann_j := ann_j);
          try eassumption; try (eapply Hbr; eassumption); auto.
        -- unfold op_ids; change (owner ev) with (fst ((tid, path), HCompute)); apply in_map; exact Ho_in_annj.
        -- intros u Hin; cbn in Hin; destruct Hin as [<- | Hin]; [right; reflexivity | left; exact Hin].
        -- intros u pk Hin; cbn; right; exact Hin.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split.
        - intros o0 res Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 res Hin; apply Hc; apply in_app_iff; now left.
        - intros o0 d0 args0 Hin; apply Hinfc; now right. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_all_ev].
      set (ev_end := @EventRecord Float EventId Pipe Unit (tid, path) (LComputeEnd (end_of (tid, path)))).
      assert (Hperm_rhs :
        Permutation ((records ++ [ev]) ++ ev_end :: map (pending_end_event end_of) inflight)
                    (ev :: ev_end :: (records ++ map (pending_end_event end_of) inflight))).
      { rewrite <- app_assoc.
        eapply perm_trans; [apply Permutation_app_comm |].
        cbn [app]. apply perm_skip. apply perm_skip. apply Permutation_app_comm. }
      split.
      * unfold btraces'. eapply perm_trans.
        -- eapply concat_map_update_nth_app_perm with (old := bt_j) (extra := [ev; ev_end]); [exact Hbt_j |].
           unfold bt_j'; cbn [bt_steps]. rewrite flat_map_app. cbn [flat_map step_events app].
           rewrite app_nil_r. apply Permutation_refl.
        -- eapply perm_trans; [apply Permutation_app_tail; exact Hperm |].
           eapply perm_trans; [apply Permutation_app_comm |].
           apply Permutation_sym; exact Hperm_rhs.
      * apply (Permutation_NoDup (Permutation_sym Hperm_rhs)).
        constructor.
        -- intros [Heq | Hin]; [discriminate Heq |].
           rewrite in_app_iff in Hin. destruct Hin as [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
        -- constructor; [| exact Hnd_all_ev].
           rewrite in_app_iff. intros [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev_end); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
    + intros u. unfold btraces'.
      rewrite (in_concat_update_nth_list_iff bt_uses j bt_j' uses btraces Hbt_j).
      * rewrite Huses_eq, in_rev_append; tauto.
      * intros z; unfold bt_j'; cbn; rewrite in_app_iff; tauto.
    + intros u Hu. apply in_rev_append in Hu as [Hu | Hu].
      * apply Huse_ex in Hu as [Hcons _].
        exists ev; repeat split; [apply in_app_iff; right; now left | symmetry; exact Hcons | exists HCompute; auto].
      * apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin. apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | left; exists HCompute; auto].
    + eapply unique_phase_snoc_fresh; [exact Huniq | exact Ho_nrec].
    + cbn; constructor; assumption.
    + intros o0 pk0 [Heq | Hin].
      * inversion Heq; subst o0 pk0. repeat split.
        -- exact Ho_in_prog.
        -- apply in_app_iff; right; now left.
        -- intros Hend. apply rec_has_phase_snoc_inv in Hend as [[r [Hr [Hor _]]] | [_ [h' [Hh' Hk']]]].
           ++ apply Ho_nrec. change (tid, path) with o; rewrite <- Hor; apply in_map; exact Hr.
           ++ pose proof (ops_unique_head ann Hnd_all Hh' Ho_in_prog) as ->. discriminate Hk'.
      * destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
        assert (Hne_o : (tid, path) <> o0).
        { intro E; subst o0; apply Ho_ninf; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin. }
        repeat split; [exact H1 | apply in_app_iff; now left | |].
        -- intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction |].
           cbn [owner] in Hov; contradiction.
        -- destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
           ++ rewrite prior_start_cons_other; [exact H4 | right; exact I].
           ++ rewrite prior_start_cons_other; [exact H4 | right; exact I].
           ++ intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
              apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
              ** assert (Hlt1 : (i1 < length records)%nat) by lia.
                 rewrite nth_error_app1 in H1' by exact Hlt1.
                 destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12);
                   [left; apply rec_has_phase_snoc; auto | right; auto].
              ** exfalso; cbn [owner] in Ho2; contradiction.
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (H2ph r h Hin Hh Hne Hk) as [Hend | [pk [Hpk Hpp]]];
          [left; apply rec_has_phase_snoc; auto | right; exists pk; split; [now right | exact Hpp]].
      * right. exists (PCompute disp args). split; [now left | reflexivity].
    + intros w p0 q0 fl0 Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl0).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor; auto].
      destruct p as [q|]; [exact (proj1 Hpr) | exact I].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_in_prog) as ->.
        discriminate Hk0.
    + eapply rec_A2_snoc_start; [exact HA2 | exact Ho_nrec |].
      eapply head_op_po_satisfied; [split; assumption | exact Hann_j | exact Hbi | exact Ho_in_rem |].
      intros o0 Hpo0. cbn [rem_po] in Hpo0. rewrite Hpo_eq, in_app_iff, in_map_iff in Hpo0.
      pose proof (bi_rem_nodup Hbi) as Hnd_r. cbn [rem_ops] in Hnd_r. rewrite Hops_eq in Hnd_r.
      inversion Hnd_r as [|? ? Hni_o _]; subst.
      destruct Hpo0 as [[u [Heq Hu]] | Hpo1]; [inversion Heq; subst u; contradiction |].
      apply program_order_in_op_ids in Hpo1 as [_ Hu]; contradiction.
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | left; exact Ho_nrec | exact HA3 | discriminate].
    + eapply rec_A5_snoc_start; [exact HA5 | exact Ho_nrec |].
      intros w dst Hw Hpe [r1 [Hr1 [How [[h1 [Hh1 Hk1]] Hp1]]]].
      unfold ev, disp in Hpe; cbn [payload pipeline queue] in Hpe. subst p.
      destruct Hpr as [_ Haw_none].
      rewrite How in Hh1. pose proof (ops_unique_head ann Hnd_all Hh1 Hw) as ->.
      destruct r1 as [o1 pl1]; cbn in *; subst o1.
      destruct pl1; try discriminate Hk1. cbn in Hp1; inversion Hp1; subst q.
      destruct (H2ph (EventRecord w (LWaitFlagStart p dst flag)) HWaitFlag Hr1 Hw ltac:(discriminate) eq_refl)
        as [[rw [Hrw [Horw [hw [Hhw Hkw]]]]] | [pk [Hpk _]]].
      * rewrite Horw in Hhw. pose proof (ops_unique_head ann Hnd_all Hhw Hw) as ->.
        exists rw; repeat split; assumption.
      * exfalso. destruct (Hinf_sp w pk Hpk) as [_ [_ [Hnend _]]].
        pose proof (Haw_fwd w p dst flag Hr1 Hnend) as Hsome. congruence.
    + eapply rec_Aval_snoc_issue; [exact HAval | exact Huses_st | exact Hdv | exact Ho_nrec | exact Huse_ex].
  - (* 7. StepSetFlagStart *)
    rename H into Hth, H0 into Hcur, H1 into Hres, H2 into Hdeclp, H3 into Hdeclq, H4 into Hpr, H5 into Hadv.
    destruct cur as [tid0 path0 rho0 cmd0 stk]; cbn [cursor_stack] in Hcur, Hadv;
      inversion Hcur; subst tid0 path0 rho0 cmd0; clear Hcur. destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
      [| exfalso; apply nth_error_None in Hann_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
      [| exfalso; apply nth_error_None in Hbt_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    pose proof (Hbr j ann_j _ bt_j Hann_j Hth Hbt_j) as Hbi.
    pose proof (refocus_event_head _ _ Hadv) as Hhead'.
    pose proof (refocus_preserves_ops_and_po _ _ Hadv) as [Hops' Hpo'].
    apply resolve_operands_rel_to_events in Hres as [Hev_ops Huse_ops].
    assert (Hops_eq : operations (annotated_of (ThreadCursor tid path rho (SetFlag tt src dst v n) stk)) =
                      ((tid, path), HSetFlag) :: operations (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_setflag. cbn [label_paths operations].
      f_equal; symmetry; exact Hops'. }
    assert (Hpo_eq : program_order (annotated_of (ThreadCursor tid path rho (SetFlag tt src dst v n) stk)) =
                     map (fun u => ((tid, path), u)) (op_ids (annotated_of cur')) ++ program_order (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_setflag. cbn [label_paths program_order]. unfold op_ids. rewrite Hops', Hpo'. reflexivity. }
    assert (Ho_in_rem : In ((tid, path), HSetFlag) (rem_ops (TRunning (ThreadCursor tid path rho (SetFlag tt src dst v n) stk))))
      by (cbn [rem_ops]; rewrite Hops_eq; now left).
    assert (Ho_in_annj : In ((tid, path), HSetFlag) (operations ann_j)) by (apply (bi_rem_sub Hbi); exact Ho_in_rem).
    assert (Ho_in_prog : In ((tid, path), HSetFlag) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
    assert (Ho_fresh : ~ In (tid, path) (map owner records) /\ ~ In (tid, path) (map fst inflight)).
    { apply (bi_rem_fresh Hbi). change (tid, path) with (fst ((tid, path), HSetFlag)); apply in_map; exact Ho_in_rem. }
    destruct Ho_fresh as [Ho_nrec Ho_ninf].
    set (s := BSSetFlag (tid, path) p q fl).
    set (bt_j' := BranchTrace (bt_steps bt_j ++ [s]) (bt_uses bt_j ++ uses)).
    set (btraces' := update_nth j bt_j' btraces).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces'.
    refine (@Build_machine_inv_at btraces' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + unfold btraces'; rewrite length_update_nth; exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite Hann_j in Hann_k; inversion Hann_k; subst ann_k.
        assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        unfold btraces' in Hbt_k; rewrite nth_error_update_nth_eq in Hbt_k by lia.
        inversion Hts_k; inversion Hbt_k; subst ts_k bt_k.
        eapply branch_inv_linear_step with (h := HSetFlag);
          try eassumption; try (left; reflexivity); try reflexivity; try discriminate; try (intros; discriminate).
        -- intros u Hin; cbn in Hin; destruct Hin as [<- | Hin]; [right; reflexivity | left; exact Hin].
        -- intros u pk Hin; cbn; right; exact Hin.
        -- intros end_of _ tev tuses Hce'.
           unfold annotated_of; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
           rewrite plug_stack_setflag. cbn [label_paths step_events app].
           eapply EventsSetFlag; [exact Hev_ops |].
           exact (refocus_preserves_command_events _ _ Hadv Hce').
      * unfold btraces' in Hbt_k; rewrite nth_error_update_nth_neq in Hts_k by exact Hneq; rewrite nth_error_update_nth_neq in Hbt_k by exact Hneq.
        eapply preserve_other_branch_inv_issue with (j := j) (ann_j := ann_j);
          try eassumption; try (eapply Hbr; eassumption); auto.
        -- unfold op_ids; change (owner ev) with (fst ((tid, path), HSetFlag)); apply in_map; exact Ho_in_annj.
        -- intros u Hin; cbn in Hin; destruct Hin as [<- | Hin]; [right; reflexivity | left; exact Hin].
        -- intros u pk Hin; cbn; right; exact Hin.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split.
        - intros o0 res Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 res Hin; apply Hc; apply in_app_iff; now left.
        - intros o0 d0 args0 Hin; apply Hinfc; now right. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_all_ev].
      set (ev_end := @EventRecord Float EventId Pipe Unit (tid, path) LSetFlagEnd).
      assert (Hperm_rhs :
        Permutation ((records ++ [ev]) ++ ev_end :: map (pending_end_event end_of) inflight)
                    (ev :: ev_end :: (records ++ map (pending_end_event end_of) inflight))).
      { rewrite <- app_assoc.
        eapply perm_trans; [apply Permutation_app_comm |].
        cbn [app]. apply perm_skip. apply perm_skip. apply Permutation_app_comm. }
      split.
      * unfold btraces'. eapply perm_trans.
        -- eapply concat_map_update_nth_app_perm with (old := bt_j) (extra := [ev; ev_end]); [exact Hbt_j |].
           unfold bt_j'; cbn [bt_steps]. rewrite flat_map_app. cbn [flat_map step_events app].
           rewrite app_nil_r. apply Permutation_refl.
        -- eapply perm_trans; [apply Permutation_app_tail; exact Hperm |].
           eapply perm_trans; [apply Permutation_app_comm |].
           apply Permutation_sym; exact Hperm_rhs.
      * apply (Permutation_NoDup (Permutation_sym Hperm_rhs)).
        constructor.
        -- intros [Heq | Hin]; [discriminate Heq |].
           rewrite in_app_iff in Hin. destruct Hin as [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
        -- constructor; [| exact Hnd_all_ev].
           rewrite in_app_iff. intros [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev_end); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
    + intros u. unfold btraces'.
      rewrite (in_concat_update_nth_list_iff bt_uses j bt_j' uses btraces Hbt_j).
      * rewrite Huses_eq, in_rev_append; tauto.
      * intros z; unfold bt_j'; cbn; rewrite in_app_iff; tauto.
    + intros u Hu. apply in_rev_append in Hu as [Hu | Hu].
      * apply Huse_ops in Hu as [Hcons _].
        exists ev; repeat split; [apply in_app_iff; right; now left | symmetry; exact Hcons | exists HSetFlag; auto].
      * apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin. apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | left; exists HSetFlag; auto].
    + eapply unique_phase_snoc_fresh; [exact Huniq | exact Ho_nrec].
    + cbn; constructor; assumption.
    + intros o0 pk0 [Heq | Hin].
      * inversion Heq; subst o0 pk0. repeat split.
        -- exact Ho_in_prog.
        -- apply in_app_iff; right; now left.
        -- intros Hend. apply rec_has_phase_snoc_inv in Hend as [[r [Hr [Hor _]]] | [_ [h' [Hh' Hk']]]].
           ++ apply Ho_nrec. change (tid, path) with o; rewrite <- Hor; apply in_map; exact Hr.
           ++ pose proof (ops_unique_head ann Hnd_all Hh' Ho_in_prog) as ->. discriminate Hk'.
        -- (* 核心 A3 快照不变式：所有此前已在管线 p 上发起的操作要么已完成，要么在 deps 中 *)
           intros o' i1 i2 r1 r2 H1' Ho1 [h1 [Hh1 Hk1]] Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
           ++ exfalso; apply Ho_nrec; change (tid, path) with o; rewrite <- Ho2; apply in_map; eapply nth_error_In; exact H2'.
           ++ rewrite nth_error_app1 in H1' by exact Hlt12.
              apply nth_error_In in H1'.
              assert (H2ph_h1 : start_kind h1 <> end_kind h1).
              { destruct r1 as [o1 pl1]; cbn in *; destruct pl1; try discriminate Hp1;
                  destruct h1; try discriminate Hk1; discriminate. }
              destruct (H2ph r1 h1 H1' Hh1 H2ph_h1 Hk1) as [Hend | [pk1 [Hpk1 Hpp1]]].
              ** left. rewrite <- Ho1. apply rec_has_phase_snoc; exact Hend.
              ** right. unfold deps, inflight_on_pipe. apply in_flat_map.
                 exists (o', pk1). rewrite Ho1 in Hpk1. split; [exact Hpk1 |].
                 rewrite Hpp1, Hp1, eqb_refl. now left.
      * destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
        assert (Hne_o : (tid, path) <> o0).
        { intro E; subst o0; apply Ho_ninf; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin. }
        repeat split; [exact H1 | apply in_app_iff; now left | |].
        -- intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction |].
           cbn [owner] in Hov; contradiction.
        -- destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
           ++ rewrite prior_start_cons_other; [exact H4 | right; exact I].
           ++ rewrite prior_start_cons_other; [exact H4 | right; exact I].
           ++ intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
              apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
              ** assert (Hlt1 : (i1 < length records)%nat) by lia.
                 rewrite nth_error_app1 in H1' by exact Hlt1.
                 destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12);
                   [left; apply rec_has_phase_snoc; auto | right; auto].
              ** exfalso; cbn [owner] in Ho2; contradiction.
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (H2ph r h Hin Hh Hne Hk) as [Hend | [pk [Hpk Hpp]]];
          [left; apply rec_has_phase_snoc; auto | right; exists pk; split; [now right | exact Hpp]].
      * right. exists (PSetFlag p q fl deps). split; [now left | reflexivity].
    + intros w p0 q0 fl0 Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl0).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | | discriminate].
      intros o0 p0 q0 fl0 Heq. inversion Heq; subst o0; exact Ho_nrec.
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor; auto].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_in_prog) as ->.
        discriminate Hk0.
    + eapply rec_A2_snoc_start; [exact HA2 | exact Ho_nrec |].
      eapply head_op_po_satisfied; [split; assumption | exact Hann_j | exact Hbi | exact Ho_in_rem |].
      intros o0 Hpo0. cbn [rem_po] in Hpo0. rewrite Hpo_eq, in_app_iff, in_map_iff in Hpo0.
      pose proof (bi_rem_nodup Hbi) as Hnd_r. cbn [rem_ops] in Hnd_r. rewrite Hops_eq in Hnd_r.
      inversion Hnd_r as [|? ? Hni_o _]; subst.
      destruct Hpo0 as [[u [Heq Hu]] | Hpo1]; [inversion Heq; subst u; contradiction |].
      apply program_order_in_op_ids in Hpo1 as [_ Hu]; contradiction.
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | left; exact Ho_nrec | exact HA3 | discriminate].
    + eapply rec_A5_snoc_start; [exact HA5 | exact Ho_nrec |].
      intros w dst0 Hw Hpe [r1 [Hr1 [How [[h1 [Hh1 Hk1]] Hp1]]]].
      unfold ev in Hpe; cbn [payload pipeline] in Hpe. inversion Hpe; subst dst0.
      destruct Hpr as [_ Haw_none].
      rewrite How in Hh1. pose proof (ops_unique_head ann Hnd_all Hh1 Hw) as ->.
      destruct r1 as [o1 pl1]; cbn in *; subst o1.
      destruct pl1; try discriminate Hk1. cbn in Hp1; inversion Hp1; subst q0.
      destruct (H2ph (EventRecord w (LWaitFlagStart p0 p flag)) HWaitFlag Hr1 Hw ltac:(discriminate) eq_refl)
        as [[rw [Hrw [Horw [hw [Hhw Hkw]]]]] | [pk [Hpk _]]].
      * rewrite Horw in Hhw. pose proof (ops_unique_head ann Hnd_all Hhw Hw) as ->.
        exists rw; repeat split; assumption.
      * exfalso. destruct (Hinf_sp w pk Hpk) as [_ [_ [Hnend _]]].
        pose proof (Haw_fwd w p0 p flag Hr1 Hnend) as Hsome. congruence.
    + eapply rec_Aval_snoc_issue; [exact HAval | exact Huses_st | exact Hdv | exact Ho_nrec | exact Huse_ops].
  - (* 8. StepWaitFlagStart *)
    rename H into Hth, H0 into Hcur, H1 into Hres, H2 into Hdeclp, H3 into Hdeclq, H4 into Hpr, H5 into Hadv.
    destruct cur as [tid0 path0 rho0 cmd0 stk]; cbn [cursor_stack] in Hcur, Hadv;
      inversion Hcur; subst tid0 path0 rho0 cmd0; clear Hcur. destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
      [| exfalso; apply nth_error_None in Hann_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
      [| exfalso; apply nth_error_None in Hbt_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    pose proof (Hbr j ann_j _ bt_j Hann_j Hth Hbt_j) as Hbi.
    pose proof (refocus_event_head _ _ Hadv) as Hhead'.
    pose proof (refocus_preserves_ops_and_po _ _ Hadv) as [Hops' Hpo'].
    apply resolve_operands_rel_to_events in Hres as [Hev_ops Huse_ops].
    assert (Hops_eq : operations (annotated_of (ThreadCursor tid path rho (WaitFlag tt src dst v n) stk)) =
                      ((tid, path), HWaitFlag) :: operations (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_waitflag. cbn [label_paths operations].
      f_equal; symmetry; exact Hops'. }
    assert (Hpo_eq : program_order (annotated_of (ThreadCursor tid path rho (WaitFlag tt src dst v n) stk)) =
                     map (fun u => ((tid, path), u)) (op_ids (annotated_of cur')) ++ program_order (annotated_of cur')).
    { unfold annotated_of in *; cbn in *. rewrite plug_stack_waitflag. cbn [label_paths program_order]. unfold op_ids. rewrite Hops', Hpo'. reflexivity. }
    assert (Ho_in_rem : In ((tid, path), HWaitFlag) (rem_ops (TRunning (ThreadCursor tid path rho (WaitFlag tt src dst v n) stk))))
      by (cbn [rem_ops]; rewrite Hops_eq; now left).
    assert (Ho_in_annj : In ((tid, path), HWaitFlag) (operations ann_j)) by (apply (bi_rem_sub Hbi); exact Ho_in_rem).
    assert (Ho_in_prog : In ((tid, path), HWaitFlag) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
    assert (Ho_fresh : ~ In (tid, path) (map owner records) /\ ~ In (tid, path) (map fst inflight)).
    { apply (bi_rem_fresh Hbi). change (tid, path) with (fst ((tid, path), HWaitFlag)); apply in_map; exact Ho_in_rem. }
    destruct Ho_fresh as [Ho_nrec Ho_ninf].
    set (s := BSWaitFlag (tid, path) p q fl).
    set (bt_j' := BranchTrace (bt_steps bt_j ++ [s]) (bt_uses bt_j ++ uses)).
    set (btraces' := update_nth j bt_j' btraces).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces'.
    refine (@Build_machine_inv_at btraces' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + unfold btraces'; rewrite length_update_nth; exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite Hann_j in Hann_k; inversion Hann_k; subst ann_k.
        assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        unfold btraces' in Hbt_k; rewrite nth_error_update_nth_eq in Hbt_k by lia.
        inversion Hts_k; inversion Hbt_k; subst ts_k bt_k.
        eapply branch_inv_linear_step with (h := HWaitFlag);
          try eassumption; try (right; reflexivity); try reflexivity; try discriminate; try (intros; discriminate).
        -- intros u Hin; cbn in Hin; destruct Hin as [<- | Hin]; [right; reflexivity | left; exact Hin].
        -- intros u pk Hin; cbn; right; exact Hin.
        -- intros end_of _ tev tuses Hce'.
           unfold annotated_of; cbn [cursor_tid cursor_path cursor_env cursor_cmd cursor_stack].
           rewrite plug_stack_waitflag. cbn [label_paths step_events app].
           eapply EventsWaitFlag; [exact Hev_ops |].
           exact (refocus_preserves_command_events _ _ Hadv Hce').
      * unfold btraces' in Hbt_k; rewrite nth_error_update_nth_neq in Hts_k by exact Hneq; rewrite nth_error_update_nth_neq in Hbt_k by exact Hneq.
        eapply preserve_other_branch_inv_issue with (j := j) (ann_j := ann_j);
          try eassumption; try (eapply Hbr; eassumption); auto.
        -- unfold op_ids; change (owner ev) with (fst ((tid, path), HWaitFlag)); apply in_map; exact Ho_in_annj.
        -- intros u Hin; cbn in Hin; destruct Hin as [<- | Hin]; [right; reflexivity | left; exact Hin].
        -- intros u pk Hin; cbn; right; exact Hin.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split.
        - intros o0 res Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 res Hin; apply Hc; apply in_app_iff; now left.
        - intros o0 d0 args0 Hin; apply Hinfc; now right. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_all_ev].
      set (ev_end := @EventRecord Float EventId Pipe Unit (tid, path) LWaitFlagEnd).
      assert (Hperm_rhs :
        Permutation ((records ++ [ev]) ++ ev_end :: map (pending_end_event end_of) inflight)
                    (ev :: ev_end :: (records ++ map (pending_end_event end_of) inflight))).
      { rewrite <- app_assoc.
        eapply perm_trans; [apply Permutation_app_comm |].
        cbn [app]. apply perm_skip. apply perm_skip. apply Permutation_app_comm. }
      split.
      * unfold btraces'. eapply perm_trans.
        -- eapply concat_map_update_nth_app_perm with (old := bt_j) (extra := [ev; ev_end]); [exact Hbt_j |].
           unfold bt_j'; cbn [bt_steps]. rewrite flat_map_app. cbn [flat_map step_events app].
           rewrite app_nil_r. apply Permutation_refl.
        -- eapply perm_trans; [apply Permutation_app_tail; exact Hperm |].
           eapply perm_trans; [apply Permutation_app_comm |].
           apply Permutation_sym; exact Hperm_rhs.
      * apply (Permutation_NoDup (Permutation_sym Hperm_rhs)).
        constructor.
        -- intros [Heq | Hin]; [discriminate Heq |].
           rewrite in_app_iff in Hin. destruct Hin as [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
        -- constructor; [| exact Hnd_all_ev].
           rewrite in_app_iff. intros [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev_end); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
    + intros u. unfold btraces'.
      rewrite (in_concat_update_nth_list_iff bt_uses j bt_j' uses btraces Hbt_j).
      * rewrite Huses_eq, in_rev_append; tauto.
      * intros z; unfold bt_j'; cbn; rewrite in_app_iff; tauto.
    + intros u Hu. apply in_rev_append in Hu as [Hu | Hu].
      * apply Huse_ops in Hu as [Hcons _].
        exists ev; repeat split; [apply in_app_iff; right; now left | symmetry; exact Hcons | exists HWaitFlag; auto].
      * apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin. apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | left; exists HWaitFlag; auto].
    + eapply unique_phase_snoc_fresh; [exact Huniq | exact Ho_nrec].
    + cbn; constructor; assumption.
    + intros o0 pk0 [Heq | Hin].
      * inversion Heq; subst o0 pk0. repeat split.
        -- exact Ho_in_prog.
        -- apply in_app_iff; right; now left.
        -- intros Hend. apply rec_has_phase_snoc_inv in Hend as [[r [Hr [Hor _]]] | [_ [h' [Hh' Hk']]]].
           ++ apply Ho_nrec. change (tid, path) with o; rewrite <- Hor; apply in_map; exact Hr.
           ++ pose proof (ops_unique_head ann Hnd_all Hh' Ho_in_prog) as ->. discriminate Hk'.
      * destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
        assert (Hne_o : (tid, path) <> o0).
        { intro E; subst o0; apply Ho_ninf; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin. }
        repeat split; [exact H1 | apply in_app_iff; now left | |].
        -- intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction |].
           cbn [owner] in Hov; contradiction.
        -- destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
           ++ rewrite prior_start_cons_other; [exact H4 | right; exact I].
           ++ rewrite prior_start_cons_other; [exact H4 | right; exact I].
           ++ intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
              apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
              ** assert (Hlt1 : (i1 < length records)%nat) by lia.
                 rewrite nth_error_app1 in H1' by exact Hlt1.
                 destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12);
                   [left; apply rec_has_phase_snoc; auto | right; auto].
              ** exfalso; cbn [owner] in Ho2; contradiction.
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (H2ph r h Hin Hh Hne Hk) as [Hend | [pk [Hpk Hpp]]];
          [left; apply rec_has_phase_snoc; auto | right; exists pk; split; [now right | exact Hpp]].
      * right. exists (PWaitFlag p q fl j). split; [now left | reflexivity].
    + intros w p0 q0 fl0 Hw Hnend.
      unfold sync', active_wait_of, active_wait_set; cbn [sync_active_wait lookup_assoc].
      apply in_app_iff in Hw as [Hw | [Heq | []]].
      * destruct (eqb Pe q0 q) eqn:Eq.
        -- apply (proj1 (eqb_spec Pe _ _)) in Eq; subst q0.
           exfalso. destruct Hpr as [_ Haw_none].
           assert (Hnend0 : ~ rec_has_end ann records w) by (intro H0; apply Hnend; apply rec_has_phase_snoc; exact H0).
           pose proof (Haw_fwd w p0 q fl0 Hw Hnend0) as Hsome. congruence.
        -- apply Haw_fwd with (p := p0) (fl := fl0); [exact Hw |].
           intro H0; apply Hnend; apply rec_has_phase_snoc; exact H0.
      * inversion Heq; subst w p0 q0 fl0. rewrite eqb_refl. reflexivity.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate |].
      intros o0 p0 q0 fl0 Heq. inversion Heq; subst o0; exact Ho_nrec.
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor; auto].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_in_prog) as ->.
        discriminate Hk0.
    + eapply rec_A2_snoc_start; [exact HA2 | exact Ho_nrec |].
      eapply head_op_po_satisfied; [split; assumption | exact Hann_j | exact Hbi | exact Ho_in_rem |].
      intros o0 Hpo0. cbn [rem_po] in Hpo0. rewrite Hpo_eq, in_app_iff, in_map_iff in Hpo0.
      pose proof (bi_rem_nodup Hbi) as Hnd_r. cbn [rem_ops] in Hnd_r. rewrite Hops_eq in Hnd_r.
      inversion Hnd_r as [|? ? Hni_o _]; subst.
      destruct Hpo0 as [[u [Heq Hu]] | Hpo1]; [inversion Heq; subst u; contradiction |].
      apply program_order_in_op_ids in Hpo1 as [_ Hu]; contradiction.
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | left; exact Ho_nrec | exact HA3 | discriminate].
    + eapply rec_A5_snoc_start; [exact HA5 | exact Ho_nrec |].
      intros w dst0 Hw Hpe [r1 [Hr1 [How [[h1 [Hh1 Hk1]] Hp1]]]].
      unfold ev in Hpe; cbn [payload pipeline] in Hpe. inversion Hpe; subst dst0.
      destruct Hpr as [_ Haw_none].
      rewrite How in Hh1. pose proof (ops_unique_head ann Hnd_all Hh1 Hw) as ->.
      destruct r1 as [o1 pl1]; cbn in *; subst o1.
      destruct pl1; try discriminate Hk1. cbn in Hp1; inversion Hp1; subst q0.
      destruct (H2ph (EventRecord w (LWaitFlagStart p0 q flag)) HWaitFlag Hr1 Hw ltac:(discriminate) eq_refl)
        as [[rw [Hrw [Horw [hw [Hhw Hkw]]]]] | [pk [Hpk _]]].
      * rewrite Horw in Hhw. pose proof (ops_unique_head ann Hnd_all Hhw Hw) as ->.
        exists rw; repeat split; assumption.
      * exfalso. destruct (Hinf_sp w pk Hpk) as [_ [_ [Hnend _]]].
        pose proof (Haw_fwd w p0 q flag Hr1 Hnend) as Hsome. congruence.
    + eapply rec_Aval_snoc_issue; [exact HAval | exact Huses_st | exact Hdv | exact Ho_nrec | exact Huse_ops].
  - (* 9. StepIf *)
    rename H into Hth, H0 into Hcur, H1 into Hres, H2 into Hadv.
    destruct cur as [tid0 path0 rho0 cmd0 stk]; cbn [cursor_stack] in Hcur, Hadv;
      inversion Hcur; subst tid0 path0 rho0 cmd0; clear Hcur. destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
      [| exfalso; apply nth_error_None in Hann_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
      [| exfalso; apply nth_error_None in Hbt_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    pose proof (Hbr j ann_j _ bt_j Hann_j Hth Hbt_j) as Hbi.
    pose proof (refocus_event_head _ _ Hadv) as Hhead'.
    pose proof (refocus_preserves_ops_and_po _ _ Hadv) as [Hops' Hpo'].
    apply resolve_operand_rel_to_events in Hres as [Hev_op Huse_op].
    set (cy := label_paths (pair tid) (xO path) (plug_stack y stk)).
    set (cn := label_paths (pair tid) (xI path) (plug_stack n stk)).
    assert (Hann_if : annotated_of (ThreadCursor tid path rho (If tt cond y n) stk) = If (tid, path) cond cy cn).
    { unfold annotated_of, cy, cn; cbn. rewrite plug_stack_if. reflexivity. }
    assert (Hbranch_eq : annotated_of (ThreadCursor tid (if b then xO path else xI path) rho (if b then y else n) stk) =
                         if b then cy else cn).
    { destruct b; reflexivity. }
    rewrite Hbranch_eq in Hops', Hpo'.
    assert (Hops_if : operations (annotated_of (ThreadCursor tid path rho (If tt cond y n) stk)) =
                      ((tid, path), HIf) :: operations cy ++ operations cn).
    { rewrite Hann_if; reflexivity. }
    assert (Hpo_if : program_order (annotated_of (ThreadCursor tid path rho (If tt cond y n) stk)) =
                     map (fun u => ((tid, path), u)) (op_ids cy ++ op_ids cn) ++ program_order cy ++ program_order cn).
    { rewrite Hann_if; reflexivity. }
    pose proof (bi_rem_nodup Hbi) as Hnd_rem. cbn [rem_ops] in Hnd_rem. rewrite Hops_if in Hnd_rem.
    cbn [map fst] in Hnd_rem. inversion Hnd_rem as [|? ? Ho_notin_yn Hnd_yn]; subst.
    rewrite map_app in Hnd_yn. apply NoDup_app_disjoint in Hnd_yn as [Hnd_y [Hnd_n Hdisj_yn]].
    assert (Ho_in_rem : In ((tid, path), HIf) (rem_ops (TRunning (ThreadCursor tid path rho (If tt cond y n) stk))))
      by (cbn [rem_ops]; rewrite Hops_if; now left).
    assert (Ho_in_annj : In ((tid, path), HIf) (operations ann_j)) by (apply (bi_rem_sub Hbi); exact Ho_in_rem).
    assert (Ho_in_prog : In ((tid, path), HIf) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
    assert (Ho_fresh : ~ In (tid, path) (map owner records) /\ ~ In (tid, path) (map fst inflight)).
    { apply (bi_rem_fresh Hbi). change (tid, path) with (fst ((tid, path), HIf)); apply in_map; exact Ho_in_rem. }
    destruct Ho_fresh as [Ho_nrec Ho_ninf].
    set (s := BSIf (tid, path) b).
    set (bt_j' := BranchTrace (bt_steps bt_j ++ [s]) (bt_uses bt_j ++ uses)).
    set (btraces' := update_nth j bt_j' btraces).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces'.
    refine (@Build_machine_inv_at btraces' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + unfold btraces'; rewrite length_update_nth; exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite Hann_j in Hann_k; inversion Hann_k; subst ann_k.
        assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        unfold btraces' in Hbt_k; rewrite nth_error_update_nth_eq in Hbt_k by lia.
        inversion Hts_k; inversion Hbt_k; subst ts_k bt_k.
        constructor; cbn [rem_ops rem_po].
        -- exact Hhead'.
        -- intros oh Hin. rewrite Hops' in Hin. apply (bi_rem_sub Hbi). cbn [rem_ops]. rewrite Hops_if.
           right; apply in_app_iff; destruct b; auto.
        -- rewrite Hops'. destruct b; assumption.
        -- intros u Hu. rewrite Hops' in Hu.
           assert (Hu_old : In u (map fst (rem_ops (TRunning (ThreadCursor tid path rho (If tt cond y n) stk))))).
           { cbn [rem_ops]; rewrite Hops_if; cbn [map fst]; right; rewrite map_app, in_app_iff; destruct b; auto. }
           destruct (bi_rem_fresh Hbi u Hu_old) as [Hnr Hni].
           assert (Huo : u <> (tid, path)).
           { intro E; subst u; apply Ho_notin_yn; rewrite map_app, in_app_iff; destruct b; auto. }
           split; [| exact Hni].
           rewrite map_app, in_app_iff; intros [| [Heq | []]]; [contradiction | unfold ev, o in Heq; cbn in Heq; congruence].
        -- intros o1 u Hpou Hu. rewrite Hops' in Hu.
           assert (Hu_old : In u (map fst (rem_ops (TRunning (ThreadCursor tid path rho (If tt cond y n) stk))))).
           { cbn [rem_ops]; rewrite Hops_if; cbn [map fst]; right; rewrite map_app, in_app_iff; destruct b; auto. }
           destruct (bi_po_closed Hbi o1 u Hpou Hu_old) as [Hrem | [Hs [Hg | [cur0 Hw]]]].
           ++ cbn [rem_po] in Hrem. rewrite Hpo_if, !in_app_iff, in_map_iff in Hrem.
              destruct Hrem as [[u' [Heq _]] | [Hpy | Hpno]].
              ** inversion Heq; subst o1 u'.
                 right; split.
                 --- exists ev; split; [apply in_app_iff; right; now left | split; [reflexivity | exists HIf; auto]].
                 --- left. exists ev; split; [apply in_app_iff; right; now left | split; [reflexivity | exists HIf; auto]].
              ** destruct b.
                 --- left; rewrite Hpo'; exact Hpy.
                 --- exfalso. apply program_order_in_op_ids in Hpy as [_ Huy].
                     unfold op_ids in Huy. eapply Hdisj_yn; [exact Huy | exact Hu].
              ** destruct b.
                 --- exfalso. apply program_order_in_op_ids in Hpno as [_ Hun].
                     unfold op_ids in Hun. eapply Hdisj_yn; [exact Hu | exact Hun].
                 --- left; rewrite Hpo'; exact Hpno.
           ++ right; split; [apply rec_has_phase_snoc; exact Hs | left; apply rec_has_phase_snoc; exact Hg].
           ++ discriminate Hw.
        -- intros end_of Hall tev tuses Hce'.
           unfold bt_j' in *; cbn [bt_steps bt_uses] in *.
           apply Forall_app in Hall as [Hall1 _].
           rewrite flat_map_app; cbn [flat_map step_events app]; rewrite app_nil_r, <- !app_assoc.
           apply (bi_cps Hbi Hall1). rewrite Hann_if.
           eapply EventsIf; [exact Hev_op |].
           rewrite <- Hbranch_eq. exact (refocus_preserves_command_events _ _ Hadv Hce').
        -- intros o0 d0 args0 Hin. apply in_app_iff in Hin as [Hin | [Heq | []]]; [| discriminate Heq].
           destruct (bi_steps_comp Hbi o0 d0 args0 Hin) as [Hi | [res [Hr Hc]]];
             [left; exact Hi | right; exists res; split; [apply in_app_iff; now left | exact Hc]].
      * unfold btraces' in Hbt_k; rewrite nth_error_update_nth_neq in Hts_k by exact Hneq; rewrite nth_error_update_nth_neq in Hbt_k by exact Hneq.
        eapply preserve_other_branch_inv_issue with (j := j) (ann_j := ann_j);
          try eassumption; try (eapply Hbr; eassumption); auto.
        unfold op_ids; change (owner ev) with (fst ((tid, path), HIf)); apply in_map; exact Ho_in_annj.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split; auto;
          intros o0 r0 Hin; [apply Hr | apply Hc]; apply in_app_iff; now left. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_all_ev]. split.
      * unfold btraces'. eapply perm_trans.
        -- eapply concat_map_update_nth_app_perm with (old := bt_j) (extra := [ev]); [exact Hbt_j |].
           unfold bt_j'; cbn [bt_steps]. rewrite flat_map_app. cbn [flat_map step_events app].
           rewrite app_nil_r. apply Permutation_refl.
        -- eapply perm_trans; [apply Permutation_app_tail; exact Hperm |].
           rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
      * apply (Permutation_NoDup (l := ev :: (records ++ map (pending_end_event end_of) inflight))).
        -- eapply perm_trans; [apply Permutation_cons_append |].
           rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
        -- constructor; [| exact Hnd_all_ev].
           rewrite in_app_iff. intros [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
    + intros u. unfold btraces'.
      rewrite (in_concat_update_nth_list_iff bt_uses j bt_j' uses btraces Hbt_j).
      * rewrite Huses_eq, in_rev_append; tauto.
      * intros z; unfold bt_j'; cbn; rewrite in_app_iff; tauto.
    + intros u Hu. apply in_rev_append in Hu as [Hu | Hu].
      * apply Huse_op in Hu as [Hcons _].
        exists ev; repeat split; [apply in_app_iff; right; now left | symmetry; exact Hcons | exists HIf; auto].
      * apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin. apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | left; exists HIf; auto].
    + eapply unique_phase_snoc_fresh; [exact Huniq | exact Ho_nrec].
    + exact Hinf_nd.
    + intros o0 pk0 Hin. destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
      repeat split; [exact H1 | apply in_app_iff; now left | |].
      * intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction |].
        cbn [owner] in Hov; subst o0. apply Ho_ninf.
        change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin.
      * destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
           ++ assert (Hlt1 : (i1 < length records)%nat) by lia.
              rewrite nth_error_app1 in H1' by exact Hlt1.
              destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12);
                [left; apply rec_has_phase_snoc; auto | right; auto].
           ++ exfalso; cbn [owner] in Ho2; subst o0; apply Ho_ninf; exact (in_map fst _ _ Hin).
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (H2ph r h Hin Hh Hne Hk) as [Hend | Hinf]; [left; apply rec_has_phase_snoc; auto | right; exact Hinf].
      * cbn [owner] in Hh. pose proof (ops_unique_head ann Hnd_all Hh Ho_in_prog) as ->. exfalso; apply Hne; reflexivity.
    + intros w p0 q0 fl0 Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl0).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_in_prog) as ->.
        exfalso; apply Hne0; reflexivity.
    + eapply rec_A2_snoc_start; [exact HA2 | exact Ho_nrec |].
      eapply head_op_po_satisfied; [split; assumption | exact Hann_j | exact Hbi | exact Ho_in_rem |].
      intros o0 Hpo0. cbn [rem_po] in Hpo0. rewrite Hpo_if, !in_app_iff, in_map_iff in Hpo0.
      destruct Hpo0 as [[u [Heq Hu]] | [Hpy | Hpno]].
      * inversion Heq; subst u. apply Ho_notin_yn; rewrite map_app; exact Hu.
      * apply program_order_in_op_ids in Hpy as [_ Hu]. apply Ho_notin_yn. rewrite map_app, in_app_iff; now left.
      * apply program_order_in_op_ids in Hpno as [_ Hu]. apply Ho_notin_yn. rewrite map_app, in_app_iff; now right.
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | left; exact Ho_nrec | exact HA3 | discriminate].
    + eapply rec_A5_snoc_start; [exact HA5 | exact Ho_nrec | intros w dst _ Hp; discriminate Hp].
    + eapply rec_Aval_snoc_issue; [exact HAval | exact Huses_st | exact Hdv | exact Ho_nrec | exact Huse_op].
  - (* 10. StepReturn *)
    rename H into Hth, H0 into Hcur, H1 into Hres.
    destruct cur as [tid0 path0 rho0 cmd0 stk]; cbn [cursor_stack] in Hcur;
      inversion Hcur; subst tid0 path0 rho0 cmd0; clear Hcur. destruct (nth_error ann j) as [ann_j|] eqn:Hann_j;
      [| exfalso; apply nth_error_None in Hann_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    destruct (nth_error btraces j) as [bt_j|] eqn:Hbt_j;
      [| exfalso; apply nth_error_None in Hbt_j; assert (j < length (ms_threads st))%nat by (apply nth_error_Some; congruence); lia].
    pose proof (Hbr j ann_j _ bt_j Hann_j Hth Hbt_j) as Hbi.
    apply resolve_operands_rel_to_events in Hres as [Hev_ops Huse_ops].
    assert (Hann_ret : annotated_of (ThreadCursor tid path rho (Return tt vs) stk) = Return (tid, path) vs).
    { unfold annotated_of; cbn. rewrite plug_stack_return. reflexivity. }
    assert (Hops_ret : operations (annotated_of (ThreadCursor tid path rho (Return tt vs) stk)) = [((tid, path), HReturn)]).
    { rewrite Hann_ret; reflexivity. }
    assert (Hpo_ret : program_order (annotated_of (ThreadCursor tid path rho (Return tt vs) stk)) = []).
    { rewrite Hann_ret; reflexivity. }
    assert (Ho_in_rem : In ((tid, path), HReturn) (rem_ops (TRunning (ThreadCursor tid path rho (Return tt vs) stk))))
      by (cbn [rem_ops]; rewrite Hops_ret; now left).
    assert (Ho_in_annj : In ((tid, path), HReturn) (operations ann_j)) by (apply (bi_rem_sub Hbi); exact Ho_in_rem).
    assert (Ho_in_prog : In ((tid, path), HReturn) (program_operations ann)) by (eapply branch_ops_in_program; eassumption).
    assert (Ho_fresh : ~ In (tid, path) (map owner records) /\ ~ In (tid, path) (map fst inflight)).
    { apply (bi_rem_fresh Hbi). change (tid, path) with (fst ((tid, path), HReturn)); apply in_map; exact Ho_in_rem. }
    destruct Ho_fresh as [Ho_nrec Ho_ninf].
    set (s := BSReturn (tid, path) args).
    set (bt_j' := BranchTrace (bt_steps bt_j ++ [s]) (bt_uses bt_j ++ uses)).
    set (btraces' := update_nth j bt_j' btraces).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces'.
    refine (@Build_machine_inv_at btraces' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + unfold btraces'; rewrite length_update_nth; exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * rewrite Hann_j in Hann_k; inversion Hann_k; subst ann_k.
        assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        unfold btraces' in Hbt_k; rewrite nth_error_update_nth_eq in Hbt_k by lia.
        inversion Hts_k; inversion Hbt_k; subst ts_k bt_k.
        constructor; cbn [rem_ops rem_po].
        -- exact I.
        -- intros oh [].
        -- constructor.
        -- intros u [].
        -- intros o1 u _ [].
        -- intros end_of Hall. unfold bt_j' in *; cbn [bt_steps bt_uses] in *. apply Forall_app in Hall as [Hall1 _].
           rewrite flat_map_app; cbn [flat_map step_events app]; rewrite app_nil_r.
           apply (bi_cps Hbi Hall1). rewrite Hann_ret.
           apply EventsReturn; exact Hev_ops.
        -- intros o0 d0 args0 Hin. apply in_app_iff in Hin as [Hin | [Heq | []]]; [| discriminate Heq].
           destruct (bi_steps_comp Hbi o0 d0 args0 Hin) as [Hi | [res [Hr Hc]]];
             [left; exact Hi | right; exists res; split; [apply in_app_iff; now left | exact Hc]].
      * unfold btraces' in Hbt_k; rewrite nth_error_update_nth_neq in Hts_k by exact Hneq; rewrite nth_error_update_nth_neq in Hbt_k by exact Hneq.
        eapply preserve_other_branch_inv_issue with (j := j) (ann_j := ann_j);
          try eassumption; try (eapply Hbr; eassumption); auto.
        unfold op_ids; change (owner ev) with (fst ((tid, path), HReturn)); apply in_map; exact Ho_in_annj.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split; auto;
          intros o0 r0 Hin; [apply Hr | apply Hc]; apply in_app_iff; now left. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_all_ev]. split.
      * unfold btraces'. eapply perm_trans.
        -- eapply concat_map_update_nth_app_perm with (old := bt_j) (extra := [ev]); [exact Hbt_j |].
           unfold bt_j'; cbn [bt_steps]. rewrite flat_map_app. cbn [flat_map step_events app].
           rewrite app_nil_r. apply Permutation_refl.
        -- eapply perm_trans; [apply Permutation_app_tail; exact Hperm |].
           rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
      * apply (Permutation_NoDup (l := ev :: (records ++ map (pending_end_event end_of) inflight))).
        -- eapply perm_trans; [apply Permutation_cons_append |].
           rewrite <- !app_assoc. apply Permutation_app_head. apply Permutation_app_comm.
        -- constructor; [| exact Hnd_all_ev].
           rewrite in_app_iff. intros [Hin | Hin].
           ++ apply Ho_nrec. change (tid, path) with (owner ev); apply in_map; exact Hin.
           ++ apply in_map_iff in Hin as [[o0 pk0] [Heq Hin0]].
              apply Ho_ninf. assert (o0 = (tid, path)) by (destruct pk0; cbn in Heq; inversion Heq; auto).
              subst o0; change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin0.
    + intros u. unfold btraces'.
      rewrite (in_concat_update_nth_list_iff bt_uses j bt_j' uses btraces Hbt_j).
      * rewrite Huses_eq, in_rev_append; tauto.
      * intros z; unfold bt_j'; cbn; rewrite in_app_iff; tauto.
    + intros u Hu. apply in_rev_append in Hu as [Hu | Hu].
      * apply Huse_ops in Hu as [Hcons _].
        exists ev; repeat split; [apply in_app_iff; right; now left | symmetry; exact Hcons | exists HReturn; auto].
      * apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin. apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | left; exists HReturn; auto].
    + eapply unique_phase_snoc_fresh; [exact Huniq | exact Ho_nrec].
    + exact Hinf_nd.
    + intros o0 pk0 Hin. destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
      repeat split; [exact H1 | apply in_app_iff; now left | |].
      * intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction |].
        cbn [owner] in Hov; subst o0. apply Ho_ninf.
        change (tid, path) with (fst ((tid, path), pk0)); apply in_map; exact Hin.
      * destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]].
           ++ assert (Hlt1 : (i1 < length records)%nat) by lia.
              rewrite nth_error_app1 in H1' by exact Hlt1.
              destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12);
                [left; apply rec_has_phase_snoc; auto | right; auto].
           ++ exfalso; cbn [owner] in Ho2; subst o0; apply Ho_ninf; exact (in_map fst _ _ Hin).
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (H2ph r h Hin Hh Hne Hk) as [Hend | Hinf]; [left; apply rec_has_phase_snoc; auto | right; exact Hinf].
      * cbn [owner] in Hh. pose proof (ops_unique_head ann Hnd_all Hh Ho_in_prog) as ->. exfalso; apply Hne; reflexivity.
    + intros w p0 q0 fl0 Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl0).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_in_prog) as ->.
        exfalso; apply Hne0; reflexivity.
    + eapply rec_A2_snoc_start; [exact HA2 | exact Ho_nrec |].
      eapply head_op_po_satisfied; [split; assumption | exact Hann_j | exact Hbi | exact Ho_in_rem |].
      intros o0 Hpo0. cbn [rem_po] in Hpo0. rewrite Hpo_ret in Hpo0. exact Hpo0.
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | left; exact Ho_nrec | exact HA3 | discriminate].
    + eapply rec_A5_snoc_start; [exact HA5 | exact Ho_nrec | intros w dst _ Hp; discriminate Hp].
    + eapply rec_Aval_snoc_issue; [exact HAval | exact Huses_st | exact Hdv | exact Ho_nrec | exact Huse_ops].
  - (* 11. StepReadEnd *)
    rename H into Hinf_lk, H0 into Hmem_ok.
    assert (Hin_inf : In (o, PRead d a) inflight) by (eapply lookup_assoc_in with (D := op_id_eq_ops); exact Hinf_lk).
    destruct (Hinf_sp o (PRead d a) Hin_inf) as [Ho_prog [Ho_start [Ho_nend Ho_prior]]].
    assert (Hns : ~ rec_is_start ann ev).
    { intros [h [Hh Hk]]. pose proof (ops_unique_head ann Hnd_all Hh Ho_prog) as ->. discriminate Hk. }
    assert (Hperm_inf : Permutation inflight ((o, PRead d a) :: remove_assoc op_id_eqb o inflight))
      by (apply (remove_assoc_perm op_id_eq_ops o (PRead d a) inflight Hinf_nd Hin_inf)).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces.
    refine (@Build_machine_inv_at btraces _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + exact Hlen_th.
    + exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      eapply preserve_branch_inv_finish; [exact Hin_inf | reflexivity | intros ? ? H; discriminate H | exact Hinf_nd |].
      eapply Hbr; eassumption.
    + intros end_of Hve.
      assert (Heo_o : end_of o = res).
      { apply (proj1 Hve o res). apply in_app_iff; right; now left. }
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split.
        - intros o0 r0 Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 r0 Hin; apply Hc; apply in_app_iff; now left.
        - intros o0 d0 args0 Hin. destruct (op_id_eqb o0 o) eqn:E.
          + apply op_id_eqb_spec in E; subst o0.
            apply (lookup_assoc_in_nodup op_id_eq_ops o (PCompute d0 args0) inflight Hinf_nd) in Hin.
            unfold lookup_inflight in Hinf_lk; unfold inflight in Hin; cbn [eqb op_id_eq_ops] in Hin; rewrite Hinf_lk in Hin; discriminate.
          + apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E.
            apply Hinfc. apply (proj2 (in_remove_assoc_iff op_id_eq_ops o (o0, PCompute d0 args0) inflight)). auto. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_ev].
      assert (Hperm_rhs :
        Permutation (records ++ map (pending_end_event end_of) inflight)
                    ((records ++ [ev]) ++ map (pending_end_event end_of) (remove_assoc op_id_eqb o inflight))).
      { rewrite <- app_assoc. apply Permutation_app_head.
        eapply perm_trans; [apply Permutation_map; exact Hperm_inf |].
        cbn [map pending_end_event]. rewrite Heo_o. apply Permutation_refl. }
      split; [eapply perm_trans; [exact Hperm | exact Hperm_rhs] | eapply Permutation_NoDup; [exact Hperm_rhs | exact Hnd_ev]].
    + exact Huses_eq.
    + intros u Hu; apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin; apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | right; exists HRead; auto].
    + eapply unique_phase_snoc_end; [exact Hnd_all | exact Huniq | exact Hrec_val | exact Ho_prog | discriminate | reflexivity | exact Ho_nend].
    + apply (NoDup_remove_assoc op_id_eq_ops o inflight Hinf_nd).
    + intros o0 pk0 Hin.
      apply (proj1 (in_remove_assoc_iff op_id_eq_ops o (o0, pk0) inflight)) in Hin as [Hin Hne_o].
      cbn [fst] in Hne_o. destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
      repeat split; [exact H1 | apply in_app_iff; now left | |].
      * intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction | cbn in Hov; congruence].
      * destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]]; [| contradiction].
           assert (Hlt1 : (i1 < length records)%nat) by lia.
           rewrite nth_error_app1 in H1' by exact Hlt1.
           destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12); [left; apply rec_has_phase_snoc; auto | right; auto].
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (op_id_eqb (owner r) o) eqn:E.
        -- apply op_id_eqb_spec in E; rewrite E. left.
           exists ev; split; [apply in_app_iff; right; now left | split; [reflexivity | exists HRead; auto]].
        -- apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E.
           destruct (H2ph r h Hin Hh Hne Hk) as [Hend | [pk [Hpk Hpp]]].
           ++ left; apply rec_has_phase_snoc; exact Hend.
           ++ right; exists pk; split; [| exact Hpp].
              apply (proj2 (in_remove_assoc_iff op_id_eq_ops o (owner r, pk) inflight)); auto.
      * exfalso; apply Hns; exists h; auto.
    + intros w p0 q0 fl0 Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl0).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 r0. unfold mem'; cbn [mem_done_val lookup_assoc]. destruct (op_id_eqb o0 o) eqn:E.
      * apply op_id_eqb_spec in E; subst o0. rewrite !in_app_iff. split.
        -- intros H; inversion H; subst; left; right; left; reflexivity.
        -- intros [[Hin | [Heq | []]] | [Hin | [Heq | []]]]; try discriminate.
           ++ exfalso; apply Ho_nend; exists (EventRecord o (LReadEnd r0)); split; [exact Hin | split; [reflexivity | exists HRead; auto]].
           ++ inversion Heq; reflexivity.
           ++ exfalso; apply Ho_nend; exists (EventRecord o (LComputeEnd r0)); split; [exact Hin | split; [reflexivity |]].
              destruct (Hrec_val _ Hin) as [[h [Hh Hk]] | [h [Hh Hk]]];
                pose proof (ops_unique_head ann Hnd_all Hh Ho_prog) as ->; discriminate Hk.
      * apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E. rewrite Hdv, !in_app_iff.
        split; [intros [|]; [left; left | right; left]; auto |].
        intros [[| [Heq | []]] | [| [Heq | []]]]; try (unfold ev in Heq; inversion Heq; congruence); try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh |].
      unfold memory_step_ok, ev; cbn [owner payload]. unfold records; rewrite rev_involutive, app_nil_r.
      rewrite Ho_prior, <- Hmw. destruct (mem_lookup a (ms_mem st)) as [v0|] eqn:Hv0; [symmetry; apply Hmem_ok; reflexivity | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_prog) as ->.
        apply In_nth_error in Ho_start as [i1 Hi1].
        assert (Hlt1 : (i1 < length records)%nat) by (apply nth_error_Some; congruence).
        exists i1, (EventRecord o (LReadStart d a)); repeat split; auto.
        rewrite nth_error_app1 by exact Hlt1; exact Hi1.
    + eapply rec_A2_snoc_non_start; [exact HA2 | exact Hns].
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | right; exact Hns | exact HA3 | discriminate].
    + eapply rec_A5_snoc_non_start; [exact HA5 | exact Hns].
    + eapply rec_Aval_snoc_non_start; [exact HAval | exact Hns].
  - (* 12. StepWriteEnd *)
    rename H into Hinf_lk.
    assert (Hin_inf : In (o, PWrite d a data) inflight) by (eapply lookup_assoc_in with (D := op_id_eq_ops); exact Hinf_lk).
    destruct (Hinf_sp o (PWrite d a data) Hin_inf) as [Ho_prog [Ho_start [Ho_nend Ho_prior]]].
    assert (Hns : ~ rec_is_start ann ev).
    { intros [h [Hh Hk]]. pose proof (ops_unique_head ann Hnd_all Hh Ho_prog) as ->. discriminate Hk. }
    assert (Hperm_inf : Permutation inflight ((o, PWrite d a data) :: remove_assoc op_id_eqb o inflight))
      by (apply (remove_assoc_perm op_id_eq_ops o (PWrite d a data) inflight Hinf_nd Hin_inf)).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces.
    refine (@Build_machine_inv_at btraces _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + exact Hlen_th.
    + exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      eapply preserve_branch_inv_finish; [exact Hin_inf | reflexivity | intros ? ? H; discriminate H | exact Hinf_nd |].
      eapply Hbr; eassumption.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split.
        - intros o0 r0 Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 r0 Hin; apply Hc; apply in_app_iff; now left.
        - intros o0 d0 args0 Hin. destruct (op_id_eqb o0 o) eqn:E.
          + apply op_id_eqb_spec in E; subst o0.
            apply (lookup_assoc_in_nodup op_id_eq_ops o (PCompute d0 args0) inflight Hinf_nd) in Hin.
            unfold lookup_inflight in Hinf_lk; unfold inflight in Hin; cbn [eqb op_id_eq_ops] in Hin; rewrite Hinf_lk in Hin; discriminate.
          + apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E.
            apply Hinfc. apply (proj2 (in_remove_assoc_iff op_id_eq_ops o (o0, PCompute d0 args0) inflight)). auto. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_ev].
      assert (Hperm_rhs :
        Permutation (records ++ map (pending_end_event end_of) inflight)
                    ((records ++ [ev]) ++ map (pending_end_event end_of) (remove_assoc op_id_eqb o inflight))).
      { rewrite <- app_assoc. apply Permutation_app_head.
        eapply perm_trans; [apply Permutation_map; exact Hperm_inf |].
        cbn [map pending_end_event]. apply Permutation_refl. }
      split; [eapply perm_trans; [exact Hperm | exact Hperm_rhs] | eapply Permutation_NoDup; [exact Hperm_rhs | exact Hnd_ev]].
    + exact Huses_eq.
    + intros u Hu; apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin; apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | right; exists HWrite; auto].
    + eapply unique_phase_snoc_end; [exact Hnd_all | exact Huniq | exact Hrec_val | exact Ho_prog | discriminate | reflexivity | exact Ho_nend].
    + apply (NoDup_remove_assoc op_id_eq_ops o inflight Hinf_nd).
    + intros o0 pk0 Hin.
      apply (proj1 (in_remove_assoc_iff op_id_eq_ops o (o0, pk0) inflight)) in Hin as [Hin Hne_o].
      cbn [fst] in Hne_o. destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
      repeat split; [exact H1 | apply in_app_iff; now left | |].
      * intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction | cbn in Hov; congruence].
      * destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]]; [| contradiction].
           assert (Hlt1 : (i1 < length records)%nat) by lia.
           rewrite nth_error_app1 in H1' by exact Hlt1.
           destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12); [left; apply rec_has_phase_snoc; auto | right; auto].
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (op_id_eqb (owner r) o) eqn:E.
        -- apply op_id_eqb_spec in E; rewrite E. left.
           exists ev; split; [apply in_app_iff; right; now left | split; [reflexivity | exists HWrite; auto]].
        -- apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E.
           destruct (H2ph r h Hin Hh Hne Hk) as [Hend | [pk [Hpk Hpp]]].
           ++ left; apply rec_has_phase_snoc; exact Hend.
           ++ right; exists pk; split; [| exact Hpp].
              apply (proj2 (in_remove_assoc_iff op_id_eq_ops o (owner r, pk) inflight)); auto.
      * exfalso; apply Hns; exists h; auto.
    + intros w p0 q0 fl0 Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl0).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh |].
      unfold memory_step_ok, ev; cbn [owner payload]. unfold records; rewrite rev_involutive, app_nil_r.
      rewrite Ho_prior. exact I.
    + intros a0. unfold mem', mem_lookup; cbn [mem_writes lookup_assoc].
      unfold ev; rewrite (latest_write_cons_write_end a0 o (ms_rev_trace st) Ho_prior).
      destruct (Nat.eqb a0 a); [reflexivity | apply Hmw].
    + apply Forall_app; split; [exact Htgt | repeat constructor].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_prog) as ->.
        apply In_nth_error in Ho_start as [i1 Hi1].
        assert (Hlt1 : (i1 < length records)%nat) by (apply nth_error_Some; congruence).
        exists i1, (EventRecord o (LWriteStart d a data)); repeat split; auto.
        rewrite nth_error_app1 by exact Hlt1; exact Hi1.
    + eapply rec_A2_snoc_non_start; [exact HA2 | exact Hns].
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | right; exact Hns | exact HA3 | discriminate].
    + eapply rec_A5_snoc_non_start; [exact HA5 | exact Hns].
    + eapply rec_Aval_snoc_non_start; [exact HAval | exact Hns].
  - (* 13. StepComputeEnd *)
    rename H into Hinf_lk, H0 into Hcomp_ok.
    assert (Hin_inf : In (o, PCompute d args) inflight) by (eapply lookup_assoc_in with (D := op_id_eq_ops); exact Hinf_lk).
    destruct (Hinf_sp o (PCompute d args) Hin_inf) as [Ho_prog [Ho_start [Ho_nend _]]].
    assert (Hns : ~ rec_is_start ann ev).
    { intros [h [Hh Hk]]. pose proof (ops_unique_head ann Hnd_all Hh Ho_prog) as ->. discriminate Hk. }
    assert (Hperm_inf : Permutation inflight ((o, PCompute d args) :: remove_assoc op_id_eqb o inflight))
      by (apply (remove_assoc_perm op_id_eq_ops o (PCompute d args) inflight Hinf_nd Hin_inf)).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces.
    refine (@Build_machine_inv_at btraces _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + exact Hlen_th.
    + exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      eapply preserve_branch_inv_finish; [exact Hin_inf | reflexivity | | exact Hinf_nd | eapply Hbr; eassumption].
      intros d0 args0 Heq; inversion Heq; subst; exists res; split; auto.
    + intros end_of Hve.
      assert (Heo_o : end_of o = res).
      { apply (proj1 (proj2 Hve) o res). apply in_app_iff; right; now left. }
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split.
        - intros o0 r0 Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 r0 Hin; apply Hc; apply in_app_iff; now left.
        - intros o0 d0 args0 Hin. destruct (op_id_eqb o0 o) eqn:E.
          + apply op_id_eqb_spec in E; subst o0.
            apply (lookup_assoc_in_nodup op_id_eq_ops o (PCompute d0 args0) inflight Hinf_nd) in Hin.
            unfold lookup_inflight in Hinf_lk; unfold inflight in Hin; cbn [eqb op_id_eq_ops] in Hin; rewrite Hinf_lk in Hin; inversion Hin; subst d0 args0.
            rewrite Heo_o; exact Hcomp_ok.
          + apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E.
            apply Hinfc. apply (proj2 (in_remove_assoc_iff op_id_eq_ops o (o0, PCompute d0 args0) inflight)). auto. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_ev].
      assert (Hperm_rhs :
        Permutation (records ++ map (pending_end_event end_of) inflight)
                    ((records ++ [ev]) ++ map (pending_end_event end_of) (remove_assoc op_id_eqb o inflight))).
      { rewrite <- app_assoc. apply Permutation_app_head.
        eapply perm_trans; [apply Permutation_map; exact Hperm_inf |].
        cbn [map pending_end_event]. rewrite Heo_o. apply Permutation_refl. }
      split; [eapply perm_trans; [exact Hperm | exact Hperm_rhs] | eapply Permutation_NoDup; [exact Hperm_rhs | exact Hnd_ev]].
    + exact Huses_eq.
    + intros u Hu; apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin; apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | right; exists HCompute; auto].
    + eapply unique_phase_snoc_end; [exact Hnd_all | exact Huniq | exact Hrec_val | exact Ho_prog | discriminate | reflexivity | exact Ho_nend].
    + apply (NoDup_remove_assoc op_id_eq_ops o inflight Hinf_nd).
    + intros o0 pk0 Hin.
      apply (proj1 (in_remove_assoc_iff op_id_eq_ops o (o0, pk0) inflight)) in Hin as [Hin Hne_o].
      cbn [fst] in Hne_o. destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
      repeat split; [exact H1 | apply in_app_iff; now left | |].
      * intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction | cbn in Hov; congruence].
      * destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]]; [| contradiction].
           assert (Hlt1 : (i1 < length records)%nat) by lia.
           rewrite nth_error_app1 in H1' by exact Hlt1.
           destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12); [left; apply rec_has_phase_snoc; auto | right; auto].
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (op_id_eqb (owner r) o) eqn:E.
        -- apply op_id_eqb_spec in E; rewrite E. left.
           exists ev; split; [apply in_app_iff; right; now left | split; [reflexivity | exists HCompute; auto]].
        -- apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E.
           destruct (H2ph r h Hin Hh Hne Hk) as [Hend | [pk [Hpk Hpp]]].
           ++ left; apply rec_has_phase_snoc; exact Hend.
           ++ right; exists pk; split; [| exact Hpp].
              apply (proj2 (in_remove_assoc_iff op_id_eq_ops o (owner r, pk) inflight)); auto.
      * exfalso; apply Hns; exists h; auto.
    + intros w p0 q0 fl0 Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl0).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + eapply flags_inv_snoc_other; [exact Hfl | discriminate | discriminate | discriminate | discriminate].
    + intros o0 r0. unfold mem'; cbn [mem_done_val lookup_assoc]. destruct (op_id_eqb o0 o) eqn:E.
      * apply op_id_eqb_spec in E; subst o0. rewrite !in_app_iff. split.
        -- intros H; inversion H; subst; right; right; left; reflexivity.
        -- intros [[Hin | [Heq | []]] | [Hin | [Heq | []]]]; try discriminate.
           ++ exfalso; apply Ho_nend; exists (EventRecord o (LReadEnd r0)); split; [exact Hin | split; [reflexivity |]].
              destruct (Hrec_val _ Hin) as [[h [Hh Hk]] | [h [Hh Hk]]];
                pose proof (ops_unique_head ann Hnd_all Hh Ho_prog) as ->; discriminate Hk.
           ++ exfalso; apply Ho_nend; exists (EventRecord o (LComputeEnd r0)); split; [exact Hin | split; [reflexivity | exists HCompute; auto]].
           ++ inversion Heq; reflexivity.
      * apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E. rewrite Hdv, !in_app_iff.
        split; [intros [|]; [left; left | right; left]; auto |].
        intros [[| [Heq | []]] | [| [Heq | []]]]; try (unfold ev in Heq; inversion Heq; congruence); try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Ho_prog) as ->.
        apply In_nth_error in Ho_start as [i1 Hi1].
        assert (Hlt1 : (i1 < length records)%nat) by (apply nth_error_Some; congruence).
        exists i1, (EventRecord o (LComputeStart d args)); repeat split; auto.
        rewrite nth_error_app1 by exact Hlt1; exact Hi1.
    + eapply rec_A2_snoc_non_start; [exact HA2 | exact Hns].
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | right; exact Hns | exact HA3 | discriminate].
    + eapply rec_A5_snoc_non_start; [exact HA5 | exact Hns].
    + eapply rec_Aval_snoc_non_start; [exact HAval | exact Hns].
  - (* 14. StepSetFlagEnd *)
    rename H into Hinf_lk, H0 into Hdrained, H1 into Hflag_f.
    assert (Hin_inf : In (f, PSetFlag p q fl deps) inflight) by (eapply lookup_assoc_in with (D := op_id_eq_ops); exact Hinf_lk).
    destruct (Hinf_sp f (PSetFlag p q fl deps) Hin_inf) as [Hf_prog [Hf_start [Hf_nend Hf_deps]]].
    assert (Hns : ~ rec_is_start ann ev).
    { intros [h [Hh Hk]]. pose proof (ops_unique_head ann Hnd_all Hh Hf_prog) as ->. discriminate Hk. }
    assert (Hperm_inf : Permutation inflight ((f, PSetFlag p q fl deps) :: remove_assoc op_id_eqb f inflight))
      by (apply (remove_assoc_perm op_id_eq_ops f (PSetFlag p q fl deps) inflight Hinf_nd Hin_inf)).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces.
    refine (@Build_machine_inv_at btraces _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + exact Hlen_th.
    + exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      eapply preserve_branch_inv_finish; [exact Hin_inf | reflexivity | intros ? ? H; discriminate H | exact Hinf_nd |].
      eapply Hbr; eassumption.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split.
        - intros o0 r0 Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 r0 Hin; apply Hc; apply in_app_iff; now left.
        - intros o0 d0 args0 Hin. destruct (op_id_eqb o0 f) eqn:E.
          + apply op_id_eqb_spec in E; subst o0.
            apply (lookup_assoc_in_nodup op_id_eq_ops f (PCompute d0 args0) inflight Hinf_nd) in Hin.
            unfold lookup_inflight in Hinf_lk; unfold inflight in Hin; cbn [eqb op_id_eq_ops] in Hin; rewrite Hinf_lk in Hin; discriminate.
          + apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E.
            apply Hinfc. apply (proj2 (in_remove_assoc_iff op_id_eq_ops f (o0, PCompute d0 args0) inflight)). auto. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_ev].
      assert (Hperm_rhs :
        Permutation (records ++ map (pending_end_event end_of) inflight)
                    ((records ++ [ev]) ++ map (pending_end_event end_of) (remove_assoc op_id_eqb f inflight))).
      { rewrite <- app_assoc. apply Permutation_app_head.
        eapply perm_trans; [apply Permutation_map; exact Hperm_inf |].
        cbn [map pending_end_event]. apply Permutation_refl. }
      split; [eapply perm_trans; [exact Hperm | exact Hperm_rhs] | eapply Permutation_NoDup; [exact Hperm_rhs | exact Hnd_ev]].
    + exact Huses_eq.
    + intros u Hu; apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin; apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | right; exists HSetFlag; auto].
    + eapply unique_phase_snoc_end; [exact Hnd_all | exact Huniq | exact Hrec_val | exact Hf_prog | discriminate | reflexivity | exact Hf_nend].
    + apply (NoDup_remove_assoc op_id_eq_ops f inflight Hinf_nd).
    + intros o0 pk0 Hin.
      apply (proj1 (in_remove_assoc_iff op_id_eq_ops f (o0, pk0) inflight)) in Hin as [Hin Hne_o].
      cbn [fst] in Hne_o. destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
      repeat split; [exact H1 | apply in_app_iff; now left | |].
      * intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction | cbn in Hov; congruence].
      * destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]]; [| contradiction].
           assert (Hlt1 : (i1 < length records)%nat) by lia.
           rewrite nth_error_app1 in H1' by exact Hlt1.
           destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12); [left; apply rec_has_phase_snoc; auto | right; auto].
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (op_id_eqb (owner r) f) eqn:E.
        -- apply op_id_eqb_spec in E; rewrite E. left.
           exists ev; split; [apply in_app_iff; right; now left | split; [reflexivity | exists HSetFlag; auto]].
        -- apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E.
           destruct (H2ph r h Hin Hh Hne Hk) as [Hend | [pk [Hpk Hpp]]].
           ++ left; apply rec_has_phase_snoc; exact Hend.
           ++ right; exists pk; split; [| exact Hpp].
              apply (proj2 (in_remove_assoc_iff op_id_eq_ops f (owner r, pk) inflight)); auto.
      * exfalso; apply Hns; exists h; auto.
    + intros w p0 q0 fl0 Hw Hnend. apply Haw_fwd with (p := p0) (fl := fl0).
      * apply in_app_iff in Hw as [Hw | [Heq | []]]; [exact Hw | discriminate Heq].
      * intro Hend; apply Hnend; apply rec_has_phase_snoc; exact Hend.
    + (* A4 核心转移：flag 从 false -> true，对应 word ++ [FlagSet] *)
      intros p' q' fl'. unfold sync'; cbn [sync_flags].
      destruct (flag_key_eqb (eqb Pe) (eqb Ee) (p', q', fl') (p, q, fl)) eqn:Ekey.
      * apply (proj1 (flag_key_eqb_spec Pe Ee _ _)) in Ekey. inversion Ekey; subst p' q' fl'.
        destruct (Hfl p q fl) as [word [Hproj Hst]].
        rewrite Hflag_f in Hst.
        exists (word ++ [FlagSet]). split.
        -- apply projection_snoc_keep.
           ++ eapply projection_ext; [| exact Hproj].
              intros r l Hr. destruct l; cbn; rewrite in_app_iff; split; try tauto;
                intros [Hp [| [Heq | []]]]; try discriminate; auto.
           ++ split; [reflexivity | apply in_app_iff; left; exact Hf_start].
        -- rewrite (flag_is_set_true_eq Pe Ee p q fl _). exists word; split; auto.
      * assert (Hneq : (p', q', fl') <> (p, q, fl)).
        { intro E; rewrite (proj2 (flag_key_eqb_spec Pe Ee _ _) E) in Ekey; discriminate. }
        destruct (Hfl p' q' fl') as [word [Hproj Hst]].
        exists word. rewrite (flag_is_set_true_neq Pe Ee _ Hneq). split; [| exact Hst].
        apply projection_snoc_skip.
        -- eapply projection_ext; [| exact Hproj].
           intros r l Hr. destruct l; cbn; rewrite in_app_iff; split; try tauto;
             intros [Hp [| [Heq | []]]]; try discriminate; auto.
        -- intros [[|] [Hp Hin]].
           ++ apply in_app_iff in Hin as [Hin | [Heq | []]]; [| discriminate].
              apply In_nth_error in Hin as [i1 Hi1].
              apply In_nth_error in Hf_start as [i2 Hi2].
              assert (Ei : i1 = i2) by (eapply Huniq; [exact Hi1 | exact Hi2 | reflexivity | reflexivity]).
              subst i2. rewrite Hi1 in Hi2; inversion Hi2; subst. apply Hneq; reflexivity.
           ++ discriminate Hp.
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Hf_prog) as ->.
        apply In_nth_error in Hf_start as [i1 Hi1].
        assert (Hlt1 : (i1 < length records)%nat) by (apply nth_error_Some; congruence).
        exists i1, (EventRecord f (LSetFlagStart p q fl)); repeat split; auto.
        rewrite nth_error_app1 by exact Hlt1; exact Hi1.
    + eapply rec_A2_snoc_non_start; [exact HA2 | exact Hns].
    + (* A3 核心验证：f 完成时，所有之前在 src = p 上发起的 o 都已在 records 中完成 *)
      intros f0 o0 src0 Hf0 Hpb jf rf Hjf Hof Hkf.
      apply nth_error_app_snoc in Hjf as [[Hjf Hltf] | [-> ->]].
      * destruct Hpb as [i1 [i2 [r1 [r2 [H1 [Ho1 [Hs1 [Hp1 [H2 [Ho2 [Hs2 [Hp2 Hlt12]]]]]]]]]]]].
        apply nth_error_app_snoc in H2 as [[H2 Hlt2] | [-> ->]]; [| exfalso; apply Hns; exact Hs2].
        assert (Hlt1 : (i1 < length records)%nat) by lia.
        rewrite nth_error_app1 in H1 by exact Hlt1.
        assert (Hpb0 : exists i1 i2 r1 r2,
          nth_error records i1 = Some r1 /\ owner r1 = o0 /\ rec_is_start ann r1 /\ pipeline (payload r1) = Some src0 /\
          nth_error records i2 = Some r2 /\ owner r2 = f0 /\ rec_is_start ann r2 /\ pipeline (payload r2) = Some src0 /\
          (i1 < i2)%nat) by (exists i1, i2, r1, r2; repeat split; assumption).
        destruct (HA3 f0 o0 src0 Hf0 Hpb0 jf rf Hjf Hof Hkf) as [io [ro [Hio [Hoo [Heo Hlt]]]]].
        exists io, ro; repeat split; auto. rewrite nth_error_app1; [exact Hio | apply nth_error_Some; congruence].
      * cbn [owner] in Hof; subst f0.
        destruct Hpb as [i1 [i2 [r1 [r2 [H1 [Ho1 [Hs1 [Hp1 [H2 [Ho2 [Hs2 [Hp2 Hlt12]]]]]]]]]]]].
        apply nth_error_app_snoc in H2 as [[H2 Hlt2] | [-> ->]]; [| exfalso; apply Hns; exact Hs2].
        assert (Hlt1 : (i1 < length records)%nat) by lia.
        rewrite nth_error_app1 in H1 by exact Hlt1.
        (* 确定 src0 = p，因为 r2 是 f 的唯一 Start 记录 *)
        apply In_nth_error in Hf_start as [is His].
        assert (Hk2 : kind (payload r2) = SetFlagStart).
        { destruct Hs2 as [h2 [Hh2 Hk2]]. rewrite Ho2 in Hh2.
          pose proof (ops_unique_head ann Hnd_all Hh2 Hf_prog) as ->. exact Hk2. }
        assert (Eis : i2 = is) by (eapply Huniq; [exact H2 | exact His | exact Ho2 | exact Hk2]).
        subst is. rewrite H2 in His; inversion His; subst r2.
        cbn [payload pipeline] in Hp2; inversion Hp2; subst src0.
        (* 由 Hf_deps，要么 o0 已完成，要么 o0 ∈ deps；由 Hdrained，deps 中的操作都不在 inflight 中，故必已完成！ *)
        assert (Hdone_o0 : rec_has_end ann records o0).
        { destruct (Hf_deps o0 i1 i2 r1 (EventRecord f (LSetFlagStart p q fl)) H1 Ho1 Hs1 Hp1 H2 eq_refl Hs2 Hlt12)
            as [Hend | Hdep]; [exact Hend |].
          unfold deps_drained in Hdrained.
          pose proof (proj1 (forallb_forall _ _) Hdrained o0 Hdep) as Hnone_b.
          cbn beta in Hnone_b.
          destruct (lookup_assoc op_id_eqb o0 (sync_inflight (ms_sync st))) eqn:Hlk0; [discriminate Hnone_b |].
          fold inflight in Hlk0.
          apply (proj1 (lookup_assoc_none_iff op_id_eq_ops o0 inflight)) in Hlk0.
          destruct Hs1 as [h1 [Hh1 Hk1]].
          assert (H2ph_h1 : start_kind h1 <> end_kind h1).
          { destruct r1 as [o1 pl1]; cbn in *; destruct pl1; try discriminate Hp1;
              destruct h1; try discriminate Hk1; discriminate. }
          apply nth_error_In in H1.
          destruct (H2ph r1 h1 H1 Hh1 H2ph_h1 Hk1) as [Hend | [pk1 [Hpk1 _]]].
          - rewrite Ho1 in Hend; exact Hend.
          - exfalso; apply Hlk0. rewrite Ho1 in Hpk1.
            change o0 with (fst (o0, pk1)); apply in_map; exact Hpk1. }
        destruct Hdone_o0 as [ro [Hro [Hoo Heo]]].
        apply In_nth_error in Hro as [io Hio].
        assert (Hltio : (io < length records)%nat) by (apply nth_error_Some; congruence).
        exists io, ro; repeat split; auto. rewrite nth_error_app1 by exact Hltio; exact Hio.
    + eapply rec_A5_snoc_non_start; [exact HA5 | exact Hns].
    + eapply rec_Aval_snoc_non_start; [exact HAval | exact Hns].
  - (* 15. StepWaitFlagEnd *)
    rename H into Hinf_lk, H0 into Hflag_t, H1 into Hth_w.
    assert (Hin_inf : In (w, PWaitFlag p q fl j) inflight) by (eapply lookup_assoc_in with (D := op_id_eq_ops); exact Hinf_lk).
    destruct (Hinf_sp w (PWaitFlag p q fl j) Hin_inf) as [Hw_prog [Hw_start [Hw_nend _]]].
    assert (Hns : ~ rec_is_start ann ev).
    { intros [h [Hh Hk]]. pose proof (ops_unique_head ann Hnd_all Hh Hw_prog) as ->. discriminate Hk. }
    assert (Hperm_inf : Permutation inflight ((w, PWaitFlag p q fl j) :: remove_assoc op_id_eqb w inflight))
      by (apply (remove_assoc_perm op_id_eq_ops w (PWaitFlag p q fl j) inflight Hinf_nd Hin_inf)).
    assert (Hrev' : rev (ev :: ms_rev_trace st) = records ++ [ev]) by (cbn; reflexivity).
    exists btraces.
    refine (@Build_machine_inv_at btraces _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
      cbn [ms_threads ms_sync ms_mem ms_rev_trace ms_rev_uses sync_inflight sync_flags sync_active_wait mem_writes mem_done_val];
      rewrite ?Hrev'.
    + rewrite length_update_nth; exact Hlen_th.
    + exact Hlen_bt.
    + intros k ann_k ts_k bt_k Hann_k Hts_k Hbt_k.
      destruct (Nat.eq_dec j k) as [-> | Hneq].
      * assert (Hklt : (k < length (ms_threads st))%nat) by (apply nth_error_Some; congruence).
        rewrite nth_error_update_nth_eq in Hts_k by exact Hklt.
        inversion Hts_k; subst ts_k.
        pose proof (Hbr k ann_k (TWaitingFlag w next_cur) bt_k Hann_k Hth_w Hbt_k) as Hbi.
        pose proof (preserve_branch_inv_finish (ev_end := ev) Hin_inf eq_refl (fun _ _ H => ltac:(discriminate H)) Hinf_nd Hbi) as Hbi'.
        constructor.
        -- exact (bi_head Hbi').
        -- exact (bi_rem_sub Hbi').
        -- exact (bi_rem_nodup Hbi').
        -- exact (bi_rem_fresh Hbi').
        -- intros o u Hpo Hu.
           destruct (bi_po_closed Hbi' o u Hpo Hu) as [Hrem | [Hs [Hg | [cur0 Hw]]]].
           ++ left; exact Hrem.
           ++ right; split; [exact Hs | left; exact Hg].
           ++ inversion Hw; subst o cur0.
              right; split; [exact Hs | left].
              exists ev; split; [apply in_app_iff; right; now left | split; [reflexivity | exists HWaitFlag; auto]].
        -- exact (bi_cps Hbi').
        -- exact (bi_steps_comp Hbi').
      * rewrite nth_error_update_nth_neq in Hts_k by exact Hneq.
        eapply preserve_branch_inv_finish; [exact Hin_inf | reflexivity | intros ? ? H; discriminate H | exact Hinf_nd |].
        eapply Hbr; eassumption.
    + intros end_of Hve.
      assert (Hve0 : valid_end_of records inflight end_of).
      { destruct Hve as [Hr [Hc Hinfc]]. repeat split.
        - intros o0 r0 Hin; apply Hr; apply in_app_iff; now left.
        - intros o0 r0 Hin; apply Hc; apply in_app_iff; now left.
        - intros o0 d0 args0 Hin. destruct (op_id_eqb o0 w) eqn:E.
          + apply op_id_eqb_spec in E; subst o0.
            apply (lookup_assoc_in_nodup op_id_eq_ops w (PCompute d0 args0) inflight Hinf_nd) in Hin.
            unfold lookup_inflight in Hinf_lk; unfold inflight in Hin; cbn [eqb op_id_eq_ops] in Hin; rewrite Hinf_lk in Hin; discriminate.
          + apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E.
            apply Hinfc. apply (proj2 (in_remove_assoc_iff op_id_eq_ops w (o0, PCompute d0 args0) inflight)). auto. }
      destruct (Hpn end_of Hve0) as [Hperm Hnd_ev].
      assert (Hperm_rhs :
        Permutation (records ++ map (pending_end_event end_of) inflight)
                    ((records ++ [ev]) ++ map (pending_end_event end_of) (remove_assoc op_id_eqb w inflight))).
      { rewrite <- app_assoc. apply Permutation_app_head.
        eapply perm_trans; [apply Permutation_map; exact Hperm_inf |].
        cbn [map pending_end_event]. apply Permutation_refl. }
      split; [eapply perm_trans; [exact Hperm | exact Hperm_rhs] | eapply Permutation_NoDup; [exact Hperm_rhs | exact Hnd_ev]].
    + exact Huses_eq.
    + intros u Hu; apply rec_has_phase_snoc; apply Huses_st; exact Hu.
    + intros r Hin; apply in_app_iff in Hin as [Hin | [<- | []]]; [auto | right; exists HWaitFlag; auto].
    + eapply unique_phase_snoc_end; [exact Hnd_all | exact Huniq | exact Hrec_val | exact Hw_prog | discriminate | reflexivity | exact Hw_nend].
    + apply (NoDup_remove_assoc op_id_eq_ops w inflight Hinf_nd).
    + intros o0 pk0 Hin.
      apply (proj1 (in_remove_assoc_iff op_id_eq_ops w (o0, pk0) inflight)) in Hin as [Hin Hne_o].
      cbn [fst] in Hne_o. destruct (Hinf_sp o0 pk0 Hin) as [H1 [H2 [H3 H4]]].
      repeat split; [exact H1 | apply in_app_iff; now left | |].
      * intros Hne. apply rec_has_phase_snoc_inv in Hne as [| [Hov _]]; [contradiction | cbn in Hov; congruence].
      * destruct pk0 as [d0 a0 | d0 a0 data0 | d0 args0 | p0 q0 fl0 deps0 | p0 q0 fl0 bj0]; auto.
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- rewrite prior_start_cons_other; [exact H4 | right; exact I].
        -- intros o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12.
           apply nth_error_app_snoc in H2' as [[H2' Hlt2] | [-> ->]]; [| contradiction].
           assert (Hlt1 : (i1 < length records)%nat) by lia.
           rewrite nth_error_app1 in H1' by exact Hlt1.
           destruct (H4 o' i1 i2 r1 r2 H1' Ho1 Hs1 Hp1 H2' Ho2 Hs2 Hlt12); [left; apply rec_has_phase_snoc; auto | right; auto].
    + intros r h Hin Hh Hne Hk. apply in_app_iff in Hin as [Hin | [<- | []]].
      * destruct (op_id_eqb (owner r) w) eqn:E.
        -- apply op_id_eqb_spec in E; rewrite E. left.
           exists ev; split; [apply in_app_iff; right; now left | split; [reflexivity | exists HWaitFlag; auto]].
        -- apply (proj1 (eqb_neq op_id_eq_ops _ _)) in E.
           destruct (H2ph r h Hin Hh Hne Hk) as [Hend | [pk [Hpk Hpp]]].
           ++ left; apply rec_has_phase_snoc; exact Hend.
           ++ right; exists pk; split; [| exact Hpp].
              apply (proj2 (in_remove_assoc_iff op_id_eq_ops w (owner r, pk) inflight)); auto.
      * exfalso; apply Hns; exists h; auto.
    + intros w0 p0 q0 fl0 Hw0 Hnend0.
      apply in_app_iff in Hw0 as [Hw0 | [Heq | []]]; [| discriminate Heq].
      assert (Hnend0_old : ~ rec_has_end ann records w0)
        by (intro H0; apply Hnend0; apply rec_has_phase_snoc; exact H0).
      destruct (eqb Pe q0 q) eqn:Eq.
      * apply (proj1 (eqb_spec Pe _ _)) in Eq; subst q0.
        pose proof (Haw_fwd w p q fl Hw_start Hw_nend) as H1.
        pose proof (Haw_fwd w0 p0 q fl0 Hw0 Hnend0_old) as H2.
        assert (Ew : w0 = w) by congruence. subst w0.
        exfalso; apply Hnend0. exists ev; split; [apply in_app_iff; right; now left | split; [reflexivity | exists HWaitFlag; auto]].
      * apply (proj1 (eqb_neq Pe _ _)) in Eq.
        unfold sync', active_wait_of, active_wait_clear; cbn [sync_active_wait].
        rewrite (lookup_assoc_remove_neq Pe _ Eq).
        eapply Haw_fwd; eassumption.
    + (* A4 核心转移：flag 从 true -> false，对应 w0 ++ [FlagSet; FlagWait] *)
      intros p' q' fl'. unfold sync'; cbn [sync_flags].
      destruct (flag_key_eqb (eqb Pe) (eqb Ee) (p', q', fl') (p, q, fl)) eqn:Ekey.
      * apply (proj1 (flag_key_eqb_spec Pe Ee _ _)) in Ekey. inversion Ekey; subst p' q' fl'.
        destruct (Hfl p q fl) as [word [Hproj Hst]].
        rewrite Hflag_t in Hst. destruct Hst as [w0 [-> Hstar0]].
        exists ((w0 ++ [FlagSet]) ++ [FlagWait]). split.
        -- apply projection_snoc_keep.
           ++ eapply projection_ext; [| exact Hproj].
              intros r l Hr. destruct l; cbn; rewrite in_app_iff; split; try tauto;
                intros [Hp [| [Heq | []]]]; try discriminate; auto.
           ++ split; [reflexivity | apply in_app_iff; left; exact Hw_start].
        -- rewrite (flag_is_set_false_eq Pe Ee p q fl _).
           rewrite <- app_assoc. apply star_snoc; [exact Hstar0 | reflexivity].
      * assert (Hneq : (p', q', fl') <> (p, q, fl)).
        { intro E; rewrite (proj2 (flag_key_eqb_spec Pe Ee _ _) E) in Ekey; discriminate. }
        destruct (Hfl p' q' fl') as [word [Hproj Hst]].
        exists word. rewrite (flag_is_set_false_neq Pe Ee _ Hneq). split; [| exact Hst].
        apply projection_snoc_skip.
        -- eapply projection_ext; [| exact Hproj].
           intros r l Hr. destruct l; cbn; rewrite in_app_iff; split; try tauto;
             intros [Hp [| [Heq | []]]]; try discriminate; auto.
        -- intros [[|] [Hp Hin]].
           ++ discriminate Hp.
           ++ apply in_app_iff in Hin as [Hin | [Heq | []]]; [| discriminate].
              apply In_nth_error in Hin as [i1 Hi1].
              apply In_nth_error in Hw_start as [i2 Hi2].
              assert (Ei : i1 = i2) by (eapply Huniq; [exact Hi1 | exact Hi2 | reflexivity | reflexivity]).
              subst i2. rewrite Hi1 in Hi2; inversion Hi2; subst. apply Hneq; reflexivity.
    + intros o0 r0. try unfold mem'; cbn [mem_done_val]. rewrite Hdv, !in_app_iff. split; [intros [|]; [left; left | right; left]; auto |].
      intros [[| [Heq | []]] | [| [Heq | []]]]; try discriminate; auto.
    + apply memory_history_snoc; split; [exact Hmh | exact I].
    + intros a0. rewrite latest_write_cons_non_write_end by discriminate. apply Hmw.
    + apply Forall_app; split; [exact Htgt | repeat constructor].
    + intros o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0.
      apply nth_error_app_snoc in Hj0 as [[Hj0 _] | [-> ->]].
      * destruct (HA1 o0 h0 Hh0 Hne0 j0 r2 Hj0 Ho0 Hk0) as [i1 [r1 [H1 [Ho1 [Hk1 Hlt]]]]].
        exists i1, r1; repeat split; auto. rewrite nth_error_app1; [exact H1 | apply nth_error_Some; congruence].
      * cbn [owner] in Ho0; subst o0. pose proof (ops_unique_head ann Hnd_all Hh0 Hw_prog) as ->.
        apply In_nth_error in Hw_start as [i1 Hi1].
        assert (Hlt1 : (i1 < length records)%nat) by (apply nth_error_Some; congruence).
        exists i1, (EventRecord w (LWaitFlagStart p q fl)); repeat split; auto.
        rewrite nth_error_app1 by exact Hlt1; exact Hi1.
    + eapply rec_A2_snoc_non_start; [exact HA2 | exact Hns].
    + eapply rec_A3_snoc_non_setflag_end; [exact Hnd_all | exact HA1 | exact Huniq | right; exact Hns | exact HA3 | discriminate].
    + eapply rec_A5_snoc_non_start; [exact HA5 | exact Hns].
    + eapply rec_Aval_snoc_non_start; [exact HAval | exact Hns].
Qed.

Lemma auto_steps_preserves_inv budget st1 st2 :
  auto_steps layout cfg model Pe Ee budget st1 st2 ->
  machine_inv st1 ->
  machine_inv st2.
Proof.
  induction 1; [auto | intros Hi; apply IHauto_steps; eapply auto_step_preserves_inv; eassumption].
Qed.

(* ========================================================================== *)
(* 7. 从 machine_inv 直接导出 TraceSemantics（Cand + A1..A5 + A_val + A_mem）  *)
(* ========================================================================== *)

(* 构造满足所有已完成结果及在途 Compute 操作的完备结果赋值函数 end_of *)
Lemma exists_valid_end_of st :
  machine_inv st ->
  exists end_of : op_id -> Val,
    valid_end_of (rev (ms_rev_trace st)) (sync_inflight (ms_sync st)) end_of.
Proof.
  intros Hinv. destruct Hinv as [btraces Hinv].
  pose proof (mi_done_val Hinv) as Hdv.
  pose proof (mi_inflight_nodup Hinv) as Hinf_nd.
  pose proof (mi_inflight_spec Hinv) as Hinf_sp.
  pose proof (mi_records_valid Hinv) as Hrec_val.
  pose proof (annotate_program_valid raw) as [_ [Hnd_all _]].
  set (records := rev (ms_rev_trace st)) in *.
  set (base := fun o => match lookup_assoc op_id_eqb o (mem_done_val (ms_mem st)) with
                        | Some v => v
                        | None => VBool false
                        end).
  assert (Hbase_r : forall o res, In (EventRecord o (LReadEnd res)) records -> base o = res).
  { intros o res Hin. unfold base.
    rewrite (proj2 (Hdv o res) (or_introl Hin)). reflexivity. }
  assert (Hbase_c : forall o res, In (EventRecord o (LComputeEnd res)) records -> base o = res).
  { intros o res Hin. unfold base.
    rewrite (proj2 (Hdv o res) (or_intror Hin)). reflexivity. }
  assert (Hinf_disj : forall o pk, In (o, pk) (sync_inflight (ms_sync st)) ->
            (forall res, ~ In (EventRecord o (LReadEnd res)) records) /\
            (forall res, ~ In (EventRecord o (LComputeEnd res)) records)).
  { intros o pk Hin. destruct (Hinf_sp o pk Hin) as [Hprog [_ [Hnend _]]]. split.
    - intros res Hr. apply Hnend.
      destruct (Hrec_val _ Hr) as [[h [Hh Hk]] | [h [Hh Hk]]].
      + pose proof (ops_unique_head ann Hnd_all Hh Hprog) as ->. destruct pk; discriminate Hk.
      + exists (EventRecord o (LReadEnd res)); repeat split; [exact Hr | exists h; auto].
    - intros res Hc. apply Hnend.
      destruct (Hrec_val _ Hc) as [[h [Hh Hk]] | [h [Hh Hk]]].
      + pose proof (ops_unique_head ann Hnd_all Hh Hprog) as ->. destruct pk; discriminate Hk.
      + exists (EventRecord o (LComputeEnd res)); repeat split; [exact Hc | exists h; auto]. }
  assert (Hext : forall inf : list (op_id * PKind),
    NoDup (map fst inf) ->
    (forall o pk, In (o, pk) inf ->
       (forall res, ~ In (EventRecord o (LReadEnd res)) records) /\
       (forall res, ~ In (EventRecord o (LComputeEnd res)) records)) ->
    exists end_of, valid_end_of records inf end_of).
  { induction inf as [|[o pk] rest IH]; intros Hnd Hdisj.
    - exists base. repeat split; [exact Hbase_r | exact Hbase_c | intros ? ? ? []].
    - cbn in Hnd. inversion Hnd as [|? ? Hni Hnd']; subst.
      destruct (IH Hnd' (fun o0 pk0 H => Hdisj o0 pk0 (or_intror H))) as [f [Hfr [Hfc Hfcomp]]].
      destruct pk as [d a | d a data | d args | p q fl deps | p q fl bj].
      + exists f; repeat split; auto; intros o0 d0 args0 [Heq | Hin]; [discriminate | eauto].
      + exists f; repeat split; auto; intros o0 d0 args0 [Heq | Hin]; [discriminate | eauto].
      + destruct (comp_total model (resource d) args) as [res Hres].
        exists (fun x => if op_id_eqb x o then res else f x).
        destruct (Hdisj o (PCompute d args) (or_introl eq_refl)) as [Hnr Hnc].
        repeat split.
        * intros o0 r0 Hin. destruct (op_id_eqb o0 o) eqn:E.
          -- apply op_id_eqb_spec in E; subst o0. exfalso; eapply Hnr; exact Hin.
          -- apply Hfr; exact Hin.
        * intros o0 r0 Hin. destruct (op_id_eqb o0 o) eqn:E.
          -- apply op_id_eqb_spec in E; subst o0. exfalso; eapply Hnc; exact Hin.
          -- apply Hfc; exact Hin.
        * intros o0 d0 args0 [Heq | Hin].
          -- inversion Heq; subst o0 d0 args0. rewrite (proj2 (op_id_eqb_spec o o) eq_refl); exact Hres.
          -- destruct (op_id_eqb o0 o) eqn:E.
             ++ apply op_id_eqb_spec in E; subst o0. exfalso; apply Hni.
                change o with (fst (o, PCompute d0 args0)); apply in_map; exact Hin.
             ++ apply Hfcomp; exact Hin.
      + exists f; repeat split; auto; intros o0 d0 args0 [Heq | Hin]; [discriminate | eauto].
      + exists f; repeat split; auto; intros o0 d0 args0 [Heq | Hin]; [discriminate | eauto]. }
  apply Hext; assumption.
Qed.

(* 逐分支组装 program_events *)
Lemma assemble_program_events end_of records inflight (anns : list AnnCmd)
    (ts : list TState) (bts : list branch_trace) (offset : nat) :
  length ts = length anns ->
  length bts = length anns ->
  (forall k ann_k t bt,
     nth_error anns k = Some ann_k ->
     nth_error ts k = Some t ->
     nth_error bts k = Some bt ->
     branch_inv records inflight (offset + k) ann_k t bt) ->
  valid_end_of records inflight end_of ->
  program_events layout model anns
    (concat (map (fun bt => flat_map (step_events end_of) (bt_steps bt)) bts))
    (concat (map bt_uses bts)).
Proof.
  revert ts bts offset. induction anns as [|a rest IH]; intros [|t ts] [|bt bts] offset Hlt Hlb Hall Hve;
    cbn in *; try discriminate; [constructor |].
  inversion Hlt as [Hlt']; inversion Hlb as [Hlb'].
  apply ProgramCons.
  - pose proof (Hall 0 a t bt eq_refl eq_refl eq_refl) as Hbi.
    assert (Hcomp_ok : Forall (step_comp_ok end_of) (bt_steps bt)).
    { apply Forall_forall. intros s Hs. destruct s; cbn [step_comp_ok]; try exact I.
      destruct (bi_steps_comp Hbi o d args Hs) as [Hinf | [res [Hrec Hc]]].
      - apply (proj2 (proj2 Hve)); exact Hinf.
      - rewrite ((proj1 (proj2 Hve)) o res Hrec). exact Hc. }
    pose proof (bi_cps Hbi Hcomp_ok) as Hcps.
    destruct t as [cur | w cur | args].
    + pose proof (Hcps [] [] (events_stop_at_event_head layout model cur (bi_head Hbi))) as Hce.
      rewrite !app_nil_r in Hce. exact Hce.
    + pose proof (Hcps [] [] (events_stop_at_event_head layout model cur (bi_head Hbi))) as Hce.
      rewrite !app_nil_r in Hce. exact Hce.
    + exact Hcps.
  - apply IH with (ts := ts) (offset := S offset); auto.
    intros k ann_k tk btk H1 H2 H3.
    replace (S offset + k)%nat with (offset + S k)%nat by lia.
    apply (Hall (S k) ann_k tk btk H1 H2 H3).
Qed.

Theorem machine_inv_implies_trace_semantics (ti : trace_indexer EventId) st :
  machine_inv st ->
  let records := rev (ms_rev_trace st) in
  let t := trace_of_records ti records in
  let kappa := kappa_of_records ti records in
  trace_semantics layout model ann t kappa /\
  Forall (fun e => target_allows cfg (payload (kappa e))) t.
Proof.
  intros Hinv records t kappa.
  destruct Hinv as [bts Hinv].
  pose proof (annotate_program_valid raw) as [_ [Hnd_all _]].
  assert (Hmap_kt : map kappa t = records) by (apply map_kappa_trace).
  assert (Hkap_k : forall idx r, nth_error records idx = Some r -> kappa (idx_to_eid ti idx) = r).
  { intros idx r0 Hr0. unfold kappa. apply kappa_of_idx; exact Hr0. }
  assert (Hearl_t : forall i j, (i < length records)%nat -> (j < length records)%nat ->
    earlier t (idx_to_eid ti i) (idx_to_eid ti j) <-> (i < j)%nat).
  { intros i j Hi Hj. unfold t. apply earlier_trace_iff; assumption. }
  assert (Hin_t : forall e, In e t <-> exists i, (i < length records)%nat /\ e = idx_to_eid ti i).
  { intros e. unfold t. apply in_trace_iff. }
  destruct (exists_valid_end_of (ex_intro _ bts Hinv)) as [end_of Hve].
  destruct Hinv as [Hlen_th Hlen_bt Hbr Hpn Huses_eq Huses_st Hrec_val Huniq
                    Hinf_nd Hinf_sp H2ph Haw_fwd Hfl Hdv Hmh Hmw Htgt HA1 HA2 HA3 HA5 HAval].
  set (events := concat (map (fun bt => flat_map (step_events end_of) (bt_steps bt)) bts)).
  set (uses_all := concat (map bt_uses bts)).
  set (ordered := records ++ map (pending_end_event end_of) (sync_inflight (ms_sync st))).
  destruct (Hpn end_of Hve) as [Hperm Hnd_ord].
  assert (Hpe : program_events layout model ann events uses_all).
  { unfold events, uses_all.
    eapply assemble_program_events with (records := records) (inflight := sync_inflight (ms_sync st))
      (ts := ms_threads st) (offset := 0);
      [exact Hlen_th | exact Hlen_bt | | exact Hve].
    intros k ann_k tk btk H1 H2 H3. cbn [Nat.add]. eapply Hbr; eassumption. }
  assert (Hnd_ev : NoDup events) by (eapply Permutation_NoDup; [apply Permutation_sym; exact Hperm | exact Hnd_ord]).
  (* 辅助桥接：event_at 与 records 中的索引 *)
  assert (Hphase_at : forall phase o e,
    event_at ann t kappa phase o e <->
    exists i r, (i < length records)%nat /\ e = idx_to_eid ti i /\
      nth_error records i = Some r /\ owner r = o /\ rec_is_phase ann phase r).
  { intros phase o e. unfold event_at, rec_is_phase, t, kappa. rewrite in_trace_iff. split.
    - intros [[i [Hi ->]] [Ho [h [Hh Hk]]]].
      destruct (nth_error records i) as [r|] eqn:Hr; [| apply nth_error_None in Hr; lia].
      pose proof (kappa_of_idx ti records i Hr) as Hkap.
      rewrite Hkap in Ho, Hk. exists i, r; repeat split; auto. exists h; rewrite Ho; auto.
    - intros [i [r [Hi [-> [Hr [Ho [h [Hh Hk]]]]]]]].
      pose proof (kappa_of_idx ti records i Hr) as Hkap.
      rewrite Hkap. split; [exists i; auto | split; [exact Ho | exists h; rewrite <- Ho; auto]]. }
  split.
  - unfold trace_semantics. exists uses_all.
    split; [| split; [unfold A_sync; split; [| split; [| split; [| split]]] | split]].
    + (* Cand / candidate_witness *)
      exists events, ordered. repeat split; [exact Hpe | exact Hnd_ev | exact Hperm |].
      unfold t, kappa. rewrite map_kappa_trace. exists (map (pending_end_event end_of) (sync_inflight (ms_sync st))). reflexivity.
    + (* A1 *)
      intros o h Hh Hne e2 He2.
      apply Hphase_at in He2 as [j [r2 [Hj [-> [Hr2 [Ho2 [h2 [Hh2 Hk2]]]]]]]].
      rewrite Ho2 in Hh2. pose proof (ops_unique_head ann Hnd_all Hh2 Hh) as ->.
      destruct (HA1 o h Hh Hne j r2 Hr2 Ho2 Hk2) as [i [r1 [Hr1 [Ho1 [Hk1 Hlt]]]]].
      assert (Hi : (i < length records)%nat) by lia.
      exists (idx_to_eid ti i). split.
      * apply Hphase_at. exists i, r1; repeat split; auto. exists h; rewrite Ho1; auto.
      * apply earlier_trace_iff; assumption.
    + (* A2 *)
      intros o u Hpo. split; intros e2 He2;
        apply Hphase_at in He2 as [j [ru [Hj [-> [Hru [Hou Hsu]]]]]];
        destruct (HA2 o u Hpo j ru Hru Hou Hsu) as
          [[i1 [r1 [Hr1 [Ho1 [Hs1 Hlt1]]]]] [i2 [r2 [Hr2 [Ho2 [Hg2 Hlt2]]]]]].
      * assert (Hi1 : (i1 < length records)%nat) by lia.
        exists (idx_to_eid ti i1); split;
          [apply Hphase_at; exists i1, r1; repeat split; auto | apply earlier_trace_iff; assumption].
      * assert (Hi2 : (i2 < length records)%nat) by lia.
        exists (idx_to_eid ti i2); split;
          [apply Hphase_at; exists i2, r2; repeat split; auto | apply earlier_trace_iff; assumption].
    + (* A3 *)
      intros f o src Hf [ea [eb [Ha [Hb [Hpa [Hpb Hearl]]]]]] ef Hef.
      apply Hphase_at in Ha as [i1 [r1 [Hi1 [-> [Hr1 [Ho1 Hs1]]]]]].
      apply Hphase_at in Hb as [i2 [r2 [Hi2 [-> [Hr2 [Ho2 Hs2]]]]]].
      apply Hphase_at in Hef as [jf [rf [Hjf [-> [Hrf [Hof [hf [Hhf Hkf]]]]]]]].
      rewrite (Hkap_k i1 r1 Hr1) in Hpa.
      rewrite (Hkap_k i2 r2 Hr2) in Hpb.
      apply (proj1 (Hearl_t i1 i2 Hi1 Hi2)) in Hearl.
      rewrite Hof in Hhf. pose proof (ops_unique_head ann Hnd_all Hhf Hf) as ->.
      assert (Hpb0 : exists i1 i2 r1 r2,
        nth_error records i1 = Some r1 /\ owner r1 = o /\ rec_is_start ann r1 /\ pipeline (payload r1) = Some src /\
        nth_error records i2 = Some r2 /\ owner r2 = f /\ rec_is_start ann r2 /\ pipeline (payload r2) = Some src /\
        (i1 < i2)%nat) by (exists i1, i2, r1, r2; repeat split; assumption).
      destruct (HA3 f o src Hf Hpb0 jf rf Hrf Hof Hkf) as [io [ro [Hio [Hoo [Heo Hlt]]]]].
      assert (Hio_lt : (io < length records)%nat) by lia.
      exists (idx_to_eid ti io); split;
        [apply Hphase_at; exists io, ro; repeat split; auto | apply Hearl_t; assumption].
    + (* A4 *)
      intros src dst fl.
      destruct (Hfl src dst fl) as [word [Hproj Hst]].
      exists word; split.
      * eapply projection_map_iff with (f := kappa); [| rewrite Hmap_kt; exact Hproj].
        intros e l He. apply Hin_t in He as [i [Hi ->]].
        destruct (nth_error records i) as [r|] eqn:Hr; [| apply nth_error_None in Hr; lia].
        pose proof (Hkap_k i r Hr) as Hkap. rewrite Hkap.
        destruct l; cbn [flag_projection rec_flag_letter].
        -- split.
           ++ intros [o [s [Hs [Hf [Hps Hke]]]]].
              apply Hphase_at in Hs as [i_s [rs [His [-> [Hrs [Hos _]]]]]].
              apply Hphase_at in Hf as [ie [re [Hie [He_eq [Hre [Hoe _]]]]]].
              apply idx_to_eid_inj in He_eq; subst ie. rewrite Hr in Hre; inversion Hre; subst re.
              rewrite (Hkap_k i_s rs Hrs) in Hps.
              rewrite Hkap in Hke.
              assert (Hpl : payload r = LSetFlagEnd) by (destruct (payload r); try discriminate Hke; reflexivity).
              split; [exact Hpl |]. rewrite Hoe.
              replace (EventRecord o (LSetFlagStart src dst fl)) with rs
                by (destruct rs; cbn in Hos, Hps; congruence).
              eapply nth_error_In; exact Hrs.
           ++ intros [Hpl Hin].
              apply In_nth_error in Hin as [i_s Hrs].
              assert (His : (i_s < length records)%nat) by (unfold records; apply nth_error_Some; rewrite Hrs; discriminate).
              destruct (Hrec_val (EventRecord (owner r) (LSetFlagStart src dst fl))
                          (nth_error_In _ _ Hrs)) as [[h [Hh Hk]] | [h [Hh Hk]]];
                cbn [owner payload kind] in Hh, Hk;
                destruct h; cbn [start_kind end_kind] in Hk; try discriminate Hk.
              exists (owner r), (idx_to_eid ti i_s). split; [| split; [| split]].
              ** apply Hphase_at. exists i_s, (EventRecord (owner r) (LSetFlagStart src dst fl)).
                 repeat split; auto. exists HSetFlag; auto.
              ** apply Hphase_at. exists i, r. repeat split; auto. exists HSetFlag; split; [exact Hh | rewrite Hpl; reflexivity].
              ** rewrite (Hkap_k i_s _ Hrs); reflexivity.
              ** rewrite Hkap, Hpl; reflexivity.
        -- split.
           ++ intros [o [s [Hs [Hf [Hps Hke]]]]].
              apply Hphase_at in Hs as [i_s [rs [His [-> [Hrs [Hos _]]]]]].
              apply Hphase_at in Hf as [ie [re [Hie [He_eq [Hre [Hoe _]]]]]].
              apply idx_to_eid_inj in He_eq; subst ie. rewrite Hr in Hre; inversion Hre; subst re.
              rewrite (Hkap_k i_s rs Hrs) in Hps.
              rewrite Hkap in Hke.
              assert (Hpl : payload r = LWaitFlagEnd) by (destruct (payload r); try discriminate Hke; reflexivity).
              split; [exact Hpl |]. rewrite Hoe.
              replace (EventRecord o (LWaitFlagStart src dst fl)) with rs
                by (destruct rs; cbn in Hos, Hps; congruence).
              eapply nth_error_In; exact Hrs.
           ++ intros [Hpl Hin].
              apply In_nth_error in Hin as [i_s Hrs].
              assert (His : (i_s < length records)%nat) by (unfold records; apply nth_error_Some; rewrite Hrs; discriminate).
              destruct (Hrec_val (EventRecord (owner r) (LWaitFlagStart src dst fl))
                          (nth_error_In _ _ Hrs)) as [[h [Hh Hk]] | [h [Hh Hk]]];
                cbn [owner payload kind] in Hh, Hk;
                destruct h; cbn [start_kind end_kind] in Hk; try discriminate Hk.
              exists (owner r), (idx_to_eid ti i_s). split; [| split; [| split]].
              ** apply Hphase_at. exists i_s, (EventRecord (owner r) (LWaitFlagStart src dst fl)).
                 repeat split; auto. exists HWaitFlag; auto.
              ** apply Hphase_at. exists i, r. repeat split; auto. exists HWaitFlag; split; [exact Hh | rewrite Hpl; reflexivity].
              ** rewrite (Hkap_k i_s _ Hrs); reflexivity.
              ** rewrite Hkap, Hpl; reflexivity.
      * destruct (flag_is_set (eqb Pe) (eqb Ee) src dst fl (sync_flags (ms_sync st))).
        -- destruct Hst as [w0 [-> Hstar0]].
           exists (w0 ++ [FlagSet; FlagWait]); split.
           ++ apply star_snoc; [exact Hstar0 | reflexivity].
           ++ exists [FlagWait]; rewrite <- app_assoc; reflexivity.
        -- exists word; split; [exact Hst | exists []; rewrite app_nil_r; reflexivity].
    + (* A5 *)
      intros w u dst Hw [ea [eb [Ha [Hb [Hpa [Hpb Hearl]]]]]] eu Heu.
      apply Hphase_at in Ha as [i1 [r1 [Hi1 [-> [Hr1 [Ho1 Hs1]]]]]].
      apply Hphase_at in Hb as [i2 [r2 [Hi2 [-> [Hr2 [Ho2 Hs2]]]]]].
      apply Hphase_at in Heu as [ju [ru [Hju [-> [Hru [Hou Hsu]]]]]].
      rewrite (Hkap_k i1 r1 Hr1) in Hpa.
      rewrite (Hkap_k i2 r2 Hr2) in Hpb.
      apply (proj1 (Hearl_t i1 i2 Hi1 Hi2)) in Hearl.
      assert (Hpb0 : exists i1 i2 r1 r2,
        nth_error records i1 = Some r1 /\ owner r1 = w /\ rec_is_start ann r1 /\ pipeline (payload r1) = Some dst /\
        nth_error records i2 = Some r2 /\ owner r2 = u /\ rec_is_start ann r2 /\ pipeline (payload r2) = Some dst /\
        (i1 < i2)%nat) by (exists i1, i2, r1, r2; repeat split; assumption).
      destruct (HA5 w u dst Hw Hpb0 ju ru Hru Hou Hsu) as [iw [rw [Hiw [How [Hkw Hlt]]]]].
      assert (Hiw_lt : (iw < length records)%nat) by lia.
      exists (idx_to_eid ti iw); split;
        [apply Hphase_at; exists iw, rw; repeat split; auto; exists HWaitFlag; rewrite How; auto
        | apply Hearl_t; assumption].
    + (* A_val / completed_result_values *)
      intros u e d res Hu Hst Hd Hres Hearl.
      apply (proj1 (Huses_eq u)) in Hu.
      apply Hphase_at in Hst as [ie [re [Hie [-> [Hre [Hoe Hse]]]]]].
      apply Hin_t in Hd as [id [Hid ->]].
      destruct (nth_error records id) as [rd|] eqn:Hrd; [| apply nth_error_None in Hrd; lia].
      unfold result_event in Hres.
      rewrite (Hkap_k id rd Hrd) in Hres.
      apply (proj1 (Hearl_t id ie Hid Hie)) in Hearl.
      exact (HAval u ie id re rd res Hu Hre Hoe Hse Hrd Hres Hearl).
    + (* A_mem / memory_values *)
      unfold memory_values, t, kappa. rewrite map_kappa_trace. exact Hmh.
  - (* target_allows *)
    apply Forall_forall. intros e He.
    apply Hin_t in He as [i [Hi ->]].
    destruct (nth_error records i) as [r|] eqn:Hr; [| apply nth_error_None in Hr; lia].
    rewrite (Hkap_k i r Hr).
    exact (proj1 (Forall_forall _ _) Htgt r (nth_error_In _ _ Hr)).
Qed.

Theorem automaton_sound (ti : trace_indexer EventId) budget st0 st :
  well_formed cfg raw ->
  init_machine budget raw = Ok st0 ->
  auto_steps layout cfg model Pe Ee budget st0 st ->
  let records := rev (ms_rev_trace st) in
  raw_program_semantics layout cfg model raw
    (trace_of_records ti records) (kappa_of_records ti records).
Proof.
  intros Hwf Hinit Hsteps records.
  pose proof (auto_steps_preserves_inv Hsteps (init_machine_inv budget Hinit)) as Hinv.
  destruct (machine_inv_implies_trace_semantics ti Hinv) as [Hts Htgt].
  pose proof (annotate_program_valid raw) as [Herase Hvalid].
  split; [exact Hwf |].
  exists ann. split.
  - split; [exact Herase | exact Hvalid].
  - unfold program_semantics.
    split; [exists raw; split; [exact Hwf | exact Herase] |].
    split; [exact Hvalid |].
    split; [exact Hts | exact Htgt].
Qed.

End Invariant.
End SoundnessProof.

(* ========================================================================== *)
(* 8. 顶层端到端可靠性定理（一阶派生解释器 & 高阶 Free Monad 解释器）           *)
(* ========================================================================== *)

Section TopLevelSoundness.
Context {Float EventId Pipe Unit : Type}.
Context (layout : allocation_layout).
Context (tgt : @executable_target Float EventId Pipe Unit).
Context (model : @computation_model Float EventId Pipe Unit).
Context (emodel : executable_model model).
Context (cpol : @choice_policy Float EventId Pipe).

Theorem derived_interpreter_sound (ti : trace_indexer EventId)
    pol step_fuel budget prog res :
  well_formed (exec_cfg tgt) (instantiate_shared layout 0 prog) ->
  run_derived_interpreter layout tgt emodel cpol pol step_fuel budget prog = Ok res ->
  shared_program_semantics layout (exec_cfg tgt) model prog
    (trace_of_records ti (rr_events res))
    (kappa_of_records ti (rr_events res)).
Proof.
  intros Hwf Hrun.
  unfold run_derived_interpreter in Hrun.
  destruct (run_derived_state layout tgt emodel cpol pol step_fuel budget prog) as [st|] eqn:Hst;
    cbn [result_bind] in Hrun; [| discriminate].
  inversion Hrun; subst res. cbn [rr_events machine_state_to_result].
  destruct (run_derived_state_steps layout tgt emodel cpol pol step_fuel budget prog Hst)
    as [st0 [Hinit Hsteps]].
  unfold shared_program_semantics.
  eapply automaton_sound; eassumption.
Qed.

Theorem free_interpreter_sound (ti : trace_indexer EventId)
    pol step_fuel branch_fuel budget prog res :
  (1 <= budget)%nat ->
  well_formed (exec_cfg tgt) (instantiate_shared layout 0 prog) ->
  run_free_interpreter layout tgt emodel cpol pol step_fuel branch_fuel budget prog = Ok res ->
  shared_program_semantics layout (exec_cfg tgt) model prog
    (trace_of_records ti (rr_events res))
    (kappa_of_records ti (rr_events res)).
Proof.
  intros Hge Hwf Hrun.
  unfold run_free_interpreter in Hrun.
  destruct (run_free_state layout tgt emodel cpol pol step_fuel branch_fuel budget prog) as [fst|] eqn:Hfst;
    cbn [result_bind] in Hrun; [| discriminate].
  inversion Hrun; subst res.
  destruct (run_free_state_steps layout tgt emodel cpol pol step_fuel branch_fuel prog Hge Hfst)
    as [st0 [st [Hinit [Hsteps Hcs]]]].
  rewrite <- (corresponds_state_result Hcs).
  cbn [rr_events machine_state_to_result].
  unfold shared_program_semantics.
  eapply automaton_sound; eassumption.
Qed.

End TopLevelSoundness.

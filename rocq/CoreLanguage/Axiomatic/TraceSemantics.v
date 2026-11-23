From Stdlib Require Import List ZArith Sorting.Permutation.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Export Events.
Import ListNotations.
Set Implicit Arguments.

Definition prefix {A : Type} (u v : list A) : Prop :=
  exists suffix, v = u ++ suffix.

Inductive star {A : Type} (language : list A -> Prop) : list A -> Prop :=
| StarEmpty : star language []
| StarCons : forall word rest, language word -> star language rest ->
    star language (word ++ rest).

Definition prefix_language {A : Type} (language : list A -> Prop) (u : list A) :=
  exists word, language word /\ prefix u word.

(* 完整的有序投影：跳过事件仅限于该事件没有任何投影字母的情形。 *)
Inductive projection {A B : Type} (select : A -> B -> Prop) : list A -> list B -> Prop :=
| ProjectNil : projection select [] []
| ProjectKeep : forall e t letter word,
    select e letter -> projection select t word ->
    projection select (e :: t) (letter :: word)
| ProjectSkip : forall e t word,
    (~ exists letter, select e letter) -> projection select t word ->
    projection select (e :: t) word.

Lemma projection_unique {A B} (select : A -> B -> Prop)
    (functional : forall e a b, select e a -> select e b -> a = b) t u v :
  projection select t u -> projection select t v -> u = v.
Proof.
  intros left. revert v. induction left; intros v right; inversion right; subst;
    try reflexivity; try solve [exfalso; eauto].
  - f_equal; eauto.
  - eauto.
Qed.

Inductive flag_letter := FlagSet | FlagWait.

Section Semantics.
Context {Float EventId Pipe Unit : Type}.
Local Notation Val := (@value Float EventId Pipe).
Local Notation Program := (@program Float EventId Pipe Unit op_id).
Local Notation EventRecordType := (@event_record Float EventId Pipe Unit).
Local Notation Use := (@use_record Float EventId Pipe).
Local Notation Model := (@computation_model Float EventId Pipe Unit).
Local Notation Kappa := (@interpretation Float EventId Pipe Unit).

(* 候选见证同时记录有限事件集合和各操作数实际取得的值。 *)
Definition candidate_witness (model : Model) (p : Program)
    (t : list EventId) (kappa : Kappa) (uses : list Use) : Prop :=
  exists events ordered,
    program_events model p events uses /\ NoDup events /\
    Permutation events ordered /\ prefix (map kappa t) ordered.

Definition Cand (model : Model) (p : Program) (t : list EventId) (kappa : Kappa) : Prop :=
  exists uses, candidate_witness model p t kappa uses.

Lemma allocated_address_in_trace model p t kappa e address :
  Cand model p t kappa -> In e t -> payload (kappa e) = LAlloc address ->
  address = Allocated (InBranch (owner (kappa e))).
Proof.
  intros (uses & events & ordered & generated & _ & perm & suffix & eq) member allocated.
  assert (present : In (kappa e) events).
  { apply (Permutation_in _ (Permutation_sym perm)). rewrite eq.
    apply in_or_app; left; apply in_map; assumption. }
  apply program_allocation_origins in generated.
  apply (proj1 (Forall_forall _ _) generated) in present.
  unfold allocation_origin in present; rewrite allocated in present; exact present.
Qed.

Lemma candidate_record_injective model p t kappa :
  Cand model p t kappa -> forall e d, In e t -> In d t -> kappa e = kappa d -> e = d.
Proof.
  intros (uses & events & ordered & generated & unique & perm & suffix & eq).
  apply (Permutation_NoDup perm) in unique. rewrite eq in unique.
  clear generated perm eq. induction t as [|head tail IH]; cbn; [tauto |].
  inversion unique as [|? ? absent tail_unique]; subst.
  intros e d [<-|he] [<-|hd] same; auto.
  - exfalso. apply absent, in_or_app. left. rewrite same. apply in_map; exact hd.
  - exfalso. apply absent, in_or_app. left. rewrite <- same. apply in_map; exact he.
Qed.

Corollary distinct_allocation_events model p t kappa e d a b :
  Cand model p t kappa -> In e t -> In d t ->
  payload (kappa e) = LAlloc a -> payload (kappa d) = LAlloc b ->
  e <> d -> a <> b.
Proof.
  intros candidate emitted_e emitted_d label_e label_d different.
  intros equal. apply different. eapply candidate_record_injective; eauto.
  pose proof (allocated_address_in_trace e candidate emitted_e label_e) as ae.
  pose proof (allocated_address_in_trace d candidate emitted_d label_d) as ad.
  destruct (kappa e), (kappa d); cbn in *; congruence.
Qed.

Definition earlier (t : list EventId) (a b : EventId) : Prop :=
  exists i j, nth_error t i = Some a /\ nth_error t j = Some b /\ (i < j)%nat.

Definition before (t : list EventId) (a b : EventId -> Prop) : Prop :=
  forall eb, b eb -> exists ea, a ea /\ earlier t ea eb.

Definition event_at (p : Program) (t : list EventId) (kappa : Kappa)
    (phase : head -> event_kind) (o : op_id) (e : EventId) : Prop :=
  In e t /\ owner (kappa e) = o /\
  exists h, In (o, h) (program_operations p) /\ kind (payload (kappa e)) = phase h.

Definition starts p t kappa := event_at p t kappa start_kind.
Definition finishes p t kappa := event_at p t kappa end_kind.
Definition gate_kind (h : head) :=
  if nonblocking h then start_kind h else end_kind h.
Definition gates p t kappa := event_at p t kappa gate_kind.

Definition pipeline_before (p : Program) (t : list EventId) (kappa : Kappa)
    (pipe : Pipe) (o u : op_id) : Prop :=
  exists a b, starts p t kappa o a /\ starts p t kappa u b /\
    pipeline (payload (kappa a)) = Some pipe /\
    pipeline (payload (kappa b)) = Some pipe /\ earlier t a b.

Lemma no_pipeline_order_for_direct p t kappa o
    (direct : forall e, starts p t kappa o e -> pipeline (payload (kappa e)) = None) :
  forall q u, ~ pipeline_before p t kappa q o u /\ ~ pipeline_before p t kappa q u o.
Proof.
  intros q u; split; intros (a & b & sa & sb & qa & qb & _).
  - rewrite (direct a sa) in qa. discriminate.
  - rewrite (direct b sb) in qb. discriminate.
Qed.

Definition A1 (p : Program) (t : list EventId) (kappa : Kappa) : Prop :=
  forall o h, In (o, h) (program_operations p) -> start_kind h <> end_kind h ->
    before t (starts p t kappa o) (finishes p t kappa o).

Definition A2 (p : Program) (t : list EventId) (kappa : Kappa) : Prop :=
  forall o u, In (o, u) (po p) ->
    before t (starts p t kappa o) (starts p t kappa u) /\
    before t (gates p t kappa o) (starts p t kappa u).

Definition A3 (p : Program) (t : list EventId) (kappa : Kappa) : Prop :=
  forall f o source,
    In (f, HSetFlag) (program_operations p) ->
    pipeline_before p t kappa source o f ->
    before t (finishes p t kappa o) (finishes p t kappa f).

Definition flag_projection (p : Program) (t : list EventId) (kappa : Kappa)
    (source target : Pipe) (flag : EventId) (e : EventId) (letter : flag_letter) : Prop :=
  exists o s, starts p t kappa o s /\ finishes p t kappa o e /\
    match letter with
    | FlagSet => payload (kappa s) = LSetFlagStart source target flag /\
                 kind (payload (kappa e)) = SetFlagEnd
    | FlagWait => payload (kappa s) = LWaitFlagStart source target flag /\
                  kind (payload (kappa e)) = WaitFlagEnd
    end.

Definition A4 (p : Program) (t : list EventId) (kappa : Kappa) : Prop :=
  forall source target flag, exists word,
    projection (flag_projection p t kappa source target flag) t word /\
    prefix_language (star (fun block => block = [FlagSet; FlagWait])) word.

Lemma A4_projected_word p t kappa source target flag word :
  A4 p t kappa ->
  projection (flag_projection p t kappa source target flag) t word ->
  prefix_language (star (fun block => block = [FlagSet; FlagWait])) word.
Proof.
  intros axiom4 observed. destruct (axiom4 source target flag) as (w & projected & alternating).
  assert (word = w) as ->; [ | exact alternating].
  eapply projection_unique; [ | exact observed | exact projected].
  intros e a b (o & s & _ & _ & ha) (u & v & _ & _ & hb).
  destruct a,b; cbn in *; intuition congruence.
Qed.

Definition A5 (p : Program) (t : list EventId) (kappa : Kappa) : Prop :=
  forall w u target,
    In (w, HWaitFlag) (program_operations p) ->
    pipeline_before p t kappa target w u ->
    before t (finishes p t kappa w) (starts p t kappa u).

Definition A_sync (p : Program) (t : list EventId) (kappa : Kappa) : Prop :=
  A1 p t kappa /\ A2 p t kappa /\ A3 p t kappa /\
  A4 p t kappa /\ A5 p t kappa.

Definition result_event (kappa : Kappa) (o : op_id) (d : EventId)
    (result : Val) : Prop :=
  kappa d = EventRecord o (LReadEnd result) \/
  kappa d = EventRecord o (LComputeEnd result).

(* 操作数在发起事件处取值；if 和 return 的单个事件也是其发起事件。 *)
Definition completed_result_values (p : Program) (t : list EventId)
    (kappa : Kappa) (uses : list Use) : Prop :=
  forall use e d result, In use uses ->
    starts p t kappa (consumer use) e -> In d t ->
    result_event kappa (producer use) d result ->
    earlier t d e -> used_value use = result.

Definition trace_semantics (model : Model) (p : Program)
    (t : list EventId) (kappa : Kappa) : Prop :=
  exists uses, candidate_witness model p t kappa uses /\
    A_sync p t kappa /\ completed_result_values p t kappa uses.

Definition target_allows (cfg : @configuration Pipe Unit)
    (l : @label Float EventId Pipe Unit) : Prop :=
  let allowed d := declared_resource cfg (resource d) /\
    match queue d with Some p => declared_pipeline cfg p | None => True end in
  match l with
  | LReadStart d a => allowed d /\ can_read cfg (resource d) a
  | LWriteStart d a _ => allowed d /\ can_write cfg (resource d) a
  | LSetFlagStart p q _ | LWaitFlagStart p q _ =>
      declared_pipeline cfg p /\ declared_pipeline cfg q
  | LComputeStart d _ => allowed d
  | LPipeAssignment _ p => declared_pipeline cfg p
  | _ => True
  end.

Definition program_semantics
    (cfg : @configuration Pipe Unit) (model : Model) (p : Program)
    (t : list EventId) (kappa : Kappa) : Prop :=
  (exists raw, well_formed cfg raw /\ map erase_annotations p = expand_program raw) /\
  annotations_valid p /\ trace_semantics model p t kappa /\
  Forall (fun e => target_allows cfg (payload (kappa e))) t.

Definition raw_program_semantics
    (cfg : @configuration Pipe Unit) (model : Model)
    (raw : @program Float EventId Pipe Unit unit)
    (t : list EventId) (kappa : Kappa) : Prop :=
  well_formed cfg raw /\ exists annotated, annotates raw annotated /\
    program_semantics cfg model annotated t kappa.

Definition shared_program_semantics cfg model (p : @shared_program Float EventId Pipe Unit) :=
  raw_program_semantics cfg model (instantiate_shared 0 p).

End Semantics.

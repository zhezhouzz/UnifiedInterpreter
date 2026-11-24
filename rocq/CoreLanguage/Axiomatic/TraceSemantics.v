From Stdlib Require Import List ZArith Bool.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Export Events.
Import ListNotations.
Set Implicit Arguments.

Record key := Key { is_block : bool; receiver : nat; source : nat; target : endpoint; flag : nat }.
Definition key_eq (a b : key) : {a=b}+{a<>b}.
Proof. decide equality; try apply Nat.eq_dec; try apply Bool.bool_dec. decide equality; apply Nat.eq_dec. Defined.
Definition addressed {D} (h : hardware D) active s cross p q e :=
  map (fun t => Key cross t p q e)
    (if cross then filter (fun t => block_edge h s p t q) active else [s]).
Definition barriers {D} (h : hardware D) s b :=
  match b with Pipe p => [p] | All => data_pipes h s end.
Definition open_item {D} (i : item D) :=
  match i with WaitItem _ _ _ | BarItem => false | _ => true end.
Definition remove_at {A} (j : nat) (xs : list A) := firstn j xs ++ skipn (S j) xs.
Definition commit {D} (m : memory D) (writes : patch D) :=
  fold_left (fun mem av => update mem (fst av) (Some (snd av))) writes m.
Definition sample {D} (m : memory D) loc :=
  match m loc with Some v => Some (loc,v) | None => None end.

(* 这三个投影只依赖轨迹前缀。position 是完成时在所属队列中的位置。 *)
Record observations D := Observed {
  pending : nat -> nat -> list (item D);
  token : key -> bool;
  contents : memory D
}.
Definition initial {D} (m : memory D) := Observed (fun _ _ => []) (fun _ => false) m.
Definition after {D} (h : hardware D) active (o : observations D) (e : event D) : observations D :=
  let queues s p :=
    match e with
    | Issued u (Submit r i) => if Nat.eqb s u && Nat.eqb p r then pending o s p ++ [i] else pending o s p
    | Issued u (Fence b) => if Nat.eqb s u && existsb (Nat.eqb p) (barriers h u b)
          then pending o s p ++ [BarItem] else pending o s p
    | Done u r j _ _ => if Nat.eqb s u && Nat.eqb p r then remove_at j (pending o s p) else pending o s p
    | _ => pending o s p end in
  let bits k :=
    match e with
    | Issued s (ScalarWait p f) => if key_eq k (Key true s p ScalarEnd f) then false else token o k
    | Done s p _ (SetItem cross q f) _ =>
        if in_dec key_eq k (addressed h active s cross p q f) then true else token o k
    | Done s q _ (WaitItem cross p f) _ => if key_eq k (Key cross s p (Data q) f) then false else token o k
    | _ => token o k end in
  let mem := match e with
    | Issued _ (Reserve _ _ ls _) => commit (contents o) (map (fun a => (a,Uninit)) ls)
    | Done _ _ _ _ writes => commit (contents o) writes
    | _ => contents o end in
  Observed queues bits mem.
Definition history {D} h active (o : observations D) t := fold_left (after h active) t o.

Definition queue_law {D} (o : observations D) (e : event D) : Prop :=
  match e with
  | Done s p j i _ => let q := pending o s p in nth_error q j = Some i /\
      match i with SetItem _ _ _ | BarItem => j=0
      | _ => forallb open_item (firstn j q) = true end
  | _ => True end.
Definition flag_law {D} (h : hardware D) active (o : observations D) (e : event D) : Prop :=
  match e with
  | Issued s (ScalarWait p f) => token o (Key true s p ScalarEnd f) = true
  | Done s p _ (SetItem cross q f) _ => Forall (fun k => token o k = false) (addressed h active s cross p q f)
  | Done s q _ (WaitItem cross p f) _ => token o (Key cross s p (Data q) f) = true
  | _ => True end.
Definition memory_law {D} (h : hardware D) (o : observations D) (e : event D) : Prop :=
  match e with
  | Issued s (Reserve space dims ls v) => allocation h s space dims ls v /\
      Forall (fun a => contents o a = None) ls
  | Done s p _ (Operation f args r w) delta =>
      Forall (fun a => accessible h s a /\ exists v, contents o a = Some v) (r ++ w) /\
      NoDup (map fst delta) /\ incl (map fst delta) w /\
      exists inputs, traverse (sample (contents o)) r = Some inputs /\ evaluate h s p f args inputs delta
  | Done _ _ _ _ delta => delta = []
  | _ => True end.
Definition at_prefixes {D} (h : hardware D) active (o : observations D)
    (test : observations D -> event D -> Prop) (t : list (event D)) :=
  forall pre e post, t = pre ++ e :: post -> test (history h active o pre) e.
Definition A_sync {D} (h : hardware D) active o t :=
  at_prefixes h active o queue_law t /\ at_prefixes h active o (flag_law h active) t.
Definition trace_semantics {D} (h : hardware D) alloc (P : program D) env m t :=
  let streams := map fst P in let o := initial m in
  candidate h alloc P env t /\ A_sync h streams o t /\ at_prefixes h streams o (memory_law h) t.
Definition program_semantics {D} (h : hardware D) params (P : program D) env m t :=
  well_formed h params P /\
  (forall s x, In s (map fst P) -> option_map category_of (env s x) = params s x) /\
  exists alloc, trace_semantics h alloc P env m t.
Definition controls_finished {D} (h : hardware D) alloc (P : program D) env t :=
  Forall (fun sc => control_plan h alloc (fst sc) (snd sc) (env (fst sc)) =
                    (issued_by (fst sc) t,true)) P.
Definition terminated {D} (h : hardware D) alloc P env m t :=
  controls_finished h alloc P env t /\
  forall s p, pending (history h (map fst P) (initial m) t) s p = [].
Definition deadlocked {D} (h : hardware D) P env m t :=
  (exists alloc, trace_semantics h alloc P env m t) /\
  ~ (exists alloc, trace_semantics h alloc P env m t /\ terminated h alloc P env m t) /\
  forall e alloc, ~ trace_semantics h alloc P env m (t ++ [e]).
Definition opened_access {D} (o : observations D) s p j r w :=
  exists f args, nth_error (pending o s p) j = Some (Operation f args r w) /\
                 forallb open_item (firstn j (pending o s p)) = true.
Definition race {D} (o : observations D) :=
  exists s p j u q k r w r' w' a,
    (s,p,j) <> (u,q,k) /\ opened_access o s p j r w /\ opened_access o u q k r' w' /\
    ((In a w /\ In a (r' ++ w')) \/ (In a r /\ In a w')).

Lemma prefixes_append {D} (h : hardware D) streams o test t u :
  at_prefixes h streams o test (t++u) -> at_prefixes h streams o test t.
Proof.
  intros H pre e post ->. apply H with (post:=post++u).
  rewrite <- app_assoc. reflexivity.
Qed.
Theorem trace_prefix_closed {D} (h : hardware D) a P env m t u :
  trace_semantics h a P env m (t++u) -> trace_semantics h a P env m t.
Proof.
  intros [[C Owners] [[Q F] M]]. split; [split|].
  - apply Forall_forall. intros sc I. rewrite Forall_forall in C.
    destruct (C sc I) as [rest E]. exists (issued_by (fst sc) u ++ rest).
    unfold issued_by in *. now rewrite E, flat_map_app, app_assoc.
  - apply Forall_app in Owners. tauto.
  - repeat split; eapply prefixes_append; eassumption.
Qed.

Section LocalNotifications.
Context {D : domains} (h : hardware D) (streams : list nat) (s p q f : nat).
Local Notation bit := (Key false s p (Data q) f).
Lemma local_notification_origin o t :
  token o bit = false -> token (history h streams o t) bit = true ->
  exists j delta, In (Done s p j (SetItem false (Data q) f) delta) t.
Proof.
  revert o. induction t as [|e rest IH]; intros o B T; [cbn [history fold_left] in T; congruence|].
  cbn [history fold_left] in T.
  destruct (token (after h streams o e) bit) eqn:E.
  - destruct e as [u act|u r j it delta].
    + destruct act; cbn [after token] in E; try congruence.
      destruct (key_eq _ _) in E; congruence.
    + destruct it; cbn [after token] in E; try congruence.
      * destruct (in_dec key_eq bit (addressed h streams u cross r q0 event)) as [M|N] in E; [|congruence].
        apply in_map_iff in M. destruct M as [v [K V]]. inversion K; subst.
        simpl in V. destruct V as [->|[]]. exists j,delta. now left.
      * destruct (key_eq _ _) in E; congruence.
  - destruct (IH _ E T) as [j [delta M]]. exists j,delta. now right.
Qed.
End LocalNotifications.

Theorem local_wait_requires_new_set {D} (h : hardware D) active o s p q f j k dw dw' pre middle post :
  let wait := fun n delta => @Done D s q n (WaitItem false p f) delta in
  at_prefixes h active o (flag_law h active) (pre ++ wait j dw :: middle ++ wait k dw' :: post) ->
  exists n delta, In (Done s p n (SetItem false (Data q) f) delta) middle.
Proof.
  cbn zeta. intro F. set (w := @Done D s q j (WaitItem false p f) dw).
  specialize (F (pre++w::middle) (Done s q k (WaitItem false p f) dw') post).
  rewrite <- app_assoc in F. specialize (F eq_refl).
  cbn [flag_law] in F. unfold history in F. rewrite fold_left_app in F. cbn [fold_left] in F.
  eapply local_notification_origin; [|exact F]. unfold w. cbn [after token].
  destruct (key_eq _ _); congruence.
Qed.

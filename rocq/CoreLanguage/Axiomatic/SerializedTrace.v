From Stdlib Require Import List Bool.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Export TraceSemantics.
Import ListNotations.
Set Implicit Arguments.

Section Fragments.
Context {D : domains} (h : hardware D) (active : list nat).
Definition allowed o (e : event D) :=
  queue_law o e /\ flag_law h active o e /\ memory_law h o e.
Fixpoint checked o (t : list (event D)) : Prop :=
  match t with [] => True
  | e :: rest => allowed o e /\ checked (after h active o e) rest end.

Lemma checked_prefixes o t : checked o t ->
  at_prefixes h active o (fun a e => allowed a e) t.
Proof.
  intros H pre. revert o t H. induction pre as [|e pre IH]; intros o t H f post ->.
  - exact (proj1 H).
  - exact (IH _ _ (proj2 H) f post eq_refl).
Qed.
Lemma checked_append o t u : checked o t -> checked (history h active o t) u ->
  checked o (t ++ u).
Proof.
  revert o. induction t; intros o H K; simpl in *; auto.
  split; [exact (proj1 H)|apply IHt; [exact (proj2 H)|exact K]].
Qed.
Definition owner (e : event D) := match e with Issued s _ | Done s _ _ _ _ => s end.
Definition fragment s o acts (post : observations D -> Prop) :=
  exists t, checked o t /\ Forall (fun e => owner e = s) t /\
    issued_by s t = acts /\ post (history h active o t).
Lemma fragment_append s o xs ys mid post :
  fragment s o xs mid -> (forall o', mid o' -> fragment s o' ys post) ->
  fragment s o (xs ++ ys) post.
Proof.
  intros [t [H [S [P M]]]] K. destruct (K _ M) as [u [J [U [V W]]]].
  exists (t++u). split; [now apply checked_append|].
  split; [now apply Forall_app|]. split.
  - unfold issued_by in *. now rewrite flat_map_app, P, V.
  - unfold history in *. now rewrite fold_left_app.
Qed.
Lemma fragment_weaken s o xs (mid post : observations D -> Prop) :
  fragment s o xs mid -> (forall a, mid a -> post a) -> fragment s o xs post.
Proof. intros [t [H [K [E M]]]] L. exists t. auto. Qed.
Lemma fragment_nil s o (post : observations D -> Prop) : post o -> fragment s o [] post.
Proof. intro H. exists []. repeat split; auto. Qed.
Lemma fragment_intro s o t acts (post : observations D -> Prop) :
  checked o t -> Forall (fun e => owner e = s) t -> issued_by s t = acts ->
  post (history h active o t) -> fragment s o acts post.
Proof. intros. exists t. auto. Qed.
Lemma checked_laws o t : checked o t ->
  A_sync h active o t /\ at_prefixes h active o (memory_law h) t.
Proof.
  intros H. pose proof (@checked_prefixes o t H) as K.
  repeat split; intros pre e post E; specialize (K pre e post E); unfold allowed in K; tauto.
Qed.
Theorem checked_iff_laws o t : checked o t <->
  A_sync h active o t /\ at_prefixes h active o (memory_law h) t.
Proof.
  split; [apply checked_laws|]. revert o. induction t as [|e t IH]; intros o [[Q F] M]; [exact I|].
  split.
  - split; [exact (Q [] e t eq_refl)|]. exact (conj (F [] e t eq_refl) (M [] e t eq_refl)).
  - apply IH. repeat split; intros pre f post E;
      first [apply (Q (e::pre) f post)|apply (F (e::pre) f post)|apply (M (e::pre) f post)];
      simpl; congruence.
Qed.
End Fragments.

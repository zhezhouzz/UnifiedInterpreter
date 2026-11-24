From Stdlib Require Import List ZArith Bool Lia.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import SerializedTrace Issue316.
Import ListNotations.
Set Implicit Arguments.

Module PipeExamples.
Local Notation D := (kernel_domains unit).
Definition hw := @kernel_hw unit (fun x => x) (fun x => x).
Definition alloc := @kernel_alloc unit (fun x => x).
Definition env : nat -> environment D := fun _ _ => None.
Definition no_memory : memory D := fun _ => None.
Definition signal_program k : program D :=
  [(0, waitf MTE2 Vector (ev k) (setf MTE2 Vector (ev 0) (Return [])))].
Definition wait k : item D := WaitItem false MTE2 k.
Definition set0 : item D := SetItem false (Data Vector) 0.
Definition sent k : list (event D) :=
  [Issued 0 (Submit Vector (wait k)); Issued 0 (Submit MTE2 set0); Done 0 MTE2 0 set0 []].
Definition run := sent 0 ++ [Done 0 Vector 0 (wait 0) []].
Example wait_before_set :
  trace_semantics hw alloc (signal_program 0) env no_memory run /\
  terminated hw alloc (signal_program 0) env no_memory run.
Proof.
  split.
  - split.
    + split; repeat constructor; try (exists []; reflexivity); simpl; auto.
    + apply checked_laws. vm_compute. repeat split; constructor; auto.
  - split; [repeat constructor|]. intros [|s] [|[|p]]; reflexivity.
Qed.

Lemma only_wait_left s p : pending (history hw [0] (initial no_memory) (sent 1)) s p =
  if (s =? 0) && (p =? Vector) then [wait 1] else [].
Proof. destruct s as [|s], p as [|[|p]]; reflexivity. Qed.
Example wrong_event_stuck : deadlocked hw (signal_program 1) env no_memory (sent 1).
Proof.
  assert (T : trace_semantics hw alloc (signal_program 1) env no_memory (sent 1)).
  { split.
    - split; repeat constructor; try (exists []; reflexivity); simpl; auto.
    - apply checked_laws. vm_compute. repeat split; constructor; auto. }
  split; [eauto|]. split.
  - intros [a [_ [_ Q]]]. specialize (Q 0 Vector). discriminate.
  - intros e a [[P Owners] [[Q F] M]].
    apply Forall_app in Owners. destruct Owners as [_ O]. inversion O as [|? ? E]; subst.
    change (In (owner e) [0]) in E. destruct E as [E|[]].
    destruct e as [s act|s p j it delta]; cbn [owner] in E; subst s.
    + inversion P as [|? ? K]; subst. destruct K as [rest B].
      apply (f_equal (@length _)) in B. simpl in B. discriminate.
    + specialize (Q (sent 1) (Done 0 p j it delta) [] eq_refl).
      specialize (F (sent 1) (Done 0 p j it delta) [] eq_refl).
      change (queue_law (history hw [0] (initial no_memory) (sent 1)) (Done 0 p j it delta)) in Q.
      destruct Q as [L _]. rewrite only_wait_left in L.
      destruct p as [|[|p]]; destruct j as [|j]; simpl in L; try discriminate;
        try (destruct j; discriminate). inversion L; subst. discriminate.
Qed.

Definition copy_item a b : item D := Operation load_op [@VView D a;@VView D b] [a] [b].
Definition copy_command a b := @Issue D MTE2 load_op [Literal (@VView D a);Literal (@VView D b)].
Definition copies : program D := [(0,copy_command 0 1 (copy_command 1 2 (Return [])))].
Definition word n : cell D := Stored (VInt n).
Definition mem : memory D := fun a => Some (word (Z.of_nat a)).
Definition copies_issued := [Issued 0 (Submit MTE2 (copy_item 0 1));Issued 0 (Submit MTE2 (copy_item 1 2))].
Definition first_then_second := copies_issued ++
  [Done 0 MTE2 0 (copy_item 0 1) [(1,word 0)];Done 0 MTE2 0 (copy_item 1 2) [(2,word 0)]].
Definition second_then_first := copies_issued ++
  [Done 0 MTE2 1 (copy_item 1 2) [(2,word 1)];Done 0 MTE2 0 (copy_item 0 1) [(1,word 0)]].
Example open_copies_race : race (history hw [0] (initial mem) copies_issued).
Proof.
  exists 0,MTE2,0,0,MTE2,1,[0],[1],[1],[2],1.
  split; [discriminate|]. split; [unfold opened_access; do 2 eexists; split; reflexivity|].
  split; [unfold opened_access; do 2 eexists; split; reflexivity|]. simpl; tauto.
Qed.
Example copy_completion_order :
  trace_semantics hw alloc copies env mem first_then_second /\
  trace_semantics hw alloc copies env mem second_then_first /\
  contents (history hw [0] (initial mem) first_then_second) 2 = Some (word 0) /\
  contents (history hw [0] (initial mem) second_then_first) 2 = Some (word 1).
Proof.
  split; [|split; [|split; reflexivity]]; split.
  1,3: split; repeat constructor; try (exists []; reflexivity); simpl; auto.
  all: apply checked_laws; vm_compute; repeat first [split | constructor | solve [intuition congruence] | eexists | reflexivity].
Qed.
Example barrier_blocks_later_copy :
  let prefix := [Issued 0 (Submit MTE2 (copy_item 0 1));Issued 0 (Fence (Pipe MTE2));
    Issued 0 (Submit MTE2 (copy_item 1 2))] in
  ~ queue_law (history hw [0] (initial mem) prefix)
      (Done 0 MTE2 2 (copy_item 1 2) [(2,word 1)]).
Proof. intros prefix [_ H]. discriminate. Qed.
Example descending_loop : iterations 5 (-2) (-2) = [5;3;1;-1]%Z.
Proof. reflexivity. Qed.
Example return_from_loop : control_plan hw alloc 0
  (For 0 (lit 5) (lit (-2)) (lit (-2)) (Return [Var 0]) (Barrier All End)) (env 0) =
  ([Control],true).
Proof. reflexivity. Qed.
Example zero_stride : control_plan hw alloc 0
  (For 0 (lit 0) (lit 2) (lit 0) End (Return [])) (env 0) = ([],false).
Proof. reflexivity. Qed.
End PipeExamples.

Section Broadcast.
Context {D : domains} (h : hardware D) (m : memory D) (p f : nat).
Hypothesis targets : forall t, block_edge h 0 p t ScalarEnd = ((t =? 1) || (t =? 2)).
Local Notation active := [0;1;2].
Definition broadcast : item D := SetItem true ScalarEnd f.
Definition send := [Issued 0 (Submit p broadcast);Done 0 p 0 broadcast []].
Definition consume s : event D := Issued s (ScalarWait p f).
Lemma broadcast_round :
  checked h active (initial m) (send ++ [consume 1;consume 2]) /\
  ~ flag_law h active (history h active (initial m) (send ++ [consume 1])) (Done 0 p 0 broadcast []).
Proof.
  assert (A : addressed h active 0 true p ScalarEnd f =
      [Key true 1 p ScalarEnd f;Key true 2 p ScalarEnd f]).
  { unfold addressed. cbn [filter]. rewrite !targets. reflexivity. }
  assert (Bits : forall t, t=1 \/ t=2 ->
      token (history h active (initial m) send) (Key true t p ScalarEnd f) = true).
  { intros t E. cbn [history send broadcast fold_left after token]. rewrite A.
    destruct (in_dec key_eq _ _); [reflexivity|]. exfalso; apply n. destruct E; subst; simpl; auto. }
  assert (Second : token (history h active (initial m) (send ++ [consume 1]))
      (Key true 2 p ScalarEnd f) = true).
  { unfold history. rewrite fold_left_app. cbn [fold_left consume after token].
    destruct (key_eq _ _); [discriminate|apply Bits; auto]. }
  split.
  - cbn [checked send app]. split; [repeat split|]. split.
    + unfold allowed, broadcast, queue_law,flag_law,memory_law.
      cbn [after pending token initial]. rewrite A, !Nat.eqb_refl. repeat split; repeat constructor.
    + split; [repeat split; apply Bits; auto|]. split; [repeat split; exact Second|exact I].
  - unfold flag_law,broadcast. rewrite A. intro K.
    apply Forall_inv_tail, Forall_inv in K. congruence.
Qed.
End Broadcast.

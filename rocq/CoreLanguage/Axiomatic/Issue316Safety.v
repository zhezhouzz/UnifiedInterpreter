From Stdlib Require Import List Arith Bool ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Export Issue316.
Import ListNotations.
Set Implicit Arguments.

Inductive buffer_use := LoadDestination | VectorSource.
Definition selected {D} side (a : action D) : list nat :=
  match side,a with
  | LoadDestination,Submit 0 (Operation 0 _ _ [w]) => [w]
  | VectorSource,Submit 1 (Operation 1 _ [r] _) => [r]
  | _,_ => [] end.
Definition buffer_sequence (addr : nat -> nat) n := map (fun i => addr (slot i)) (seq 0 n).
Definition addresses {D} side (t : list (event D)) := flat_map (selected side) (issued_by 0 t).
Definition data_issue {D} (a : action D) :=
  match a with Submit _ (Operation _ _ _ _) => [a] | _ => [] end.

Section Safety.
Context {F16 : Type} (addr : nat -> nat) (exp_f16 : F16 -> F16).
Theorem issue316_data_path n m t :
  issue316_trace addr exp_f16 n m t ->
  prefix (flat_map data_issue (issued_by 0 t)) (flat_map (fun i =>
    let b := addr (slot i) in
    [@op F16 MTE2 load_op (addr (src_index i)) b; op Vector exp_op b (addr output_index)]) (seq 0 n)).
Proof.
  intros [[C _] _]. inversion C as [|? ? P]; subst. cbn [fst snd] in P.
  rewrite issue316_plan in P. destruct P as [rest E]. cbn [fst] in E.
  assert (K : forall xs, flat_map data_issue (flat_map (@turn F16 addr) xs ++ cleanup) =
      flat_map (fun i => let b := addr (slot i) in
       [op MTE2 load_op (addr (src_index i)) b;op Vector exp_op b (addr output_index)]) xs).
  { induction xs as [|i xs IH]; [reflexivity|]. cbn [flat_map].
    rewrite <- app_assoc,flat_map_app,IH. reflexivity. }
  exists (flat_map data_issue rest). rewrite <- K.
  change (flat_map data_issue (@actions F16 addr n) =
    flat_map data_issue (issued_by 0 t) ++ flat_map data_issue rest).
  rewrite E,flat_map_app. reflexivity.
Qed.
Lemma selected_iterations side ub xs :
  flat_map (selected side) (flat_map (@turn_with F16 addr ub) xs ++ cleanup) =
  map (fun i => ub (slot i)) xs.
Proof.
  induction xs as [|i xs IH]; [destruct side; reflexivity|].
  cbn [flat_map map]. rewrite <- app_assoc,flat_map_app,IH. destruct side; reflexivity.
Qed.
Lemma selected_actions side n :
  flat_map (selected side) (@actions F16 addr n) = buffer_sequence addr n.
Proof.
  unfold actions,turn,buffer_sequence. rewrite flat_map_app,selected_iterations.
  destruct side; reflexivity.
Qed.
Theorem issue316_buffer_selection n m t :
  issue316_trace addr exp_f16 n m t -> forall side, prefix (addresses side t) (buffer_sequence addr n).
Proof.
  intros [[H _] _] side. inversion H as [|? ? K]; subst.
  cbn [fst snd] in K.
  rewrite issue316_plan in K. destruct K as [rest E]. simpl in E.
  exists (flat_map (selected side) rest). rewrite <- (@selected_actions side n), E, flat_map_app. reflexivity.
Qed.
Corollary issue316_iteration_address n m t side i a :
  issue316_trace addr exp_f16 n m t -> nth_error (addresses side t) i = Some a ->
  i < n /\ a = addr (if Nat.even i then 0 else 1).
Proof.
  intros H A. destruct (issue316_buffer_selection H side) as [rest E].
  assert (K : i < length (addresses side t)) by (apply nth_error_Some; congruence).
  assert (B : nth_error (buffer_sequence addr n) i = Some a) by
    (rewrite E, nth_error_app1 by exact K; exact A).
  unfold buffer_sequence in B. rewrite nth_error_map, nth_error_seq in B.
  destruct (i <? n) eqn:L; [apply Nat.ltb_lt in L|discriminate].
  injection B as <-. auto.
Qed.

Lemma prefix_selection_nth {A B} (project : A -> list B) xs ys i a :
  prefix xs ys -> nth_error (flat_map project xs) i = Some a ->
  nth_error (flat_map project ys) i = Some a.
Proof.
  intros [rest ->] E. rewrite flat_map_app,nth_error_app1; auto.
  apply nth_error_Some; congruence.
Qed.
(* UB 的实际分配可以独立于 GM 布局，也可以在任一次分配申请时停止。 *)
Theorem issue316_allocated_iteration_address al n m t side i a :
  trace_semantics (kernel_hw addr exp_f16) al issue316 (kernel_env addr n) m t ->
  nth_error (addresses side t) i = Some a ->
  i < n /\ exists ls, al 0 (slot i) = Some (ls,a).
Proof.
  intros [[C _] _] A. inversion C as [|? ? K]; subst. cbn [fst snd] in K.
  pose proof (prefix_selection_nth (selected side) i K A) as E.
  unfold control_plan,kernel in E. cbn [stream_plan lit ev setf lookup traverse integer] in E.
  destruct (al 0 0) as [[la va]|] eqn:EA; [|destruct i; discriminate].
  destruct (al 0 1) as [[lb vb]|] eqn:EB; [|destruct side,i; discriminate].
  set (ub := fun k : nat => if Nat.eqb k 0 then va else vb).
  set (start := [@Reserve (kernel_domains F16) 0 [1024%Z] la va;Reserve 0 [1024%Z] lb vb;
    put Vector MTE2 0;put Vector MTE2 1]).
  change (nth_error (flat_map (selected side) (fst (fold_right emit
    (fold_right (loop_step addr exp_f16 al ub n) (loop_end addr exp_f16 al ub n)
       (iterations 0 (Z.of_nat n) 1) 2) start))) i = Some a) in E.
  rewrite iterations_nat, loop_plan, fold_emit in E. cbn [fst] in E.
  rewrite flat_map_app,selected_iterations in E.
  assert (S : flat_map (selected side) start = []) by (destruct side; reflexivity).
  rewrite S,app_nil_l,nth_error_map,nth_error_seq in E.
  destruct (i <? n) eqn:B; [apply Nat.ltb_lt in B|discriminate]. injection E as <-.
  split; auto. unfold slot. destruct (Nat.even i); cbn [ub]; eauto.
Qed.
Corollary issue316_program_buffer_selection n m t :
  program_semantics (kernel_hw addr exp_f16) kernel_params issue316 (kernel_env addr n) m t ->
  exists al, trace_semantics (kernel_hw addr exp_f16) al issue316 (kernel_env addr n) m t /\
    forall side i a, nth_error (addresses side t) i = Some a ->
      i < n /\ exists ls, al 0 (slot i) = Some (ls,a).
Proof.
  intros [_ [_ [al T]]]. exists al. split; [exact T|].
  intros side i a A. exact (issue316_allocated_iteration_address side i T A).
Qed.
Corollary freeA_second_consumption n m pre middle post j k d d' :
  let wait := fun pos delta => @Done (kernel_domains F16) 0 MTE2 pos (WaitItem false Vector 0) delta in
  issue316_trace addr exp_f16 n m (pre ++ wait j d :: middle ++ wait k d' :: post) ->
  exists pos delta, In (Done 0 Vector pos (SetItem false (Data MTE2) 0) delta) middle.
Proof.
  cbn zeta. intros [_ [[_ F] _]].
  exact (@local_wait_requires_new_set _ _ _ _ 0 Vector MTE2 0 j k d d' pre middle post F).
Qed.
End Safety.

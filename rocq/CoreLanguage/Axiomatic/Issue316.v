From Stdlib Require Import List ZArith Lia.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Export TraceSemantics.
Import ListNotations.
Set Implicit Arguments.

(* 每个内存单元表示一个完整的 1024 元素 tile。 *)
Definition tile (F16 : Type) := {i : nat | i < 1024} -> F16.
Definition kernel_domains F16 := Domains (tile F16) nat.
Definition MTE2 := 0. Definition Vector := 1.
Definition load_op := 0. Definition exp_op := 1.
Definition output_index := 2.
Definition src_index i := 3 + i.
Definition slot i := if Nat.even i then 0 else 1.

Section Kernel.
Context {F16 : Type}.
Local Notation D := (kernel_domains F16).
Variable addr : nat -> nat.
Variable exp_f16 : F16 -> F16.
Local Notation count_var := 0.
Local Notation buffer_a := 1.
Local Notation buffer_b := 2.
Local Notation output_var := 3.
Local Notation index_var := 4.
Local Notation slot_var := 5.
Local Notation event_var := 6.
Local Notation local_view := 7.
Local Notation source_view := 8.
(* 四个标量操作依次计算 slot、事件编号、所选 UB 视图和 GM 输入视图。 *)
Definition scalar_op (g : nat) (args : list (value D)) : option (value D) :=
  match g,args with
  | 0,[VInt i] => Some (VInt (Z.of_nat (slot (Z.to_nat i))))
  | 1,[VInt k] => Some (VEvent (Z.to_nat k))
  | 2,[VInt k; VView a; VView b] => Some (VView (if Z.eqb k 0 then a else b))
  | 3,[VInt i] => Some (@VView D (addr (src_index (Z.to_nat i))))
  | _,_ => None end.
Definition transform f (c : cell D) : cell D :=
  if Nat.eqb f exp_op then match c with
    | Stored (VFloat a) => Stored (@VFloat D (fun j => exp_f16 (a j)))
    | _ => Uninit end else c.
Definition kernel_hw : hardware D := {|
  available_stream := fun s => s=0;
  data_pipes := fun _ => [MTE2;Vector];
  local_edge := fun _ p q => In (p,q) [(Vector,MTE2);(MTE2,Vector)];
  block_edge := fun _ _ _ _ => false; has_space := fun _ sp => sp=0;
  barrier_allowed := fun _ b => match b with Pipe p => In p [MTE2;Vector] | All => True end;
  accessible := fun _ _ => True;
  scalar_signature := fun g => match g with
    | 0 => Some ([TInt],TInt) | 1 => Some ([TInt],TEvent)
    | 2 => Some ([TInt;TView;TView],TView) | 3 => Some ([TInt],TView) | _ => None end;
  issue_signature := fun _ p f => if (Nat.eqb p f && Nat.ltb p 2)%bool
    then Some [TView;TView] else None;
  scalar_eval := fun _ => scalar_op;
  allocation := fun _ sp dims ls v => sp=0 /\ dims=[1024%Z] /\ ls=[v];
  footprint := fun _ _ _ vs => match vs with [VView a;VView b] => Some ([a],[b]) | _ => None end;
  evaluate := fun _ _ f vs read write => exists a b c,
    vs=[VView a;VView b] /\ read=[(a,c)] /\ write=[(b,transform f c)]
|}.
Definition kernel_alloc : allocator D := fun _ index => Some ([addr index],addr index).
Definition kernel_env n : nat -> environment D := fun _ x =>
  match x with 0 => Some (VInt (Z.of_nat n)) | 3 => Some (@VView D (addr output_index)) | _ => None end.
Definition kernel_params : nat -> context := fun _ x =>
  match x with 0 => Some TInt | 3 => Some TView | _ => None end.
Definition lit z : operand D := Literal (VInt z).
Definition ev k : operand D := Literal (VEvent k).
Definition setf p q e := @Sync D LocalSet p (Data q) e.
Definition waitf p q e := @Sync D LocalWait p (Data q) e.
Definition iteration_body : command D :=
  Scalar slot_var 0 [Var index_var] (
  Scalar event_var 1 [Var slot_var] (
  Scalar local_view 2 [Var slot_var;Var buffer_a;Var buffer_b] (
  Scalar source_view 3 [Var index_var] (
  waitf Vector MTE2 (Var event_var) (
  Issue MTE2 load_op [Var source_view;Var local_view] (
  setf MTE2 Vector (Var event_var) (
  waitf MTE2 Vector (Var event_var) (
  Issue Vector exp_op [Var local_view;Var output_var] (
  setf Vector MTE2 (Var event_var) (
  Barrier (Pipe Vector) End)))))))))).
Definition drain : command D := waitf Vector MTE2 (ev 0) (waitf Vector MTE2 (ev 1)
  (Barrier All (Return []))).
Definition kernel : command D := Alloc buffer_a 0 [lit 1024] (Alloc buffer_b 0 [lit 1024]
  (setf Vector MTE2 (ev 0) (setf Vector MTE2 (ev 1)
  (For index_var (lit 0) (Var count_var) (lit 1) iteration_body drain)))).
Definition issue316 : program D := [(0,kernel)].

Definition put p q k : action D := Submit p (SetItem false (Data q) k).
Definition take p q k : action D := Submit q (WaitItem false p k).
Definition op p f a b : action D := Submit p (@Operation D f [VView a;VView b] [a] [b]).
Definition reserve i : action D := @Reserve D 0 [1024%Z] [addr i] (addr i).
Definition setup := [reserve 0;reserve 1;put Vector MTE2 0;put Vector MTE2 1].
Definition turn_with (ub : nat -> nat) i :=
  let k := slot i in let b := ub k in
  [Control;Control;Control;Control;Control;
   take Vector MTE2 k; op MTE2 load_op (addr (src_index i)) b; put MTE2 Vector k;
   take MTE2 Vector k; op Vector exp_op b (addr output_index);
   put Vector MTE2 k; Fence (Pipe Vector)].
Definition turn := turn_with addr.
Definition cleanup := [Control;take Vector MTE2 0;take Vector MTE2 1;Fence All].
Definition actions n := setup ++ flat_map turn (seq 0 n) ++ cleanup.
Definition issue316_trace n m t :=
  trace_semantics kernel_hw kernel_alloc issue316 (kernel_env n) m t.

Lemma issue316_well_formed : well_formed kernel_hw kernel_params issue316.
Proof.
  split.
  { constructor; cbn [kernel_hw data_pipes local_edge block_edge barrier_allowed
      scalar_eval scalar_signature allocation has_space accessible footprint].
    - intros; repeat constructor; simpl; intuition discriminate.
    - intros s p q E. repeat destruct E as [E|E]; try contradiction;
        inversion E; subst; simpl; auto.
    - discriminate.
    - auto.
    - intros s f vs v E. unfold scalar_op in E.
      repeat match type of E with context [match ?a with _ => _ end] =>
        destruct a eqn:? in E end; inversion E; subst; reflexivity.
    - intros s sp dims ls v [-> [_ ->]]. repeat constructor; simpl; tauto.
    - intros s p f vs r w E.
      repeat match type of E with context [match ?a with _ => _ end] =>
        destruct a in E end; inversion E; subst; repeat constructor; simpl; tauto. }
  split; [repeat constructor; simpl; tauto|]. split; [repeat constructor|]. constructor; [|constructor].
  cbv. repeat first [split | solve [eauto 10] | eexists].
Qed.
Lemma iterations_nat n : iterations 0 (Z.of_nat n) 1 = map Z.of_nat (seq 0 n).
Proof.
  unfold iterations. change (map (fun i => (0 + Z.of_nat i * 1)%Z)
    (seq 0 (Z.to_nat ((Z.of_nat n - 0 + 1 - 1) / 1))) = map Z.of_nat (seq 0 n)).
  rewrite Z.div_1_r. replace (Z.of_nat n - 0 + 1 - 1)%Z with (Z.of_nat n) by lia.
  rewrite Nat2Z.id. apply map_ext. intros; lia.
Qed.
Definition loop_env (ub : nat -> nat) n := update (update (kernel_env n 0) buffer_a
  (Some (@VView D (ub 0)))) buffer_b (Some (@VView D (ub 1))).
Definition loop_step al ub n i (rest : nat -> plan D) index := emit Control
  (stream_plan kernel_hw al 0 iteration_body (update (loop_env ub n) index_var (Some (VInt i))) rest index).
Definition loop_end al ub n index := emit Control
  (stream_plan kernel_hw al 0 drain (loop_env ub n) (fun _ => finish) index).
Lemma step_plan al ub n i rest index : loop_step al ub n (Z.of_nat i) rest index =
  fold_right emit (rest index) (turn_with ub i).
Proof.
  unfold loop_step, loop_env, iteration_body, turn_with.
  cbn [stream_plan kernel_hw scalar_op scalar_eval footprint lookup traverse
    update Nat.eqb setf waitf ev fold_right].
  rewrite !Nat2Z.id. unfold slot. destruct (Nat.even i); reflexivity.
Qed.
Lemma fold_emit xs ys b : fold_right (@emit D) (ys,b) xs = (xs++ys,b).
Proof. induction xs; simpl; [reflexivity|now rewrite IHxs]. Qed.
Lemma loop_plan al ub n xs :
  fold_right (loop_step al ub n) (loop_end al ub n) (map Z.of_nat xs) 2 =
    (flat_map (turn_with ub) xs ++ cleanup,true).
Proof.
  induction xs as [|i xs IH]; [reflexivity|].
  cbn [map fold_right flat_map]. rewrite step_plan, IH, fold_emit, app_assoc. reflexivity.
Qed.
Lemma issue316_plan n :
  control_plan kernel_hw kernel_alloc 0 kernel (kernel_env n 0) = (actions n,true).
Proof.
  change (fold_right emit (fold_right (loop_step kernel_alloc addr n) (loop_end kernel_alloc addr n)
    (iterations 0 (Z.of_nat n) 1) 2) setup = (actions n,true)).
  rewrite iterations_nat, loop_plan, fold_emit. reflexivity.
Qed.
End Kernel.

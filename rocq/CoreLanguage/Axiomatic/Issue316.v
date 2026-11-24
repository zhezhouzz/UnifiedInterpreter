From Stdlib Require Import List ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics.
Import ListNotations.
Set Implicit Arguments.

(* GitCode Ascend/AscendNPU-IR #316，第 2.2、2.3 节。 *)
Inductive issue_pipe := MTE2 | Vector.
Inductive issue_resource := TransferEngine | VectorUnit.
Definition input_addresses count : list memory_resource := map (fun i => 2 * S i) (seq 0 count).
Definition output : memory_resource := 0.
Definition buffer_a layout := address_at layout (BeforeRun 0).
Definition buffer_b layout := address_at layout (BeforeRun 1).
Definition is_buffer layout a := a = buffer_a layout \/ a = buffer_b layout.

Definition buffers_disjoint layout count :=
  forall a, is_buffer layout a -> ~ In a (output :: input_addresses count).

Definition target layout (count : nat) : @configuration issue_pipe issue_resource :=
  {| declared_pipeline := fun _ => True;
     declared_resource := fun _ => True;
     can_read := fun r a => match r with
       | TransferEngine => In a (input_addresses count) | VectorUnit => is_buffer layout a end;
     can_write := fun r a => match r with
       | TransferEngine => is_buffer layout a | VectorUnit => a = output end |}.

Lemma separate_buffers layout : buffer_a layout <> buffer_b layout.
Proof. apply distinct_allocations. discriminate. Qed.

Section Program.
Context {F16 : Type}.
Record Tile := {
  elements : list F16;
  element_count : length elements = 1024
}.

Definition map_tile (f : F16 -> F16) (xs : Tile) : Tile :=
  {| elements := map f (elements xs);
     element_count := eq_trans (length_map f (elements xs)) (element_count xs) |}.

Local Notation Arg := (@operand Tile nat issue_pipe).
Local Notation Cmd := (@command Tile nat issue_pipe issue_resource unit).
Local Notation Model := (@computation_model Tile nat issue_pipe issue_resource).

Definition pipe_arg (p : issue_pipe) : Arg := Literal (VPipe p).
Definition flag (id : nat) : Arg := Literal (VEvent id).
Definition integer (v : Z) : Arg := Literal (VInt v).
(* 自然数只编码源程序中的变量名称。 *)
Definition bufA : var := 0.  Definition bufB : var := 1.
Definition active : var := 2. Definition i : var := 3.
Definition slot : var := 4. Definition first : var := 5.
Definition buf : var := 6. Definition ready : var := 7. Definition free : var := 8.
Definition src : var := 9. Definition x : var := 10. Definition y : var := 11.
Definition s : var := 12. Definition initialFirst : var := 13. Definition initial : var := 14.
Definition current : Arg := OVar active.

Definition fence (p : Arg) (next : Cmd) : Cmd :=
  SetFlag tt p p (flag 4) (WaitFlag tt p p (flag 4) next).

Definition choose_slot (body : Cmd) : Cmd :=
  LetAtomic tt slot IntMod [OVar i; integer 2] (
  LetAtomic tt first IntEq [OVar slot; integer 0] (
  Select buf (OVar first) (OVar bufA) (OVar bufB) (
  Select ready (OVar first) (flag 0) (flag 1) (
  Select free (OVar first) (flag 2) (flag 3) body)))).

Definition load_iteration count : Cmd :=
  choose_slot (
  LetAtomic tt src (MemoryAt (input_addresses count)) [OVar i] (
  WaitFlag tt (pipe_arg Vector) current (OVar free) (
  Read tt x (Dispatch TransferEngine (Some current)) (OVar src) (
  fence current (
  Write tt (Dispatch TransferEngine (Some current)) (OVar buf) (OVar x) (
  SetFlag tt current (pipe_arg Vector) (OVar ready) LoopEnd)))))).

Definition vector_iteration : Cmd :=
  choose_slot (
  WaitFlag tt (pipe_arg MTE2) current (OVar ready) (
  Read tt x (Dispatch VectorUnit (Some current)) (OVar buf) (
  fence current (
  CCompute tt y (Dispatch VectorUnit (Some current)) [OVar x] (
  fence current (
  Write tt (Dispatch VectorUnit (Some current)) (Literal (VMemory output)) (OVar y) (
  fence current (
  SetFlag tt current (pipe_arg MTE2) (OVar free) LoopEnd)))))))).

Definition initially_free : Cmd :=
  LetAtomic tt initialFirst IntEq [OVar s; integer 0] (
  Select initial (OVar initialFirst) (flag 2) (flag 3) (
  SetFlag tt current (pipe_arg MTE2) (OVar initial) LoopEnd)).

Definition issue316 (count : nat) : @shared_program Tile nat issue_pipe issue_resource :=
  SharedAlloc bufA (SharedAlloc bufB (Run
  [CAlias active (pipe_arg MTE2)
     (For i 0 count (load_iteration count) (Return tt []));
   CAlias active (pipe_arg Vector)
     (For s 0 (Nat.min 2 count) initially_free
       (For i 0 count vector_iteration (Return tt [])))])).

Context (layout : allocation_layout).

Definition branches count := instantiate_shared layout 0 (issue316 count).

(* 单元素 f16 指数的舍入由目标提供，Vector 对读到的整块数据逐元素计算。 *)
Definition implements_vexp (exp_f16 : F16 -> F16) (model : Model) :=
  forall xs result, comp model VectorUnit [VFloat xs] result <->
                    result = VFloat (map_tile exp_f16 xs).

Definition issue316_trace (exp_f16 : F16 -> F16) (model : Model) count t kappa :=
  (implements_vexp exp_f16 model /\ buffers_disjoint layout count) /\
  shared_program_semantics layout (target layout count) model (issue316 count) t kappa.

Example nonzero_loop_bounds :
  expand_loops (For i 3 5 (LoopEnd : Cmd) (Return tt [])) LoopEnd =
  CAlias i (integer 3) (CAlias i (integer 4) (Return tt [])).
Proof. reflexivity. Qed.

Example empty_loop_bounds (lo hi : nat) (empty : hi <= lo) :
  expand_loops (For i lo hi (load_iteration hi) (Return tt [])) LoopEnd =
  Return tt [].
Proof. cbn [expand_loops]. rewrite (proj2 (Nat.sub_0_le hi lo) empty). reflexivity. Qed.

Definition variable_type (v : var) : category :=
  match v with 0 | 1 | 6 | 9 => TMemory | 2 => TPipe | 3 | 4 | 12 => TInt
  | 5 | 13 => TBool | 7 | 8 | 14 => TEvent | _ => TFloat end.

Example issue316_well_formed count : well_formed (target layout count) (branches count).
Proof.
  split; [discriminate |].
  repeat (apply Forall_cons); try apply Forall_nil.
  all: split; [cbv; repeat constructor; cbn; intuition discriminate |].
  all: split; [cbn; repeat split; repeat apply Forall_cons; try apply Forall_nil;
                cbv; intuition congruence |].
  all: split; [cbn; tauto | exists variable_type; cbn; repeat split; repeat constructor].
Qed.

Local Definition op_id_eq_dec (x y : op_id) : {x = y} + {x <> y}.
Proof. decide equality; apply Pos.eq_dec. Defined.

Example three_iterations_annotated : annotates (branches 3) (annotate_program (branches 3)).
Proof.
  split; [reflexivity | split].
  - set (ids := map fst (program_operations (annotate_program (branches 3)))).
    assert (same : nodup op_id_eq_dec ids = ids) by (vm_compute; reflexivity).
    rewrite <- same. apply NoDup_nodup.
  - intros [|[|j]] c lookup o member; try (destruct j; discriminate).
    all: inversion lookup; subst c; clear lookup.
    all: match type of member with In _ ?ids =>
      match goal with |- thread _ = ?tid =>
        assert (branch_ids : Forall (fun u => thread u = tid) ids)
          by (vm_compute; repeat constructor);
        exact (proj1 (Forall_forall _ _) branch_ids o member)
      end end.
Qed.

(* 在两个完整分支的候选事件上检查跨 pipeline 的通知。 *)
Definition cross_flag (l : @label Tile nat issue_pipe issue_resource) :=
  match l with
  | LSetFlagStart MTE2 Vector e | LSetFlagStart Vector MTE2 e => [(FlagSet, e)]
  | LWaitFlagStart MTE2 Vector e | LWaitFlagStart Vector MTE2 e => [(FlagWait, e)]
  | _ => []
  end.

Definition transferred (l : @label Tile nat issue_pipe issue_resource) :=
  match l with LWriteStart (Dispatch TransferEngine (Some MTE2)) a _ => [a] | _ => [] end.
Definition consumed (l : @label Tile nat issue_pipe issue_resource) :=
  match l with LReadStart (Dispatch VectorUnit (Some Vector)) a => [a] | _ => [] end.
Definition slot_result (l : @label Tile nat issue_pipe issue_resource) :=
  match l with LAtomic IntMod _ (VInt v) => [v] | _ => [] end.

Definition rotation := [buffer_a layout; buffer_b layout; buffer_a layout].

(* 保留两个分支中与 bufA 复用相关的发起，检查 A3、A5 所用的 pipeline 和先后关系。 *)
Inductive reuse_step := WaitFreeA | WriteBufA | SetFreeA | WriteOutput.
Definition reuse_steps (l : @label Tile nat issue_pipe issue_resource) :=
  match l with
  | LWaitFlagStart Vector MTE2 2 => [WaitFreeA]
  | LSetFlagStart Vector MTE2 2 => [SetFreeA]
  | LWriteStart (Dispatch TransferEngine (Some MTE2)) a _ =>
      if Nat.eqb a (buffer_a layout) then [WriteBufA] else []
  | LWriteStart (Dispatch VectorUnit (Some Vector)) a _ =>
      if Nat.eqb a output then [WriteOutput] else []
  | _ => []
  end.

Local Ltac generate_events tile exp_f16 computes :=
  repeat first
    [ eapply ProgramCons | apply ProgramNil
    | eapply EventsAlias; [reflexivity |]
    | eapply EventsSelect; [reflexivity | reflexivity |]
    | eapply EventsAtomic
    | match goal with |- eval_atomic _ _ = _ => reflexivity end
    | eapply EventsSetFlag | eapply EventsWaitFlag
    | eapply EventsRead with (result := VFloat tile)
    | eapply EventsCompute with (args := [VFloat tile]) (result := VFloat (map_tile exp_f16 tile))
    | eapply EventsWrite | apply EventsReturn
    | eapply QueuedValues | eapply ValuesCons | apply ValuesNil
    | eapply UseKnown; reflexivity
    | lazymatch goal with
      | |- operand_value _ _ _ (OVar ?v) _ _ =>
          first [unify v y; eapply UseAsync with (a := VFloat (map_tile exp_f16 tile)); reflexivity
                | eapply UseAsync with (a := VFloat tile); reflexivity]
      end
    | apply (proj2 (computes tile _)); reflexivity ].

Example zero_iterations (model : Model) :
  exists events, program_events layout model (annotate_program (branches 0)) events [] /\
    map (fun e => kind (payload e)) events = [ReturnEvent; ReturnEvent].
Proof.
  eexists; split.
  - repeat first [eapply ProgramCons with (uses := []) (rest := []) | apply ProgramNil
    | eapply EventsAlias; [reflexivity |] | apply EventsReturn | apply ValuesNil].
  - reflexivity.
Qed.

Example one_iteration (model : Model) (exp_f16 : F16 -> F16)
    (tile : Tile) (computes : implements_vexp exp_f16 model) :
  exists events uses, program_events layout model (annotate_program (branches 1)) events uses /\
    flat_map (fun e => transferred (payload e)) events = [buffer_a layout] /\
    flat_map (fun e => consumed (payload e)) events = [buffer_a layout] /\
    flat_map (fun e => cross_flag (payload e)) events =
      [(FlagWait,2); (FlagSet,0); (FlagSet,2); (FlagWait,0); (FlagSet,2)].
Proof.
  eexists; eexists; split; [generate_events tile exp_f16 computes | repeat split; reflexivity].
Qed.

Example three_iteration_events (model : Model) (exp_f16 : F16 -> F16)
    (tile : Tile) (computes : implements_vexp exp_f16 model) :
  exists events uses, program_events layout model (annotate_program (branches 3)) events uses /\
    flat_map (fun e => transferred (payload e)) events = rotation /\
    flat_map (fun e => consumed (payload e)) events = rotation /\
    flat_map (fun e => slot_result (payload e)) events = [0;1;0;0;1;0]%Z /\
    flat_map (fun e => reuse_steps (payload e)) events =
      [WaitFreeA; WriteBufA; WaitFreeA; WriteBufA;
       SetFreeA; WriteOutput; SetFreeA; WriteOutput; WriteOutput; SetFreeA] /\
    filter (fun k => match k with ComputeStart | ComputeEnd => true | _ => false end)
      (map (fun e => kind (payload e)) events) =
      [ComputeStart; ComputeEnd; ComputeStart; ComputeEnd; ComputeStart; ComputeEnd] /\
    flat_map (fun e => cross_flag (payload e)) events =
      [(FlagWait,2); (FlagSet,0); (FlagWait,3); (FlagSet,1); (FlagWait,2); (FlagSet,0);
       (FlagSet,2); (FlagSet,3); (FlagWait,0); (FlagSet,2);
       (FlagWait,1); (FlagSet,3); (FlagWait,0); (FlagSet,2)].
Proof.
  eexists; eexists; split.
  - generate_events tile exp_f16 computes.
  - repeat split; try reflexivity.
    pose proof (not_eq_sym (separate_buffers layout)) as different.
    apply Nat.eqb_neq in different. unfold buffer_a, buffer_b in different.
    cbn [flat_map reuse_steps payload app]. unfold buffer_a.
    now rewrite !Nat.eqb_refl, different.
Qed.

End Program.

(* freeA 上按分支程序顺序发起的三次设置和两次等待。 *)
Inductive free_action := InitialA | ReleaseA0 | ReleaseA2 | WaitA0 | WaitA2.
Definition is_set a :=
  match a with InitialA | ReleaseA0 | ReleaseA2 => true | _ => false end.
Definition free_letter a := if is_set a then FlagSet else FlagWait.

Local Lemma flag_blocks word :
  star (fun b => b = [FlagSet; FlagWait]) word ->
  word = [] \/ exists tail, word = FlagSet :: FlagWait :: tail /\
    star (fun b => b = [FlagSet; FlagWait]) tail.
Proof.
  intros blocks. destruct blocks as [|block rest same more].
  - now left.
  - subst block. right. exists rest. auto.
Qed.

(* A3 保持设置的完成顺序，A5 保持等待的完成顺序，A4 约束两者的交错。 *)
Theorem freeA_second_consumption history :
  prefix (filter is_set history) [InitialA; ReleaseA0; ReleaseA2] ->
  prefix (filter (fun a => negb (is_set a)) history) [WaitA0; WaitA2] ->
  prefix_language (star (fun b => b = [FlagSet; FlagWait])) (map free_letter history) ->
  In WaitA2 history -> prefix [InitialA; WaitA0; ReleaseA0; WaitA2] history.
Proof.
  intros [sets S] [waits W] [word [blocks [rest R]]] member.
  assert (padded : exists suffix tail, map free_letter history ++ suffix =
    FlagSet :: FlagWait :: FlagSet :: FlagWait :: tail).
  { destruct (flag_blocks blocks) as [-> | (t & -> & more)].
    - exists (rest ++ [FlagSet; FlagWait; FlagSet; FlagWait]), [].
      rewrite app_assoc, <- R. reflexivity.
    - destruct (flag_blocks more) as [-> | (u & -> & _)].
      + exists (rest ++ [FlagSet; FlagWait]), []. rewrite app_assoc, <- R. reflexivity.
      + exists rest, u. now rewrite <- R. }
  destruct padded as (suffix & tail & order).
  do 4 (destruct history as [|a history]; [cbn in member; intuition discriminate |];
    destruct a; cbn in S,W,order,member; try discriminate).
  exists history. reflexivity.
Qed.

Corollary freeA_trace_prefix {F16} (p : @program (@Tile F16) nat issue_pipe issue_resource op_id)
    t kappa history :
  A4 p t kappa ->
  projection (flag_projection p t kappa Vector MTE2 2) t (map free_letter history) ->
  prefix (filter is_set history) [InitialA; ReleaseA0; ReleaseA2] ->
  prefix (filter (fun a => negb (is_set a)) history) [WaitA0; WaitA2] ->
  In WaitA2 history -> prefix [InitialA; WaitA0; ReleaseA0; WaitA2] history.
Proof.
  intros a4 observed sets waits. apply freeA_second_consumption; auto.
  eapply A4_projected_word; eassumption.
Qed.

Example first_slot_readable layout : can_read (target layout 3) VectorUnit (buffer_a layout).
Proof. now left. Qed.

Example mte2_cannot_read_ub layout count :
  buffers_disjoint layout count -> ~ can_read (target layout count) TransferEngine (buffer_a layout).
Proof. intros disjoint reads. eapply disjoint; [now left | now right]. Qed.

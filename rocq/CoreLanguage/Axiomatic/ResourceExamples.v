From Stdlib Require Import List ZArith Sorting.Permutation.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics.
Import ListNotations.

Module SharedResource.
(* 两个分支只使用同一个资源。目标没有声明任何 pipeline。 *)
Definition cfg : @configuration Empty_set unit :=
  {| declared_pipeline := fun _ => False; declared_resource := fun _ => True;
     can_read := fun _ _ => False;
     can_write := fun _ _ => False |}.
Local Notation Cmd := (@command unit nat Empty_set unit unit).
Local Notation Model := (@computation_model unit nat Empty_set unit).
Local Notation Event := (@event_record unit nat Empty_set unit).
Definition branch : Cmd := CCompute tt 0 (Dispatch tt None) [] (Return tt []).
Definition example := annotate_program [branch; branch].
Definition start (j : positive) : Event :=
  EventRecord (j, 1%positive) (LComputeStart (Dispatch tt None) []).
Definition finish (j : positive) v : Event :=
  EventRecord (j, 1%positive) (LComputeEnd v).
Definition meaning (e : nat) := start (if Nat.eqb e 0 then 1%positive else 2%positive).

Lemma both_prefixes (model : Model) (layout : allocation_layout) (t : list nat)
    (order : t = [0;1] \/ t = [1;0]) :
  program_semantics layout cfg model example t meaning.
Proof.
  split.
  - exists [branch; branch]. split; [ | reflexivity]. cbn. split; [discriminate |].
    repeat apply Forall_cons; try apply Forall_nil.
    all: split; [repeat constructor; simpl; tauto |].
    all: split; [cbn; repeat constructor | split; [exact I | exists (fun _ => TFloat); cbn; auto]].
  - split.
    + split.
      * cbn. repeat constructor; cbn; intuition discriminate.
      * intros [|[|j]] c eq; try (destruct j; discriminate);
          inversion eq; subst; cbn; intros o [<-|[<-|[]]]; reflexivity.
    + split.
      * exists []. split.
        -- destruct (comp_total model tt []) as [v computes].
           exists [start 1; finish 1 v; start 2; finish 2 v].
           exists (map meaning t ++ [finish 1 v; finish 2 v]).
           split.
           ++ apply ProgramCons with (events := [start 1; finish 1 v])
                (remaining := [start 2; finish 2 v]) (uses := []) (rest := []).
              2: apply ProgramCons with (events := [start 2; finish 2 v])
                   (remaining := []) (uses := []) (rest := []); [ | apply ProgramNil].
              all: apply EventsCompute with (uses := []) (rest := []);
                [apply DirectValues, ValuesNil | exact computes | apply EventsStop; exact I].
           ++ split; [repeat constructor; cbn; intuition discriminate |].
              split; [ | eexists; reflexivity].
              destruct order as [->| ->]; cbn.
              ** apply perm_skip, perm_swap.
              ** eapply Permutation_trans; [apply perm_skip, perm_swap | apply perm_swap].
        -- split.
           2: { split; [intros u e d v H; inversion H |].
                destruct order as [->| ->]; repeat split. }
           unfold A_sync. split.
           ++ intros o h member phases e (_ & _ & h' & member' & k).
              cbn in member'. destruct member' as [eq|[eq|[eq|[eq|[]]]]];
                inversion eq; subst; destruct e; discriminate k.
           ++ split.
              ** intros o u edge. cbn in edge.
                 destruct edge as [eq|[eq|[]]]; inversion eq; subst;
                   split; intros e (_ & owner_eq & _); destruct e; discriminate.
              ** split; [intros f o p; destruct p |].
                 split; [intros p; destruct p |].
                 intros w u p; destruct p.
      * destruct order as [->| ->]; repeat constructor.
Qed.
End SharedResource.

Module LocalAllocation.
Local Notation Cmd := (@command unit nat bool unit unit).
Local Notation Model := (@computation_model unit nat bool unit).

(* 同一条申请命令在循环中执行两次。地址取自展开后的动态操作位置。 *)
Example two_iterations (model : Model) :
  let body : Cmd := For 0 0 2 (Alloc tt 1 LoopEnd) (Return tt []) in
  let pos := pair 1%positive in
  exists a b, a <> b /\
    command_events odd_allocation_layout model empty_environment
      (label_paths pos 1%positive (expand_loops body LoopEnd))
      [EventRecord (pos 2%positive) (LAlloc a); EventRecord (pos 8%positive) (LAlloc b);
       EventRecord (pos 16%positive) (LReturn [])] [].
Proof.
  cbn. eexists (address_at odd_allocation_layout (InBranch (1,2)%positive)).
  eexists (address_at odd_allocation_layout (InBranch (1,8)%positive)). split.
  - apply distinct_allocations; discriminate.
  - repeat first [eapply EventsAlias; [reflexivity |] | apply EventsAlloc
                 | apply EventsReturn | apply ValuesNil].
Qed.

Example invalid_scalar_inputs :
  @eval_atomic unit nat bool IntMod [VInt 3; VInt 0] = None /\
  @eval_atomic unit nat bool BoolAnd [VBool true; VInt 0] = None /\
  @eval_atomic unit nat bool (MemoryAt [0%nat]) [VInt (-1)] = None.
Proof. repeat split. Qed.

Example bool_compute (model : Model) (o doneId : op_id) :
  command_events odd_allocation_layout model empty_environment
    (LetAtomic o 0 BoolNot [Literal (VBool false)] (Return doneId [OVar 0]))
    [EventRecord o (LAtomic BoolNot [VBool false] (VBool true));
     EventRecord doneId (LReturn [VBool true])] [].
Proof.
  eapply EventsAtomic with (uses := []) (rest := []); [ | reflexivity | apply EventsReturn];
    eapply ValuesCons with (uses := []) (rest := []); [apply UseKnown; reflexivity | apply ValuesNil |
    apply UseKnown; reflexivity | apply ValuesNil].
Qed.
End LocalAllocation.

Module MemoryValues.
Local Notation Event := (@event_record unit nat bool unit).
Local Notation Value := (@value unit nat bool).

Definition buffer := address_at odd_allocation_layout (BeforeRun 0).
Definition other_buffer := address_at odd_allocation_layout (BeforeRun 1).
Definition direct : execution unit bool := Dispatch tt None.
Definition queued : execution unit bool := Dispatch tt (Some true).
Definition observes (events : list Event) : Prop :=
  memory_values (seq 0 (length events))
    (fun e => nth e events (EventRecord (1, 1)%positive (LReturn []))).

(* 读发起后、读完成前，向同一个地址完成的写入决定读取结果。 *)
Definition reads_after_overwrite (result : Value) : list Event :=
  [ EventRecord (1, 1)%positive (LWriteStart queued buffer (VInt 10));
    EventRecord (1, 1)%positive LWriteEnd;
    EventRecord (2, 1)%positive (LReadStart direct buffer);
    EventRecord (1, 2)%positive (LWriteStart queued buffer (VInt 20));
    EventRecord (1, 2)%positive LWriteEnd;
    EventRecord (1, 3)%positive (LWriteStart queued other_buffer (VInt 30));
    EventRecord (1, 3)%positive LWriteEnd;
    EventRecord (1, 4)%positive (LWriteStart queued buffer (VInt 40));
    EventRecord (2, 1)%positive (LReadEnd result) ].

Example read_latest_completed_write : observes (reads_after_overwrite (VInt 20)).
Proof. cbv; repeat split. Qed.

Example reject_stale_or_pending_write :
  ~ observes (reads_after_overwrite (VInt 10)) /\
  ~ observes (reads_after_overwrite (VInt 40)).
Proof. cbv; intuition discriminate. Qed.

Example allocation_cannot_overwrite_existing_contents :
  ~ observes [EventRecord (1, 1)%positive (LWriteStart queued buffer (VInt 10));
              EventRecord (1, 1)%positive LWriteEnd;
              EventRecord (2, 1)%positive (LAlloc buffer)].
Proof. cbv; intuition discriminate. Qed.
End MemoryValues.

Module ReadWithoutPriorWrite.
Local Notation Model := (@computation_model unit nat Empty_set unit).
Local Notation Event := (@event_record unit nat Empty_set unit).
Local Notation Cmd := (@command unit nat Empty_set unit op_id).

Definition read_op : op_id := (1, 1)%positive.
Definition return_op : op_id := (1, 2)%positive.
Definition read_program address : list Cmd :=
  [Read read_op 0 (Dispatch tt None) (Literal (VMemory address)) (Return return_op [])].

Definition read_events address result (e : nat) : Event :=
  match e with
  | 0%nat => EventRecord read_op (LReadStart (Dispatch tt None) address)
  | _ => EventRecord read_op (LReadEnd result)
  end.

Example read_can_complete_with_any_value (model : Model) address result :
  trace_semantics odd_allocation_layout model (read_program address)
    [0; 1] (read_events address result).
Proof.
  exists []. refine (conj _ (conj _ (conj _ _))).
  - exists [read_events address result 0; read_events address result 1],
      [read_events address result 0; read_events address result 1].
    split.
    + apply ProgramCons with (events := [read_events address result 0; read_events address result 1])
        (remaining := []) (uses := []) (rest := []); [ | apply ProgramNil].
      apply EventsRead with (uses := []) (rest := []).
      * apply DirectValues. eapply ValuesCons with (uses := []) (rest := []);
          [apply UseKnown; reflexivity | apply ValuesNil].
      * apply EventsStop. exact I.
    + split; [repeat constructor; simpl; intuition discriminate |].
      split; [reflexivity | exists []; reflexivity].
  - refine (conj _ (conj _ (conj _ (conj _ _)))).
    + intros o h member different e (in_trace & _ & head & head_member & phase).
      cbn in member, head_member. destruct member as [member|[member|[]]];
        destruct head_member as [head_member|[head_member|[]]];
        inversion member; inversion head_member; subst; try contradiction; try discriminate.
      destruct e as [|e]; [discriminate phase |].
      exists 0%nat. split.
      * repeat split; try (cbn; auto). exists HRead. cbn; auto.
      * exists 0%nat, 1%nat. destruct e; [repeat split; constructor | cbn in in_trace; intuition discriminate].
    + intros o u edge. cbn in edge. destruct edge as [edge|[]]; inversion edge; subst.
      split; intros e (_ & owner_eq & _); destruct e; discriminate owner_eq.
    + intros f o p; destruct p.
    + intros p; destruct p.
    + intros w u p; destruct p.
  - intros use e d value member; inversion member.
  - repeat split.
Qed.
End ReadWithoutPriorWrite.

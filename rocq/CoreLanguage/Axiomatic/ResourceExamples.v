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

Lemma both_prefixes (model : Model) (t : list nat) (order : t = [0;1] \/ t = [1;0]) :
  program_semantics cfg model example t meaning.
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
        -- split; [ | intros u e d v H; inversion H].
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
    command_events model empty_environment
      (label_paths pos 1%positive (expand_loops body LoopEnd))
      [EventRecord (pos 2%positive) (LAlloc a); EventRecord (pos 8%positive) (LAlloc b);
       EventRecord (pos 16%positive) (LReturn [])] [].
Proof.
  cbn. eexists (Allocated (InBranch (1,2)%positive)).
  eexists (Allocated (InBranch (1,8)%positive)). split; [discriminate |].
  repeat first [eapply EventsAlias; [reflexivity |] | apply EventsAlloc
               | apply EventsReturn | apply ValuesNil].
Qed.

Example invalid_scalar_inputs :
  @eval_atomic unit nat bool IntMod [VInt 3; VInt 0] = None /\
  @eval_atomic unit nat bool BoolAnd [VBool true; VInt 0] = None /\
  @eval_atomic unit nat bool (MemoryAt [ExternalMemory 0]) [VInt (-1)] = None.
Proof. repeat split. Qed.

Example bool_compute (model : Model) (o doneId : op_id) :
  command_events model empty_environment
    (LetAtomic o 0 BoolNot [Literal (VBool false)] (Return doneId [OVar 0]))
    [EventRecord o (LAtomic BoolNot [VBool false] (VBool true));
     EventRecord doneId (LReturn [VBool true])] [].
Proof.
  eapply EventsAtomic with (uses := []) (rest := []); [ | reflexivity | apply EventsReturn];
    eapply ValuesCons with (uses := []) (rest := []); [apply UseKnown; reflexivity | apply ValuesNil |
    apply UseKnown; reflexivity | apply ValuesNil].
Qed.
End LocalAllocation.

From Stdlib Require Import List ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Export Syntax.
Import ListNotations.
Set Implicit Arguments.

Inductive event_kind :=
| ReadStart | ReadEnd | WriteStart | WriteEnd | ComputeStart | ComputeEnd
| SetFlagStart | SetFlagEnd | WaitFlagStart | WaitFlagEnd
| BranchEvent | ReturnEvent | PipeAssignment
| AtomicEvent | AllocEvent.

Section Events.
Context {Float EventId Pipe Unit : Type}.
Local Notation Val := (@value Float EventId Pipe).
Local Notation Cmd := (@command Float EventId Pipe Unit op_id).

(* label 将事件种类与对应类别的载荷一起表示。 *)
Inductive label :=
| LReadStart (d : execution Unit Pipe) (addr : memory_resource) | LReadEnd (result : Val)
| LWriteStart (d : execution Unit Pipe) (addr : memory_resource) (data : Val) | LWriteEnd
| LComputeStart (d : execution Unit Pipe) (args : list Val) | LComputeEnd (result : Val)
| LAtomic (f : atomic_op) (args : list Val) (result : Val)
| LAlloc (address : memory_resource)
| LSetFlagStart (p q : Pipe) (flag : EventId) | LSetFlagEnd
| LWaitFlagStart (p q : Pipe) (flag : EventId) | LWaitFlagEnd
| LBranch (choice : bool) | LReturn (results : list Val)
| LPipeAssignment (x : var) (p : Pipe).

Record event_record := EventRecord { owner : op_id; payload : label }.
Definition K := event_record.
Definition interpretation := EventId -> K.
Definition trace := list EventId.

Definition kind (a : label) : event_kind :=
  match a with
  | LReadStart _ _ => ReadStart | LReadEnd _ => ReadEnd
  | LWriteStart _ _ _ => WriteStart | LWriteEnd => WriteEnd
  | LComputeStart _ _ => ComputeStart | LComputeEnd _ => ComputeEnd
  | LAtomic _ _ _ => AtomicEvent | LAlloc _ => AllocEvent
  | LSetFlagStart _ _ _ => SetFlagStart | LSetFlagEnd => SetFlagEnd
  | LWaitFlagStart _ _ _ => WaitFlagStart | LWaitFlagEnd => WaitFlagEnd
  | LBranch _ => BranchEvent | LReturn _ => ReturnEvent
  | LPipeAssignment _ _ => PipeAssignment
  end.

Definition start_kind (h : head) :=
  match h with
  | HRead => ReadStart | HWrite => WriteStart | HCompute => ComputeStart
  | HAtomic => AtomicEvent | HAlloc => AllocEvent
  | HSetFlag => SetFlagStart | HWaitFlag => WaitFlagStart | HAssignPipe => PipeAssignment
  | HIf => BranchEvent | HReturn => ReturnEvent
  end.

Definition end_kind (h : head) :=
  match h with
  | HRead => ReadEnd | HWrite => WriteEnd | HCompute => ComputeEnd
  | HAtomic => AtomicEvent | HAlloc => AllocEvent
  | HSetFlag => SetFlagEnd | HWaitFlag => WaitFlagEnd | HAssignPipe => PipeAssignment
  | HIf => BranchEvent | HReturn => ReturnEvent
  end.

Definition pipeline (l : label) : option Pipe :=
  match l with
  | LReadStart d _ | LWriteStart d _ _ | LComputeStart d _ => queue d
  | LSetFlagStart p _ _ => Some p
  | LWaitFlagStart _ q _ => Some q
  | _ => None
  end.

Definition nonblocking (h : head) : bool :=
  match h with
  | HRead | HWrite | HCompute | HSetFlag => true
  | _ => false
  end.

(* 异步绑定指代产生结果的命令；Known 保存常量值。 *)
Inductive binding := Known (v : Val) | Async (source : op_id).
Definition environment := var -> option binding.
Definition empty_environment : environment := fun _ => None.
Definition bind (rho : environment) (x : var) (v : binding) : environment :=
  fun y => if Nat.eqb x y then Some v else rho y.

Definition resolve (rho : environment) (v : @operand Float EventId Pipe)
    : option binding :=
  match v with Literal a => Some (Known a) | OVar x => rho x end.

Record use_record := UseRecord {
  consumer : op_id;
  operand_index : nat;
  producer : op_id;
  used_value : Val
}.

Inductive operand_value (rho : environment) (o : op_id) (index : nat)
    (v : @operand Float EventId Pipe) : Val -> list use_record -> Prop :=
| UseKnown : forall a, resolve rho v = Some (Known a) -> operand_value rho o index v a []
| UseAsync : forall r a, resolve rho v = Some (Async r) ->
    operand_value rho o index v a [UseRecord o index r a].

Inductive operand_values (rho : environment) (o : op_id)
    : nat -> list (@operand Float EventId Pipe) -> list Val -> list use_record -> Prop :=
| ValuesNil : forall i, operand_values rho o i [] [] []
| ValuesCons : forall i v vs a args uses rest,
    operand_value rho o i v a uses ->
    operand_values rho o (S i) vs args rest ->
    operand_values rho o i (v :: vs) (a :: args) (uses ++ rest).

Record computation_model := {
  comp : Unit -> list Val -> Val -> Prop;
  comp_total : forall r args, exists result, comp r args result
}.

Definition eval_atomic (f : atomic_op) (args : list Val) : option Val :=
  match f, args with
  | IntAdd, [VInt a; VInt b] => Some (VInt (a + b))
  | IntSub, [VInt a; VInt b] => Some (VInt (a - b))
  | IntMul, [VInt a; VInt b] => Some (VInt (a * b))
  | IntMod, [VInt a; VInt b] => if Z.eqb b 0 then None else Some (VInt (Z.modulo a b))
  | IntEq, [VInt a; VInt b] => Some (VBool (Z.eqb a b))
  | IntLt, [VInt a; VInt b] => Some (VBool (Z.ltb a b))
  | BoolNot, [VBool b] => Some (VBool (negb b))
  | BoolAnd, [VBool a; VBool b] => Some (VBool (andb a b))
  | BoolOr, [VBool a; VBool b] => Some (VBool (orb a b))
  | MemoryAt inputs, [VInt i] =>
      if Z.ltb i 0 then None else option_map VMemory (nth_error inputs (Z.to_nat i))
  | _, _ => None
  end.

(* 显式队列操作数占用位置 0。直接使用资源时，数据操作数从位置 0 开始。 *)
Inductive execution_values rho o (vs : list (@operand Float EventId Pipe)) :
    option (@operand Float EventId Pipe) -> option Pipe -> list Val -> list use_record -> Prop :=
| DirectValues : forall args uses, operand_values rho o 0 vs args uses ->
    execution_values rho o vs None None args uses
| QueuedValues : forall v p args uses,
    operand_values rho o 0 (v :: vs) (VPipe p :: args) uses ->
    execution_values rho o vs (Some v) (Some p) args uses.

(* 列表枚举有限事件集合；Cand 中的 NoDup 和排列条件消除列表顺序的意义。 *)
Inductive command_events (model : computation_model)
    : environment -> Cmd -> list K -> list use_record -> Prop :=
| EventsStop : forall rho c,
    (match c with CAlias _ _ _ | Select _ _ _ _ _ => False | _ => True end) ->
    command_events model rho c [] []
| EventsAlias : forall rho x v n b events uses,
    resolve rho v = Some b -> command_events model (bind rho x b) n events uses ->
    command_events model rho (CAlias x v n) events uses
| EventsSelect : forall rho x condition yes no n b selected events uses,
    resolve rho condition = Some (Known (VBool b)) ->
    resolve rho (if b then yes else no) = Some selected ->
    command_events model (bind rho x selected) n events uses ->
    command_events model rho (Select x condition yes no n) events uses
| EventsAlloc : forall rho o x n events uses,
    let address := Allocated (InBranch o) in
    command_events model (bind rho x (Known (VMemory address))) n events uses ->
    command_events model rho (Alloc o x n) (EventRecord o (LAlloc address) :: events) uses
| EventsAtomic : forall rho o x f vs n args result events uses rest,
    operand_values rho o 0 vs args uses -> eval_atomic f args = Some result ->
    command_events model (bind rho x (Known result)) n events rest ->
    command_events model rho (LetAtomic o x f vs n)
      (EventRecord o (LAtomic f args result) :: events) (uses ++ rest)
| EventsAssignPipe : forall rho o x v n p events uses rest,
    operand_value rho o 0 v (VPipe p) uses ->
    command_events model (bind rho x (Known (VPipe p))) n events rest ->
    command_events model rho (AssignPipe o x v n)
      (EventRecord o (LPipeAssignment x p) :: events) (uses ++ rest)
| EventsRead : forall rho o x d v n p a result events uses rest,
    execution_values rho o [v] (queue d) p [VMemory a] uses ->
    command_events model (bind rho x (Async o)) n events rest ->
    command_events model rho (Read o x d v n)
      (EventRecord o (LReadStart (Dispatch (resource d) p) a) :: EventRecord o (LReadEnd result) :: events)
      (uses ++ rest)
| EventsCompute : forall rho o x d vs n p args result events uses rest,
    execution_values rho o vs (queue d) p args uses -> comp model (resource d) args result ->
    command_events model (bind rho x (Async o)) n events rest ->
    command_events model rho (CCompute o x d vs n)
      (EventRecord o (LComputeStart (Dispatch (resource d) p) args) :: EventRecord o (LComputeEnd result) :: events)
      (uses ++ rest)
| EventsWrite : forall rho o d a v n p addr data events uses rest,
    execution_values rho o [a; v] (queue d) p [VMemory addr; data] uses ->
    command_events model rho n events rest ->
    command_events model rho (Write o d a v n)
      (EventRecord o (LWriteStart (Dispatch (resource d) p) addr data) :: EventRecord o LWriteEnd :: events)
      (uses ++ rest)
| EventsSetFlag : forall rho o src dst v n p q flag events uses rest,
    operand_values rho o 0 [src; dst; v] [VPipe p; VPipe q; VEvent flag] uses ->
    command_events model rho n events rest ->
    command_events model rho (SetFlag o src dst v n)
      (EventRecord o (LSetFlagStart p q flag) :: EventRecord o LSetFlagEnd :: events)
      (uses ++ rest)
| EventsWaitFlag : forall rho o src dst v n p q flag events uses rest,
    operand_values rho o 0 [src; dst; v] [VPipe p; VPipe q; VEvent flag] uses ->
    command_events model rho n events rest ->
    command_events model rho (WaitFlag o src dst v n)
      (EventRecord o (LWaitFlagStart p q flag) :: EventRecord o LWaitFlagEnd :: events)
      (uses ++ rest)
| EventsIf : forall rho o v yes no b events uses rest,
    operand_value rho o 0 v (VBool b) uses ->
    command_events model rho (if b then yes else no) events rest ->
    command_events model rho (If o v yes no)
      (EventRecord o (LBranch b) :: events) (uses ++ rest)
| EventsReturn : forall rho o vs args uses,
    operand_values rho o 0 vs args uses ->
    command_events model rho (Return o vs) [EventRecord o (LReturn args)] uses.

Inductive program_events (model : computation_model)
    : list Cmd -> list K -> list use_record -> Prop :=
| ProgramNil : program_events model [] [] []
| ProgramCons : forall c p events remaining uses rest,
    command_events model empty_environment c events uses ->
    program_events model p remaining rest ->
    program_events model (c :: p) (events ++ remaining) (uses ++ rest).

Definition allocation_origin (e : event_record) :=
  match payload e with
  | LAlloc a => a = Allocated (InBranch (owner e))
  | _ => True
  end.

Lemma command_allocation_origins model rho c events uses :
  command_events model rho c events uses -> Forall allocation_origin events.
Proof.
  induction 1; repeat (constructor; cbn); auto.
Qed.

Lemma program_allocation_origins model p events uses :
  program_events model p events uses -> Forall allocation_origin events.
Proof.
  induction 1; [constructor |]. apply Forall_app; split; eauto using command_allocation_origins.
Qed.

End Events.

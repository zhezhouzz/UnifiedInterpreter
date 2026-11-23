From Stdlib Require Import List ZArith.
Import ListNotations.
Set Implicit Arguments.

Definition var := nat.
Definition op_id := (positive * positive)%type.
Definition thread (o : op_id) := fst o.

Inductive allocation_site := BeforeRun (index : nat) | InBranch (operation : op_id).
Inductive memory_resource := ExternalMemory (name : nat) | Allocated (site : allocation_site).

Lemma distinct_allocations a b : a <> b -> Allocated a <> Allocated b.
Proof. congruence. Qed.

Inductive atomic_op :=
| IntAdd | IntSub | IntMul | IntMod | IntEq | IntLt
| BoolNot | BoolAnd | BoolOr
| MemoryAt (inputs : list memory_resource).

Record execution (Unit Queue : Type) := Dispatch {
  resource : Unit;
  queue : option Queue
}.
Arguments Dispatch {Unit Queue} _ _.

Section Syntax.
Context {Float EventId Pipe Unit : Type}.

Inductive value : Type :=
| VInt (n : Z)
| VFloat (r : Float)
| VBool (b : bool)
| VEvent (e : EventId)
| VPipe (p : Pipe)
| VMemory (address : memory_resource).

Inductive operand : Type :=
| Literal (v : value)
| OVar (x : var).

(* Label 为 unit 时对应原始语法，为 op_id 时对应带位置标注的语法。 *)
Inductive command (Label : Type) : Type :=
| Return (o : Label) (args : list operand)
| CAlias (x : var) (v : operand) (next : command Label)
| Alloc (o : Label) (x : var) (next : command Label)
| LetAtomic (o : Label) (x : var) (f : atomic_op) (args : list operand) (body : command Label)
| Select (x : var) (condition yes no : operand) (next : command Label)
| AssignPipe (o : Label) (x : var) (v : operand) (next : command Label)
| CCompute (o : Label) (x : var) (p : execution Unit operand)
    (args : list operand) (next : command Label)
| Read (o : Label) (x : var) (p : execution Unit operand) (addr : operand) (next : command Label)
| Write (o : Label) (p : execution Unit operand) (addr data : operand) (next : command Label)
| SetFlag (o : Label) (p q flag : operand) (next : command Label)
| WaitFlag (o : Label) (p q flag : operand) (next : command Label)
| For (index : var) (lower upper : nat) (body next : command Label)
| LoopEnd
| If (o : Label) (condition : operand) (yes no : command Label).

Arguments LoopEnd {Label}.

Definition program (Label : Type) := list (command Label).

Inductive shared_program :=
| Run (branches : program unit)
| SharedAlloc (x : var) (body : shared_program).

(* 并发前的每次申请得到独立地址，各分支继承同一绑定。 *)
Fixpoint instantiate_shared (index : nat) (p : shared_program) : program unit :=
  match p with
  | Run branches => branches
  | SharedAlloc x body =>
      map (CAlias x (Literal (VMemory (Allocated (BeforeRun index)))))
          (instantiate_shared (S index) body)
  end.

(* 循环体在 LoopEnd 处接续下一轮。Return 直接结束并发分支。 *)
Fixpoint expand_loops {L} (c : command L) (at_end : command L) : command L :=
  let expand := fun n => expand_loops n at_end in
  match c with
  | LoopEnd => at_end
  | For x lo hi body n =>
      fold_right (fun i rest => CAlias x (Literal (VInt (Z.of_nat i))) (expand_loops body rest))
                 (expand n) (seq lo (hi - lo))
  | Return o vs => Return o vs
  | CAlias x v n => CAlias x v (expand n)
  | Alloc o x n => Alloc o x (expand n)
  | LetAtomic o x f vs n => LetAtomic o x f vs (expand n)
  | Select x b y z n => Select x b y z (expand n)
  | AssignPipe o x v n => AssignPipe o x v (expand n)
  | CCompute o x p vs n => CCompute o x p vs (expand n)
  | Read o x p a n => Read o x p a (expand n)
  | Write o p a v n => Write o p a v (expand n)
  | SetFlag o p q v n => SetFlag o p q v (expand n)
  | WaitFlag o p q v n => WaitFlag o p q v (expand n)
  | If o v y n => If o v (expand y) (expand n)
  end.

Definition expand_program {L} (p : program L) :=
  map (fun c => expand_loops c LoopEnd) p.

(* 正整数编码语法树路径。两个分支分别追加 0 与 1。 *)
Fixpoint label_paths {A B} (label_at : positive -> B) (path : positive)
    (c : command A) : command B :=
  let o := label_at path in
  let next := label_paths label_at (xO path) in
  match c with
  | LoopEnd => LoopEnd
  | For x lo hi body n => For x lo hi (next body) (next n)
  | Return _ vs => Return o vs
  | CAlias x v n => CAlias x v (next n)
  | Alloc _ x n => Alloc o x (next n)
  | LetAtomic _ x f vs n => LetAtomic o x f vs (next n)
  | Select x b y z n => Select x b y z (next n)
  | AssignPipe _ x v n => AssignPipe o x v (next n)
  | CCompute _ x p vs n => CCompute o x p vs (next n)
  | Read _ x p v n => Read o x p v (next n)
  | Write _ p a v n => Write o p a v (next n)
  | SetFlag _ p q v n => SetFlag o p q v (next n)
  | WaitFlag _ p q v n => WaitFlag o p q v (next n)
  | If _ v y n => If o v (next y) (label_paths label_at (xI path) n)
  end.

Definition erase_annotations (c : command op_id) : command unit :=
  label_paths (fun _ => tt) 1%positive c.

Definition annotate_program (p : program unit) : program op_id :=
  map (fun jc => label_paths (pair (Pos.of_succ_nat (fst jc))) 1%positive (snd jc))
      (combine (seq 0 (length p)) (expand_program p)).

Record configuration := {
  declared_pipeline : Pipe -> Prop;
  declared_resource : Unit -> Prop;
  can_read : Unit -> memory_resource -> Prop;
  can_write : Unit -> memory_resource -> Prop
}.

Definition scoped_operand (cfg : configuration) (bound : list var) (v : operand) : Prop :=
  match v with
  | Literal (VPipe p) => declared_pipeline cfg p
  | Literal _ => True
  | OVar x => In x bound
  end.

Fixpoint bindings {L} (c : command L) : list var :=
  match c with
  | For x _ _ body n => x :: bindings body ++ bindings n
  | LoopEnd => []
  | CAlias x _ n | CCompute _ x _ _ n | Read _ x _ _ n | Alloc _ x n
  | LetAtomic _ x _ _ n | Select x _ _ _ n => x :: bindings n
  | AssignPipe _ _ _ n => bindings n
  | Write _ _ _ _ n | SetFlag _ _ _ _ n | WaitFlag _ _ _ _ n => bindings n
  | If _ _ y n => bindings y ++ bindings n
  | Return _ _ => []
  end.

Fixpoint scoped {L} (cfg : configuration) (immutable bound : list var)
    (c : command L) : Prop :=
  let ok := scoped_operand cfg bound in
  let issued d := declared_resource cfg (resource d) /\
    match queue d with Some v => ok v | None => True end in
  match c with
  | For x _ _ body n => scoped cfg immutable (x :: bound) body /\ scoped cfg immutable bound n
  | LoopEnd => True
  | Return _ vs => Forall ok vs
  | CAlias x v n => ok v /\ scoped cfg immutable (x :: bound) n
  | Alloc _ x n => scoped cfg immutable (x :: bound) n
  | LetAtomic _ x _ vs n => Forall ok vs /\ scoped cfg immutable (x :: bound) n
  | Select x b y z n => ok b /\ ok y /\ ok z /\ scoped cfg immutable (x :: bound) n
  | AssignPipe _ x v n => ~ In x immutable /\ ok v /\ scoped cfg immutable (x :: bound) n
  | CCompute _ x p vs n => issued p /\ Forall ok vs /\ scoped cfg immutable (x :: bound) n
  | Read _ x p a n => issued p /\ ok a /\ scoped cfg immutable (x :: bound) n
  | Write _ p a v n => issued p /\ ok a /\ ok v /\ scoped cfg immutable bound n
  | SetFlag _ p q v n | WaitFlag _ p q v n =>
      ok p /\ ok q /\ ok v /\ scoped cfg immutable bound n
  | If _ v y n => ok v /\ scoped cfg immutable bound y /\ scoped cfg immutable bound n
  end.

Inductive category := TInt | TFloat | TBool | TEvent | TPipe | TMemory.

Definition atomic_signature (f : atomic_op) : list category * category :=
  match f with
  | IntAdd | IntSub | IntMul | IntMod => ([TInt; TInt], TInt)
  | IntEq | IntLt => ([TInt; TInt], TBool)
  | BoolNot => ([TBool], TBool)
  | BoolAnd | BoolOr => ([TBool; TBool], TBool)
  | MemoryAt _ => ([TInt], TMemory)
  end.

Definition value_category (v : value) : category :=
  match v with
  | VInt _ => TInt | VFloat _ => TFloat | VBool _ => TBool
  | VEvent _ => TEvent | VPipe _ => TPipe | VMemory _ => TMemory
  end.

Definition operand_category (types : var -> category) (v : operand) :=
  match v with Literal a => value_category a | OVar x => types x end.

Fixpoint categories_valid {L} (types : var -> category) (c : command L) : Prop :=
  let issued (d : execution Unit operand) :=
    match queue d with Some v => operand_category types v = TPipe | None => True end in
  match c with
  | For x _ _ body n => types x = TInt /\ categories_valid types body /\ categories_valid types n
  | LoopEnd => True
  | Alloc _ x n => types x = TMemory /\ categories_valid types n
  | LetAtomic _ x f vs n =>
      (map (operand_category types) vs, types x) = atomic_signature f /\ categories_valid types n
  | Select x b y z n => operand_category types b = TBool /\
      types x = operand_category types y /\ types x = operand_category types z /\ categories_valid types n
  | CAlias x v n => types x = operand_category types v /\ categories_valid types n
  | AssignPipe _ x v n => types x = TPipe /\ operand_category types v = TPipe /\ categories_valid types n
  | CCompute _ _ p _ n => issued p /\ categories_valid types n
  | Read _ _ p a n | Write _ p a _ n => issued p /\
      operand_category types a = TMemory /\ categories_valid types n
  | SetFlag _ p q v n | WaitFlag _ p q v n =>
      operand_category types p = TPipe /\ operand_category types q = TPipe /\
      operand_category types v = TEvent /\ categories_valid types n
  | If _ v y n => operand_category types v = TBool /\
      categories_valid types y /\ categories_valid types n
  | Return _ _ => True
  end.

Fixpoint ends_correctly {L} (inside : bool) (c : command L) : Prop :=
  match c with
  | LoopEnd => inside = true
  | Return _ _ => True
  | For _ _ _ body n => ends_correctly true body /\ ends_correctly inside n
  | If _ _ y n => ends_correctly inside y /\ ends_correctly inside n
  | CAlias _ _ n | AssignPipe _ _ _ n | CCompute _ _ _ _ n | LetAtomic _ _ _ _ n
  | Select _ _ _ _ n | Alloc _ _ n | Read _ _ _ _ n | Write _ _ _ _ n
  | SetFlag _ _ _ _ n | WaitFlag _ _ _ _ n => ends_correctly inside n
  end.

Definition well_formed {L} (cfg : configuration) (p : program L) : Prop :=
  p <> [] /\ Forall (fun c => NoDup (bindings c) /\ scoped cfg (bindings c) [] c /\
    ends_correctly false c /\ exists types, categories_valid types c) p.

Inductive head :=
| HRead | HWrite | HCompute | HAssignPipe | HAtomic | HAlloc
| HSetFlag | HWaitFlag
| HIf | HReturn.

Fixpoint operations (c : command op_id) : list (op_id * head) :=
  match c with
  | For _ _ _ _ _ | LoopEnd => []
  | Return o _ => [(o, HReturn)]
  | CAlias _ _ n | Select _ _ _ _ n => operations n
  | Alloc o _ n => (o, HAlloc) :: operations n
  | LetAtomic o _ _ _ n => (o, HAtomic) :: operations n
  | AssignPipe o _ _ n => (o, HAssignPipe) :: operations n
  | CCompute o _ _ _ n => (o, HCompute) :: operations n
  | Read o _ _ _ n => (o, HRead) :: operations n
  | Write o _ _ _ n => (o, HWrite) :: operations n
  | SetFlag o _ _ _ n => (o, HSetFlag) :: operations n
  | WaitFlag o _ _ _ n => (o, HWaitFlag) :: operations n
  | If o _ y n => (o, HIf) :: (operations y ++ operations n)
  end.

Definition op_ids c := map fst (operations c).
Definition program_operations (p : program op_id) := concat (map operations p).

Fixpoint program_order (c : command op_id) : list (op_id * op_id) :=
  match c with
  | For _ _ _ _ _ | LoopEnd => []
  | Return _ _ => []
  | CAlias _ _ n | Select _ _ _ _ n => program_order n
  | AssignPipe o _ _ n | CCompute o _ _ _ n | LetAtomic o _ _ _ n | Alloc o _ n
  | Read o _ _ _ n | Write o _ _ _ n
  | SetFlag o _ _ _ n | WaitFlag o _ _ _ n =>
      map (fun u => (o, u)) (op_ids n) ++ program_order n
  | If o _ y n => map (fun u => (o, u)) (op_ids y ++ op_ids n) ++
      program_order y ++ program_order n
  end.

Definition po (p : program op_id) := concat (map program_order p).

Definition annotations_valid (p : program op_id) : Prop :=
  NoDup (map fst (program_operations p)) /\
  forall j c, nth_error p j = Some c ->
    forall o, In o (op_ids c) -> thread o = Pos.of_succ_nat j.

Definition annotates (raw : program unit) (annotated : program op_id) : Prop :=
  map erase_annotations annotated = expand_program raw /\ annotations_valid annotated.

End Syntax.

Arguments LoopEnd {Float EventId Pipe Unit Label}.

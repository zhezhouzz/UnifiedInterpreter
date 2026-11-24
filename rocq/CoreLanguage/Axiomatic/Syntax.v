From Stdlib Require Import List ZArith Bool.
Import ListNotations.
Set Implicit Arguments.

(* 流、数据管道、操作、空间和变量各自在自己的名称空间中编号。 *)
Record domains := Domains { float_type : Type; view_type : Type }.
Inductive value (D : domains) :=
| VInt (z : Z) | VFloat (x : float_type D) | VBool (b : bool)
| VEvent (e : nat) | VView (v : view_type D).
Arguments VInt {D}. Arguments VFloat {D}. Arguments VBool {D}.
Arguments VEvent {D}. Arguments VView {D}.
Inductive category := TInt | TFloat | TBool | TEvent | TView.
Definition category_of {D} (v : value D) :=
  match v with VInt _ => TInt | VFloat _ => TFloat | VBool _ => TBool
  | VEvent _ => TEvent | VView _ => TView end.
Inductive operand (D : domains) := Literal (v : value D) | Var (x : nat).
Arguments Literal {D}. Arguments Var {D}.
Inductive endpoint := Data (pipe : nat) | ScalarEnd.
Inductive barrier := Pipe (pipe : nat) | All.
Inductive signal := LocalSet | LocalWait | BlockSet | BlockWait.
Inductive command (D : domains) :=
| Return (vs : list (operand D)) | End
| Scalar (x op : nat) (vs : list (operand D)) (next : command D)
| Alloc (x space : nat) (dims : list (operand D)) (next : command D)
| Issue (p f : nat) (vs : list (operand D)) (next : command D)
| Sync (mode : signal) (p : nat) (q : endpoint) (e : operand D) (next : command D)
| Barrier (b : barrier) (next : command D)
| Branch (test : operand D) (yes no next : command D)
| For (index : nat) (lo hi stride : operand D) (body next : command D).
Arguments Return {D}. Arguments End {D}. Arguments Scalar {D}. Arguments Alloc {D}.
Arguments Issue {D}. Arguments Sync {D}. Arguments Barrier {D}.
Arguments Branch {D}. Arguments For {D}.
Inductive cell (D : domains) := Uninit | Stored (v : value D).
Arguments Uninit {D}. Arguments Stored {D}.
Definition memory D := nat -> option (cell D).
Definition patch D := list (nat * cell D).
Record hardware (D : domains) := Hardware {
  available_stream : nat -> Prop;
  data_pipes : nat -> list nat;
  local_edge : nat -> nat -> nat -> Prop;
  block_edge : nat -> nat -> nat -> endpoint -> bool;
  has_space : nat -> nat -> Prop;
  barrier_allowed : nat -> barrier -> Prop;
  accessible : nat -> nat -> Prop;
  scalar_signature : nat -> option (list category * category);
  issue_signature : nat -> nat -> nat -> option (list category);
  scalar_eval : nat -> nat -> list (value D) -> option (value D);
  allocation : nat -> nat -> list Z -> list nat -> view_type D -> Prop;
  footprint : nat -> nat -> nat -> list (value D) -> option (list nat * list nat);
  evaluate : nat -> nat -> nat -> list (value D) -> patch D -> patch D -> Prop
}.
Definition program D := list (nat * command D).
Record valid_hardware {D} (h : hardware D) : Prop := {
  pipes_unique : forall s, NoDup (data_pipes h s);
  local_pipes : forall s p q, local_edge h s p q -> In p (data_pipes h s) /\ In q (data_pipes h s);
  block_pipes : forall s p t q, block_edge h s p t q = true ->
    s<>t /\ In p (data_pipes h s) /\ match q with Data r => In r (data_pipes h t) | ScalarEnd => True end;
  barrier_pipe : forall s p, barrier_allowed h s (Pipe p) -> In p (data_pipes h s);
  scalar_typed : forall s f vs v, scalar_eval h s f vs = Some v ->
    scalar_signature h f = Some (map category_of vs, category_of v);
  allocation_local : forall s sp dims ls v, allocation h s sp dims ls v ->
    has_space h s sp /\ NoDup ls /\ Forall (accessible h s) ls;
  footprint_sets : forall s p f vs r w, footprint h s p f vs = Some (r,w) ->
    NoDup r /\ NoDup w /\ Forall (accessible h s) (r++w)
}.
Definition update {A} (f : nat -> A) x (v : A) y := if Nat.eqb y x then v else f y.
Fixpoint traverse {A B} (f : A -> option B) (xs : list A) : option (list B) :=
  match xs with [] => Some [] | x :: rest =>
    match f x, traverse f rest with Some y, Some ys => Some (y :: ys) | _,_ => None end end.
Definition lookup {D} (env : nat -> option (value D)) (v : operand D) :=
  match v with Literal a => Some a | Var x => env x end.
Definition integer {D} (v : value D) := match v with VInt z => Some z | _ => None end.
Definition context := nat -> option category.
Definition typeof {D} (g : context) (v : operand D) :=
  match v with Literal a => Some (category_of a) | Var x => g x end.
Definition endpoints_ok {D} (h : hardware D) (active : list nat) s mode p q :=
  match mode, q with
  | LocalSet, Data r | LocalWait, Data r =>
      In p (data_pipes h s) /\ In r (data_pipes h s) /\ local_edge h s p r
  | BlockSet, _ => In p (data_pipes h s) /\ exists t, In t active /\ t <> s /\
      block_edge h s p t q = true /\ match q with Data r => In r (data_pipes h t) | ScalarEnd => True end
  | BlockWait, _ => (match q with Data r => In r (data_pipes h s) | ScalarEnd => True end) /\
      exists t, In t active /\ t <> s /\ In p (data_pipes h t) /\ block_edge h t p s q = true
  | _,_ => False end.
Fixpoint typed {D} (h : hardware D) (active : list nat) s (g : context) (c : command D) : Prop :=
  let types := traverse (typeof g) in
  match c with
  | End => True | Return vs => exists ts, types vs = Some ts
  | Scalar x f vs n => exists ts t, types vs = Some ts /\ scalar_signature h f = Some (ts,t)
        /\ g x = None /\ typed h active s (update g x (Some t)) n
  | Alloc x m vs n => has_space h s m /\ types vs = Some (repeat TInt (length vs)) /\
        g x = None /\ typed h active s (update g x (Some TView)) n
  | Issue p f vs n => In p (data_pipes h s) /\
        (exists ts, types vs = Some ts /\ issue_signature h s p f = Some ts) /\ typed h active s g n
  | Sync mode p q e n => typeof g e = Some TEvent /\ endpoints_ok h active s mode p q /\ typed h active s g n
  | Barrier b n => barrier_allowed h s b /\
        (match b with Pipe p => In p (data_pipes h s) | All => True end) /\ typed h active s g n
  | Branch v y z n => typeof g v = Some TBool /\ typed h active s g y /\ typed h active s g z /\ typed h active s g n
  | For x lo hi k body n => types [lo;hi;k] = Some [TInt;TInt;TInt] /\ g x = None /\
        typed h active s (update g x (Some TInt)) body /\ typed h active s g n
  end.
Definition well_formed {D} (h : hardware D) (parameters : nat -> context) (P : program D) :=
  let streams := map fst P in valid_hardware h /\ NoDup streams /\ Forall (available_stream h) streams /\
  Forall (fun sc => typed h streams (fst sc) (parameters (fst sc)) (snd sc)) P.

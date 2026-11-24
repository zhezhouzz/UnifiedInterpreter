From Stdlib Require Import List ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Export Syntax.
Import ListNotations.
Set Implicit Arguments.

Inductive item (D : domains) :=
| Operation (f : nat) (args : list (value D)) (reads writes : list nat)
| SetItem (cross : bool) (q : endpoint) (event : nat)
| WaitItem (cross : bool) (source event : nat)
| BarItem.
Arguments Operation {D}. Arguments SetItem {D}. Arguments WaitItem {D}. Arguments BarItem {D}.
Inductive action (D : domains) :=
| Control
| Reserve (space : nat) (dims : list Z) (addresses : list nat) (view : view_type D)
| Submit (p : nat) (i : item D)
| Fence (b : barrier)
| ScalarWait (source event : nat).
Arguments Control {D}. Arguments Reserve {D}. Arguments Submit {D}.
Arguments Fence {D}. Arguments ScalarWait {D}.
Inductive event (D : domains) :=
| Issued (stream : nat) (a : action D)
| Done (stream pipe position : nat) (i : item D) (writes : patch D).
Arguments Issued {D}. Arguments Done {D}.

(* 编译控制指令只决定各流的发射候选。等待是否能通过由轨迹公理判定。 *)
Definition plan D := (list (action D) * bool)%type.
Definition stop {D} : plan D := ([], false).
Definition finish {D} : plan D := ([], true).
Definition emit {D} (a : action D) (tail : plan D) : plan D := (a :: fst tail, snd tail).
Definition environment D := nat -> option (value D).
Definition allocator D := nat -> nat -> option (list nat * view_type D).
Definition iterations (lo hi stride : Z) : list Z :=
  let distance := if Z.ltb 0 stride then (hi-lo)%Z else (lo-hi)%Z in
  let width := Z.abs stride in
  map (fun i => (lo + Z.of_nat i * stride)%Z)
      (seq 0 (Z.to_nat ((distance + width - 1) / width))).

Fixpoint stream_plan {D} (h : hardware D) (alloc : allocator D) (s : nat) (c : command D)
    (env : environment D) (at_end : nat -> plan D) (fresh : nat) : plan D :=
  let args := traverse (lookup env) in
  let run n := stream_plan h alloc s n env at_end fresh in
  match c with
  | End => at_end fresh
  | Return vs => match args vs with Some _ => finish | None => stop end
  | Scalar x g vs n =>
      match args vs with Some av => match scalar_eval h s g av with
      | Some v => emit Control (stream_plan h alloc s n (update env x (Some v)) at_end fresh)
      | None => stop end | None => stop end
  | Alloc x space vs n =>
      match traverse (fun v => match lookup env v with Some a => integer a | None => None end) vs with
      | Some dims => match alloc s fresh with
          | Some (ls,view) => emit (Reserve space dims ls view)
              (stream_plan h alloc s n (update env x (Some (VView view))) at_end (S fresh))
          | None => stop end
      | None => stop end
  | Issue p f vs n => match args vs with Some av =>
      match footprint h s p f av with Some (r,w) => emit (Submit p (Operation f av r w)) (run n)
      | None => stop end | None => stop end
  | Sync mode p q e n => match lookup env e with
      | Some (VEvent k) => match mode,q with
          | LocalSet,Data _ => emit (Submit p (SetItem false q k)) (run n)
          | BlockSet,_ => emit (Submit p (SetItem true q k)) (run n)
          | LocalWait,Data r => emit (Submit r (WaitItem false p k)) (run n)
          | BlockWait,Data r => emit (Submit r (WaitItem true p k)) (run n)
          | BlockWait,ScalarEnd => emit (ScalarWait p k) (run n)
          | _,_ => stop end | _ => stop end
  | Barrier b n => emit (Fence b) (run n)
  | Branch test yes no n => match lookup env test with
      | Some (VBool b) => emit Control (if b
          then stream_plan h alloc s yes env (stream_plan h alloc s n env at_end) fresh
          else stream_plan h alloc s no env (stream_plan h alloc s n env at_end) fresh)
      | _ => stop end
  | For x lo hi stride body n => match args [lo;hi;stride] with
      | Some [VInt a;VInt b;VInt k] => if Z.eqb k 0 then stop else
          fold_right (fun i rest index => emit Control
            (stream_plan h alloc s body (update env x (Some (VInt i))) rest index))
            (fun index => emit Control (stream_plan h alloc s n env at_end index))
            (iterations a b k) fresh
      | _ => stop end
  end.

Definition control_plan {D} h alloc s (c : command D) env :=
  stream_plan h alloc s c env (fun _ => finish) 0.
Definition issued_by {D} (s : nat) (t : list (event D)) :=
  flat_map (fun e => match e with Issued u a => if Nat.eqb s u then [a] else [] | _ => [] end) t.
Definition prefix {A} (xs ys : list A) := exists rest, ys = xs ++ rest.
Definition candidate {D} h alloc (P : program D) env (t : list (event D)) :=
  Forall (fun sc => prefix (issued_by (fst sc) t)
    (fst (control_plan h alloc (fst sc) (snd sc) (env (fst sc))))) P /\
  Forall (fun e => In (match e with Issued s _ | Done s _ _ _ _ => s end) (map fst P)) t.

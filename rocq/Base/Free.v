Set Implicit Arguments.

(* A finite free computation is sufficient for the terminating HFusion
   fragment.  The event signature determines which effects a denotation may
   request; only a handler can assign stateful meaning to those requests. *)
Inductive computation (E : Type -> Type) (A : Type) : Type :=
| Return (value : A)
| Trigger {X : Type} (request : E X)
    (continue : X -> computation E A).

Arguments Return {E A} _.
Arguments Trigger {E A X} _ _.

Fixpoint bind {E A B} (program : computation E A)
    (next : A -> computation E B) : computation E B :=
  match program with
  | Return value => next value
  | Trigger request continue =>
      Trigger request (fun result => bind (continue result) next)
  end.

Definition perform {E X} (request : E X) : computation E X :=
  Trigger request Return.

Notation "x <-! program ;; next" :=
  (bind program (fun x => next))
  (at level 100, program at next level, right associativity).

Notation "program ;;! next" :=
  (bind program (fun _ => next))
  (at level 100, right associativity).

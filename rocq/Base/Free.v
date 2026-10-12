Set Implicit Arguments.

(* A finite free computation is sufficient for the terminating HFusion
   fragment.  The event signature determines which effects a denotation may
   request; only a handler can assign stateful meaning to those requests. *)
Inductive computation (Effect : Type -> Type) (A : Type) : Type :=
| Return (value : A)
| Trigger {X : Type} (effect : Effect X)
    (continue : X -> computation Effect A).

Arguments Return {Effect A} _.
Arguments Trigger {Effect A X} _ _.

Fixpoint bind {Effect A B} (program : computation Effect A)
    (next : A -> computation Effect B) : computation Effect B :=
  match program with
  | Return value => next value
  | Trigger effect continue =>
      Trigger effect (fun result => bind (continue result) next)
  end.

Definition perform {Effect X} (effect : Effect X) : computation Effect X :=
  Trigger effect Return.

Notation "x <-! program ;; next" :=
  (bind program (fun x => next))
  (at level 100, program at next level, right associativity).

Notation "program ;;! next" :=
  (bind program (fun _ => next))
  (at level 100, right associativity).

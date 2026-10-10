From Stdlib Require Import String.

Set Implicit Arguments.

Inductive result (E A : Type) : Type :=
| Ok : A -> result E A
| Error : E -> result E A.

Arguments Ok {E A} _.
Arguments Error {E A} _.

Definition result_map {E A B} (f : A -> B) (r : result E A)
    : result E B :=
  match r with
  | Ok x => Ok (f x)
  | Error e => Error e
  end.

Definition result_bind {E A B} (r : result E A)
    (k : A -> result E B) : result E B :=
  match r with
  | Ok x => k x
  | Error e => Error e
  end.

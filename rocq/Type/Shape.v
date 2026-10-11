From Stdlib Require Import Bool List PeanoNat.

Import ListNotations.

(* MLIR dimensions are either known statically or supplied at runtime. *)
Inductive dimension :=
| StaticDim (size : nat)
| DynamicDim.

Definition shape := list dimension.
Definition runtime_shape := list nat.

Fixpoint shape_matches (concrete : runtime_shape) (abstract : shape) : Prop :=
  match concrete, abstract with
  | [], [] => True
  | size :: concrete_rest, dimension :: abstract_rest =>
      match dimension with
      | StaticDim expected => size = expected
      | DynamicDim => True
      end /\ shape_matches concrete_rest abstract_rest
  | _, _ => False
  end.

Fixpoint shape_matchesb (concrete : runtime_shape) (abstract : shape) : bool :=
  match concrete, abstract with
  | [], [] => true
  | size :: concrete_rest, dimension :: abstract_rest =>
      match dimension with
      | StaticDim expected => Nat.eqb size expected
      | DynamicDim => true
      end && shape_matchesb concrete_rest abstract_rest
  | _, _ => false
  end.

Definition static_shape (dimensions : list nat) : shape :=
  map StaticDim dimensions.


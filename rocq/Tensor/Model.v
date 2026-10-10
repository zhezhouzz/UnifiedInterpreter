From Stdlib Require Import List PeanoNat.
From UnifiedInterpreter.Value Require Import DType.

Import ListNotations.
Set Implicit Arguments.

(* A tensor is a pure n-dimensional value. It has no allocation identity and
   cannot alias mutable memory. Elements are stored in row-major logical order;
   concrete memory layouts belong to memref descriptors, not tensors. *)
Record tensor (Value : Type) := {
  tensor_shape : list nat;
  tensor_element_type : dtype;
  tensor_elements : list Value
}.

Fixpoint shape_size (shape : list nat) : nat :=
  match shape with
  | [] => 1
  | dimension :: rest => dimension * shape_size rest
  end.

Definition tensor_well_formed {Value} (value : tensor Value) : Prop :=
  List.length (tensor_elements value) = shape_size (tensor_shape value).

Fixpoint prepend_each (index : nat) (coordinates : list (list nat))
    : list (list nat) :=
  match coordinates with
  | [] => []
  | coordinate :: rest =>
      (index :: coordinate) :: prepend_each index rest
  end.

Fixpoint enumerate_dimension (size : nat) (coordinates : list (list nat))
    : list (list nat) :=
  match size with
  | O => []
  | S size' =>
      enumerate_dimension size' coordinates ++
      prepend_each size' coordinates
  end.

Fixpoint tensor_indices (shape : list nat) : list (list nat) :=
  match shape with
  | [] => [[]]
  | dimension :: rest => enumerate_dimension dimension (tensor_indices rest)
  end.

Example indices_2_by_3 :
  tensor_indices [2; 3] =
    [[0; 0]; [0; 1]; [0; 2]; [1; 0]; [1; 1]; [1; 2]].
Proof. reflexivity. Qed.

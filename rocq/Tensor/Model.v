From Stdlib Require Import List PeanoNat.
From UnifiedInterpreter.Type Require Import DType Shape.

Import ListNotations.
Set Implicit Arguments.

Fixpoint shape_size (shape : list nat) : nat :=
  match shape with
  | [] => 1
  | dimension :: rest => dimension * shape_size rest
  end.

(* A runtime tensor is indexed by its concrete shape and element dtype.
   Consequently, two tensors accepted at the same indexed argument position
   have matching types by construction. The only stored data is the row-major
   element list; its length proof lives in Prop and is erased by extraction. *)
Record tensor (Value : Type) (shape : concrete_shape)
    (element_type : dtype) := {
  tensor_elements : list Value;
  tensor_size_correct :
    List.length tensor_elements = shape_size shape
}.

Arguments tensor_elements {Value shape element_type} _.
Arguments tensor_size_correct {Value shape element_type} _.

Definition tensor_of_list {Value} (shape : concrete_shape)
    (element_type : dtype) (elements : list Value)
    : option (tensor Value shape element_type) :=
  match Nat.eq_dec (List.length elements) (shape_size shape) with
  | left proof =>
      Some {| tensor_elements := elements; tensor_size_correct := proof |}
  | right _ => None
  end.

(* Existential packaging is used only at boundaries where shape and dtype are
   discovered dynamically, for example when materializing a memref view. *)
Inductive packed_tensor (Value : Type) :=
| PackTensor (shape : concrete_shape) (element_type : dtype)
    (value : tensor Value shape element_type).

Arguments PackTensor {Value} shape element_type value.

(* A homogeneous-shape package permits variadic operations whose operands may
   have different element dtypes while sharing one statically known shape. *)
Inductive shaped_tensor (Value : Type) (shape : concrete_shape) :=
| ShapedTensor (element_type : dtype)
    (value : tensor Value shape element_type).

Arguments ShapedTensor {Value shape} element_type value.

(* Connection between an MLIR shape, which may contain dynamic dimensions,
   and the concrete shape indexing an executable tensor value. *)
Record refined_tensor (Value : Type) (abstract_shape : shape)
    (element_type : dtype) := {
  refined_concrete_shape : concrete_shape;
  refined_shape_matches :
    shape_matches refined_concrete_shape abstract_shape;
  refined_value : tensor Value refined_concrete_shape element_type
}.

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

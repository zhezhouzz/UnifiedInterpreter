From Stdlib Require Import List PeanoNat.
From UnifiedInterpreter.Type Require Import MLIR Shape.

Import ListNotations.
Set Implicit Arguments.

Fixpoint num_elements (shape : list nat) : nat :=
  match shape with
  | [] => 1
  | dimension :: rest => dimension * num_elements rest
  end.

(* A runtime tensor value is indexed by its runtime shape and MLIR element type.
   Consequently, two tensors accepted at the same indexed argument position
   have matching types by construction. The only stored data is the row-major
   element list; its length proof lives in Prop and is erased by extraction. *)
Record tensor (Value : Type) (shape : runtime_shape)
    (element_type : mlir_type) := {
  tensor_elements : list Value;
  tensor_num_elements_correct :
    List.length tensor_elements = num_elements shape
}.

Arguments tensor_elements {Value shape element_type} _.
Arguments tensor_num_elements_correct {Value shape element_type} _.

Definition tensor_of_list {Value} (shape : runtime_shape)
    (element_type : mlir_type) (elements : list Value)
    : option (tensor Value shape element_type) :=
  match Nat.eq_dec (List.length elements) (num_elements shape) with
  | left proof =>
      Some {| tensor_elements := elements; tensor_num_elements_correct := proof |}
  | right _ => None
  end.

(* Existential packaging is used only at boundaries where the runtime shape and
   element type are discovered dynamically, for example when materializing a
   memref view. *)
Inductive packed_tensor (Value : Type) :=
| PackTensor (shape : runtime_shape) (element_type : mlir_type)
    (value : tensor Value shape element_type).

Arguments PackTensor {Value} shape element_type value.

(* A homogeneous-shape package permits variadic operations whose operands may
   have different element types while sharing one runtime shape. *)
Inductive shaped_tensor (Value : Type) (shape : runtime_shape) :=
| ShapedTensor (element_type : mlir_type)
    (value : tensor Value shape element_type).

Arguments ShapedTensor {Value shape} element_type value.

(* Connection between an MLIR shape, which may contain dynamic dimensions,
   and the runtime shape indexing an executable tensor value. *)
Record refined_tensor (Value : Type) (abstract_shape : shape)
    (element_type : mlir_type) := {
  refined_runtime_shape : runtime_shape;
  refined_shape_matches :
    shape_matches refined_runtime_shape abstract_shape;
  refined_value : tensor Value refined_runtime_shape element_type
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

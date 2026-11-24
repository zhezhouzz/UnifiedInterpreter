From Stdlib Require Import List Bool PeanoNat.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors.

Import ListNotations.
Set Implicit Arguments.

(* Empty destinations carry shape/type but no fabricated zero elements. Defined
   values reuse the existing length-certified tensor, not a second tensor model. *)
Inductive value (S : Type) :=
| EmptyTensor (shape : list nat) (element_type : mlir_type)
| DefinedTensor (contents : packed_tensor S).
Arguments EmptyTensor {S} _ _.
Arguments DefinedTensor {S} _.

Definition shape {S} (v : value S) : list nat :=
  match v with EmptyTensor sh _ => sh
  | DefinedTensor (PackTensor sh _ _) => sh end.
Definition element_type {S} (v : value S) : mlir_type :=
  match v with EmptyTensor _ ty => ty
  | DefinedTensor (PackTensor _ ty _) => ty end.
Definition elements {S} (v : value S) : result runtime_error (list S) :=
  match v with EmptyTensor _ _ => Error ReadUninitialized
  | DefinedTensor (PackTensor _ _ t) => Ok (tensor_elements t) end.

Definition make_value {S} (sh : list nat) (ty : mlir_type) (xs : list S)
    : result runtime_error (value S) :=
  match tensor_of_list sh ty xs with
  | Some t => Ok (DefinedTensor (PackTensor sh ty t))
  | None => Error InvalidShape
  end.

Fixpoint shape_eq (a b : list nat) : bool :=
  match a,b with
  | [],[] => true
  | x::xs,y::ys => Nat.eqb x y && shape_eq xs ys
  | _,_ => false end.

Definition f32 (ty : mlir_type) : bool := mlir_element_type_eqb ty Float32Type.
Definition f16 (ty : mlir_type) : bool := mlir_element_type_eqb ty Float16Type.
Definition matrix_element_type (ty : mlir_type) : bool :=
  f16 ty || mlir_element_type_eqb ty BFloat16Type.
Definition supported_shape (sh : list nat) : bool :=
  match sh with [_] | [_;_] => forallb (fun n => negb (Nat.eqb n 0)) sh
  | _ => false end.

(* Linalg inserts axes; HIVM broadcasts existing size-one axes. *)
Definition broadcast_tensor {S} (insert_axes : bool)
    (src dst : value S) (dims : list nat) : result runtime_error (value S) :=
  let axis_is_broadcast i := existsb (Nat.eqb i) dims in
  let project coordinate :=
    let indexed := combine (seq 0 (length coordinate)) coordinate in
    if insert_axes then map snd (filter (fun p => negb (axis_is_broadcast (fst p))) indexed)
    else map (fun p => if axis_is_broadcast (fst p) then 0 else snd p) indexed in
  let dst_shape := shape dst in
  let expected :=
    if insert_axes then project dst_shape
    else map (fun p => if axis_is_broadcast (fst p) then 1 else snd p)
      (combine (seq 0 (length dst_shape)) dst_shape) in
  if forallb (fun i => Nat.ltb i (length dst_shape)) dims &&
      shape_eq expected (shape src) &&
      mlir_element_type_eqb (element_type src) (element_type dst) then
    xs <-? elements src ;;
    let fix gather coordinates :=
      match coordinates with
      | [] => Ok []
      | coordinate :: rest =>
          match nth_error xs (linear_coordinate (shape src) (project coordinate)) with
          | None => Error InvalidShape
          | Some x => tail <-? gather rest ;; Ok (x :: tail)
          end
      end in
    result <-? gather (tensor_indices dst_shape) ;;
    make_value dst_shape (element_type dst) result
  else Error InvalidShape.

Inductive operand (S : Type) :=
| ScalarOperand (ty : mlir_type) (scalar : S)
| TensorOperand (tensor : value S).
Arguments ScalarOperand {S} _ _.
Arguments TensorOperand {S} _.

Lemma make_value_shape {S} sh ty (xs : list S) v :
  make_value sh ty xs = Ok v -> shape v = sh /\ element_type v = ty.
Proof.
  unfold make_value. destruct (tensor_of_list sh ty xs); intro H;
    inversion H; subst; split; reflexivity.
Qed.

Lemma make_value_elements {S} sh ty (xs : list S) v :
  make_value sh ty xs = Ok v -> elements v = Ok xs.
Proof.
  unfold make_value, tensor_of_list.
  destruct (Nat.eq_dec (length xs) (num_elements sh)); intro H;
    inversion H; reflexivity.
Qed.

Lemma elements_length {S} (v : value S) xs :
  elements v = Ok xs -> length xs = num_elements (shape v).
Proof.
  destruct v as [sh ty|[sh ty t]]; cbn; intro H; inversion H; subst.
  apply tensor_num_elements_correct.
Qed.

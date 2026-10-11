From Stdlib Require Import Bool List PeanoNat.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.Value Require Import DType Scalar.

Import ListNotations.
Set Implicit Arguments.

Definition scalar_failure {A} (outcome : result scalar_error A)
    : result runtime_error A :=
  match outcome with
  | Ok value => Ok value
  | Error _ => Error NumericFailure
  end.

Fixpoint map_scalar_result {Scalar}
    (function : Scalar -> result scalar_error Scalar) (values : list Scalar)
    : result runtime_error (list Scalar) :=
  match values with
  | [] => Ok []
  | value :: rest =>
      mapped <-? scalar_failure (function value) ;;
      mapped_rest <-? map_scalar_result function rest ;;
      Ok (mapped :: mapped_rest)
  end.

Fixpoint map2_scalar_result {Scalar}
    (function : Scalar -> Scalar -> result scalar_error Scalar)
    (left right : list Scalar) : result runtime_error (list Scalar) :=
  match left, right with
  | [], [] => Ok []
  | left_value :: left_rest, right_value :: right_rest =>
      mapped <-? scalar_failure (function left_value right_value) ;;
      mapped_rest <-? map2_scalar_result function left_rest right_rest ;;
      Ok (mapped :: mapped_rest)
  | _, _ => Error InvalidShape
  end.

Fixpoint flat_index (shape coordinate : list nat)
    : result runtime_error nat :=
  match shape, coordinate with
  | [], [] => Ok 0
  | dimension :: shape_rest, index :: coordinate_rest =>
      if index <? dimension then
        rest <-? flat_index shape_rest coordinate_rest ;;
        Ok (index * shape_size shape_rest + rest)
      else Error InvalidShape
  | _, _ => Error InvalidShape
  end.

Definition tensor_lookup {Scalar} (value : tensor Scalar)
    (coordinate : list nat) : result runtime_error Scalar :=
  index <-? flat_index (tensor_shape value) coordinate ;;
  match nth_error (tensor_elements value) index with
  | Some element => Ok element
  | None => Error InvalidShape
  end.

Fixpoint same_shape {Scalar} (shape : list nat) (values : list (tensor Scalar))
    : bool :=
  match values with
  | [] => true
  | value :: rest =>
      if tensor_well_formedb value &&
         if list_eq_dec Nat.eq_dec (tensor_shape value) shape then true else false
      then same_shape shape rest
      else false
  end.

Fixpoint strictly_increasing_from (lower : nat) (values : list nat) : bool :=
  match values with
  | [] => true
  | value :: rest =>
      (lower <=? value) && strictly_increasing_from (S value) rest
  end.

Definition valid_dimensions (rank : nat) (dimensions : list nat) : bool :=
  strictly_increasing_from 0 dimensions &&
  forallb (fun dimension => dimension <? rank) dimensions.

Definition is_reduction_dimension (index : nat) (dimensions : list nat) : bool :=
  existsb (Nat.eqb index) dimensions.

Fixpoint projected_shape_from (index : nat) (shape dimensions : list nat)
    (keep_reduction : bool) : list nat :=
  match shape with
  | [] => []
  | size :: rest =>
      if Bool.eqb (is_reduction_dimension index dimensions) keep_reduction
      then size :: projected_shape_from (S index) rest dimensions keep_reduction
      else projected_shape_from (S index) rest dimensions keep_reduction
  end.

Definition result_shape (shape dimensions : list nat) : list nat :=
  projected_shape_from 0 shape dimensions false.

Definition reduction_shape (shape dimensions : list nat) : list nat :=
  projected_shape_from 0 shape dimensions true.

Fixpoint merge_coordinates_from (index : nat) (shape dimensions : list nat)
    (output reduction : list nat) : result runtime_error (list nat) :=
  match shape with
  | [] =>
      match output, reduction with
      | [], [] => Ok []
      | _, _ => Error InvalidShape
      end
  | _ :: shape_rest =>
      if is_reduction_dimension index dimensions then
        match reduction with
        | [] => Error InvalidShape
        | value :: reduction_rest =>
            rest <-? merge_coordinates_from (S index) shape_rest dimensions
              output reduction_rest ;;
            Ok (value :: rest)
        end
      else
        match output with
        | [] => Error InvalidShape
        | value :: output_rest =>
            rest <-? merge_coordinates_from (S index) shape_rest dimensions
              output_rest reduction ;;
            Ok (value :: rest)
        end
  end.

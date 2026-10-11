From Stdlib Require Import Bool List PeanoNat.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.HFusion.Semantics Require Import Common.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors.

Import ListNotations.
Set Implicit Arguments.

(* A linalg.reduce combiner is the executable meaning of its mandatory region.
   It receives one scalar from every input followed separately by the current
   accumulator values, and must yield one value per init/result.  This is not a
   configurable interpreter handler: the program's region evaluator supplies
   this function. *)
Definition reduction_combiner (Scalar : Type) :=
  list Scalar -> list Scalar -> result runtime_error (list Scalar).

Fixpoint lookup_tensors {Scalar shape}
    (values : list (shaped_tensor Scalar shape))
    (coordinate : list nat) : result runtime_error (list Scalar) :=
  match values with
  | [] => Ok []
  | ShapedTensor _ value :: rest =>
      element <-? tensor_lookup value coordinate ;;
      elements <-? lookup_tensors rest coordinate ;;
      Ok (element :: elements)
  end.

Fixpoint fold_reduction_coordinates {Scalar}
    (combiner : reduction_combiner Scalar) (shape dimensions : list nat)
    (inputs : list (shaped_tensor Scalar shape))
    (output_coordinate : list nat)
    (reduction_coordinates : list (list nat)) (accumulators : list Scalar)
    : result runtime_error (list Scalar) :=
  match reduction_coordinates with
  | [] => Ok accumulators
  | reduction_coordinate :: rest =>
      coordinate <-?
        merge_coordinates_from 0 shape dimensions
          output_coordinate reduction_coordinate ;;
      input_values <-? lookup_tensors inputs coordinate ;;
      accumulators' <-? combiner input_values accumulators ;;
      if Nat.eqb (length accumulators') (length accumulators) then
        fold_reduction_coordinates combiner dimensions inputs
          output_coordinate rest accumulators'
      else Error InvalidShape
  end.

Fixpoint append_columns {Scalar} (columns : list (list Scalar))
    (values : list Scalar) : result runtime_error (list (list Scalar)) :=
  match columns, values with
  | [], [] => Ok []
  | column :: columns_rest, value :: values_rest =>
      result_rest <-? append_columns columns_rest values_rest ;;
      Ok ((column ++ [value]) :: result_rest)
  | _, _ => Error InvalidShape
  end.

Fixpoint reduce_output_coordinates {Scalar}
    (combiner : reduction_combiner Scalar) (shape dimensions : list nat)
    (inputs : list (shaped_tensor Scalar shape))
    (inits : list (shaped_tensor Scalar (result_shape shape dimensions)))
    (reduction_coordinates output_coordinates : list (list nat))
    (columns : list (list Scalar))
    : result runtime_error (list (list Scalar)) :=
  match output_coordinates with
  | [] => Ok columns
  | output_coordinate :: rest =>
      initial_values <-? lookup_tensors inits output_coordinate ;;
      reduced <-?
        fold_reduction_coordinates combiner dimensions inputs
          output_coordinate reduction_coordinates initial_values ;;
      columns' <-? append_columns columns reduced ;;
      reduce_output_coordinates combiner dimensions inputs inits
        reduction_coordinates rest columns'
  end.

Fixpoint build_reduction_results {Scalar shape}
    (inits : list (shaped_tensor Scalar shape))
    (columns : list (list Scalar))
    : result runtime_error (list (shaped_tensor Scalar shape)) :=
  match inits, columns with
  | [], [] => Ok []
  | ShapedTensor element_type _ :: inits_rest, column :: columns_rest =>
      results <-? build_reduction_results inits_rest columns_rest ;;
      match tensor_of_list shape element_type column with
      | Some output => Ok (ShapedTensor element_type output :: results)
      | None => Error InvalidShape
      end
  | _, _ => Error InvalidShape
  end.

(* Complete structural semantics for linalg.reduce.

   MLIR LinalgStructuredOps.td permits variadic inputs and inits, requires a
   single combiner region, and requires dimensions to be strictly increasing.
   This definition supports arbitrary rank, any number of reduction dimensions,
   and any number of inputs/results.  The output shape is the input shape with
   all reduction dimensions removed.  Every output coordinate starts from the
   corresponding init values, then executes the combiner once per point in the
   Cartesian product of reduction dimensions.

   Tensor element arithmetic is intentionally not hard-coded here: add, max,
   multi-result, or another legal region are all obtained by executing the
   actual combiner region. *)
Definition sem_linalg_reduce {Scalar}
    (combiner : reduction_combiner Scalar) (dimensions : list nat)
    (input_shape : list nat)
    (inputs : list (shaped_tensor Scalar input_shape))
    (inits : list
      (shaped_tensor Scalar (result_shape input_shape dimensions)))
    : result runtime_error
        (list (shaped_tensor Scalar (result_shape input_shape dimensions))) :=
  let output_shape := result_shape input_shape dimensions in
  if valid_dimensions (length input_shape) dimensions then
    columns <-?
      reduce_output_coordinates combiner dimensions inputs inits
        (tensor_indices (reduction_shape input_shape dimensions))
        (tensor_indices output_shape)
        (repeat [] (length inits)) ;;
    build_reduction_results inits columns
  else Error InvalidShape.

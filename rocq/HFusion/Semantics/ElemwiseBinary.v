From Stdlib Require Import Bool List PeanoNat.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.HFusion Require Import Attrs Instr.
From UnifiedInterpreter.HFusion.Semantics Require Import Common.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.Value Require Import Scalar.

Import ListNotations.
Set Implicit Arguments.

(* Upstream MLIR LinalgEnums.td defines all ten BinaryFn cases represented
   below. Huawei's framework_interface.md selects this standard Linalg
   operation for add/sub/mul/div/max/min and delegates its semantics to MLIR. *)
Definition scalar_operation_of_linalg_binary
    (function : linalg_binary_fn) : scalar_operation :=
  match function with
  | LinalgAdd => ScalarAdd
  | LinalgSub => ScalarSub
  | LinalgMul => ScalarMul
  | LinalgDiv => ScalarDiv
  | LinalgDivUnsigned => ScalarDivUnsigned
  | LinalgMaxSigned => ScalarMax
  | LinalgMinSigned => ScalarMin
  | LinalgMaxUnsigned => ScalarMaxUnsigned
  | LinalgMinUnsigned => ScalarMinUnsigned
  | LinalgPowF => ScalarPow
  end.

Inductive elementwise_operand (Scalar : Type) (shape : list nat) :=
| ElementwiseScalar (element_type : mlir_type) (value : Scalar)
| ElementwiseTensor (element_type : mlir_type)
    (value : tensor Scalar shape element_type).

Arguments ElementwiseScalar {Scalar shape} _ _.
Arguments ElementwiseTensor {Scalar shape element_type} _.

Definition elementwise_operand_type {Scalar shape}
    (operand : elementwise_operand Scalar shape) : mlir_type :=
  match operand with
  | ElementwiseScalar element_type _ => element_type
  | @ElementwiseTensor _ _ element_type _ => element_type
  end.

Definition linalg_cast_spec (cast : linalg_type_fn)
    (source target : mlir_type) : hfusion_cast_spec :=
  {| cast_source_element_type := source;
     cast_result_element_type := target;
     cast_type_fn :=
       match cast with
       | LinalgCastSigned => HFusionCastSigned
       | LinalgCastUnsigned => HFusionCastUnsigned
       end;
     cast_round_mode := HFusionRint;
     cast_unsigned_mode :=
       match cast with
       | LinalgCastSigned => HFusionSI2SI
       | LinalgCastUnsigned => HFusionUI2UI
       end;
     cast_enable_overflow := true;
     cast_enable_saturate := false |}.

Definition expand_elementwise_operand {Scalar} `{ScalarOps Scalar}
    (cast : linalg_type_fn) (output_shape : list nat) (result_element_type : mlir_type)
    (operand : elementwise_operand Scalar output_shape)
    : result runtime_error (list Scalar) :=
  let specification :=
    linalg_cast_spec cast (elementwise_operand_type operand) result_element_type in
  let cast_values values := map_scalar_result (scalar_cast specification) values in
  match operand with
  | ElementwiseScalar _ value =>
      cast_value <-? scalar_failure (scalar_cast specification value) ;;
      Ok (repeat cast_value (num_elements output_shape))
  | @ElementwiseTensor _ _ _ value => cast_values (tensor_elements value)
  end.

(* Complete named-op semantics for linalg.elemwise_binary:
   1. receive operands whose destination shape already agrees by type;
   2. broadcast rank-0 scalar operands over that shape;
   3. cast both operands to the result element type using Linalg TypeFn;
   4. apply any legal BinaryFn pointwise.

   The destination's previous elements are not read: the named op assigns every
   output element. *)
Definition sem_linalg_elemwise_binary {Scalar} `{ScalarOps Scalar}
    (function : linalg_binary_fn) (cast : linalg_type_fn)
    (output_shape : list nat) (result_element_type : mlir_type)
    (left right : elementwise_operand Scalar output_shape)
    : result runtime_error (tensor Scalar output_shape result_element_type) :=
  left_values <-?
    expand_elementwise_operand cast result_element_type left ;;
  right_values <-?
    expand_elementwise_operand cast result_element_type right ;;
  values <-?
    map2_scalar_result
      (eval_scalar_operation (scalar_operation_of_linalg_binary function))
      left_values right_values ;;
  match tensor_of_list output_shape result_element_type values with
  | Some output => Ok output
  | None => Error InvalidShape
  end.

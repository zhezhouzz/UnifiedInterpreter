From Stdlib Require Import Bool List PeanoNat.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.HFusion Require Import Instr.
From UnifiedInterpreter.HFusion.Semantics Require Import Common.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.Value Require Import DType Scalar.

Import ListNotations.
Set Implicit Arguments.

(* Upstream MLIR LinalgEnums.td defines all ten BinaryFn cases represented
   below. Huawei's framework_interface.md selects this standard Linalg
   operation for add/sub/mul/div/max/min and delegates its semantics to MLIR. *)
Definition eval_linalg_binary {Scalar} `{ScalarOps Scalar}
    (function : linalg_binary_fn) (left right : Scalar)
    : result scalar_error Scalar :=
  match function with
  | LinalgAdd => eval_scalar_operation ScalarAdd left right
  | LinalgSub => eval_scalar_operation ScalarSub left right
  | LinalgMul => eval_scalar_operation ScalarMul left right
  | LinalgDiv => eval_scalar_operation ScalarDiv left right
  | LinalgDivUnsigned => eval_scalar_operation ScalarDivUnsigned left right
  | LinalgMaxSigned => eval_scalar_operation ScalarMax left right
  | LinalgMinSigned => eval_scalar_operation ScalarMin left right
  | LinalgMaxUnsigned => eval_scalar_operation ScalarMaxUnsigned left right
  | LinalgMinUnsigned => eval_scalar_operation ScalarMinUnsigned left right
  | LinalgPowF => eval_scalar_operation ScalarPow left right
  end.

Inductive elementwise_operand (Scalar : Type) :=
| ElementwiseScalar (element_type : dtype) (value : Scalar)
| ElementwiseTensor (value : tensor Scalar).

Arguments ElementwiseScalar {Scalar} _ _.
Arguments ElementwiseTensor {Scalar} _.

Definition elementwise_operand_type {Scalar}
    (operand : elementwise_operand Scalar) : dtype :=
  match operand with
  | ElementwiseScalar element_type _ => element_type
  | ElementwiseTensor value => tensor_element_type value
  end.

Definition linalg_cast_spec (cast : linalg_type_fn)
    (source target : dtype) : cast_spec :=
  {| cast_source := source;
     cast_target := target;
     cast_kind_value :=
       match cast with
       | LinalgCastSigned => CastSigned
       | LinalgCastUnsigned => CastUnsigned
       end;
     cast_round_mode := RoundBasic RoundNearestEven;
     cast_unsigned_mode :=
       match cast with
       | LinalgCastSigned => SI2SI
       | LinalgCastUnsigned => UI2UI
       end;
     cast_enable_overflow := true;
     cast_enable_saturate := false |}.

Definition expand_elementwise_operand {Scalar} `{ScalarOps Scalar}
    (cast : linalg_type_fn) (output_shape : list nat) (output_type : dtype)
    (operand : elementwise_operand Scalar)
    : result runtime_error (list Scalar) :=
  let specification :=
    linalg_cast_spec cast (elementwise_operand_type operand) output_type in
  let cast_values values := map_scalar_result (scalar_cast specification) values in
  match operand with
  | ElementwiseScalar _ value =>
      cast_value <-? scalar_failure (scalar_cast specification value) ;;
      Ok (repeat cast_value (shape_size output_shape))
  | ElementwiseTensor value =>
      if tensor_well_formedb value &&
         if list_eq_dec Nat.eq_dec (tensor_shape value) output_shape
         then true else false
      then cast_values (tensor_elements value)
      else Error InvalidShape
  end.

(* Complete named-op semantics for linalg.elemwise_binary:
   1. verify tensor operands match the destination shape;
   2. broadcast rank-0 scalar operands over that shape;
   3. cast both operands to the destination/accumulator dtype using TypeFn;
   4. apply any legal BinaryFn pointwise.

   The destination's previous elements are not read: the named op assigns every
   output element. *)
Definition sem_linalg_elemwise_binary {Scalar} `{ScalarOps Scalar}
    (function : linalg_binary_fn) (cast : linalg_type_fn)
    (left right : elementwise_operand Scalar)
    (output_shape : list nat) (output_type : dtype)
    : result runtime_error (tensor Scalar) :=
  left_values <-?
    expand_elementwise_operand cast output_shape output_type left ;;
  right_values <-?
    expand_elementwise_operand cast output_shape output_type right ;;
  values <-?
    map2_scalar_result (eval_linalg_binary function) left_values right_values ;;
  Ok {| tensor_shape := output_shape;
        tensor_element_type := output_type;
        tensor_elements := values |}.

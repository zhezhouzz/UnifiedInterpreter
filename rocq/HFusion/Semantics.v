From Stdlib Require Import List PeanoNat.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.HFusion Require Import Instr.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.Value Require Import DType Scalar.

Import ListNotations.
Set Implicit Arguments.

(* Huawei documents the Linalg/Tensor part of the Linalg/HFusion layer as
   using standard MLIR operation semantics:
   https://ascendnpu-ir.readthedocs.io/en/latest/sources/developer_guide/
     conversion/interface_api.html

   These direct executable functions cover the three operation instances used
   most heavily by the captured FlashAttention HFusion artifact. *)

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

Definition eval_linalg_binary {Scalar} `{ScalarOps Scalar}
    (function : linalg_binary_fn) (left right : Scalar)
    : result scalar_error Scalar :=
  match function with
  | LinalgAdd => eval_scalar_operation ScalarAdd left right
  | LinalgSub => eval_scalar_operation ScalarSub left right
  | LinalgMul => eval_scalar_operation ScalarMul left right
  | LinalgDiv => eval_scalar_operation ScalarDiv left right
  end.

Inductive elementwise_operand (Scalar : Type) :=
| ElementwiseScalar (value : Scalar)
| ElementwiseTensor (value : tensor Scalar).

Arguments ElementwiseScalar {Scalar} _.
Arguments ElementwiseTensor {Scalar} _.

Definition expand_elementwise_operand {Scalar} (shape : list nat)
    (operand : elementwise_operand Scalar) : result runtime_error (list Scalar) :=
  match operand with
  | ElementwiseScalar value => Ok (repeat value (shape_size shape))
  | ElementwiseTensor value =>
      if list_eq_dec Nat.eq_dec (tensor_shape value) shape
      then Ok (tensor_elements value)
      else Error InvalidShape
  end.

(* linalg.elemwise_binary

   Huawei's framework-integration document maps add/sub/mul/div to
   linalg.binary_fn<add/sub/mul/div> and shows both scalar and tensor operands:
   docs/source/en/developer_guide/conversion/framework_interface.md.
   Huawei's interface overview delegates the operation semantics to MLIR
   Linalg.  The MLIR named op applies BinaryFn elementwise; outs supplies the
   result shape.  A scalar operand is broadcast to every result element. *)
Definition sem_linalg_elemwise_binary {Scalar} `{ScalarOps Scalar}
    (function : linalg_binary_fn)
    (left right : elementwise_operand Scalar)
    (output_shape : list nat) (output_type : dtype)
    : result runtime_error (tensor Scalar) :=
  left_values <-? expand_elementwise_operand output_shape left ;;
  right_values <-? expand_elementwise_operand output_shape right ;;
  values <-?
    map2_scalar_result (eval_linalg_binary function) left_values right_values ;;
  Ok {| tensor_shape := output_shape;
        tensor_element_type := output_type;
        tensor_elements := values |}.

Inductive reduction_function := ReductionAdd | ReductionMax.

Definition eval_reduction {Scalar} `{ScalarOps Scalar}
    (function : reduction_function) (value accumulator : Scalar) : Scalar :=
  match function with
  | ReductionAdd => scalar_add value accumulator
  | ReductionMax => scalar_max value accumulator
  end.

Fixpoint fold_reduction {Scalar} `{ScalarOps Scalar}
    (function : reduction_function) (values : list Scalar)
    (accumulator : Scalar) : Scalar :=
  match values with
  | [] => accumulator
  | value :: rest =>
      fold_reduction function rest
        (eval_reduction function value accumulator)
  end.

Fixpoint reduce_rows {Scalar} `{ScalarOps Scalar}
    (function : reduction_function) (columns rows : nat)
    (values initial_values : list Scalar) : result runtime_error (list Scalar) :=
  match rows, initial_values with
  | O, [] =>
      match values with [] => Ok [] | _ => Error InvalidShape end
  | S remaining_rows, initial :: remaining_initials =>
      let row := firstn columns values in
      if Nat.eqb (length row) columns then
        reduced_rest <-?
          reduce_rows function columns remaining_rows
            (skipn columns values) remaining_initials ;;
        Ok (fold_reduction function row initial :: reduced_rest)
      else Error InvalidShape
  | _, _ => Error InvalidShape
  end.

(* linalg.reduce

   Huawei's framework-integration document says sum lowers to linalg.reduce
   with arith.addf/addi and max lowers with maximumf/maxsi.  MLIR defines outs
   as the initial accumulator and the nested region as the combining function.

   hfusion_level.mlir contains rank-2 tensors reduced on dimensions=[1] with
   arith.addf or arith.maxnumf.  This function implements precisely that
   executable subset: each row is folded left-to-right from its outs element.
   Other dimensions are rejected rather than given an invented meaning. *)
Definition sem_linalg_reduce {Scalar} `{ScalarOps Scalar}
    (function : reduction_function) (dimensions : list nat)
    (input initial : tensor Scalar) : result runtime_error (tensor Scalar) :=
  match dimensions, tensor_shape input, tensor_shape initial with
  | [1], [rows; columns], [initial_rows] =>
      if Nat.eqb rows initial_rows then
        values <-?
          reduce_rows function columns rows
            (tensor_elements input) (tensor_elements initial) ;;
        Ok {| tensor_shape := [rows];
              tensor_element_type := tensor_element_type initial;
              tensor_elements := values |}
      else Error InvalidShape
  | _, _, _ => Error UnsupportedInstruction
  end.

Definition hfusion_rounding (mode : hfusion_round_mode) : option round_mode :=
  match mode with
  | HFusionRint => Some RoundNearestEven
  | HFusionFloor => Some RoundDown
  | HFusionCeil => Some RoundUp
  | HFusionTrunc => Some RoundTowardZero
  | HFusionRound | HFusionOdd | HFusionTruncWithOverflow => None
  end.

(* hfusion.cast

   Huawei's source of truth is
   bishengir/include/bishengir/Dialect/HFusion/IR/
     HFusionNamedStructuredOps.yaml and HFusionEnums.td.
   CastOp applies the conversion elementwise.  Its ODS defaults are
   cast_signed, RINT, enable_overflow=true, enable_saturate=false, and SI2SI;
   RINT means nearest with ties to even.  Huawei's FAQ shows the same cast form
   around normalized HFusion operations.

   This first executable definition covers exactly the numeric cast form in
   the FlashAttention artifact.  Modes whose behavior ScalarOps cannot yet
   distinguish fail explicitly. *)
Definition sem_hfusion_cast {Scalar} `{ScalarOps Scalar}
    (cast : hfusion_cast_kind) (rounding : hfusion_round_mode)
    (enable_overflow enable_saturate : bool)
    (unsigned_mode : hfusion_unsigned_mode) (target_type : dtype)
    (input : tensor Scalar) : result runtime_error (tensor Scalar) :=
  match cast, enable_overflow, enable_saturate, unsigned_mode,
        hfusion_rounding rounding with
  | HFusionCastSigned, true, false, HFusionSI2SI, Some round_mode =>
      let specification :=
        {| cast_source := tensor_element_type input;
           cast_target := target_type;
           cast_round_mode := round_mode |} in
      values <-?
        map_scalar_result (scalar_cast specification) (tensor_elements input) ;;
      Ok {| tensor_shape := tensor_shape input;
            tensor_element_type := target_type;
            tensor_elements := values |}
  | _, _, _, _, _ => Error UnsupportedInstruction
  end.

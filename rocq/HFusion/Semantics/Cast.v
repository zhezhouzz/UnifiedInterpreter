From Stdlib Require Import List.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.HFusion Require Import Instr.
From UnifiedInterpreter.HFusion.Semantics Require Import Common.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.Value Require Import DType Scalar.

Set Implicit Arguments.

Definition hfusion_rounding (mode : hfusion_round_mode)
    : extended_round_mode :=
  match mode with
  | HFusionRint => RoundBasic RoundNearestEven
  | HFusionRound => RoundNearestAway
  | HFusionFloor => RoundBasic RoundDown
  | HFusionCeil => RoundBasic RoundUp
  | HFusionTrunc => RoundBasic RoundTowardZero
  | HFusionOdd => RoundOdd
  | HFusionTruncWithOverflow => TruncWithOverflow
  end.

(* Complete structural semantics for Huawei's hfusion.cast.

   HFusionNamedStructuredOps.yaml says CastOp applies its conversion
   elementwise. HFusionEnums.td defines all TypeFn, RoundMode, and UnsignedMode
   cases. This function forwards every legal attribute combination to the
   scalar model: signed and unsigned conversion, bitcast, all seven rounding
   modes, overflow control, saturation control, and all four signedness
   transitions.

   ScalarOps supplies the bit-accurate behavior of each source/target dtype
   pair. The tensor operation is therefore reusable with exact, IEEE, or
   adversarial scalar models without rejecting a legal HFusion mode. *)
Definition sem_hfusion_cast {Scalar} `{ScalarOps Scalar}
    (cast : cast_kind) (rounding : hfusion_round_mode)
    (enable_overflow enable_saturate : bool)
    (signedness : unsigned_mode) (target_type : dtype)
    (input : tensor Scalar) : result runtime_error (tensor Scalar) :=
  let specification :=
    {| cast_source := tensor_element_type input;
       cast_target := target_type;
       cast_kind_value := cast;
       cast_round_mode := hfusion_rounding rounding;
       cast_unsigned_mode := signedness;
       cast_enable_overflow := enable_overflow;
       cast_enable_saturate := enable_saturate |} in
  values <-?
    map_scalar_result (scalar_cast specification) (tensor_elements input) ;;
  Ok {| tensor_shape := tensor_shape input;
        tensor_element_type := target_type;
        tensor_elements := values |}.

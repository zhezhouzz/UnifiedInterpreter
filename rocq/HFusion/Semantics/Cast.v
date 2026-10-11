From Stdlib Require Import List.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.HFusion Require Import Attrs Instr.
From UnifiedInterpreter.HFusion.Semantics Require Import Common.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.Value Require Import Scalar.

Set Implicit Arguments.

(* Complete structural semantics for Huawei's hfusion.cast.

   HFusionNamedStructuredOps.yaml says CastOp applies its conversion
   elementwise. HFusionEnums.td defines all TypeFn, RoundMode, and UnsignedMode
   cases. This function forwards every legal attribute combination to the
   scalar model: signed and unsigned conversion, bitcast, all seven rounding
   modes, overflow control, saturation control, and all four signedness
   transitions.

   ScalarOps supplies the bit-accurate behavior of each source/target mlir_type
   pair. The tensor operation is therefore reusable with exact, IEEE, or
   adversarial scalar models without rejecting a legal HFusion mode. *)
Definition sem_hfusion_cast {Scalar shape source_element_type} `{ScalarOps Scalar}
    (type_fn : hfusion_type_fn) (round_mode : hfusion_round_mode)
    (enable_overflow enable_saturate : bool)
    (unsigned_mode : hfusion_unsigned_mode) (result_element_type : mlir_type)
    (input : tensor Scalar shape source_element_type)
    : result runtime_error (tensor Scalar shape result_element_type) :=
  let specification :=
    {| cast_source_element_type := source_element_type;
       cast_result_element_type := result_element_type;
       cast_type_fn := type_fn;
       cast_round_mode := round_mode;
       cast_unsigned_mode := unsigned_mode;
       cast_enable_overflow := enable_overflow;
       cast_enable_saturate := enable_saturate |} in
  values <-?
    map_scalar_result (scalar_cast specification) (tensor_elements input) ;;
  match tensor_of_list shape result_element_type values with
  | Some output => Ok output
  | None => Error InvalidShape
  end.

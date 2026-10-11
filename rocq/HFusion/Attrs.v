From UnifiedInterpreter.Type Require Import MLIR.

(* AscendNPU-IR HFusionEnums.td: TypeFn. *)
Inductive hfusion_type_fn :=
| HFusionCastSigned
| HFusionCastUnsigned
| HFusionBitcast.

(* AscendNPU-IR HFusionEnums.td: RoundMode. *)
Inductive hfusion_round_mode :=
| HFusionRint
| HFusionRound
| HFusionFloor
| HFusionCeil
| HFusionTrunc
| HFusionOdd
| HFusionTruncWithOverflow.

(* AscendNPU-IR HFusionEnums.td: UnsignedMode. *)
Inductive hfusion_unsigned_mode :=
| HFusionSI2SI
| HFusionSI2UI
| HFusionUI2SI
| HFusionUI2UI.

Record hfusion_cast_spec := {
  cast_source_element_type : mlir_type;
  cast_result_element_type : mlir_type;
  cast_type_fn : hfusion_type_fn;
  cast_round_mode : hfusion_round_mode;
  cast_unsigned_mode : hfusion_unsigned_mode;
  cast_enable_overflow : bool;
  cast_enable_saturate : bool
}.

From UnifiedInterpreter.HFusion Require Import Syntax.
From UnifiedInterpreter.Value Require Import DType.

Inductive hfusion_cast_kind := HFusionCastSigned.
Inductive hfusion_round_mode := HFusionRint.

Inductive hfusion_instr :=
| HFusionCast (cast : hfusion_cast_kind) (rounding : hfusion_round_mode)
    (input output : typed_value) (result_type : mlir_type).

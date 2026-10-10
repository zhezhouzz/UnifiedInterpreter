From UnifiedInterpreter.HFusion Require Import Syntax.

Inductive scf_instr :=
| ScfFor (induction_variable : block_argument)
    (lower_bound upper_bound step : typed_value).

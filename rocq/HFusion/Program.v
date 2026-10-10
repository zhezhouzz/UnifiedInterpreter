From Stdlib Require Import List.
From UnifiedInterpreter.HFusion Require Import Syntax Instr.

Definition hfusion_operation := operation instr.
Definition hfusion_region := region instr.
Definition hfusion_program := list hfusion_operation.

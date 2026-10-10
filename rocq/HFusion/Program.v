From UnifiedInterpreter.HFusion Require Import
  Syntax ArithInstr TensorInstr MemRefInstr BufferizationInstr LinalgInstr
  ScfInstr FuncInstr HFusionInstr.

(* Closed operation inventory for the captured FlashAttention HFusion module.
   Adding another source artifact requires extending this sum deliberately. *)
Inductive hfusion_stage_instr :=
| ArithOp (instruction : arith_instr)
| TensorOp (instruction : tensor_instr)
| MemRefOp (instruction : memref_instr)
| BufferizationOp (instruction : bufferization_instr)
| LinalgOp (instruction : linalg_instr)
| ScfOp (instruction : scf_instr)
| FuncOp (instruction : func_instr)
| HFusionOp (instruction : hfusion_instr).

Definition hfusion_operation := operation hfusion_stage_instr.
Definition hfusion_region := region hfusion_stage_instr.
Definition hfusion_program := list hfusion_operation.

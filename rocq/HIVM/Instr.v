From Stdlib Require Import List ZArith.
From UnifiedInterpreter.HFusion Require Import Syntax Instr.

(* Only the compute-stage attention vocabulary. Common MLIR payloads remain
   shared with HFusion; this is a separate stage, not an HFusion opcode. *)
Inductive binary_op := VAdd | VSub | VMul | VDiv.
Inductive unary_op := VExp | VLn.
Inductive reduce_op := ReduceSum | ReduceMax.

Record cast_spec := {
  cast_rint : bool;
  cast_signed : bool
}.
Definition default_cast := {| cast_rint := true; cast_signed := true |}.

Record mm_spec := {
  mm_b_transpose : bool;
  mm_init : bool;
  mm_real_m : Z;
  mm_real_k : Z;
  mm_real_n : Z
}.

Inductive hivm_operation :=
| VectorBinary (op : binary_op) (left right destination : ssa_value)
| VectorUnary (op : unary_op) (input destination : ssa_value)
| VectorBroadcast (input destination : ssa_value) (dimensions : list nat)
| VectorReduce (op : reduce_op) (input destination : ssa_value)
    (dimensions : list nat)
| VectorCast (spec : cast_spec) (input destination : ssa_value)
| MatrixMultiply (left right destination init real_m real_k real_n : ssa_value)
    (b_transpose : bool).

Inductive instr :=
| CommonArith (op : arith_operation)
| CommonTensor (op : tensor_operation)
| CommonMemRef (op : memref_operation)
| CommonBufferization (op : bufferization_operation)
| CommonScf (op : scf_operation)
| CommonFunc (op : func_operation)
| HIVM (op : hivm_operation).

Definition hivm_program := list (operation instr).

From Stdlib Require Import List String ZArith QArith.
From UnifiedInterpreter.Value Require Import DType.

Import ListNotations.

Definition value_id := nat.
Definition symbol_name := string.

Inductive dimension :=
| StaticDim (size : nat)
| DynamicDim.

Record strided_layout := {
  layout_offset : option Z;
  layout_strides : list (option Z)
}.

Inductive mlir_type :=
| IndexType
| IntegerType (bits : nat) (sign : signedness)
| FloatType (format : dtype)
| TensorType (shape : list nat) (element_type : dtype)
| MemRefType (shape : list dimension) (element_type : dtype)
    (layout : option strided_layout).

Record typed_value := {
  value_name : value_id;
  value_type : mlir_type
}.

Inductive index_expr :=
| StaticIndex (value : Z)
| DynamicIndex (value : value_id).

Inductive float_literal :=
| FiniteFloat (value : Q)
| PositiveInfinity
| NegativeInfinity
| NotANumber.

Inductive literal :=
| IndexLiteral (value : Z)
| IntegerLiteral (value : Z)
| FloatLiteral (value : float_literal).

Record block_argument := {
  block_argument_name : value_id;
  block_argument_type : mlir_type
}.

(* Regions are recursive at the MLIR level.  Dialect files define only opcode
   payloads; this common node supplies SSA results and nested regions. *)
Inductive operation (Instruction : Type) : Type :=
| OperationNode
    (results : list value_id)
    (instruction : Instruction)
    (regions : list (region Instruction))
with region (Instruction : Type) : Type :=
| RegionNode
    (arguments : list block_argument)
    (body : list (operation Instruction)).

Arguments OperationNode {Instruction} _ _ _.
Arguments RegionNode {Instruction} _ _.

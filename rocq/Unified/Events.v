From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.Type Require Import MLIR.

Import ListNotations.

Inductive event :=
| EInstructionStart (name : string)
| EInstructionEnd (name : string)
| EAllocation (id : nat) (elements : nat)
| EDescriptor (id base : nat) (offset : Z)
    (sizes strides : list Z)
| EMemoryRead (allocation : nat) (indices : list Z)
| EMemoryWrite (allocation : nat) (indices : list Z)
(* A range operation is one observation regardless of how many cells it
   touches: the trace records the operation, not its element count. *)
| EMemoryReadRange (allocation : nat) (count : nat)
| EMemoryWriteRange (allocation : nat) (count : nat)
| ENumericBoundary (operation : string) (input output : mlir_type).

(* Events are an observation vocabulary only. Core instruction semantics do not
   receive a trace and therefore cannot inspect or rewrite execution history. *)

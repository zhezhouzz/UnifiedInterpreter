From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.Value Require Import DType.

Import ListNotations.

Inductive event :=
| EInstructionStart (name : string)
| EInstructionEnd (name : string)
| EAllocation (id : nat) (elements : nat)
| EDescriptor (id base : nat) (offset : Z)
    (sizes strides : list Z)
| EMemoryRead (allocation : nat) (indices : list Z)
| EMemoryWrite (allocation : nat) (indices : list Z)
| ENumericBoundary (operation : string) (input output : dtype).

Inductive runtime_error :=
| InvalidShape
| InvalidDescriptor
| InvalidMemoryAccess
| UnsupportedInstruction
| NumericFailure
| OutOfFuel.

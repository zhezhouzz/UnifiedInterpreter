From UnifiedInterpreter.Memory Require Import Model.

Inductive undefined_behavior :=
| CopySourceDestinationOverlap.

Inductive runtime_error :=
| InvalidShape
| InvalidDescriptor
| InvalidMemoryAccess
| StaticProgramError
| RuntimeMemoryError (cause : memory_error)
| ReadUninitialized
| UndefinedBehavior (cause : undefined_behavior)
| UnsupportedInstruction
| NumericFailure
| OutOfFuel.

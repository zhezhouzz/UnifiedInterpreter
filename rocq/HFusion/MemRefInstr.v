From Stdlib Require Import List.
From UnifiedInterpreter.HFusion Require Import Syntax.

Inductive memref_instr :=
| MemRefAlloc (result_type : mlir_type)
| MemRefCopy (source destination : typed_value)
| MemRefReinterpretCast (source : typed_value)
    (offsets sizes strides : list index_expr) (result_type : mlir_type).

From Stdlib Require Import List ZArith.
From UnifiedInterpreter.Type Require Import DType Shape.

Record strided_layout := {
  layout_offset : option Z;
  layout_strides : list (option Z)
}.

(* Types belong to the common MLIR layer rather than any one dialect. Both
   tensors and memrefs retain dynamic dimensions instead of prematurely
   replacing them with concrete runtime sizes. *)
Inductive mlir_type :=
| IndexType
| IntegerType (bits : nat) (sign : signedness)
| FloatType (format : dtype)
| TensorType (dimensions : shape) (element_type : dtype)
| MemRefType (dimensions : shape) (element_type : dtype)
    (layout : option strided_layout).


From Stdlib Require Import List.
From UnifiedInterpreter.HFusion Require Import Syntax.
From UnifiedInterpreter.Value Require Import DType.

Inductive tensor_instr :=
| TensorEmpty (shape : list nat) (element_type : dtype)
| TensorExpandShape (input : typed_value)
    (reassociation : list (list nat)) (output_shape : list nat)
    (result_type : mlir_type)
| TensorCollapseShape (input : typed_value)
    (reassociation : list (list nat)) (result_type : mlir_type).

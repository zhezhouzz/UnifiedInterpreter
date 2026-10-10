From UnifiedInterpreter.HFusion Require Import Syntax.

Record tensor_access := {
  access_restrict : bool;
  access_writable : bool
}.

Inductive bufferization_instr :=
| BufferizationToTensor (source : typed_value) (access : tensor_access)
    (result_type : mlir_type)
| BufferizationMaterializeInDestination
    (source destination : typed_value) (writable : bool).

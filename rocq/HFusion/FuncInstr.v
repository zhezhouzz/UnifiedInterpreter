From Stdlib Require Import List String.
From UnifiedInterpreter.HFusion Require Import Syntax.

Inductive hacc_argument_type :=
| FftsBaseAddress
| SyncBlockLock
| Workspace.

Inductive tensor_kind :=
| TensorKindInput
| TensorKindOutput.

Inductive argument_attribute :=
| HaccArgumentType (kind : hacc_argument_type)
| TtTensorKind (kind : tensor_kind).

Record function_argument := {
  function_argument_value : block_argument;
  function_argument_attributes : list argument_attribute
}.

Inductive function_kind := DeviceFunction.
Inductive execution_mode := MixMode.
Inductive parallel_mode := SimdMode.

Record function_attributes := {
  sync_block_lock_argument_index : option nat;
  workspace_argument_index : option nat;
  hacc_entry : bool;
  hacc_function_kind : option function_kind;
  function_execution_mode : option execution_mode;
  function_parallel_mode : option parallel_mode
}.

Inductive func_instr :=
| FuncFunction (name : symbol_name) (arguments : list function_argument)
    (results : list mlir_type) (attributes : function_attributes)
| FuncReturn (values : list typed_value).

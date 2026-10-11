From Stdlib Require Import List String.
From UnifiedInterpreter.HFusion Require Import Attrs Syntax.
From UnifiedInterpreter.Type Require Import MLIR.

Import ListNotations.

Inductive arith_binary_operator :=
| ArithAddI | ArithMulI | ArithDivSI | ArithRemSI
| ArithAddF | ArithMaxNumF.

Inductive arith_cast_operator := ArithExtSI | ArithIndexCast.

Inductive arith_operation :=
| ArithConstant (value : literal) (result_type : mlir_type)
| ArithBinary (operator : arith_binary_operator)
    (left right : ssa_value) (result_type : mlir_type)
| ArithCast (operator : arith_cast_operator) (input : ssa_value)
    (result_type : mlir_type).

Inductive tensor_operation :=
| TensorEmpty (shape : list nat) (element_type : mlir_type)
| TensorExpandShape (input : ssa_value)
    (reassociation : list (list nat)) (output_shape : list nat)
    (result_type : mlir_type)
| TensorCollapseShape (input : ssa_value)
    (reassociation : list (list nat)) (result_type : mlir_type).

Inductive memref_operation :=
| MemRefAlloc (result_type : mlir_type)
| MemRefCopy (source destination : ssa_value)
| MemRefReinterpretCast (source : ssa_value)
    (offsets sizes strides : list index_expr) (result_type : mlir_type).

Record tensor_access := {
  access_restrict : bool;
  access_writable : bool
}.

Inductive bufferization_operation :=
| BufferizationToTensor (source : ssa_value) (access : tensor_access)
    (result_type : mlir_type)
| BufferizationMaterializeInDestination
    (source destination : ssa_value) (writable : bool).

(* Upstream MLIR LinalgEnums.td: complete BinaryFn enumeration. *)
Inductive linalg_binary_fn :=
| LinalgAdd | LinalgSub | LinalgMul | LinalgDiv | LinalgDivUnsigned
| LinalgMaxSigned | LinalgMinSigned
| LinalgMaxUnsigned | LinalgMinUnsigned
| LinalgPowF.
Inductive linalg_type_fn := LinalgCastSigned | LinalgCastUnsigned.
Inductive linalg_unary_fn := LinalgExp | LinalgLog.
Inductive matmul_input_precision := MatmulIEEE.

Inductive linalg_operation :=
| LinalgFill (input : ssa_value) (output : ssa_value)
| LinalgTranspose (input output : ssa_value) (permutation : list nat)
| LinalgMatmul (left right output : ssa_value)
    (input_precision : matmul_input_precision)
| LinalgElemwiseBinary (function : linalg_binary_fn) (cast : linalg_type_fn)
    (left right output : ssa_value)
| LinalgElemwiseUnary (function : linalg_unary_fn)
    (input output : ssa_value)
| LinalgReduce (input output : ssa_value) (dimensions : list nat)
| LinalgBroadcast (input output : ssa_value) (dimensions : list nat)
| LinalgYield (values : list ssa_value).

Inductive scf_operation :=
| ScfFor (induction_variable : block_argument)
    (lower_bound upper_bound step : ssa_value).

Inductive hacc_argument_type := FftsBaseAddress | SyncBlockLock | Workspace.
Inductive tensor_kind := TensorKindInput | TensorKindOutput.

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

Inductive func_operation :=
| FuncFunction (name : symbol_name) (arguments : list function_argument)
    (results : list mlir_type) (attributes : function_attributes)
| FuncReturn (values : list ssa_value).

Inductive hfusion_dialect_operation :=
| HFusionCast (type_fn : hfusion_type_fn) (round_mode : hfusion_round_mode)
    (enable_overflow enable_saturate : bool)
    (unsigned_mode : hfusion_unsigned_mode)
    (input output : ssa_value) (result_type : mlir_type).

(* The closed instruction type for the captured HFusion-stage artifact. *)
Inductive instr :=
| ArithInstr (operation : arith_operation)
| TensorInstr (operation : tensor_operation)
| MemRefInstr (operation : memref_operation)
| BufferizationInstr (operation : bufferization_operation)
| LinalgInstr (operation : linalg_operation)
| ScfInstr (operation : scf_operation)
| FuncInstr (operation : func_operation)
| HFusionInstr (operation : hfusion_dialect_operation).

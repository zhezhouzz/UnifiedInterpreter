From Stdlib Require Import List.
From UnifiedInterpreter.Base Require Import Result StateM.
From UnifiedInterpreter.HFusion Require Import Syntax Instr.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors State.
From UnifiedInterpreter.Value Require Import DType Scalar.

Import ListNotations.
Set Implicit Arguments.

(* Documentation sources used below:

   [Ascend interface]
   AscendNPU-IR, docs/source/en/developer_guide/conversion/interface_api.md.
   https://ascendnpu-ir.readthedocs.io/en/latest/sources/developer_guide/
     conversion/interface_api.html
   It specifies that the Linalg/Tensor layer uses standard MLIR operator
   semantics and that the HFusion layer adds Ascend-aware named operations,
   fusion, bufferization, tiling, and scheduling.

   [Ascend cast ODS]
   bishengir/include/bishengir/Dialect/HFusion/IR/
     HFusionNamedStructuredOps.yaml and HFusionEnums.td.
   https://github.com/Ascend/AscendNPU-IR/tree/master/bishengir/include/
     bishengir/Dialect/HFusion/IR
   CastOp is elementwise and carries TypeFn, RoundMode, enable_overflow,
   enable_saturate, and UnsignedMode.  RINT is nearest with ties to even.

   The standard-dialect clauses below refer to the upstream MLIR dialect
   documents, as required by [Ascend interface]:
   https://mlir.llvm.org/docs/Dialects/ArithOps/
   https://mlir.llvm.org/docs/Dialects/TensorOps/
   https://mlir.llvm.org/docs/Dialects/MemRef/
   https://mlir.llvm.org/docs/Dialects/BufferizationOps/
   https://mlir.llvm.org/docs/Dialects/Linalg/
   https://mlir.llvm.org/docs/Dialects/SCFDialect/
   https://mlir.llvm.org/docs/Dialects/Func/
*)

(* A handler supplies the runtime value domain and the concrete meaning of
   every operation admitted by Instr.instr.  Keeping one field per operation
   makes missing semantics visible at handler construction time: adding an
   Instr constructor forces every handler to be updated.  Operands are still
   SSA references here; the concrete handler owns the SSA environment and
   resolves them in its State. *)
Record instr_handler (State RuntimeValue : Type) := {
  (* MLIR Arith: arith.constant materializes its typed literal. *)
  sem_arith_constant : literal -> mlir_type ->
    M runtime_error State RuntimeValue;
  (* MLIR Arith: integer/float binary ops apply the selected scalar operation
     to two same-typed operands.  DivSI/RemSI use signed integer semantics;
     MaxNumF follows maxNum NaN behavior. *)
  sem_arith_binary : arith_binary_operator -> typed_value -> typed_value ->
    mlir_type -> M runtime_error State RuntimeValue;
  (* MLIR Arith: ExtSI sign-extends; IndexCast converts between index and an
     integer type according to the target index width. *)
  sem_arith_cast : arith_cast_operator -> typed_value -> mlir_type ->
    M runtime_error State RuntimeValue;

  (* MLIR Tensor: tensor.empty creates an uninitialized destination tensor;
     reading a cell before it is written must therefore fail, not yield zero. *)
  sem_tensor_empty : list nat -> dtype ->
    M runtime_error State RuntimeValue;
  (* MLIR Tensor: expand/collapse reshape logical indices without changing
     element order; reassociation and element-count constraints are checked. *)
  sem_tensor_expand_shape : typed_value -> list (list nat) -> list nat ->
    mlir_type -> M runtime_error State RuntimeValue;
  sem_tensor_collapse_shape : typed_value -> list (list nat) -> mlir_type ->
    M runtime_error State RuntimeValue;

  (* MLIR MemRef: alloc creates fresh storage. *)
  sem_memref_alloc : mlir_type -> M runtime_error State RuntimeValue;
  (* MLIR MemRef: copy copies every source element to the destination and
     requires compatible shapes and element types. *)
  sem_memref_copy : typed_value -> typed_value ->
    M runtime_error State RuntimeValue;
  (* MLIR MemRef: reinterpret_cast creates a descriptor/view with the supplied
     offset, sizes, and strides.  It does not allocate or copy storage; the
     MLIR contract places validity/in-bounds responsibility on the program. *)
  sem_memref_reinterpret_cast : typed_value -> list index_expr ->
    list index_expr -> list index_expr -> mlir_type ->
    M runtime_error State RuntimeValue;

  (* MLIR Bufferization: to_tensor exposes a memref through tensor semantics;
     restrict/writable are aliasing and mutability promises, not data motion. *)
  sem_bufferization_to_tensor : typed_value -> tensor_access -> mlir_type ->
    M runtime_error State RuntimeValue;
  (* MLIR Bufferization: materialize_in_destination writes the tensor value
     into the destination memref. *)
  sem_bufferization_materialize : typed_value -> typed_value -> bool ->
    M runtime_error State RuntimeValue;

  (* MLIR Linalg destination-style operations.  The outs operand supplies the
     result shape and, for reductions/matmul, the initial accumulator. *)
  sem_linalg_fill : typed_value -> typed_value ->
    M runtime_error State RuntimeValue;
  sem_linalg_transpose : typed_value -> typed_value -> list nat ->
    M runtime_error State RuntimeValue;
  sem_linalg_matmul : typed_value -> typed_value -> typed_value ->
    matmul_input_precision -> M runtime_error State RuntimeValue;
  sem_linalg_elemwise_binary : linalg_binary_fn -> typed_value ->
    typed_value -> typed_value -> M runtime_error State RuntimeValue;
  sem_linalg_elemwise_unary : linalg_unary_fn -> typed_value ->
    typed_value -> M runtime_error State RuntimeValue;
  (* MLIR Linalg: reduce folds the selected dimensions.  Its combining
     operation is the single nested region attached to the operation node. *)
  sem_linalg_reduce : typed_value -> typed_value -> list nat ->
    list (region instr) -> M runtime_error State RuntimeValue;
  sem_linalg_broadcast : typed_value -> typed_value -> list nat ->
    M runtime_error State RuntimeValue;
  (* MLIR Linalg: yield terminates a structured-op region and returns its
     scalar values to the enclosing operation. *)
  sem_linalg_yield : list typed_value ->
    M runtime_error State RuntimeValue;

  (* MLIR SCF: scf.for evaluates bounds once, repeatedly executes its one
     region, and increments the induction variable by step. *)
  sem_scf_for : block_argument -> typed_value -> typed_value -> typed_value ->
    list (region instr) -> M runtime_error State RuntimeValue;

  (* MLIR Func: func.func introduces a callable region; func.return terminates
     it and supplies the declared results.  Ascend hacc.entry/function_kind
     remain function attributes, as documented by [Ascend interface]. *)
  sem_func_function : symbol_name -> list function_argument ->
    list mlir_type -> function_attributes -> list (region instr) ->
    M runtime_error State RuntimeValue;
  sem_func_return : list typed_value ->
    M runtime_error State RuntimeValue;

  (* Ascend CastOp, [Ascend cast ODS]: apply the selected conversion
     elementwise, using all five semantic attributes even when textual MLIR
     omits attributes whose ODS defaults are in force. *)
  sem_hfusion_cast : hfusion_cast_kind -> hfusion_round_mode -> bool -> bool ->
    hfusion_unsigned_mode -> typed_value -> typed_value -> mlir_type ->
    M runtime_error State RuntimeValue
}.

(* The only instruction dispatcher.  It preserves nested regions for the
   three operations whose meaning depends on a body: linalg.reduce, scf.for,
   and func.func. *)
Definition exec_instr {State RuntimeValue}
    (handler : instr_handler State RuntimeValue)
    (instruction : instr) (regions : list (region instr))
    : M runtime_error State RuntimeValue :=
  match instruction with
  | ArithInstr operation =>
      match operation with
      | ArithConstant value result_type =>
          sem_arith_constant handler value result_type
      | ArithBinary operator lhs rhs result_type =>
          sem_arith_binary handler operator lhs rhs result_type
      | ArithCast operator input result_type =>
          sem_arith_cast handler operator input result_type
      end
  | TensorInstr operation =>
      match operation with
      | TensorEmpty shape element_type =>
          sem_tensor_empty handler shape element_type
      | TensorExpandShape input reassociation output_shape result_type =>
          sem_tensor_expand_shape handler input reassociation output_shape
            result_type
      | TensorCollapseShape input reassociation result_type =>
          sem_tensor_collapse_shape handler input reassociation result_type
      end
  | MemRefInstr operation =>
      match operation with
      | MemRefAlloc result_type => sem_memref_alloc handler result_type
      | MemRefCopy source destination =>
          sem_memref_copy handler source destination
      | MemRefReinterpretCast source offsets sizes strides result_type =>
          sem_memref_reinterpret_cast handler source offsets sizes strides
            result_type
      end
  | BufferizationInstr operation =>
      match operation with
      | BufferizationToTensor source access result_type =>
          sem_bufferization_to_tensor handler source access result_type
      | BufferizationMaterializeInDestination source destination writable =>
          sem_bufferization_materialize handler source destination writable
      end
  | LinalgInstr operation =>
      match operation with
      | LinalgFill input output => sem_linalg_fill handler input output
      | LinalgTranspose input output permutation =>
          sem_linalg_transpose handler input output permutation
      | LinalgMatmul lhs rhs output precision =>
          sem_linalg_matmul handler lhs rhs output precision
      | LinalgElemwiseBinary function lhs rhs output =>
          sem_linalg_elemwise_binary handler function lhs rhs output
      | LinalgElemwiseUnary function input output =>
          sem_linalg_elemwise_unary handler function input output
      | LinalgReduce input output dimensions =>
          sem_linalg_reduce handler input output dimensions regions
      | LinalgBroadcast input output dimensions =>
          sem_linalg_broadcast handler input output dimensions
      | LinalgYield values => sem_linalg_yield handler values
      end
  | ScfInstr (ScfFor variable lower upper step) =>
      sem_scf_for handler variable lower upper step regions
  | FuncInstr operation =>
      match operation with
      | FuncFunction name arguments results attributes =>
          sem_func_function handler name arguments results attributes regions
      | FuncReturn values => sem_func_return handler values
      end
  | HFusionInstr
      (HFusionCast cast rounding overflow saturate unsigned input output
        result_type) =>
      sem_hfusion_cast handler cast rounding overflow saturate unsigned input
        output result_type
  end.

(* Temporary executable foundations used by the smoke tests.  Dialect
   operation semantics will call these helpers; these definitions are not
   themselves HFusion-stage operation syntax. *)
Definition local_alloc {Scalar} (space : address_space)
    (element_type : dtype) (contents : list Scalar)
    : M runtime_error (memory_state Scalar) allocation_id :=
  fun memory => Ok (allocate_buffer space element_type contents memory).

Definition exec_alloc {Scalar State} `{HasMemory Scalar State}
    (space : address_space) (element_type : dtype) (contents : list Scalar)
    : M runtime_error State allocation_id :=
  zoom memory_lens (local_alloc space element_type contents).

Definition exec_scalar_operation {Scalar State} `{ScalarOps Scalar}
    (operation : scalar_operation) (left right : Scalar)
    : M runtime_error State Scalar :=
  fun state =>
    match eval_scalar_operation operation left right with
    | Ok value => Ok (value, state)
    | Error _ => Error NumericFailure
    end.

Definition exec_fail {State}
    : M runtime_error State unit :=
  fail InvalidMemoryAccess.

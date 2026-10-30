From Stdlib Require Import Extraction ExtrOcamlBasic ExtrOcamlNatInt.
From Stdlib Require Import ExtrOCamlInt63 ExtrOCamlPArray.
From UnifiedInterpreter.Examples Require Import FrameworkSmoke.
From UnifiedInterpreter.HFusion.Semantics Require Import
  ElemwiseBinary Reduce Cast.
From UnifiedInterpreter.Examples Require Import TestSupport.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Memory Require Import Effects Handler.
From UnifiedInterpreter.HFusion Require Import Interpreter Runtime.
From UnifiedInterpreter.HFusion.Semantics Require Import Memory.
From UnifiedInterpreter.Examples Require Import MemoryEffects.
From UnifiedInterpreter.Value Require Import Scalar.
From UnifiedInterpreter.HIVM Require Import Semantics Arith Execution.
From UnifiedInterpreter.HFusion.Semantics Require Import Structured.
From UnifiedInterpreter.Examples Require Import HIVMCompute HIVMMemory HIVMExceptional.

Extraction Language OCaml.
(* 保留数组类型别名，供官方 Parray 类型映射使用。 *)
Extraction NoInline PrimArray.array.
(* 空内存提取为构造器值，满足 OCaml 的多态值限制。 *)
Extraction Inline base.empty gmap.gmap_empty gmap.gset_empty mapset.mapset_empty.
Set Extraction Output Directory "Extraction".

Extraction "unified_semantics.ml"
  smoke_result
  view_example
  read_view
  exec_alloc
  eval_scalar_operation
  exec_scalar_operation
  sem_linalg_elemwise_binary
  sem_linalg_reduce
  sem_hfusion_cast
  handle_memory
  eval_memory_instruction
  artifact_memory_result
  materialize_program
  sem_empty sem_binary sem_unary sem_broadcast sem_reduce sem_cast sem_mmad sem_reshape
  sem_integer_constant sem_integer_binary sem_integer_cast sem_float_constant
  evaluate run_memory extracted_checks memory_check exceptional_checks
  sem_linalg_fill sem_linalg_transpose sem_linalg_broadcast
  sem_linalg_unary sem_linalg_matmul.

From Stdlib Require Import Extraction ExtrOcamlBasic ExtrOcamlNatInt.
From UnifiedInterpreter.Examples Require Import FrameworkSmoke.
From UnifiedInterpreter.HFusion Require Import Instructions.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Value Require Import Scalar.

Extraction Language OCaml.
Set Extraction Output Directory "Extraction".

Extraction "unified_semantics.ml"
  smoke_result
  view_example
  read_view
  exec_alloc
  eval_scalar_operation
  exec_scalar_operation.

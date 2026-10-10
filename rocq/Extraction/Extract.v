From Stdlib Require Import Extraction ExtrOcamlBasic ExtrOcamlNatInt.
From UnifiedInterpreter.Examples Require Import FrameworkSmoke.
From UnifiedInterpreter.HFusion Require Import Instructions.

Extraction Language OCaml.
Set Extraction Output Directory "_build/rocq".

Extraction "unified_semantics.ml"
  smoke_result
  exec_alloc
  exec_scalar_add.

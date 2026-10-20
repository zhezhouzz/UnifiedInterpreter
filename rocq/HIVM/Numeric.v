From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.Value Require Import Scalar.
From UnifiedInterpreter.HFusion Require Import Syntax.
From UnifiedInterpreter.HIVM Require Import Instr.

(* Computational contract, without algebraic laws that would exclude IEEE
   values. The backend owns rounding, NaNs, infinities and f16/f32 encoding.
   Max MUST propagate NaNs; it is not arith.maxnumf. MAC receives both input
   and accumulator types so it need not round products as standalone f16. *)
Class Numeric (S : Type) := {
  number_literal : mlir_type -> float_literal -> result scalar_error S;
  number_zero : mlir_type -> S;
  number_binary : binary_op -> mlir_type -> S -> S -> result scalar_error S;
  number_unary : unary_op -> mlir_type -> S -> result scalar_error S;
  number_reduce_seed : reduce_op -> mlir_type -> S;
  number_reduce : reduce_op -> mlir_type -> S -> S -> result scalar_error S;
  number_cast : cast_spec -> mlir_type -> mlir_type -> S -> result scalar_error S;
  number_mac : mlir_type -> mlir_type -> S -> S -> S -> result scalar_error S
}.

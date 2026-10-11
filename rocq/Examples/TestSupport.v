From Stdlib Require Import List.
From UnifiedInterpreter.Base Require Import Result StateM.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors State.
From UnifiedInterpreter.Type Require Import HFusion MLIR.
From UnifiedInterpreter.Value Require Import Scalar.

Import ListNotations.
Set Implicit Arguments.

(* Smoke-test helpers, deliberately not HFusion operation semantics. *)
Definition local_alloc {Scalar} (space : address_space)
    (element_type : mlir_type) (contents : list Scalar)
    : M runtime_error (memory_state Scalar) allocation_id :=
  fun memory => Ok (allocate_buffer space element_type contents memory).

Definition exec_alloc {Scalar State} `{HasMemory Scalar State}
    (space : address_space) (element_type : mlir_type) (contents : list Scalar)
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

Definition exec_fail {State} : M runtime_error State unit :=
  fail InvalidMemoryAccess.

From Stdlib Require Import List.
From UnifiedInterpreter.Base Require Import Result StateM.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors State.
From UnifiedInterpreter.Value Require Import DType Scalar.

Import ListNotations.
Set Implicit Arguments.

Definition local_alloc {Scalar} (space : address_space)
    (element_type : dtype) (contents : list Scalar)
    : M runtime_error (memory_state Scalar) allocation_id :=
  fun memory => Ok (allocate_buffer space element_type contents memory).

Definition exec_alloc {Scalar State} `{HasMemory Scalar State}
    (space : address_space) (element_type : dtype) (contents : list Scalar)
    : M runtime_error State allocation_id :=
  zoom memory_lens (local_alloc space element_type contents).

Definition exec_scalar_add {Scalar State} `{ScalarOps Scalar}
    (left right : Scalar) : M runtime_error State Scalar :=
  pure (scalar_add left right).

Definition exec_fail {State}
    : M runtime_error State unit :=
  fail InvalidMemoryAccess.

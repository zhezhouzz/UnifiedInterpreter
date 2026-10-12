From Stdlib Require Import List ZArith.
From stdpp Require Import gmap.
From UnifiedInterpreter.Base Require Import Free Result.
From UnifiedInterpreter.HFusion Require Import Instr Runtime Syntax.
From UnifiedInterpreter.HFusion.Semantics Require Import Memory.
From UnifiedInterpreter.Memory Require Import Effects Model.
From UnifiedInterpreter.Type Require Import MLIR Shape.
From UnifiedInterpreter.Unified Require Import Errors.

Import ListNotations.
Set Implicit Arguments.

Fixpoint concrete_shape (dimensions : shape) : option (list nat) :=
  match dimensions with
  | [] => Some []
  | StaticDim size :: rest =>
      match concrete_shape rest with
      | Some sizes => Some (size :: sizes)
      | None => None
      end
  | DynamicDim :: _ => None
  end.

Definition lookup_value {Scalar} (value : ssa_value)
    (environment : ssa_environment Scalar) : option (runtime_value Scalar) :=
  environment !! value_name value.

Definition bind_one_result {Scalar} (results : list value_id)
    (value : runtime_value Scalar) (environment : ssa_environment Scalar)
    : result runtime_error (ssa_environment Scalar) :=
  match results with
  | [result_id] => Ok (<[result_id := value]> environment)
  | _ => Error StaticProgramError
  end.

Definition resolve_index {Scalar} (expression : index_expr)
    (environment : ssa_environment Scalar) : result runtime_error Z :=
  match expression with
  | StaticIndex value => Ok value
  | DynamicIndex id =>
      match environment !! id with
      | Some (RuntimeIndex value) => Ok value
      | _ => Error StaticProgramError
      end
  end.

Fixpoint resolve_indices {Scalar} (expressions : list index_expr)
    (environment : ssa_environment Scalar) : result runtime_error (list Z) :=
  match expressions with
  | [] => Ok []
  | expression :: rest =>
      value <-? resolve_index expression environment ;;
      values <-? resolve_indices rest environment ;;
      Ok (value :: values)
  end.

Fixpoint z_to_nat_list (values : list Z) : option (list nat) :=
  match values with
  | [] => Some []
  | Zneg _ :: _ => None
  | value :: rest =>
      match z_to_nat_list rest with
      | Some values' => Some (Z.to_nat value :: values')
      | None => None
      end
  end.

Definition eval_memref_operation {Scalar} (results : list value_id)
    (operation : memref_operation) (environment : ssa_environment Scalar)
    : memory_computation Scalar (result runtime_error (ssa_environment Scalar)) :=
  match operation with
  | MemRefAlloc result_type =>
      match result_type with
      | RankedMemRefType dimensions element_type _ space =>
          match concrete_shape dimensions with
          | Some shape =>
              descriptor <-! sem_memref_alloc space element_type shape ;;
              Return (bind_one_result results
                (RuntimeMemRef descriptor) environment)
          | None => Return (Error UnsupportedInstruction)
          end
      | _ => Return (Error StaticProgramError)
      end
  | MemRefCopy source destination =>
      match lookup_value source environment, lookup_value destination environment,
          value_type source with
      | Some (RuntimeMemRef source_id), Some (RuntimeMemRef destination_id),
          RankedMemRefType dimensions _ _ _ =>
          match concrete_shape dimensions with
          | Some shape =>
              sem_memref_copy shape source_id destination_id ;;!
              Return (Ok environment)
          | None => Return (Error UnsupportedInstruction)
          end
      | _, _, _ => Return (Error StaticProgramError)
      end
  | MemRefReinterpretCast source offsets sizes strides _ =>
      match lookup_value source environment,
          resolve_indices offsets environment,
          resolve_indices sizes environment,
          resolve_indices strides environment with
      | Some (RuntimeMemRef source_id), Ok [offset], Ok size_values,
          Ok stride_values =>
          match z_to_nat_list size_values with
          | Some shape =>
              descriptor <-!
                sem_memref_reinterpret_cast source_id offset shape stride_values ;;
              Return (bind_one_result results
                (RuntimeMemRef descriptor) environment)
          | None => Return (Error StaticProgramError)
          end
      | _, _, _, _ => Return (Error StaticProgramError)
      end
  end.

Definition eval_bufferization_operation {Scalar} (results : list value_id)
    (operation : bufferization_operation)
    (environment : ssa_environment Scalar)
    : memory_computation Scalar (result runtime_error (ssa_environment Scalar)) :=
  match operation with
  | BufferizationToTensor source access result_type =>
      match lookup_value source environment, result_type with
      | Some (RuntimeMemRef descriptor),
          RankedTensorType dimensions element_type =>
          match concrete_shape dimensions with
          | Some shape =>
              tensor <-!
                sem_bufferization_to_tensor descriptor shape element_type access ;;
              Return (bind_one_result results (RuntimeTensor tensor) environment)
          | None => Return (Error UnsupportedInstruction)
          end
      | _, _ => Return (Error StaticProgramError)
      end
  | BufferizationMaterializeInDestination source destination writable =>
      match lookup_value source environment, lookup_value destination environment with
      | Some (RuntimeTensor tensor), Some (RuntimeMemRef descriptor) =>
          _ <-! sem_bufferization_materialize_in_destination
            tensor descriptor writable ;;
          Return (Ok environment)
      | _, _ => Return (Error StaticProgramError)
      end
  end.

Definition eval_memory_instruction {Scalar} (results : list value_id)
    (instruction : instr) (environment : ssa_environment Scalar)
    : memory_computation Scalar (result runtime_error (ssa_environment Scalar)) :=
  match instruction with
  | MemRefInstr operation => eval_memref_operation results operation environment
  | BufferizationInstr operation =>
      eval_bufferization_operation results operation environment
  | _ => Return (Error UnsupportedInstruction)
  end.

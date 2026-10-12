From Stdlib Require Import List ZArith.
From UnifiedInterpreter.Base Require Import Free.
From UnifiedInterpreter.HFusion Require Import Instr Runtime.
From UnifiedInterpreter.Memory Require Import Effects Model.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Type Require Import HFusion MLIR.

Import ListNotations.
Set Implicit Arguments.

Definition sem_memref_alloc {Scalar} (space : address_space)
    (element_type : mlir_type) (shape : list nat)
    : memory_computation Scalar descriptor_id :=
  perform (Allocate space element_type shape).

Definition sem_memref_reinterpret_cast {Scalar} (source : descriptor_id)
    (offset : Z) (sizes : list nat) (strides : list Z)
    : memory_computation Scalar descriptor_id :=
  perform (Reinterpret source offset sizes strides).

Fixpoint copy_coordinates {Scalar} (source destination : descriptor_id)
    (coordinates : list (list nat)) : memory_computation Scalar unit :=
  match coordinates with
  | [] => Return tt
  | coordinate :: rest =>
      value <-! perform (Read source coordinate) ;;
      perform (Write destination coordinate value) ;;!
      copy_coordinates source destination rest
  end.

(* MLIR memref.copy permits different layouts but requires equal logical shape
   and element type. Those type conditions belong to elaboration; the dynamic
   semantics checks the documented non-overlap precondition and copies by
   logical coordinate. *)
Definition sem_memref_copy {Scalar} (shape : list nat)
    (source destination : descriptor_id) : memory_computation Scalar unit :=
  perform (AssertDisjoint source destination) ;;!
  copy_coordinates source destination (tensor_indices shape).

Definition sem_bufferization_to_tensor {Scalar} (descriptor : descriptor_id)
    (shape : list nat) (element_type : mlir_type) (access : tensor_access)
    : memory_computation Scalar (runtime_tensor Scalar) :=
  perform (ValidateDescriptor descriptor shape element_type) ;;!
  perform (ClaimTensorView descriptor
    (access_restrict access) (access_writable access)) ;;!
  Return (MemRefBackedTensor descriptor shape element_type access).

Fixpoint read_tensor_coordinates {Scalar} (descriptor : descriptor_id)
    (coordinates : list (list nat)) : memory_computation Scalar (list Scalar) :=
  match coordinates with
  | [] => Return []
  | coordinate :: rest =>
      value <-! perform (Read descriptor coordinate) ;;
      values <-! read_tensor_coordinates descriptor rest ;;
      Return (value :: values)
  end.

Definition materialize_runtime_tensor {Scalar} (value : runtime_tensor Scalar)
    : memory_computation Scalar (option (packed_tensor Scalar)) :=
  match value with
  | OwnedTensor tensor => Return (Some tensor)
  | MemRefBackedTensor descriptor shape element_type _ =>
      values <-! read_tensor_coordinates descriptor (tensor_indices shape) ;;
      match tensor_of_list shape element_type values with
      | Some tensor => Return (Some (PackTensor shape element_type tensor))
      | None => Return None
      end
  end.

Fixpoint write_tensor_coordinates {Scalar} (destination : descriptor_id)
    (coordinates : list (list nat)) (values : list Scalar)
    : memory_computation Scalar bool :=
  match coordinates, values with
  | [], [] => Return true
  | coordinate :: coordinates', value :: values' =>
      perform (Write destination coordinate value) ;;!
      write_tensor_coordinates destination coordinates' values'
  | _, _ => Return false
  end.

Definition sem_bufferization_materialize_in_destination {Scalar}
    (source : runtime_tensor Scalar) (destination : descriptor_id)
    (writable : bool)
    : memory_computation Scalar bool :=
  if writable then
    materialized <-! materialize_runtime_tensor source ;;
    match materialized with
    | None => Return false
    | Some (PackTensor shape element_type tensor) =>
        perform (ValidateDescriptor destination shape element_type) ;;!
        write_tensor_coordinates destination (tensor_indices shape)
          (tensor_elements tensor)
    end
  else perform (Reject ReadOnlyTensorView) ;;! Return false.

From Stdlib Require Import List ZArith.
From UnifiedInterpreter.Base Require Import Free.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Type Require Import HFusion MLIR.

Set Implicit Arguments.

(* Primitive memory requests.  Compound HFusion operations such as
   [memref.copy] are denoted by sequences of these effects. *)
Inductive memory_effect (Value : Type) : Type -> Type :=
| Allocate (space : address_space) (element_type : mlir_type)
    (dimensions : list nat) : memory_effect Value descriptor_id
| Reinterpret (source : descriptor_id) (offset : Z)
    (sizes : list nat) (strides : list Z)
    : memory_effect Value descriptor_id
| Read (descriptor : descriptor_id) (coordinate : list nat)
    : memory_effect Value Value
| Write (descriptor : descriptor_id) (coordinate : list nat) (value : Value)
    : memory_effect Value unit
| AssertDisjoint (left right : descriptor_id) : memory_effect Value unit
| ValidateDescriptor (descriptor : descriptor_id) (shape : list nat)
    (element_type : mlir_type) : memory_effect Value unit
| ClaimTensorView (descriptor : descriptor_id) (restrict writable : bool)
    : memory_effect Value unit
| Reject (error : memory_error) : memory_effect Value unit.

Arguments Allocate {Value} _ _ _.
Arguments Reinterpret {Value} _ _ _ _.
Arguments Read {Value} _ _.
Arguments Write {Value} _ _ _.
Arguments AssertDisjoint {Value} _ _.
Arguments ValidateDescriptor {Value} _ _ _.
Arguments ClaimTensorView {Value} _ _ _.
Arguments Reject {Value} _.

Definition memory_computation (Value A : Type) :=
  computation (memory_effect Value) A.

From Stdlib Require Import List ZArith.
From stdpp Require Import gmap.
From UnifiedInterpreter.Base Require Import Free Result.
From UnifiedInterpreter.Memory Require Import Effects Model.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Type Require Import HFusion MLIR.
From UnifiedInterpreter.Unified Require Import Errors Events.

Import ListNotations.
Open Scope Z_scope.
Set Implicit Arguments.

Fixpoint coordinate_in_bounds (coordinate sizes : list nat) : bool :=
  match coordinate, sizes with
  | [], [] => true
  | index :: coordinate', size :: sizes' =>
      Nat.ltb index size && coordinate_in_bounds coordinate' sizes'
  | _, _ => false
  end.

Fixpoint nat_list_eqb (left right : list nat) : bool :=
  match left, right with
  | [], [] => true
  | left_value :: left_rest, right_value :: right_rest =>
      Nat.eqb left_value right_value && nat_list_eqb left_rest right_rest
  | _, _ => false
  end.

Definition memory_failure {A} (error : memory_error) : result runtime_error A :=
  match error with
  | ReadUninitializedCell => Error ReadUninitialized
  | OverlappingCopy => Error (UndefinedBehavior CopySourceDestinationOverlap)
  | other => Error (RuntimeMemoryError other)
  end.

Definition descriptor_in_bounds {Value} (memory : memory_state Value)
    (descriptor : memref_descriptor) : bool :=
  match lookup_buffer (descriptor_allocation descriptor) memory with
  | None => false
  | Some storage =>
      forallb (fun address =>
        match address with
        | Zneg _ => false
        | Z0 => negb (Nat.eqb (length (buffer_cells storage)) 0)
        | Zpos positive =>
            Nat.ltb (Pos.to_nat positive) (length (buffer_cells storage))
        end) (descriptor_addresses descriptor)
  end.

Definition handle_allocate {Value} (space : address_space)
    (element_type : mlir_type) (dimensions : list nat)
    (memory : memory_state Value)
    : descriptor_id * memory_state Value * list event :=
  let allocation := memory_next_allocation memory in
  let '(descriptor, memory') :=
    allocate_memref space element_type dimensions memory in
  (descriptor, memory',
   [EAllocation allocation (num_elements dimensions);
    EDescriptor descriptor allocation 0 (map Z.of_nat dimensions)
      (row_major_strides dimensions)]).

Definition handle_reinterpret {Value} (source : descriptor_id) (offset : Z)
    (sizes : list nat) (strides : list Z) (memory : memory_state Value)
    : result runtime_error (descriptor_id * memory_state Value * list event) :=
  match lookup_descriptor source memory with
  | None => memory_failure UnknownDescriptor
  | Some source_descriptor =>
      if Nat.eqb (length sizes) (length strides) then
        let descriptor :=
          {| descriptor_allocation := descriptor_allocation source_descriptor;
             descriptor_offset := offset;
             descriptor_sizes := sizes;
             descriptor_strides := strides |} in
        if descriptor_in_bounds memory descriptor then
          let '(id, memory') := insert_descriptor descriptor memory in
          Ok (id, memory',
            [EDescriptor id (descriptor_allocation descriptor)
              offset (map Z.of_nat sizes) strides])
        else memory_failure ViewAddressOutOfBounds
      else memory_failure InvalidViewRank
  end.

Definition handle_read {Value} (descriptor_id : descriptor_id)
    (coordinate : list nat) (memory : memory_state Value)
    : result runtime_error (Value * memory_state Value * list event) :=
  match lookup_descriptor descriptor_id memory with
  | None => memory_failure UnknownDescriptor
  | Some descriptor =>
      match lookup_buffer (descriptor_allocation descriptor) memory with
      | None => memory_failure UnknownAllocation
      | Some storage =>
          if coordinate_in_bounds coordinate (descriptor_sizes descriptor) then
            match view_cell_offset (descriptor_offset descriptor)
                (descriptor_strides descriptor) coordinate with
            | Error error => memory_failure error
            | Ok address =>
                match read_buffer_cell storage address with
                | Error error => memory_failure error
                | Ok value =>
                    Ok (value, memory,
                      [EMemoryRead (descriptor_allocation descriptor)
                        (map Z.of_nat coordinate)])
                end
            end
          else memory_failure ViewAddressOutOfBounds
      end
  end.

Definition handle_write {Value} (descriptor_id : descriptor_id)
    (coordinate : list nat) (value : Value) (memory : memory_state Value)
    : result runtime_error (unit * memory_state Value * list event) :=
  match lookup_descriptor descriptor_id memory with
  | None => memory_failure UnknownDescriptor
  | Some descriptor =>
      match lookup_buffer (descriptor_allocation descriptor) memory with
      | None => memory_failure UnknownAllocation
      | Some storage =>
          if coordinate_in_bounds coordinate (descriptor_sizes descriptor) then
            match view_cell_offset (descriptor_offset descriptor)
                (descriptor_strides descriptor) coordinate with
            | Error error => memory_failure error
            | Ok address =>
                match write_buffer_cell storage address value with
                | Error error => memory_failure error
                | Ok storage' =>
                    let memory' :=
                      {| memory_buffers :=
                           <[descriptor_allocation descriptor := storage']>
                             (memory_buffers memory);
                         memory_descriptors := memory_descriptors memory;
                         memory_restricted_descriptors :=
                           memory_restricted_descriptors memory;
                         memory_next_allocation := memory_next_allocation memory;
                         memory_next_descriptor := memory_next_descriptor memory |} in
                    Ok (tt, memory',
                      [EMemoryWrite (descriptor_allocation descriptor)
                        (map Z.of_nat coordinate)])
                end
            end
          else memory_failure ViewAddressOutOfBounds
      end
  end.

Definition handle_claim {Value} (descriptor_id : descriptor_id)
    (restrict writable : bool) (memory : memory_state Value)
    : result runtime_error (unit * memory_state Value * list event) :=
  match lookup_descriptor descriptor_id memory with
  | None => memory_failure UnknownDescriptor
  | Some descriptor =>
      if restrict then
        let conflicts :=
          existsb (fun claimed =>
            match lookup_descriptor claimed memory with
            | Some other => descriptors_overlap descriptor other
            | None => false
            end) (elements (memory_restricted_descriptors memory)) in
        if conflicts then memory_failure RestrictAliasConflict
        else
          Ok (tt,
            {| memory_buffers := memory_buffers memory;
               memory_descriptors := memory_descriptors memory;
               memory_restricted_descriptors :=
                 {[ descriptor_id ]} ∪ memory_restricted_descriptors memory;
               memory_next_allocation := memory_next_allocation memory;
               memory_next_descriptor := memory_next_descriptor memory |}, [])
      else Ok (tt, memory, [])
  end.

Definition handle_disjoint {Value} (left_id right_id : descriptor_id)
    (memory : memory_state Value)
    : result runtime_error (unit * memory_state Value * list event) :=
  match lookup_descriptor left_id memory, lookup_descriptor right_id memory with
  | Some left_descriptor, Some right_descriptor =>
      if descriptors_overlap left_descriptor right_descriptor
      then Error (UndefinedBehavior CopySourceDestinationOverlap)
      else Ok (tt, memory, [])
  | _, _ => memory_failure UnknownDescriptor
  end.

Definition handle_validate {Value} (descriptor_id : descriptor_id)
    (shape : list nat) (element_type : mlir_type)
    (memory : memory_state Value)
    : result runtime_error (unit * memory_state Value * list event) :=
  match lookup_descriptor descriptor_id memory with
  | None => memory_failure UnknownDescriptor
  | Some descriptor =>
      match lookup_buffer (descriptor_allocation descriptor) memory with
      | None => memory_failure UnknownAllocation
      | Some storage =>
          if nat_list_eqb shape (descriptor_sizes descriptor) then
            if mlir_element_type_eqb element_type (buffer_element_type storage)
            then Ok (tt, memory, [])
            else memory_failure IncompatibleMemRef
          else memory_failure IncompatibleMemRef
      end
  end.

Definition handle_effect {Value X} (effect : memory_effect Value X)
    (memory : memory_state Value)
    : result runtime_error (X * memory_state Value * list event) :=
  match effect with
  | Allocate space element_type dimensions =>
      let '(descriptor, memory', trace) :=
        handle_allocate space element_type dimensions memory in
      Ok (descriptor, memory', trace)
  | Reinterpret source offset sizes strides =>
      handle_reinterpret source offset sizes strides memory
  | Read descriptor coordinate => handle_read descriptor coordinate memory
  | Write descriptor coordinate value =>
      handle_write descriptor coordinate value memory
  | AssertDisjoint left_id right_id => handle_disjoint left_id right_id memory
  | ValidateDescriptor descriptor shape element_type =>
      handle_validate descriptor shape element_type memory
  | ClaimTensorView descriptor restrict writable =>
      handle_claim descriptor restrict writable memory
  | Reject error => memory_failure error
  end.

Fixpoint handle_memory {Value A} (fuel : nat)
    (program : memory_computation Value A) (memory : memory_state Value)
    : result runtime_error (A * memory_state Value * list event) :=
  match fuel with
  | O => Error OutOfFuel
  | S fuel' =>
      match program with
      | Return value => Ok (value, memory, [])
      | Trigger effect continue =>
          match handle_effect effect memory with
          | Error error => Error error
          | Ok (answer, memory', trace) =>
              match handle_memory fuel' (continue answer) memory' with
              | Error error => Error error
              | Ok (value, memory'', trace') =>
                  Ok (value, memory'', trace ++ trace')
              end
          end
      end
  end.

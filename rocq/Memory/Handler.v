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

(* Bulk access handlers.  They perform the accesses through the bulk model
   functions, which are definitionally the sequence of single-cell accesses in
   coordinate order: there is no separate pre-validation, so a per-coordinate
   error is reported before any length mismatch, exactly as the pointwise
   specification does.  The trace records one operation. *)
Definition handle_read_range {Value} (descriptor_id : descriptor_id)
    (coordinates : list (list nat)) (memory : memory_state Value)
    : result runtime_error (list Value * memory_state Value * list event) :=
  match lookup_descriptor descriptor_id memory with
  | None => memory_failure UnknownDescriptor
  | Some descriptor =>
      match lookup_buffer (descriptor_allocation descriptor) memory with
      | None => memory_failure UnknownAllocation
      | Some storage =>
          match read_coordinates storage (descriptor_offset descriptor)
              (descriptor_strides descriptor) coordinates with
          | Error error => memory_failure error
          | Ok values =>
              Ok (values, memory,
                [EMemoryReadRange (descriptor_allocation descriptor)
                  (length coordinates)])
          end
      end
  end.

Definition handle_write_range {Value} (descriptor_id : descriptor_id)
    (coordinates : list (list nat)) (values : list Value)
    (memory : memory_state Value)
    : result runtime_error (unit * memory_state Value * list event) :=
  match lookup_descriptor descriptor_id memory with
  | None => memory_failure UnknownDescriptor
  | Some descriptor =>
      match lookup_buffer (descriptor_allocation descriptor) memory with
      | None => memory_failure UnknownAllocation
      | Some storage =>
          match write_coordinates storage (descriptor_offset descriptor)
              (descriptor_strides descriptor) coordinates values with
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
                [EMemoryWriteRange (descriptor_allocation descriptor)
                  (length coordinates)])
          end
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

Definition handle_effect {Value X} (request : memory_effect Value X)
    (memory : memory_state Value)
    : result runtime_error (X * memory_state Value * list event) :=
  match request with
  | Allocate space element_type dimensions =>
      let '(descriptor, memory', trace) :=
        handle_allocate space element_type dimensions memory in
      Ok (descriptor, memory', trace)
  | Reinterpret source offset sizes strides =>
      handle_reinterpret source offset sizes strides memory
  | Read descriptor coordinate => handle_read descriptor coordinate memory
  | Write descriptor coordinate value =>
      handle_write descriptor coordinate value memory
  | ReadRange descriptor coordinates =>
      handle_read_range descriptor coordinates memory
  | WriteRange descriptor coordinates values =>
      handle_write_range descriptor coordinates values memory
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
      | Trigger request continue =>
          match handle_effect request memory with
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

(* Accumulate events backwards to release previous memory states immediately.
   This has the same fuel convention and observable trace as handle_memory. *)
Fixpoint handle_memory_tail {Value A} (fuel : nat)
    (program : memory_computation Value A) (memory : memory_state Value)
    (reversed_trace : list event)
    : result runtime_error (A * memory_state Value * list event) :=
  match fuel with
  | O => Error OutOfFuel
  | S fuel' =>
      match program with
      | Return value => Ok (value, memory, rev reversed_trace)
      | Trigger request continue =>
          match handle_effect request memory with
          | Error error => Error error
          | Ok (answer, memory', trace) =>
              handle_memory_tail fuel' (continue answer) memory'
                (rev_append trace reversed_trace)
          end
      end
  end.

Lemma handle_memory_tail_correct {Value A} fuel
    (program : memory_computation Value A) memory acc :
  handle_memory_tail fuel program memory acc =
    match handle_memory fuel program memory with
    | Error e => Error e
    | Ok (value, memory', trace) => Ok (value, memory', rev acc ++ trace)
    end.
Proof.
  revert program memory acc. induction fuel as [|fuel IH]; intros; cbn; auto.
  destruct program as [value|X request continue]; cbn.
  - now rewrite app_nil_r.
  - destruct (handle_effect request memory) as [[[answer mem] trace]|err]; cbn; auto.
    rewrite IH. destruct (handle_memory fuel (continue answer) mem)
      as [[[value mem'] events]|err]; cbn; auto.
    rewrite rev_append_rev, rev_app_distr, rev_involutive, app_assoc. reflexivity.
Qed.

From Stdlib Require Import List ZArith.
From UnifiedInterpreter.Base Require Import Result StateM.
From UnifiedInterpreter.Memory Require Import Model.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors State.
From UnifiedInterpreter.HFusion Require Import Instr.
From UnifiedInterpreter.HFusion.Semantics Require Import
  ElemwiseBinary Reduce Cast.
From UnifiedInterpreter.Examples Require Import TestSupport.
From UnifiedInterpreter.Value Require Import DType Scalar.

Import ListNotations.

#[local] Instance ZScalarOps : ScalarOps Z :=
  {| scalar_zero := 0%Z;
     scalar_one := 1%Z;
     scalar_of_Z := fun value => value;
     scalar_add := Z.add;
     scalar_sub := Z.sub;
     scalar_mul := Z.mul;
     scalar_div := fun left right =>
       if Z.eqb right 0 then Error ScalarDivisionByZero
       else Ok (Z.quot left right);
     scalar_div_unsigned := fun left right =>
       if Z.eqb right 0 then Error ScalarDivisionByZero
       else Ok (Z.quot left right);
     scalar_max := Z.max;
     scalar_min := Z.min;
     scalar_max_unsigned := Z.max;
     scalar_min_unsigned := Z.min;
     scalar_pow := fun base exponent =>
       if exponent <? 0 then Error ScalarDomainError
       else Ok (Z.pow base exponent);
     scalar_exp := fun _ => Error ScalarDomainError;
     scalar_log := fun _ => Error ScalarDomainError;
     scalar_cast := fun _ value => Ok value |}.

Definition smoke_initial : memory_state Z := empty_memory.

Definition smoke_result :
    result runtime_error (allocation_id * memory_state Z) :=
  exec_alloc ASDefault (DInt 64 Signed)
    [10%Z; 20%Z; 30%Z] smoke_initial.

Example smoke_allocates_id_zero :
  match smoke_result with
  | Ok (id, _) => id = 0%nat
  | Error _ => False
  end.
Proof. reflexivity. Qed.

Example smoke_allocation_is_readable :
  match smoke_result with
  | Ok (id, state) =>
      lookup_buffer id state =
      Some {| buffer_address_space := ASDefault;
              buffer_element_type := DInt 64 Signed;
              buffer_cells := [10%Z; 20%Z; 30%Z] |}
  | Error _ => False
  end.
Proof. reflexivity. Qed.

Example smoke_preserves_descriptor_map :
  match smoke_result with
  | Ok (_, state) =>
      memory_descriptors state = memory_descriptors smoke_initial
  | Error _ => False
  end.
Proof. reflexivity. Qed.

Example failure_exposes_no_partial_state :
  @exec_fail (memory_state Z) smoke_initial = Error InvalidMemoryAccess.
Proof. reflexivity. Qed.

Definition allocate_then_fail :
    M runtime_error (memory_state Z) unit :=
  _ <- exec_alloc ASDefault (DInt 64 Signed) [42%Z] ;;
  fail InvalidMemoryAccess.

Example failed_sequence_exposes_no_intermediate_state :
  allocate_then_fail smoke_initial = Error InvalidMemoryAccess.
Proof. reflexivity. Qed.

Example scalar_add_is_selected {Scalar} `{ScalarOps Scalar}
    (left right : Scalar) :
  eval_scalar_operation ScalarAdd left right =
    Ok (scalar_add left right).
Proof. reflexivity. Qed.

Example scalar_operation_preserves_state {Scalar State} `{ScalarOps Scalar}
    (left right : Scalar) (state : State) :
  exec_scalar_operation ScalarAdd left right state =
    Ok (scalar_add left right, state).
Proof. reflexivity. Qed.

Example elemwise_binary_add_executes :
  sem_linalg_elemwise_binary LinalgAdd
    LinalgCastSigned
    (ElementwiseTensor
      {| tensor_shape := [2%nat]; tensor_element_type := DF32;
         tensor_elements := [1%Z; 2%Z] |})
    (ElementwiseTensor
      {| tensor_shape := [2%nat]; tensor_element_type := DF32;
         tensor_elements := [10%Z; 20%Z] |})
    [2%nat] DF32 =
  Ok {| tensor_shape := [2%nat]; tensor_element_type := DF32;
        tensor_elements := [11%Z; 22%Z] |}.
Proof. reflexivity. Qed.

Example row_reduction_add_executes :
  sem_linalg_reduce
    (fun inputs accumulators =>
      match inputs, accumulators with
      | [value], [accumulator] => Ok [Z.add value accumulator]
      | _, _ => Error InvalidShape
      end)
    [1%nat]
    [{| tensor_shape := [2%nat; 3%nat]; tensor_element_type := DF32;
        tensor_elements := [1%Z; 2%Z; 3%Z; 4%Z; 5%Z; 6%Z] |}]
    [{| tensor_shape := [2%nat]; tensor_element_type := DF32;
        tensor_elements := [10%Z; 20%Z] |}] =
  Ok [{| tensor_shape := [2%nat]; tensor_element_type := DF32;
         tensor_elements := [16%Z; 35%Z] |}].
Proof. reflexivity. Qed.

Example multi_axis_multi_result_reduction_executes :
  sem_linalg_reduce
    (fun inputs accumulators =>
      match inputs, accumulators with
      | [value], [sum; maximum] => Ok [Z.add value sum; Z.max value maximum]
      | _, _ => Error InvalidShape
      end)
    [0%nat; 2%nat]
    [{| tensor_shape := [2%nat; 2%nat; 2%nat];
        tensor_element_type := DF32;
        tensor_elements := [1%Z; 2%Z; 3%Z; 4%Z; 5%Z; 6%Z; 7%Z; 8%Z] |}]
    [{| tensor_shape := [2%nat]; tensor_element_type := DF32;
        tensor_elements := [0%Z; 0%Z] |};
     {| tensor_shape := [2%nat]; tensor_element_type := DF32;
        tensor_elements := [0%Z; 0%Z] |}] =
  Ok [{| tensor_shape := [2%nat]; tensor_element_type := DF32;
         tensor_elements := [14%Z; 22%Z] |};
      {| tensor_shape := [2%nat]; tensor_element_type := DF32;
         tensor_elements := [6%Z; 8%Z] |}].
Proof. reflexivity. Qed.

Example malformed_elemwise_tensor_is_rejected :
  sem_linalg_elemwise_binary LinalgAdd LinalgCastSigned
    (ElementwiseTensor
      {| tensor_shape := [2%nat]; tensor_element_type := DF32;
         tensor_elements := [1%Z] |})
    (ElementwiseScalar DF32 10%Z) [2%nat] DF32 = Error InvalidShape.
Proof. reflexivity. Qed.

Example complete_binary_fn_cases_are_executable :
  eval_linalg_binary LinalgDivUnsigned 8%Z 2%Z = Ok 4%Z /\
  eval_linalg_binary LinalgMaxSigned (-1)%Z 2%Z = Ok 2%Z /\
  eval_linalg_binary LinalgMinSigned (-1)%Z 2%Z = Ok (-1)%Z /\
  eval_linalg_binary LinalgMaxUnsigned 1%Z 2%Z = Ok 2%Z /\
  eval_linalg_binary LinalgMinUnsigned 1%Z 2%Z = Ok 1%Z /\
  eval_linalg_binary LinalgPowF 2%Z 3%Z = Ok 8%Z.
Proof. repeat split; reflexivity. Qed.

Example hfusion_cast_executes :
  sem_hfusion_cast CastSigned HFusionRint true false SI2SI DF16
    {| tensor_shape := [2%nat]; tensor_element_type := DF32;
       tensor_elements := [1%Z; 2%Z] |} =
  Ok {| tensor_shape := [2%nat]; tensor_element_type := DF16;
        tensor_elements := [1%Z; 2%Z] |}.
Proof. reflexivity. Qed.

Definition view_example : result memory_error (tensor Z) :=
  let '(allocation, memory) :=
    allocate_buffer ASGM (DInt 64 Signed)
      [0%Z; 1%Z; 2%Z; 3%Z; 4%Z; 5%Z] empty_memory in
  let descriptor :=
    {| descriptor_allocation := allocation;
       descriptor_offset := 1%Z;
       descriptor_sizes := [2%nat; 2%nat];
       descriptor_strides := [3%Z; 1%Z] |} in
  let '(view, memory') := insert_descriptor descriptor memory in
  read_view memory' view.

Example view_materializes_independent_tensor :
  view_example =
    Ok {| tensor_shape := [2%nat; 2%nat];
          tensor_element_type := DInt 64 Signed;
          tensor_elements := [1%Z; 2%Z; 4%Z; 5%Z] |}.
Proof. reflexivity. Qed.

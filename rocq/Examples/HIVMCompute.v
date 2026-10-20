From Stdlib Require Import List ZArith QArith Bool.
From UnifiedInterpreter.Base Require Import Result Free Lens StateM.
From UnifiedInterpreter.Type Require Import MLIR HFusion.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Value Require Import Scalar.
From UnifiedInterpreter.Memory Require Import Model Effects Handler.
From UnifiedInterpreter.Unified Require Import State Errors Events.
From UnifiedInterpreter.HFusion Require Import Instr Syntax Runtime.
From UnifiedInterpreter.HFusion.Semantics Require Import Memory.
From UnifiedInterpreter.HIVM Require Import Instr Numeric Value Semantics Arith Execution.

Import ListNotations.
Open Scope Z_scope.

(* This is a finite-integer STRUCTURAL test backend, not f16/f32 arithmetic.
   exp and ln deliberately return distinguishable sentinels. The finite max
   seed is suitable only for these examples, not a production Numeric model. *)
Definition test_numeric : Numeric Z :=
  {| number_literal := fun ty lit =>
       if f32 ty then match lit with
         | FiniteFloat q => if Pos.eqb (Qden q) 1 then Ok (Qnum q)
                            else Error ScalarDomainError
         | NegativeInfinity => Ok (-1000000)
         | _ => Error ScalarDomainError end
       else Error ScalarUnsupportedCast;
     number_zero := fun _ => 0;
     number_binary := fun op ty a b =>
       if f32 ty then match op with
         | VAdd => Ok (a+b) | VSub => Ok (a-b) | VMul => Ok (a*b)
         | VDiv => if Z.eqb b 0 then Error ScalarDivisionByZero
                   else Ok (Z.quot a b) end
       else Error ScalarDomainError;
     number_unary := fun op ty x => if f32 ty
       then Ok (x + match op with VExp => 1000 | VLn => 2000 end)
       else Error ScalarDomainError;
     number_reduce_seed := fun op _ => match op with
       | ReduceSum => 0 | ReduceMax => -1000000 end;
     number_reduce := fun op ty a b => if f32 ty then
       Ok (match op with ReduceSum => a+b | ReduceMax => Z.max a b end)
       else Error ScalarDomainError;
     number_cast := fun spec src dst x =>
       if cast_rint spec && cast_signed spec && f32 src && f16 dst
       then Ok (x+3000) else Error ScalarUnsupportedCast;
     number_mac := fun src dst a b acc =>
       if f16 src && f32 dst then Ok (acc+a*b) else Error ScalarDomainError |}.

#[local] Existing Instance test_numeric.

Definition v (sh : list nat) (ty : mlir_type) (xs : list Z) : value Z :=
  match make_value sh ty xs with Ok x => x | Error _ => EmptyTensor sh ty end.
Definition out (sh : list nat) : value Z := EmptyTensor sh Float32Type.
Definition observe (r : result runtime_error (value Z)) :=
  result_bind r (@elements Z).
Definition x2 := v [2%nat] Float32Type [2;4].
Definition matrix := v [2%nat;3%nat] Float32Type [1;2;3;4;5;6].

Example add_tensor : observe (sem_binary VAdd (TensorOperand x2)
  (TensorOperand x2) (out [2%nat])) = Ok [4;8].
Proof. reflexivity. Qed.
Example add_scalar_left : observe (sem_binary VAdd (ScalarOperand Float32Type 3)
  (TensorOperand x2) (out [2%nat])) = Ok [5;7].
Proof. reflexivity. Qed.
Example sub_scalar_right : observe (sem_binary VSub (TensorOperand x2)
  (ScalarOperand Float32Type 1) (out [2%nat])) = Ok [1;3].
Proof. reflexivity. Qed.
Example multiply_scalar : observe (sem_binary VMul (TensorOperand x2)
  (ScalarOperand Float32Type 3) (out [2%nat])) = Ok [6;12].
Proof. reflexivity. Qed.
Example divide_tensor : observe (sem_binary VDiv (TensorOperand x2)
  (ScalarOperand Float32Type 2) (out [2%nat])) = Ok [1;2].
Proof. reflexivity. Qed.
Example numeric_error_propagates : observe (sem_binary VDiv (TensorOperand x2)
  (ScalarOperand Float32Type 0) (out [2%nat])) = Error NumericFailure.
Proof. reflexivity. Qed.
Example exp_backend_forwarded : observe (sem_unary VExp x2 (out [2%nat])) =
  Ok [1002;1004].
Proof. reflexivity. Qed.
Example ln_backend_forwarded : observe (sem_unary VLn x2 (out [2%nat])) =
  Ok [2002;2004].
Proof. reflexivity. Qed.
Example cast_defaults_forwarded : observe (sem_cast default_cast x2
  (EmptyTensor [2%nat] Float16Type)) = Ok [3002;3004].
Proof. reflexivity. Qed.
Example unsupported_cast_mode : sem_cast
  {| cast_rint := false; cast_signed := true |} x2
  (EmptyTensor [2%nat] Float16Type) = Error UnsupportedInstruction.
Proof. reflexivity. Qed.
Example unsupported_cast_type : sem_cast default_cast x2 (out [2%nat]) =
  Error UnsupportedInstruction.
Proof. reflexivity. Qed.
Example scalar_broadcast : observe (sem_broadcast (ScalarOperand Float32Type 7)
  (out [2%nat;2%nat]) []) = Ok [7;7;7;7].
Proof. reflexivity. Qed.
Example column_broadcast : observe (sem_broadcast
  (TensorOperand (v [2%nat;1%nat] Float32Type [7;9]))
  (out [2%nat;3%nat]) [1%nat]) = Ok [7;7;7;9;9;9].
Proof. reflexivity. Qed.
Example wrong_broadcast_dimension : sem_broadcast
  (TensorOperand (v [2%nat;1%nat] Float32Type [7;9]))
  (out [2%nat;3%nat]) [0%nat] = Error InvalidShape.
Proof. reflexivity. Qed.
Example sum_keepdims : observe (sem_reduce ReduceSum matrix
  (out [2%nat;1%nat]) [1%nat]) = Ok [6;15].
Proof. reflexivity. Qed.
Example max_keepdims : observe (sem_reduce ReduceMax matrix
  (out [2%nat;1%nat]) [1%nat]) = Ok [3;6].
Proof. reflexivity. Qed.
Example reduce_does_not_read_destination : observe (sem_reduce ReduceSum matrix
  (v [2%nat;1%nat] Float32Type [100;200]) [1%nat]) = Ok [6;15].
Proof. reflexivity. Qed.
Example reduce_wrong_shape : sem_reduce ReduceSum matrix
  (out [2%nat]) [1%nat] = Error UnsupportedInstruction.
Proof. reflexivity. Qed.
Example reduce_wrong_axes : sem_reduce ReduceSum matrix
  (out [2%nat;1%nat]) [0%nat;1%nat] = Error InvalidShape.
Proof. reflexivity. Qed.

Definition mm (trans init : bool) :=
  {| mm_b_transpose := trans; mm_init := init;
     mm_real_m := 0; mm_real_k := 0; mm_real_n := 0 |}.
Definition a := v [2%nat;3%nat] Float16Type [1;2;3;4;5;6].
Definition b := v [3%nat;2%nat] Float16Type [7;8;9;10;11;12].
Definition bt := v [2%nat;3%nat] Float16Type [7;9;11;8;10;12].
Definition mm_result := sem_mmad (mm false true) a b (out [2%nat;2%nat]).
Example matmul_clear : observe mm_result = Ok [58;64;139;154].
Proof. reflexivity. Qed.
Example matmul_transpose : observe (sem_mmad (mm true true) a bt
  (out [2%nat;2%nat])) = Ok [58;64;139;154].
Proof. reflexivity. Qed.
Example matmul_accumulate : observe (sem_mmad (mm false false) a b
  (v [2%nat;2%nat] Float32Type [1;2;3;4])) = Ok [59;66;142;158].
Proof. reflexivity. Qed.
Example matmul_clear_ignores_old_values : observe (sem_mmad (mm false true) a b
  (v [2%nat;2%nat] Float32Type [100;200;300;400])) = Ok [58;64;139;154].
Proof. reflexivity. Qed.
Example matmul_uninitialized_accumulator : sem_mmad (mm false false) a b
  (out [2%nat;2%nat]) = Error ReadUninitialized.
Proof. reflexivity. Qed.
Example matmul_bad_shape : sem_mmad (mm false true) a bt
  (out [2%nat;2%nat]) = Error InvalidShape.
Proof. reflexivity. Qed.
Example matmul_nonstub_sizes : sem_mmad
  {| mm_b_transpose := false; mm_init := true;
     mm_real_m := 2; mm_real_k := 3; mm_real_n := 2 |}
  a b (out [2%nat;2%nat]) = Error UnsupportedInstruction.
Proof. reflexivity. Qed.

Example expand_shape : observe (sem_reshape true x2 [2%nat;1%nat]
  [[0%nat;1%nat]]) = Ok [2;4].
Proof. reflexivity. Qed.
Example collapse_shape : observe (sem_reshape false matrix [6%nat]
  [[0%nat;1%nat]]) = Ok [1;2;3;4;5;6].
Proof. reflexivity. Qed.
Example reshape_empty_stays_uninitialized :
  sem_reshape true (out [2%nat]) [2%nat;1%nat] [[0%nat;1%nat]] =
    Ok (out [2%nat;1%nat]).
Proof. reflexivity. Qed.
Example reshape_wrong_reassociation : sem_reshape false matrix [6%nat]
  [[1%nat;0%nat]] = Error InvalidShape.
Proof. reflexivity. Qed.
Example reshape_wrong_count : sem_reshape false matrix [5%nat]
  [[0%nat;1%nat]] = Error InvalidShape.
Proof. reflexivity. Qed.
Example binary_wrong_shape : sem_binary VAdd (TensorOperand x2)
  (TensorOperand matrix) (out [2%nat]) = Error InvalidShape.
Proof. reflexivity. Qed.
Example binary_uninitialized_read : sem_binary VAdd
  (TensorOperand (out [2%nat])) (TensorOperand x2) (out [2%nat]) =
  Error ReadUninitialized.
Proof. reflexivity. Qed.
Example wrong_element_type : sem_binary VAdd
  (ScalarOperand Float16Type 1) (TensorOperand x2) (out [2%nat]) =
  Error StaticProgramError.
Proof. reflexivity. Qed.

Definition i32 := IntegerType 32 Signless.
Definition i64 := IntegerType 64 Signless.
Example true_constant : sem_integer_constant (IntegerType 1 Signless) 1 = Ok 1.
Proof. reflexivity. Qed.
Example false_constant : sem_integer_constant (IntegerType 1 Signless) 0 = Ok 0.
Proof. reflexivity. Qed.
Example addi_wraps : sem_integer_binary ArithAddI i32 2147483647 1 = Ok (-2147483648).
Proof. reflexivity. Qed.
Example muli_wraps : sem_integer_binary ArithMulI i32 1073741824 4 = Ok 0.
Proof. reflexivity. Qed.
Example signed_division : sem_integer_binary ArithDivSI i32 (-7) 3 = Ok (-2).
Proof. reflexivity. Qed.
Example signed_remainder : sem_integer_binary ArithRemSI i32 (-7) 3 = Ok (-1).
Proof. reflexivity. Qed.
Example integer_divide_zero : sem_integer_binary ArithDivSI i32 7 0 = Error NumericFailure.
Proof. reflexivity. Qed.
Example integer_divide_overflow : sem_integer_binary ArithDivSI i32 (-2147483648) (-1) = Error NumericFailure.
Proof. reflexivity. Qed.
Example remainder_minimum_minus_one : sem_integer_binary ArithRemSI i32 (-2147483648) (-1) = Ok 0.
Proof. reflexivity. Qed.
Example remainder_zero : sem_integer_binary ArithRemSI i32 7 0 = Error NumericFailure.
Proof. reflexivity. Qed.
Example sign_extension : sem_integer_cast ArithExtSI i32 i64 4294967295 = Ok (-1).
Proof. reflexivity. Qed.
Example index_cast : sem_integer_cast ArithIndexCast i64 IndexType (-1) = Ok (-1).
Proof. reflexivity. Qed.
Example index_cast_i32 : sem_integer_cast ArithIndexCast i32 IndexType 32 = Ok 32.
Proof. reflexivity. Qed.
Example float_negative_infinity : sem_float_constant Float32Type NegativeInfinity = Ok (-1000000).
Proof. reflexivity. Qed.
Example float_zero : sem_float_constant Float32Type (FiniteFloat 0) = Ok 0.
Proof. reflexivity. Qed.
Example float_minus_one : sem_float_constant Float32Type (FiniteFloat (-1)) = Ok (-1).
Proof. reflexivity. Qed.
Example empty_not_zero : @sem_empty Z [2%nat;3%nat] Float32Type =
  Ok (EmptyTensor [2%nat;3%nat] Float32Type).
Proof. reflexivity. Qed.
Example empty_bad_type : @sem_empty Z [2%nat] Float64Type = Error UnsupportedInstruction.
Proof. reflexivity. Qed.
Example dispatcher_calls_binary : observe (evaluate
  (BinaryRequest VAdd (TensorOperand x2) (TensorOperand x2) (out [2%nat]))) =
  Ok [4;8].
Proof. reflexivity. Qed.

Definition check_values (expected : list Z) (r : result runtime_error (value Z)) : bool :=
  match observe r with
  | Ok xs => forallb (fun pair => Z.eqb (fst pair) (snd pair)) (combine expected xs)
      && Nat.eqb (length expected) (length xs)
  | Error _ => false end.

Definition extracted_checks : list bool :=
  [check_values [58;64;139;154] mm_result;
   check_values [6;15] (sem_reduce ReduceSum matrix (out [2%nat;1%nat]) [1%nat]);
   check_values [3002;3004] (sem_cast default_cast x2 (EmptyTensor [2%nat] Float16Type));
   check_values [1002;1004] (sem_unary VExp x2 (out [2%nat]));
   check_values [2002;2004] (sem_unary VLn x2 (out [2%nat]))].

Example extracted_checks_pass : forallb (fun b => b) extracted_checks = true.
Proof. reflexivity. Qed.

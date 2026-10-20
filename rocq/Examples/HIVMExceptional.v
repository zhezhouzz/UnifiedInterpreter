From Stdlib Require Import List ZArith.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.Value Require Import Scalar.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.HIVM Require Import Instr Numeric Value Semantics.

Import ListNotations.

(* A reduction-only test model. Unlike the finite structural mock, it has
   explicit NaN and negative infinity. Unsupported arithmetic is an error. *)
Inductive sample := Finite (n : Z) | MinusInfinity | NaN.

Definition propagate_max (a b : sample) : sample :=
  match a,b with
  | NaN,_ | _,NaN => NaN
  | MinusInfinity,x | x,MinusInfinity => x
  | Finite x,Finite y => Finite (Z.max x y)
  end.

Definition exceptional_numeric : Numeric sample :=
  {| number_literal := fun _ _ => Error ScalarDomainError;
     number_zero := fun _ => Finite 0;
     number_binary := fun _ _ _ _ => Error ScalarDomainError;
     number_unary := fun _ _ _ => Error ScalarDomainError;
     number_reduce_seed := fun op _ =>
       match op with ReduceSum => Finite 0 | ReduceMax => MinusInfinity end;
     number_reduce := fun op ty a b =>
       match op with
       | ReduceMax => if f32 ty then Ok (propagate_max a b)
                      else Error ScalarDomainError
       | ReduceSum => Error ScalarDomainError end;
     number_cast := fun _ _ _ _ => Error ScalarUnsupportedCast;
     number_mac := fun _ _ _ _ _ => Error ScalarDomainError |}.
#[local] Existing Instance exceptional_numeric.

Definition exceptional_reduce (a b : sample) :=
  let t := @Build_tensor sample [1%nat;2%nat] Float32Type [a;b] eq_refl in
  result_bind (sem_reduce ReduceMax (DefinedTensor (PackTensor _ _ t))
    (EmptyTensor [1%nat;1%nat] Float32Type) [1%nat]) (@elements sample).

Example nan_on_left : exceptional_reduce NaN (Finite 1) = Ok [NaN].
Proof. reflexivity. Qed.
Example nan_on_right : exceptional_reduce (Finite 1) NaN = Ok [NaN].
Proof. reflexivity. Qed.
Example actual_negative_infinity_seed :
  exceptional_reduce (Finite (-2000000)) (Finite (-3000000)) =
    Ok [Finite (-2000000)].
Proof. reflexivity. Qed.

Definition exceptional_checks : list bool :=
  map (fun r => match r with Ok [NaN] => true | _ => false end)
    [exceptional_reduce NaN (Finite 1); exceptional_reduce (Finite 1) NaN].
Example exceptional_checks_pass : forallb (fun x => x) exceptional_checks = true.
Proof. reflexivity. Qed.

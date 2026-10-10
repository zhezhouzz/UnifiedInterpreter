From Stdlib Require Import ZArith QArith.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Value Require Import DType.

Open Scope Z_scope.
Set Implicit Arguments.

Inductive scalar_error :=
| ScalarDivisionByZero
| ScalarDomainError
| ScalarUnsupportedCast.

(* This class contains only executable operations. Algebraic laws belong in
   ScalarLaws below and therefore disappear during extraction. *)
Class ScalarOps (Scalar : Type) := {
  scalar_zero : Scalar;
  scalar_one : Scalar;
  scalar_of_Z : Z -> Scalar;
  scalar_add : Scalar -> Scalar -> Scalar;
  scalar_sub : Scalar -> Scalar -> Scalar;
  scalar_mul : Scalar -> Scalar -> Scalar;
  scalar_div : Scalar -> Scalar -> result scalar_error Scalar;
  scalar_max : Scalar -> Scalar -> Scalar;
  scalar_exp : Scalar -> result scalar_error Scalar;
  scalar_log : Scalar -> result scalar_error Scalar;
  scalar_cast : cast_spec -> Scalar -> result scalar_error Scalar
}.

(* The binary scalar operations that an IR instruction may request.  Keeping
   this set explicit prevents the interpreter from accepting arbitrary Rocq
   functions as source-language operations.  Unary operations and casts have
   different arities and will use their own operation types. *)
Inductive scalar_operation :=
| ScalarAdd
| ScalarSub
| ScalarMul
| ScalarDiv
| ScalarMax.

Definition eval_scalar_operation {Scalar} `{ScalarOps Scalar}
    (operation : scalar_operation) (left right : Scalar)
    : result scalar_error Scalar :=
  match operation with
  | ScalarAdd => Ok (scalar_add left right)
  | ScalarSub => Ok (scalar_sub left right)
  | ScalarMul => Ok (scalar_mul left right)
  | ScalarDiv => scalar_div left right
  | ScalarMax => Ok (scalar_max left right)
  end.

Class ScalarLaws (Scalar : Type) `{ScalarOps Scalar} : Prop := {
  scalar_add_zero_l : forall x, scalar_add scalar_zero x = x;
  scalar_add_zero_r : forall x, scalar_add x scalar_zero = x;
  scalar_mul_one_l : forall x, scalar_mul scalar_one x = x;
  scalar_mul_one_r : forall x, scalar_mul x scalar_one = x
}.

(* Exact algebraic semantics can instantiate this interface with Q. Exact
   transcendental functions remain a separate backend decision. *)
Definition exact_rational := Q.

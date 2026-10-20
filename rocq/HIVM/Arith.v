From Stdlib Require Import ZArith Bool.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.HFusion Require Import Instr Syntax.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.HFusion.Semantics Require Import Common.
From UnifiedInterpreter.HIVM Require Import Numeric.

Open Scope Z_scope.
Set Implicit Arguments.

(* Index is explicitly 64-bit in this reference profile. Values exposed by this
   API are signed canonical integers, except i1's boolean values 0 and 1. *)
Definition integer_width (ty : mlir_type) : option nat :=
  match ty with
  | IndexType => Some 64%nat
  | IntegerType width Signless =>
      if Nat.eqb width 1 || Nat.eqb width 32 || Nat.eqb width 64
      then Some width else None
  | _ => None
  end.

Definition canonical_integer (width : nat) (x : Z) : Z :=
  let modulus := 2 ^ Z.of_nat width in
  let bits := x mod modulus in
  if Nat.eqb width 1 then bits
  else if bits <? modulus / 2 then bits else bits - modulus.

Definition sem_integer_constant (ty : mlir_type) (x : Z)
    : result runtime_error Z :=
  match integer_width ty with
  | Some width => Ok (canonical_integer width x)
  | None => Error UnsupportedInstruction
  end.

Definition sem_integer_binary (op : arith_binary_operator) (ty : mlir_type)
    (x y : Z) : result runtime_error Z :=
  match integer_width ty with
  | None => Error UnsupportedInstruction
  | Some width =>
      let a := canonical_integer width x in
      let b := canonical_integer width y in
      match op with
      | ArithAddI => Ok (canonical_integer width (a+b))
      | ArithMulI => Ok (canonical_integer width (a*b))
      | ArithDivSI | ArithRemSI =>
          if Nat.eqb width 1 then Error UnsupportedInstruction
          else if Z.eqb b 0 ||
            (match op with ArithDivSI =>
              Z.eqb a (- (2 ^ (Z.of_nat width - 1))) && Z.eqb b (-1)
             | _ => false end)
          then Error NumericFailure
          else Ok (match op with
                   | ArithDivSI => Z.quot a b
                   | _ => Z.rem a b end)
      | _ => Error UnsupportedInstruction
      end
  end.

Definition sem_integer_cast (op : arith_cast_operator)
    (source target : mlir_type) (x : Z) : result runtime_error Z :=
  match integer_width source, integer_width target with
  | Some from, Some dest =>
      let legal := match op, source, target with
        | ArithExtSI, IntegerType 32 Signless, IntegerType 64 Signless => true
        | ArithIndexCast, IntegerType 32 Signless, IndexType => true
        | ArithIndexCast, IntegerType 64 Signless, IndexType => true
        | _,_,_ => false end in
      if legal then Ok (canonical_integer dest (canonical_integer from x))
      else Error UnsupportedInstruction
  | _,_ => Error UnsupportedInstruction
  end.

Definition sem_float_constant {S} `{Numeric S} (ty : mlir_type)
    (literal : float_literal) : result runtime_error S :=
  if mlir_element_type_eqb ty Float32Type
  then scalar_failure (number_literal ty literal)
  else Error UnsupportedInstruction.

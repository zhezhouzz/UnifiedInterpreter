From Stdlib Require Import List Bool.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.Tensor Require Import Model Matrix.
From UnifiedInterpreter.Value Require Import Scalar.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.HFusion.Semantics Require Import Common.
From UnifiedInterpreter.HIVM Require Import Value.
Import ListNotations.
Set Implicit Arguments.

(* Shared runtime value packaging does not identify HFusion and HIVM ops.
   These are the structured HFusion operations needed by the archived input. *)
Definition sem_linalg_fill {S} (ty : mlir_type) (x : S) (dst : value S)
    : result runtime_error (value S) :=
  if mlir_element_type_eqb ty (element_type dst) then
    make_value (shape dst) ty (repeat x (num_elements (shape dst)))
  else Error StaticProgramError.

Definition sem_linalg_transpose {S} (src dst : value S) (permutation : list nat)
    : result runtime_error (value S) :=
  match shape src, shape dst with
  | [m;n], [n';m'] =>
      if shape_eq permutation [1;0] && Nat.eqb n n' && Nat.eqb m m' &&
         mlir_element_type_eqb (element_type src) (element_type dst) then
        xs <-? elements src ;;
        make_value (shape dst) (element_type dst)
          (concat (matrix_columns n (matrix_rows m n xs)))
      else Error InvalidShape
  | _,_ => Error UnsupportedInstruction
  end.

Definition sem_linalg_broadcast {S} (src dst : value S) (dimensions : list nat)
    : result runtime_error (value S) :=
  match shape src, shape dst with
  | [m], [m';n] =>
      if shape_eq dimensions [1] && Nat.eqb m m' &&
         mlir_element_type_eqb (element_type src) (element_type dst) then
        xs <-? elements src ;;
        make_value (shape dst) (element_type dst)
          (flat_map (fun x => repeat x n) xs)
      else Error InvalidShape
  | _,_ => Error UnsupportedInstruction
  end.

Definition sem_linalg_unary {S} `{ScalarOps S} (is_exp : bool)
    (src dst : value S) : result runtime_error (value S) :=
  if shape_eq (shape src) (shape dst) && f32 (element_type src) &&
     f32 (element_type dst) then
    xs <-? elements src ;;
    ys <-? map_scalar_result (if is_exp then scalar_exp else scalar_log) xs ;;
    make_value (shape dst) (element_type dst) ys
  else Error InvalidShape.

Definition sem_linalg_matmul {S} `{ScalarOps S} (a b dst : value S)
    : result runtime_error (value S) :=
  match shape a,shape b,shape dst with
  | [m;k],[k';n],[m';n'] =>
      if Nat.eqb k k' && Nat.eqb m m' && Nat.eqb n n' &&
         f16 (element_type a) && f16 (element_type b) &&
         f32 (element_type dst) then
        av <-? elements a ;;
        bv <-? elements b ;;
        init <-? elements dst ;;
        xs <-? matrix_product
          (fun x y acc => Ok (scalar_add acc (scalar_mul x y)))
          (matrix_rows m k av) (matrix_columns n (matrix_rows k n bv))
          (matrix_rows m n init) ;;
        make_value (shape dst) (element_type dst) xs
      else Error InvalidShape
  | _,_,_ => Error UnsupportedInstruction
  end.

From Stdlib Require Import List.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.Tensor Require Import Model Matrix.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.HFusion.Semantics Require Import Structured Common.
From UnifiedInterpreter.HIVM Require Import Value Semantics Numeric.
Import ListNotations.
Set Implicit Arguments.

Example optimized_matrix_matches_indexed {S} {N : Numeric S}
    (a b c d e f g h i j k l p q r s : S) :
  matrix_product
    (fun x y acc => scalar_failure (number_mac Float16Type Float32Type x y acc))
    (matrix_rows 2 3 [a;b;c;d;e;f])
    (matrix_columns 2 (matrix_rows 3 2 [g;h;i;j;k;l]))
    (matrix_rows 2 2 [p;q;r;s]) =
  matmul_cells (tensor_indices [2;2]) 3 2 false
    [a;b;c;d;e;f] [g;h;i;j;k;l] [p;q;r;s].
Proof.
  cbn.
  repeat match goal with
  | |- context [number_mac ?t ?u ?x ?y ?acc] =>
      destruct (number_mac t u x y acc); cbn; try reflexivity
  end.
Qed.

Example structured_transpose_rectangular {S} (a b c d e f : S) :
  result_bind (src <-? make_value [2;3] Float16Type [a;b;c;d;e;f] ;;
    sem_linalg_transpose src (EmptyTensor [3;2] Float16Type) [1;0]) (@elements S) =
  Ok [a;d;b;e;c;f].
Proof. reflexivity. Qed.

Example structured_broadcast_rows {S} (a b : S) :
  result_bind (src <-? make_value [2] Float32Type [a;b] ;;
    sem_linalg_broadcast src (EmptyTensor [2;3] Float32Type) [1]) (@elements S) =
  Ok [a;a;a;b;b;b].
Proof. reflexivity. Qed.

Example structured_fill_empty {S} (x : S) :
  result_bind (sem_linalg_fill Float32Type x
    (EmptyTensor [2;2] Float32Type)) (@elements S) = Ok [x;x;x;x].
Proof. reflexivity. Qed.

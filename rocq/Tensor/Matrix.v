From Stdlib Require Import List.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Unified Require Import Errors.
Import ListNotations.
Set Implicit Arguments.

(* Split once, then traverse rows/columns sequentially inside each dot product.
   Arithmetic remains parameterized; no host matrix implementation is used. *)
Fixpoint matrix_rows {S} (count width : nat) (xs : list S) : list (list S) :=
  match count with
  | O => []
  | S n => firstn width xs :: matrix_rows n width (skipn width xs)
  end.

Definition matrix_columns {S} (width : nat) (rows : list (list S))
    : list (list S) :=
  map (fun j => flat_map (fun row =>
    match nth_error row j with Some x => [x] | None => [] end) rows)
    (seq 0 width).

Fixpoint matrix_dot {S} (mac : S -> S -> S -> result runtime_error S)
    (a b : list S) (acc : S) : result runtime_error S :=
  match a,b with
  | [],[] => Ok acc
  | x::xs,y::ys =>
      next <-? mac x y acc ;;
      matrix_dot mac xs ys next
  | _,_ => Error InvalidShape
  end.

Fixpoint matrix_row {S} (mac : S -> S -> S -> result runtime_error S)
    (a : list S) (columns : list (list S)) (init : list S)
    : result runtime_error (list S) :=
  match columns,init with
  | [],[] => Ok []
  | col::cols,x::xs =>
      y <-? matrix_dot mac a col x ;;
      ys <-? matrix_row mac a cols xs ;;
      Ok (y::ys)
  | _,_ => Error InvalidShape
  end.

Fixpoint matrix_product {S} (mac : S -> S -> S -> result runtime_error S)
    (rows columns : list (list S)) (init : list (list S))
    : result runtime_error (list S) :=
  match rows,init with
  | [],[] => Ok []
  | row::rest,acc::accs =>
      ys <-? matrix_row mac row columns acc ;;
      zs <-? matrix_product mac rest columns accs ;;
      Ok (ys ++ zs)
  | _,_ => Error InvalidShape
  end.

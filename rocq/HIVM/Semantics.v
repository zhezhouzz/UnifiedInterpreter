From Stdlib Require Import List Bool ZArith.
From UnifiedInterpreter.Base Require Import Result.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Tensor Require Import Matrix.
From UnifiedInterpreter.Unified Require Import Errors.
From UnifiedInterpreter.HFusion.Semantics Require Import Common.
From UnifiedInterpreter.HIVM Require Import Instr Numeric Value.

Import ListNotations.
Set Implicit Arguments.

Definition sem_empty {S} (sh : list nat) (ty : mlir_type)
    : result runtime_error (value S) :=
  if supported_shape sh && (f16 ty || f32 ty)
  then Ok (EmptyTensor sh ty) else Error UnsupportedInstruction.

Definition expand_operand {S} (dst : value S) (arg : operand S)
    : result runtime_error (list S) :=
  match arg with
  | ScalarOperand ty x =>
      if mlir_element_type_eqb ty (element_type dst)
      then Ok (repeat x (num_elements (shape dst)))
      else Error StaticProgramError
  | TensorOperand v =>
      if shape_eq (shape v) (shape dst) &&
         mlir_element_type_eqb (element_type v) (element_type dst)
      then elements v else Error InvalidShape
  end.

Definition sem_binary {S} `{Numeric S} (op : binary_op)
    (left right : operand S) (dst : value S) : result runtime_error (value S) :=
  if f32 (element_type dst) && supported_shape (shape dst) then
    xs <-? expand_operand dst left ;;
    ys <-? expand_operand dst right ;;
    zs <-? map2_scalar_result (number_binary op (element_type dst)) xs ys ;;
    make_value (shape dst) (element_type dst) zs
  else Error UnsupportedInstruction.

Definition sem_unary {S} `{Numeric S} (op : unary_op)
    (input dst : value S) : result runtime_error (value S) :=
  if f32 (element_type dst) && supported_shape (shape dst) then
    xs <-? expand_operand dst (TensorOperand input) ;;
    ys <-? map_scalar_result (number_unary op (element_type dst)) xs ;;
    make_value (shape dst) (element_type dst) ys
  else Error UnsupportedInstruction.

Definition sem_broadcast {S} (input : operand S) (dst : value S)
    (dims : list nat) : result runtime_error (value S) :=
  if f32 (element_type dst) && supported_shape (shape dst) then
    match input with
    | ScalarOperand ty x =>
        if shape_eq dims [] && f32 ty
        then make_value (shape dst) ty (repeat x (num_elements (shape dst)))
        else Error UnsupportedInstruction
    | TensorOperand src =>
        match shape src, shape dst with
        | [m;one], [m';n] =>
            if shape_eq dims [1] && Nat.eqb m m' && Nat.eqb one 1 &&
               f32 (element_type src) then
              xs <-? elements src ;;
              make_value (shape dst) (element_type dst)
                (flat_map (fun x => repeat x n) xs)
            else Error InvalidShape
        | _,_ => Error UnsupportedInstruction
        end
    end
  else Error UnsupportedInstruction.

Fixpoint reduce_values {S} `{Numeric S} (op : reduce_op) (ty : mlir_type)
    (xs : list S) (acc : S) : result runtime_error S :=
  match xs with
  | [] => Ok acc
  | x::rest =>
      acc' <-? scalar_failure (number_reduce op ty acc x) ;;
      reduce_values op ty rest acc'
  end.

Fixpoint reduce_rows {S} `{Numeric S} (op : reduce_op) (ty : mlir_type)
    (rows width : nat) (xs : list S) : result runtime_error (list S) :=
  match rows with
  | O => Ok []
  | S rows' =>
      x <-? reduce_values op ty (firstn width xs) (number_reduce_seed op ty) ;;
      rest <-? reduce_rows op ty rows' width (skipn width xs) ;;
      Ok (x::rest)
  end.

(* HIVM reduction uses its operation's identity, not arbitrary old destination
   cells. The destination specifies the keep-dim result shape. *)
Definition sem_reduce {S} `{Numeric S} (op : reduce_op)
    (input dst : value S) (dims : list nat) : result runtime_error (value S) :=
  match shape input, shape dst with
  | [m;n], [m';one] =>
      if shape_eq dims [1] && Nat.eqb m m' && Nat.eqb one 1 &&
         supported_shape (shape input) && f32 (element_type input) &&
         f32 (element_type dst) then
        xs <-? elements input ;;
        ys <-? reduce_rows op Float32Type m n xs ;;
        make_value [m;1] Float32Type ys
      else Error InvalidShape
  | _,_ => Error UnsupportedInstruction
  end.

Definition sem_cast {S} `{Numeric S} (spec : cast_spec)
    (input dst : value S) : result runtime_error (value S) :=
  if cast_rint spec && cast_signed spec && f32 (element_type input) &&
     f16 (element_type dst) && supported_shape (shape input) then
    if shape_eq (shape input) (shape dst) then
      xs <-? elements input ;;
      ys <-? map_scalar_result
        (number_cast spec (element_type input) (element_type dst)) xs ;;
      make_value (shape dst) (element_type dst) ys
    else Error InvalidShape
  else Error UnsupportedInstruction.

Fixpoint dot_product {S} `{Numeric S} (count : nat) (a b : list S)
    (a_start a_step b_start b_step : nat) (acc : S)
    : result runtime_error S :=
  match count with
  | O => Ok acc
  | S count' =>
      match nth_error a a_start, nth_error b b_start with
      | Some x, Some y =>
          next <-? scalar_failure (number_mac Float16Type Float32Type x y acc) ;;
          dot_product count' a b (a_start+a_step) a_step
            (b_start+b_step) b_step next
      | _,_ => Error InvalidShape
      end
  end.

Fixpoint matmul_cells {S} `{Numeric S} (coordinates : list (list nat))
    (k n : nat) (transposed : bool) (a b : list S) (initial : list S)
    : result runtime_error (list S) :=
  match coordinates, initial with
  | [],[] => Ok []
  | [i;j]::coords, acc::rest =>
      c <-? dot_product k a b (i*k) 1
        (if transposed then j*k else j) (if transposed then 1 else n) acc ;;
      cs <-? matmul_cells coords k n transposed a b rest ;;
      Ok (c::cs)
  | _,_ => Error InvalidShape
  end.

Definition sem_mmad {S} `{Numeric S} (spec : mm_spec)
    (a b dst : value S) : result runtime_error (value S) :=
  (* These zero values are ConvertHFusionToHIVM's M/K/N stubs, not sizes. *)
  if Z.eqb (mm_real_m spec) 0 && Z.eqb (mm_real_k spec) 0 &&
     Z.eqb (mm_real_n spec) 0 then
    match shape a, shape b, shape dst with
    | [m;k], [b0;b1], [m';n] =>
        if Nat.eqb m m' &&
           (if mm_b_transpose spec
            then Nat.eqb b0 n && Nat.eqb b1 k
            else Nat.eqb b0 k && Nat.eqb b1 n) &&
           supported_shape (shape a) && supported_shape (shape b) &&
           supported_shape (shape dst) &&
           f16 (element_type a) && f16 (element_type b) && f32 (element_type dst)
        then
          av <-? elements a ;;
          bv <-? elements b ;;
          init <-? (if mm_init spec
                    then Ok (repeat (number_zero Float32Type) (m*n))
                    else elements dst) ;;
          let columns := if mm_b_transpose spec then matrix_rows n k bv
            else matrix_columns n (matrix_rows k n bv) in
          result <-? matrix_product
            (fun x y acc => scalar_failure
              (number_mac Float16Type Float32Type x y acc))
            (matrix_rows m k av) columns (matrix_rows m n init) ;;
          make_value [m;n] Float32Type result
        else Error InvalidShape
    | _,_,_ => Error UnsupportedInstruction
    end
  else Error UnsupportedInstruction.

(* Reassociation is an ordered partition of all axes of the expanded shape. *)
Definition valid_reassociation (expanded collapsed : list nat)
    (groups : list (list nat)) : bool :=
  Nat.eqb (length groups) (length collapsed) &&
  forallb (fun g => negb (Nat.eqb (length g) 0)) groups &&
  shape_eq (concat groups) (seq 0 (length expanded)) &&
  shape_eq (map (fun g => num_elements (map (fun i => nth i expanded 0) g)) groups)
    collapsed.

Definition sem_reshape {S} (expanding : bool) (input : value S)
    (target : list nat) (groups : list (list nat))
    : result runtime_error (value S) :=
  let expanded := if expanding then target else shape input in
  let collapsed := if expanding then shape input else target in
  if valid_reassociation expanded collapsed groups &&
     supported_shape target && supported_shape (shape input) &&
     (f16 (element_type input) || f32 (element_type input)) then
    match input with
    | EmptyTensor _ ty => Ok (EmptyTensor target ty)
    | DefinedTensor _ =>
        xs <-? elements input ;;
        make_value target (element_type input) xs
    end
  else Error InvalidShape.

Lemma reshape_preserves_elements {S} expanding (input : value S) target groups out xs :
  elements input = Ok xs -> sem_reshape expanding input target groups = Ok out ->
  elements out = Ok xs.
Proof.
  unfold sem_reshape. destruct (_ && _ && _ && _) eqn:valid; try discriminate.
  destruct input as [sh ty|t]; cbn; intros H Hout; try discriminate.
  rewrite H in Hout. cbn in Hout. eapply make_value_elements; eauto.
Qed.

Lemma binary_preserves_shape_type {S} `{Numeric S} op left right dst out :
  sem_binary op left right dst = Ok out ->
  shape out = shape dst /\ element_type out = element_type dst.
Proof.
  unfold sem_binary. destruct (_ && _); try discriminate.
  unfold result_bind.
  destruct (expand_operand dst left); try discriminate.
  destruct (expand_operand dst right); try discriminate.
  destruct (map2_scalar_result _ _ _); try discriminate.
  apply make_value_shape.
Qed.

Lemma unary_preserves_shape_type {S} `{Numeric S} op input dst out :
  sem_unary op input dst = Ok out ->
  shape out = shape dst /\ element_type out = element_type dst.
Proof.
  unfold sem_unary. destruct (_ && _); try discriminate.
  unfold result_bind.
  destruct (expand_operand dst (TensorOperand input)); try discriminate.
  destruct (map_scalar_result _ _); try discriminate.
  apply make_value_shape.
Qed.

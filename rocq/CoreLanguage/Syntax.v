From Stdlib Require Import List.
From stdpp Require Import gmap.

Import ListNotations.
Set Implicit Arguments.

Definition pipeline_id := nat.
Definition address := nat.
Definition var := nat.
Definition function_id := nat.
Definition primitive_id := nat.
Definition lock_id := nat.

Inductive exec_kind := Cube | Vector | Scalar | MTE.

#[global] Instance exec_kind_eq_dec : EqDecision exec_kind.
Proof. solve_decision. Defined.

Record event_key := {
  event_scope : nat;
  event_source : pipeline_id;
  event_target : pipeline_id;
  event_number : nat
}.

#[global] Instance event_key_eq_dec : EqDecision event_key.
Proof. solve_decision. Defined.

#[global] Instance event_key_countable : Countable event_key.
Proof.
  refine (inj_countable'
    (fun e => (event_scope e, event_source e, event_target e, event_number e))
    (fun '(s, p, q, n) =>
      {| event_scope := s; event_source := p;
         event_target := q; event_number := n |}) _).
  intros []; reflexivity.
Defined.

Inductive value (Numeric : Type) : Type :=
| VScalar (number : Numeric)
| VBool (boolean : bool)
| VAddress (location : address)
| VRegion (region : gset address)
| VMap (entries : gmap address (value Numeric))
| VVector (entries : list Numeric)
| VMatrix (rows : list (list Numeric))
| VUnit.

Arguments VScalar {Numeric} _.
Arguments VBool {Numeric} _.
Arguments VAddress {Numeric} _.
Arguments VRegion {Numeric} _.
Arguments VMap {Numeric} _.
Arguments VVector {Numeric} _.
Arguments VMatrix {Numeric} _.
Arguments VUnit {Numeric}.

Inductive value_type :=
| TyScalar | TyBool | TyAddress | TyRegion | TyMap
| TyVector (length : nat)
| TyMatrix (row_lengths : list nat)
| TyUnit.

#[global] Instance value_type_eq_dec : EqDecision value_type.
Proof. solve_decision. Defined.

Definition value_type_of {Numeric} (v : value Numeric) : value_type :=
  match v with
  | VScalar _ => TyScalar
  | VBool _ => TyBool
  | VAddress _ => TyAddress
  | VRegion _ => TyRegion
  | VMap _ => TyMap
  | VVector entries => TyVector (length entries)
  | VMatrix rows => TyMatrix (map (@length Numeric) rows)
  | VUnit => TyUnit
  end.

Inductive expr (Numeric : Type) : Type :=
| EValue (literal : value Numeric)
| EVar (name : var)
| EApply (primitive : primitive_id) (arguments : list (expr Numeric)).

Arguments EValue {Numeric} _.
Arguments EVar {Numeric} _.
Arguments EApply {Numeric} _ _.

Inductive op (Numeric : Type) : Type :=
| ORead (region : expr Numeric)
| OWrite (region contents : expr Numeric)
| OCompute (kind : exec_kind) (function : function_id)
    (arguments : list (expr Numeric)).

Arguments ORead {Numeric} _.
Arguments OWrite {Numeric} _ _.
Arguments OCompute {Numeric} _ _ _.

Inductive command (Numeric : Type) : Type :=
| CSkip
| CAssign (name : var) (expression : expr Numeric)
| COp (destination : var) (operation : op Numeric)
| CSetFlag (event : event_key)
| CWaitFlag (event : event_key)
| CLock (lock : lock_id)
| CUnlock (lock : lock_id)
| CSeq (first second : command Numeric)
| CIf (condition : expr Numeric) (yes no : command Numeric)
| CWhile (condition : expr Numeric) (body : command Numeric).

Arguments CSkip {Numeric}.
Arguments CAssign {Numeric} _ _.
Arguments COp {Numeric} _ _.
Arguments CSetFlag {Numeric} _.
Arguments CWaitFlag {Numeric} _.
Arguments CLock {Numeric} _.
Arguments CUnlock {Numeric} _.
Arguments CSeq {Numeric} _ _.
Arguments CIf {Numeric} _ _ _.
Arguments CWhile {Numeric} _ _.

Inductive eval_context (Numeric : Type) : Type :=
| Hole
| SeqContext (context : eval_context Numeric) (following : command Numeric).

Arguments Hole {Numeric}.
Arguments SeqContext {Numeric} _ _.

Fixpoint fill {Numeric} (context : eval_context Numeric)
    (current : command Numeric) : command Numeric :=
  match context with
  | Hole => current
  | SeqContext inner following => CSeq (fill inner current) following
  end.

Record model (Numeric : Type) := {
  pipeline_kind : pipeline_id -> exec_kind;
  primitive_eval : primitive_id -> list (value Numeric) -> option (value Numeric);
  compute_eval : function_id -> list (value Numeric) -> option (value Numeric);
  compute_signature : function_id -> option (list value_type * value_type);
  supports : pipeline_id -> function_id -> list value_type -> bool;
  can_read : pipeline_id -> address -> bool;
  can_write : pipeline_id -> address -> bool;
  type_ok : address -> value Numeric -> bool;
  declared_pipelines : gset pipeline_id;
  declared_events : gset event_key;
  scope_participants : nat -> gset pipeline_id;
  lock_participants : gmap lock_id (gset pipeline_id)
}.

Arguments pipeline_kind {Numeric} _ _.
Arguments primitive_eval {Numeric} _ _ _.
Arguments compute_eval {Numeric} _ _ _.
Arguments compute_signature {Numeric} _ _.
Arguments supports {Numeric} _ _ _ _.
Arguments can_read {Numeric} _ _ _.
Arguments can_write {Numeric} _ _ _.
Arguments type_ok {Numeric} _ _ _.
Arguments declared_pipelines {Numeric} _.
Arguments declared_events {Numeric} _.
Arguments scope_participants {Numeric} _ _.
Arguments lock_participants {Numeric} _.

Definition well_typed_computations {Numeric} (m : model Numeric) : Prop :=
  forall function arguments result,
    compute_eval m function arguments = Some result ->
    exists input_types output_type,
      compute_signature m function = Some (input_types, output_type) /\
      map value_type_of arguments = input_types /\
      value_type_of result = output_type.

Definition well_formed_model {Numeric} (m : model Numeric) : Prop :=
  (forall e, e ∈ declared_events m ->
    event_source e ∈ scope_participants m (event_scope e) /\
    event_target e ∈ scope_participants m (event_scope e)) /\
  (forall l participants, lock_participants m !! l = Some participants ->
    participants ⊆ declared_pipelines m) /\
  well_typed_computations m.

Definition may_set {Numeric} (m : model Numeric) (p : pipeline_id)
    (e : event_key) : Prop :=
  e ∈ declared_events m /\ p = event_source e.

Definition may_wait {Numeric} (m : model Numeric) (p : pipeline_id)
    (e : event_key) : Prop :=
  e ∈ declared_events m /\ p = event_target e.

Definition lock_member {Numeric} (m : model Numeric) (p : pipeline_id)
    (l : lock_id) : Prop :=
  exists participants,
    lock_participants m !! l = Some participants /\ p ∈ participants.

Section Expressions.
  Context {Numeric : Type} (m : model Numeric).

  Fixpoint eval_expr (locals : gmap var (value Numeric))
      (expression : expr Numeric) : option (value Numeric) :=
    match expression with
    | EValue literal => Some literal
    | EVar name => locals !! name
    | EApply primitive arguments =>
        let fix evaluate_arguments expressions :=
          match expressions with
          | [] => Some []
          | expression :: rest =>
              match eval_expr locals expression, evaluate_arguments rest with
              | Some result, Some results => Some (result :: results)
              | _, _ => None
              end
          end in
        match evaluate_arguments arguments with
        | Some values => primitive_eval m primitive values
        | None => None
        end
    end.

  Fixpoint eval_exprs (locals : gmap var (value Numeric))
      (expressions : list (expr Numeric)) : option (list (value Numeric)) :=
    match expressions with
    | [] => Some []
    | expression :: rest =>
        match eval_expr locals expression, eval_exprs locals rest with
        | Some result, Some results => Some (result :: results)
        | _, _ => None
        end
    end.

End Expressions.

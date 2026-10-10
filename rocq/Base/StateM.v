From Stdlib Require Import FunctionalExtensionality.
From UnifiedInterpreter.Base Require Import Lens Result.

Set Implicit Arguments.

(* Failure carries no successor state, so an atomic instruction cannot expose
   or commit a partially updated state after trapping. *)
Definition M (Err State A : Type) : Type :=
  State -> result Err (A * State).

Definition pure {Err State A} (value : A) : M Err State A :=
  fun state => Ok (value, state).

Definition bind {Err State A B}
    (computation : M Err State A)
    (next : A -> M Err State B) : M Err State B :=
  fun state =>
    match computation state with
    | Ok (value, state') => next value state'
    | Error error => Error error
    end.

Definition fail {Err State A} (error : Err) : M Err State A :=
  fun _ => Error error.

Definition get {Err State} : M Err State State :=
  fun state => Ok (state, state).

Definition put {Err State} (state : State) : M Err State unit :=
  fun _ => Ok (tt, state).

Definition modify {Err State} (f : State -> State) : M Err State unit :=
  fun state => Ok (tt, f state).

Definition zoom {Err State Component A}
    (lens : Lens State Component)
    (computation : M Err Component A) : M Err State A :=
  fun state =>
    match computation (lens_get lens state) with
    | Ok (value, component') =>
        Ok (value, lens_put lens component' state)
    | Error error => Error error
    end.

Notation "x <- computation ;; next" :=
  (bind computation (fun x => next))
  (at level 100, computation at next level, right associativity).

Notation "computation ;; next" :=
  (bind computation (fun _ => next))
  (at level 100, right associativity).

Lemma zoom_pure {Err State Component A}
    (lens : Lens State Component) `{LawfulLens State Component lens}
    (value : A) :
  @zoom Err State Component A lens (pure value) = pure value.
Proof.
  apply functional_extensionality; intro state.
  cbn. rewrite lens_put_get. reflexivity.
Qed.

Lemma zoom_preserves_independent_view
    {Err State Changed Observed A}
    (changed : Lens State Changed) (observed : Lens State Observed)
    `{IndependentLenses State Changed Observed changed observed}
    (computation : M Err Changed A)
    (state state' : State) (value : A) :
  zoom changed computation state = Ok (value, state') ->
  lens_get observed state' = lens_get observed state.
Proof.
  unfold zoom. destruct (computation (lens_get changed state)) as [[v c]|error];
    intro result; inversion result; subst.
  apply lens_get_put_other.
Qed.

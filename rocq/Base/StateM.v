From Stdlib Require Import List FunctionalExtensionality.
From UnifiedInterpreter.Base Require Import Lens.

Import ListNotations.
Set Implicit Arguments.

Inductive exec_result (Event Error State A : Type) : Type :=
| ExecOk : A -> State -> list Event -> exec_result Event Error State A
| ExecError : Error -> State -> list Event -> exec_result Event Error State A.

Arguments ExecOk {Event Error State A} _ _ _.
Arguments ExecError {Event Error State A} _ _ _.

Definition M (Event Error State A : Type) : Type :=
  State -> exec_result Event Error State A.

Definition pure {Event Error State A} (value : A)
    : M Event Error State A :=
  fun state => ExecOk value state [].

Definition bind {Event Error State A B}
    (computation : M Event Error State A)
    (next : A -> M Event Error State B)
    : M Event Error State B :=
  fun state =>
    match computation state with
    | ExecOk value state' events =>
        match next value state' with
        | ExecOk result state'' events' =>
            ExecOk result state'' (events ++ events')
        | ExecError error state'' events' =>
            ExecError error state'' (events ++ events')
        end
    | ExecError error state' events => ExecError error state' events
    end.

Definition fail {Event Error State A} (error : Error)
    : M Event Error State A :=
  fun state => ExecError error state [].

Definition emit {Event Error State} (event : Event)
    : M Event Error State unit :=
  fun state => ExecOk tt state [event].

Definition get {Event Error State} : M Event Error State State :=
  fun state => ExecOk state state [].

Definition put {Event Error State} (state : State)
    : M Event Error State unit :=
  fun _ => ExecOk tt state [].

Definition modify {Event Error State} (f : State -> State)
    : M Event Error State unit :=
  fun state => ExecOk tt (f state) [].

Definition zoom {Event Error State Component A}
    (lens : Lens State Component)
    (computation : M Event Error Component A)
    : M Event Error State A :=
  fun state =>
    match computation (lens_get lens state) with
    | ExecOk value component' events =>
        ExecOk value (lens_put lens component' state) events
    | ExecError error component' events =>
        ExecError error (lens_put lens component' state) events
    end.

Notation "x <- computation ;; next" :=
  (bind computation (fun x => next))
  (at level 100, computation at next level, right associativity).

Notation "computation ;; next" :=
  (bind computation (fun _ => next))
  (at level 100, right associativity).

Lemma zoom_pure {Event Error State Component A}
    (lens : Lens State Component) `{LawfulLens State Component lens}
    (value : A) :
  @zoom Event Error State Component A lens (pure value) = pure value.
Proof.
  apply functional_extensionality; intro state.
  cbn. rewrite lens_put_get. reflexivity.
Qed.

Lemma zoom_preserves_independent_view
    {Event Error State Changed Observed A}
    (changed : Lens State Changed) (observed : Lens State Observed)
    `{IndependentLenses State Changed Observed changed observed}
    (computation : M Event Error Changed A)
    (state state' : State) (value : A) (events : list Event) :
  zoom changed computation state = ExecOk value state' events ->
  lens_get observed state' = lens_get observed state.
Proof.
  unfold zoom. destruct (computation (lens_get changed state));
    intro result; inversion result; subst.
  apply lens_get_put_other.
Qed.

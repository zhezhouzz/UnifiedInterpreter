Set Implicit Arguments.

Record Lens (S C : Type) : Type := {
  lens_get : S -> C;
  lens_put : C -> S -> S
}.

Arguments lens_get {S C} _ _.
Arguments lens_put {S C} _ _ _.

(* Laws are separated from the computational lens and erased by extraction. *)
Class LawfulLens {S C : Type} (lens : Lens S C) : Prop := {
  lens_get_put :
    forall (state : S) (component : C),
      lens_get lens (lens_put lens component state) = component;
  lens_put_get :
    forall state : S,
      lens_put lens (lens_get lens state) state = state;
  lens_put_put :
    forall (state : S) (first second : C),
      lens_put lens second (lens_put lens first state) =
      lens_put lens second state
}.

Class IndependentLenses {S Left Right : Type}
    (left : Lens S Left) (right : Lens S Right) : Prop := {
  lens_get_put_other :
    forall (state : S) (component : Left),
      lens_get right (lens_put left component state) =
      lens_get right state;
  lens_put_commute :
    forall (state : S) (left_component : Left) (right_component : Right),
      lens_put right right_component
        (lens_put left left_component state) =
      lens_put left left_component
        (lens_put right right_component state)
}.

Definition lens_compose {Outer Inner Component : Type}
    (outer : Lens Outer Inner) (inner : Lens Inner Component)
    : Lens Outer Component :=
  {| lens_get := fun state => lens_get inner (lens_get outer state);
     lens_put := fun component state =>
       lens_put outer
         (lens_put inner component (lens_get outer state))
         state |}.

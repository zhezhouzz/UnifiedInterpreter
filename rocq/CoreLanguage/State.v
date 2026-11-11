From Stdlib Require Import List.
From stdpp Require Import gmap.
From UnifiedInterpreter.CoreLanguage Require Import Syntax.

Set Implicit Arguments.

Inductive operation_state (Numeric : Type) : Type :=
| Reading (remaining : gset address) (collected : gmap address (value Numeric))
| Writing (remaining : gset address) (contents : gmap address (value Numeric))
| Computing (kind : exec_kind) (function : function_id)
    (arguments : list (value Numeric))
| Done (result : value Numeric).

Arguments Reading {Numeric} _ _.
Arguments Writing {Numeric} _ _.
Arguments Computing {Numeric} _ _ _.
Arguments Done {Numeric} _.

Record pipeline_state (Numeric : Type) := {
  pipeline_code : command Numeric;
  pipeline_locals : gmap var (value Numeric);
  pipeline_operation : option (operation_state Numeric)
}.

Arguments pipeline_code {Numeric} _.
Arguments pipeline_locals {Numeric} _.
Arguments pipeline_operation {Numeric} _.

Record machine (Numeric : Type) := {
  memory : gmap address (value Numeric);
  flags : gmap event_key bool;
  locks : gmap lock_id (option pipeline_id);
  pipelines : gmap pipeline_id (pipeline_state Numeric)
}.

Arguments memory {Numeric} _.
Arguments flags {Numeric} _.
Arguments locks {Numeric} _.
Arguments pipelines {Numeric} _.

Definition set_memory {Numeric} (s : machine Numeric)
    (new_memory : gmap address (value Numeric)) : machine Numeric :=
  {| memory := new_memory; flags := flags s; locks := locks s;
     pipelines := pipelines s |}.

Definition set_flags {Numeric} (s : machine Numeric)
    (new_flags : gmap event_key bool) : machine Numeric :=
  {| memory := memory s; flags := new_flags; locks := locks s;
     pipelines := pipelines s |}.

Definition set_locks {Numeric} (s : machine Numeric)
    (new_locks : gmap lock_id (option pipeline_id)) : machine Numeric :=
  {| memory := memory s; flags := flags s; locks := new_locks;
     pipelines := pipelines s |}.

Definition set_pipelines {Numeric} (s : machine Numeric)
    (new_pipelines : gmap pipeline_id (pipeline_state Numeric)) : machine Numeric :=
  {| memory := memory s; flags := flags s; locks := locks s;
     pipelines := new_pipelines |}.

Definition set_code {Numeric} (t : pipeline_state Numeric)
    (new_code : command Numeric) : pipeline_state Numeric :=
  {| pipeline_code := new_code; pipeline_locals := pipeline_locals t;
     pipeline_operation := pipeline_operation t |}.

Definition set_locals {Numeric} (t : pipeline_state Numeric)
    (new_locals : gmap var (value Numeric)) : pipeline_state Numeric :=
  {| pipeline_code := pipeline_code t; pipeline_locals := new_locals;
     pipeline_operation := pipeline_operation t |}.

Definition set_operation {Numeric} (t : pipeline_state Numeric)
    (operation : option (operation_state Numeric)) : pipeline_state Numeric :=
  {| pipeline_code := pipeline_code t; pipeline_locals := pipeline_locals t;
     pipeline_operation := operation |}.

Definition program (Numeric : Type) := gmap pipeline_id (command Numeric).

Definition initial_machine {Numeric} (m : model Numeric) (code : program Numeric)
    (initial_memory : gmap address (value Numeric))
    (initial_locals : gmap pipeline_id (gmap var (value Numeric))) : machine Numeric :=
  {| memory := initial_memory;
     flags := gset_to_gmap false (declared_events m);
     locks := (fun _ => None) <$> lock_participants m;
     pipelines := map_imap (fun p commands => Some
       {| pipeline_code := commands;
          pipeline_locals := default ∅ (initial_locals !! p);
          pipeline_operation := None |}) code |}.

Definition initial_well_formed {Numeric} (m : model Numeric) (code : program Numeric)
    (initial_memory : gmap address (value Numeric))
    (initial_locals : gmap pipeline_id (gmap var (value Numeric))) : Prop :=
  well_formed_model m /\
  dom code = declared_pipelines m /\
  dom initial_locals ⊆ declared_pipelines m /\
  (forall a v, initial_memory !! a = Some v -> type_ok m a v = true).

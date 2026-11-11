From UnifiedInterpreter.CoreLanguage Require Import Syntax State.

Inductive label (Numeric : Type) : Type :=
| LAssign (p : pipeline_id) (x : var) (v : value Numeric)
| LControl (p : pipeline_id)
| LBegin (p : pipeline_id) (j : task_id) (operation : op Numeric)
| LRead (p : pipeline_id) (j : task_id) (a : address) (v : value Numeric)
| LWrite (p : pipeline_id) (j : task_id) (a : address) (v : value Numeric)
| LFinish (p : pipeline_id) (j : task_id)
| LJoin (p : pipeline_id) (j : task_id)
| LSet (p : pipeline_id) (event : event_key)
| LWait (p : pipeline_id) (event : event_key)
| LAcquire (p : pipeline_id) (lock : lock_id)
| LRelease (p : pipeline_id) (lock : lock_id)
| LError (p : pipeline_id).

Arguments LAssign {Numeric} _ _ _.
Arguments LControl {Numeric} _.
Arguments LBegin {Numeric} _ _ _.
Arguments LRead {Numeric} _ _ _ _.
Arguments LWrite {Numeric} _ _ _ _.
Arguments LFinish {Numeric} _ _.
Arguments LJoin {Numeric} _ _.
Arguments LSet {Numeric} _ _.
Arguments LWait {Numeric} _ _.
Arguments LAcquire {Numeric} _ _.
Arguments LRelease {Numeric} _ _.
Arguments LError {Numeric} _.

Inductive configuration (Numeric : Type) : Type :=
| Running (state : machine Numeric)
| Error.

Arguments Running {Numeric} _.
Arguments Error {Numeric}.

Definition control_owner {Numeric} (event : label Numeric) : option pipeline_id :=
  match event with
  | LAssign p _ _ | LControl p | LBegin p _ _ | LJoin p _
  | LSet p _ | LWait p _ | LAcquire p _ | LRelease p _ | LError p => Some p
  | LRead _ _ _ _ | LWrite _ _ _ _ | LFinish _ _ => None
  end.

Definition task_event {Numeric} (event : label Numeric) : option task_id :=
  match event with
  | LBegin _ j _ | LRead _ j _ _ | LWrite _ j _ _ | LFinish _ j => Some j
  | _ => None
  end.

Definition access {Numeric} (event : label Numeric) : option (address * bool) :=
  match event with
  | LRead _ _ a _ => Some (a, false)
  | LWrite _ _ a _ => Some (a, true)
  | _ => None
  end.

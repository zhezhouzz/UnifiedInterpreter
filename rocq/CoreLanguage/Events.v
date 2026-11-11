From UnifiedInterpreter.CoreLanguage Require Import Syntax State.

Inductive label (Numeric : Type) : Type :=
| LAssign (p : pipeline_id) (x : var) (v : value Numeric)
| LControl (p : pipeline_id)
| LStart (p : pipeline_id) (operation : op Numeric)
| LRead (p : pipeline_id) (a : address) (v : value Numeric)
| LWrite (p : pipeline_id) (a : address) (v : value Numeric)
| LComplete (p : pipeline_id) (x : var) (v : value Numeric)
| LSet (p : pipeline_id) (event : event_key)
| LWait (p : pipeline_id) (event : event_key)
| LAcquire (p : pipeline_id) (lock : lock_id)
| LRelease (p : pipeline_id) (lock : lock_id)
| LError (p : pipeline_id).

Arguments LAssign {Numeric} _ _ _.
Arguments LControl {Numeric} _.
Arguments LStart {Numeric} _ _.
Arguments LRead {Numeric} _ _ _.
Arguments LWrite {Numeric} _ _ _.
Arguments LComplete {Numeric} _ _ _.
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

Definition event_owner {Numeric} (event : label Numeric) : pipeline_id :=
  match event with
  | LAssign p _ _ | LControl p | LStart p _ | LRead p _ _ | LWrite p _ _
  | LComplete p _ _ | LSet p _ | LWait p _ | LAcquire p _ | LRelease p _
  | LError p => p
  end.

Definition access {Numeric} (event : label Numeric) : option (address * bool) :=
  match event with
  | LRead _ a _ => Some (a, false)
  | LWrite _ a _ => Some (a, true)
  | _ => None
  end.

From Stdlib Require Import List.
From UnifiedInterpreter.Base Require Import Free Result StateM Lens.
From UnifiedInterpreter.Type Require Import MLIR.
From UnifiedInterpreter.Tensor Require Import Model.
From UnifiedInterpreter.Memory Require Import Model Effects Handler.
From UnifiedInterpreter.Unified Require Import State Events Errors.
From UnifiedInterpreter.HFusion Require Import Runtime.
From UnifiedInterpreter.HFusion.Semantics Require Import Memory.
From UnifiedInterpreter.HIVM Require Import Instr Numeric Value Semantics.

Set Implicit Arguments.

(* Evaluated requests: no parser, SSA evaluator or whole-program runner is
   hidden here. This dispatcher is the extraction-facing primitive API. *)
Inductive request (S : Type) :=
| BinaryRequest (op : binary_op) (a b : operand S) (dst : value S)
| UnaryRequest (op : unary_op) (src dst : value S)
| BroadcastRequest (src : operand S) (dst : value S) (dims : list nat)
| ReduceRequest (op : reduce_op) (src dst : value S) (dims : list nat)
| CastRequest (spec : cast_spec) (src dst : value S)
| MmadRequest (spec : mm_spec) (a b dst : value S)
| ReshapeRequest (expanding : bool) (src : value S)
    (target : list nat) (groups : list (list nat)).

Definition evaluate {S} `{Numeric S} (r : request S)
    : result runtime_error (value S) :=
  match r with
  | BinaryRequest op a b dst => sem_binary op a b dst
  | UnaryRequest op src dst => sem_unary op src dst
  | BroadcastRequest src dst dims => sem_broadcast src dst dims
  | ReduceRequest op src dst dims => sem_reduce op src dst dims
  | CastRequest spec src dst => sem_cast spec src dst
  | MmadRequest spec a b dst => sem_mmad spec a b dst
  | ReshapeRequest expanding src target groups =>
      sem_reshape expanding src target groups
  end.

Definition materialize {S} (v : runtime_tensor S)
    : memory_computation S (result runtime_error (value S)) :=
  t <-! materialize_runtime_tensor v ;;
  Return (match t with
    | Some t => Ok (DefinedTensor t)
    | None => Error InvalidShape end).

Definition write_result {S} (v : value S) (destination : descriptor_id)
    : memory_computation S (result runtime_error unit) :=
  match v with
  | EmptyTensor _ _ => Return (Error ReadUninitialized)
  | DefinedTensor t =>
      written <-! sem_bufferization_materialize_in_destination
        (OwnedTensor t) destination true ;;
      Return (if written then Ok tt else Error InvalidShape)
  end.

(* The inner error must be checked before committing the new component.
   No failed compound instruction leaks a partially updated state. *)
Definition local_memory {S A} (fuel : nat)
    (program : memory_computation S (result runtime_error A))
    : M runtime_error (memory_state S) (A * list event) :=
  fun memory =>
    match handle_memory fuel program memory with
    | Error e => Error e
    | Ok (Error e, _, _) => Error e
    | Ok (Ok v, memory', trace) => Ok ((v, trace), memory')
    end.

Definition run_memory {S State A} `{HasMemory S State} (fuel : nat)
    (program : memory_computation S (result runtime_error A))
    : M runtime_error State (A * list event) :=
  zoom memory_lens (local_memory fuel program).

Lemma run_memory_preserves_independent {S State A Other}
    `{HasMemory S State} (view : Lens State Other)
    `{IndependentLenses State (memory_state S) Other memory_lens view}
    fuel (program : memory_computation S (result runtime_error A)) st st' output :
  run_memory fuel program st = Ok (output, st') ->
  lens_get view st' = lens_get view st.
Proof.
  unfold run_memory, zoom.
  destruct (local_memory fuel program (lens_get memory_lens st))
    as [[v component]|e]; intro Hrun; inversion Hrun; subst.
  apply lens_get_put_other.
Qed.

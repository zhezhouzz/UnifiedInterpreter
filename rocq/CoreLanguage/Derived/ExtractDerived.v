From Stdlib Require Import List ZArith Bool Extraction ExtrOcamlBasic ExtrOcamlNatInt.
From UnifiedInterpreter.Base Require Import Free Result.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics Issue316 ResourceExamples.
From UnifiedInterpreter.CoreLanguage.Derived Require Import
  Refocusing Automaton CoreEffects Handlers Soundness DerivedExamples.
Import ListNotations.

(* -------------------------------------------------------------------------- *)
(* 供 OCaml 提取后直接运行的 Issue #316 具体实例（F16 := Z，exp_f16 := x + 100） *)
(* -------------------------------------------------------------------------- *)

Module DerivedExtractionDemo.
Import Issue316Validation SharedResourceValidation MemoryAndChoiceValidation.

Definition demo_exp_f16 (x : Z) : Z := (x + 100)%Z.

Definition demo_tile (v : Z) : @Tile Z :=
  {| elements := repeat v 1024;
     element_count := repeat_length v 1024 |}.

Definition demo_model : @computation_model (@Tile Z) nat issue_pipe issue_resource :=
  {| comp := fun r args res =>
       match r, args with
       | VectorUnit, [VFloat xs] => res = VFloat (map_tile demo_exp_f16 xs)
       | _, _ => res = VInt 0%Z
       end;
     comp_total := fun r args =>
       match r, args with
       | VectorUnit, [VFloat xs] => ex_intro _ (VFloat (map_tile demo_exp_f16 xs)) eq_refl
       | _, _ => ex_intro _ (VInt 0%Z) eq_refl
       end |}.

Lemma demo_model_implements : implements_vexp demo_exp_f16 demo_model.
Proof. intros xs res. reflexivity. Qed.

Definition demo_issue316_serialized :=
  issue316_run_serialized demo_model_implements (demo_tile 1) (demo_tile 2) (demo_tile 3).

Definition demo_issue316_overlapped :=
  issue316_run_overlapped demo_model_implements (demo_tile 1) (demo_tile 2) (demo_tile 3).

Definition demo_issue316_free_overlapped :=
  issue316_run_free_overlapped demo_model_implements (demo_tile 1) (demo_tile 2) (demo_tile 3).

Definition demo_issue316_summary
    (r : result step_error (@run_result (@Tile Z) nat issue_pipe issue_resource))
    : option (nat * nat * nat * bool * list Z) :=
  match r with
  | Error _ => None
  | Ok res =>
      let evs := rr_events res in
      let outs :=
        flat_map (fun v =>
          match v with
          | VFloat t => match elements t with x :: _ => [x] | [] => [] end
          | _ => []
          end) (vector_output_writes evs) in
      Some (length evs, rr_inflight_count res, max_inflight evs,
            check_double_buffer_overlap evs, outs)
  end.

Definition demo_issue316_serialized_summary :=
  demo_issue316_summary demo_issue316_serialized.

Definition demo_issue316_overlapped_summary :=
  demo_issue316_summary demo_issue316_overlapped.

Definition demo_issue316_free_overlapped_summary :=
  demo_issue316_summary demo_issue316_free_overlapped.

Definition demo_shared_order_01 := run_order_01.
Definition demo_shared_order_10 := run_order_10.
Definition demo_overwrite := run_overwrite.
Definition demo_uninit_permissive := run_uninit_permissive.
Definition demo_loop_alloc := run_loop_alloc.

End DerivedExtractionDemo.

Extraction Language OCaml.
Set Extraction Output Directory "Extraction".

Extraction "derived_core_interpreter.ml"
  Refocusing.refocus
  Automaton.init_machine
  Automaton.exec_issue_branch
  Automaton.exec_finish_op
  Automaton.strict_choice_policy
  Automaton.permissive_choice_policy
  CoreEffects.denote_branch
  Handlers.serialized_policy
  Handlers.overlapped_round_robin_policy
  Handlers.scripted_policy
  Handlers.handle_core_effect
  Handlers.handle_finish_effect
  Handlers.run_derived_interpreter
  Handlers.run_free_interpreter
  Issue316Validation.issue316_exec_target
  Issue316Validation.issue316_exec_model
  Issue316Validation.vector_output_writes
  Issue316Validation.max_inflight
  Issue316Validation.check_double_buffer_overlap
  DerivedExtractionDemo.demo_issue316_serialized_summary
  DerivedExtractionDemo.demo_issue316_overlapped_summary
  DerivedExtractionDemo.demo_issue316_free_overlapped_summary
  DerivedExtractionDemo.demo_shared_order_01
  DerivedExtractionDemo.demo_shared_order_10
  DerivedExtractionDemo.demo_overwrite
  DerivedExtractionDemo.demo_uninit_permissive
  DerivedExtractionDemo.demo_loop_alloc.

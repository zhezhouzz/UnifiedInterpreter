From UnifiedInterpreter.CoreLanguage.Derived Require Import
  Refocusing Automaton CoreEffects Handlers Soundness Completeness DerivedExamples.

(* ========================================================================== *)
(* 顶层定理公理审计（Verification Ladder Step 2）                               *)
(* 所有派生解释器核心定理必须均打印 "Closed under the global context"              *)
(* ========================================================================== *)

Print Assumptions Soundness.automaton_sound.
Print Assumptions Soundness.derived_interpreter_sound.
Print Assumptions Soundness.free_interpreter_sound.
Print Assumptions Handlers.free_and_derived_equivalent.

Print Assumptions Completeness.automaton_complete.
Print Assumptions Completeness.automaton_iff_program_semantics.
Print Assumptions Completeness.derived_interpreter_complete.
Print Assumptions Completeness.free_interpreter_complete.

Print Assumptions DerivedExamples.Issue316Validation.issue316_serialized_valid.
Print Assumptions DerivedExamples.Issue316Validation.issue316_overlapped_valid.
Print Assumptions DerivedExamples.Issue316Validation.issue316_free_matches_and_valid.
Print Assumptions DerivedExamples.SharedResourceValidation.shared_resource_both_orders_derived.
Print Assumptions DerivedExamples.MemoryAndChoiceValidation.overwrite_observes_latest_completed_write.
Print Assumptions DerivedExamples.MemoryAndChoiceValidation.uninit_read_strict_rejects_scripted.
Print Assumptions DerivedExamples.MemoryAndChoiceValidation.uninit_read_strict_deadlocks_serialized.
Print Assumptions DerivedExamples.MemoryAndChoiceValidation.uninit_read_permissive_sound.
Print Assumptions DerivedExamples.MemoryAndChoiceValidation.loop_alloc_distinct_and_sound.
Print Assumptions DerivedExamples.MemoryAndChoiceValidation.early_async_strict_rejects.
Print Assumptions DerivedExamples.MemoryAndChoiceValidation.early_async_permissive_sound.
Print Assumptions DerivedExamples.MemoryAndChoiceValidation.open_bool_program_complete.

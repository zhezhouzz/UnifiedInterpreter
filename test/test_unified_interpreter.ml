let find_case id cases =
  List.find (fun (case : Unified_interpreter.Language.case) -> case.id = id) cases

let run_first case =
  let execution = Unified_interpreter.Report.execute case in
  List.hd execution.runs

let () =
  let open Unified_interpreter in
  let cases = Examples.cases () in
  assert (List.length cases = 3);
  List.iter
    (fun case ->
      let execution = Report.execute case in
      Report.agreement case execution
      |> List.iter (fun (_scope, diff) -> assert (diff <= 1e-5));
      let run = List.hd execution.runs in
      assert (run.scope = case.handler_stack);
      assert (Report.trace_contains run.state "H1 CV-before-map source");
      assert (Report.trace_contains run.state "H2 CV-core-map program_id");
      assert (Report.trace_contains run.state "H3 vector");
      assert (Report.trace_contains run.state "H4 on-chip-memory-map load");
      assert (Report.trace_contains run.state "H4 on-chip-memory-map store");
      assert (Report.trace_contains run.state "H5 alloc.local");
      assert (Report.trace_contains run.state "H5 async.copy.in");
      assert (Report.trace_contains run.state "H5 wait");
      assert (Report.trace_contains run.state "H5 barrier");
      assert (Report.trace_contains run.state "H5 async.copy.out");
      assert (not (Report.trace_contains run.state "H1 load"));
      assert (not (Report.trace_contains run.state "H1 fadd"));
      assert (not (Report.trace_contains run.state "H4 async.copy.in"));
      assert (not (Report.trace_contains run.state "H4 barrier"));
      match case.id with
      | "vector-add" ->
          assert (Report.trace_contains run.state "vector.fadd")
      | "vector-add-user-scoped" ->
          assert (run.scope = Language.source_to_simd_stack);
          assert (Report.trace_contains run.state "user.scope enter");
          assert (Report.trace_contains run.state "manual_h5_midpoint");
          assert (Report.trace_contains run.state "after_vector_fadd");
          assert (Report.trace_contains run.state "vector.fadd")
      | "fused-softmax" ->
          assert (Report.trace_contains run.state "vector.reduce.max");
          assert (Report.trace_contains run.state "vector.exp");
          assert (Report.trace_contains run.state "vector.reduce.sum")
      | _ -> assert false)
    cases;
  let ordinary = find_case "vector-add" cases |> run_first in
  let user_scoped = find_case "vector-add-user-scoped" cases |> run_first in
  let ordinary_out = Interpreter.tensor ordinary.state "out" in
  let user_scoped_out = Interpreter.tensor user_scoped.state "out" in
  assert (Tensor.max_abs_diff ordinary_out user_scoped_out <= 1e-5)

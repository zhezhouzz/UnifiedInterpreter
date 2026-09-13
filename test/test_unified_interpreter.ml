let find_case id cases =
  List.find (fun (case : Unified_interpreter.Language.case) -> case.id = id) cases

let find_input id inputs =
  List.find
    (fun (input : Unified_interpreter.Language.program_input) ->
      input.input_id = id)
    inputs

let run_first input =
  let execution = Unified_interpreter.Report.execute input in
  List.hd execution.runs

let () =
  let open Unified_interpreter in
  let cases = Examples.cases () in
  let inputs = Examples.program_inputs () in
  assert (List.length cases = 3);
  assert (List.length inputs = 3);
  List.iter
    (fun (input : Language.program_input) ->
      let case = input.case in
      let execution = Report.execute input in
      Report.agreement input execution
      |> List.iter (fun (_scope, diff) -> assert (diff <= 1e-5));
      let run = List.hd execution.runs in
      assert (run.scope = input.root_handlers);
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
          assert (input.root_handlers = Language.default_handler_stack);
          assert (Report.trace_contains run.state "vector.fadd")
      | "vector-add-user-scoped" ->
          assert (input.root_handlers = Language.source_to_simd_stack);
          assert (Report.trace_contains run.state "user.scope enter");
          assert (Report.trace_contains run.state "manual_h5_midpoint");
          assert (Report.trace_contains run.state "after_vector_fadd");
          assert (Report.trace_contains run.state "vector.fadd")
      | "fused-softmax" ->
          assert (Report.trace_contains run.state "vector.reduce.max");
          assert (Report.trace_contains run.state "vector.exp");
          assert (Report.trace_contains run.state "vector.reduce.sum")
      | _ -> assert false)
    inputs;
  let ordinary = find_input "vector-add-full-root" inputs |> run_first in
  let user_scoped = find_input "vector-add-user-root" inputs |> run_first in
  let ordinary_out = Interpreter.tensor ordinary.state "out" in
  let user_scoped_out = Interpreter.tensor user_scoped.state "out" in
  assert (Tensor.max_abs_diff ordinary_out user_scoped_out <= 1e-5);
  let vector_add = find_case "vector-add" cases in
  let custom_input =
    Examples.program_input ~input_id:"test-vector-add-custom"
      ~input_title:"Test Vector Add Custom Root"
      ~root_handlers:Language.default_handler_stack vector_add
  in
  let custom = run_first custom_input in
  assert (custom.scope = Language.default_handler_stack)

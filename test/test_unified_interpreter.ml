let () =
  let open Unified_interpreter in
  let cases = Examples.cases () in
  assert (List.length cases = 2);
  List.iter
    (fun case ->
      let execution = Report.execute case in
      Report.agreement case execution
      |> List.iter (fun (_scope, diff) -> assert (diff <= 1e-5));
      let run = List.hd execution.runs in
      assert (run.scope = Interpreter.H4_H3_H2_H1);
      assert (Report.trace_contains run.state "H1 source");
      assert (Report.trace_contains run.state "H2 bind program_id");
      assert (Report.trace_contains run.state "H3 vector");
      assert (Report.trace_contains run.state "H4 lower load");
      assert (Report.trace_contains run.state "H4 async.copy.in");
      assert (Report.trace_contains run.state "H4 lower store");
      assert (not (Report.trace_contains run.state "H1 load"));
      assert (not (Report.trace_contains run.state "H1 fadd"));
      match case.id with
      | "vector-add" ->
          assert (Report.trace_contains run.state "vector.fadd")
      | "fused-softmax" ->
          assert (Report.trace_contains run.state "vector.reduce.max");
          assert (Report.trace_contains run.state "vector.exp");
          assert (Report.trace_contains run.state "vector.reduce.sum")
      | _ -> assert false)
    cases

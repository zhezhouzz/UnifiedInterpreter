let () =
  let open Unified_interpreter in
  let cases = Examples.cases () in
  assert (List.length cases = 2);
  List.iter
    (fun case ->
      let execution = Report.execute case in
      Report.agreement case execution
      |> List.iter (fun (_scope, diff) -> assert (diff <= 1e-5));
      let run scope =
        List.find
          (fun (r : Report.run_result) -> r.scope = scope)
          execution.runs
      in
      let h3 = run Interpreter.H1_H3 in
      let h4 = run Interpreter.H1_H4 in
      let mixed = run Interpreter.H1_H4_H3 in
      assert (Report.trace_contains h3.state "H3 vector");
      assert (Report.trace_contains h4.state "H4 lower load");
      assert (Report.trace_contains h4.state "async.copy.in");
      assert (Report.trace_contains mixed.state "H3 vector");
      assert (Report.trace_contains mixed.state "H4 lower store");
      match case.id with
      | "vector-add" ->
          assert (Report.trace_contains mixed.state "vector.fadd")
      | "fused-softmax" ->
          assert (Report.trace_contains mixed.state "vector.reduce.max");
          assert (Report.trace_contains mixed.state "vector.exp");
          assert (Report.trace_contains mixed.state "vector.reduce.sum")
      | _ -> assert false)
    cases
